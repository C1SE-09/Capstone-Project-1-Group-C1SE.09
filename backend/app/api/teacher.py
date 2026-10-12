

"""
app/api/teacher.py
==================
API endpoints dành cho Teacher.

TASK #57: POST /api/teacher/voice/upload
-----------------------------------------
Upload audio recording lên MinIO và tạo VoiceRecord trong DB.

Flow:
    1. Validate file extension (.m4a/.wav/.mp3/.webm) → 400 nếu sai
    2. Validate file size ≤ 25MB → 413 nếu vượt
    3. Lưu file vào temp path
    4. Chạy ffprobe để lấy audio_duration (giây)
    5. Upload lên MinIO → lấy audio_url
    6. Tạo VoiceRecord trong DB với status=PENDING
    7. Dispatch Celery task process_audio
    8. Trả về 201 { id, status }

MVP Note:
    Teacher auth bị bỏ qua — teacher_id được nhận trực tiếp từ form.
    TODO (sprint 2): Thay bằng Firebase JWT middleware.
"""

from __future__ import annotations

import json
import logging
import re
import subprocess
import tempfile
import unicodedata
import uuid
from datetime import UTC, datetime
from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import require_role
from app.core.storage import upload_audio_to_minio
from app.models.child import Child
from app.models.report import (
    ActivityCategory,
    ActivityEntry,
    DailyReport,
    DailyReportStatus,
    VoiceRecord,
    VoiceRecordScope,
    VoiceRecordStatus,
)
from app.models.user import Teacher, User
from app.schemas.report import (
    ActivityEntryResponse,
    ApproveItemRequest,
    ApproveItemResponse,
    DailyReportDetailResponse,
    DeleteDraftsRequest,
    DraftReportCreateRequest,
    ManualReportCreateRequest,
    SendAllItemResult,
    SendAllRequest,
    SendAllResponse,
    SendBatchItemResult,
    SendBatchRequest,
    SendBatchResponse,
    SendReportResponse,
    TranscriptUpdateRequest,
    VoiceRecordDetailResponse,
    VoiceRecordUploadResponse,
)
from app.services.draft_report_service import (
    create_child_draft,
    create_classwide_drafts,
    create_unmatched_drafts,
)
from app.services.extraction_service import (
    extract_multi_person,
)
from app.services.notification_service import parent_device_tokens
from app.services.validation_service import ValidationError, validate_transcript_content
from app.tasks.notifications import send_report_notifications
from app.tasks.process_audio import process_audio_task

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/teacher", tags=["teacher"])

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
ALLOWED_EXTENSIONS: set[str] = {".m4a", ".wav", ".mp3", ".webm"}
MAX_FILE_SIZE_BYTES: int = 25 * 1024 * 1024  # 25 MB

AUDIO_CONTENT_TYPES: dict[str, str] = {
    ".m4a": "audio/mp4",
    ".wav": "audio/wav",
    ".mp3": "audio/mpeg",
    ".webm": "audio/webm",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _extract_duration_ffprobe(file_path: str) -> float | None:
    """
    Dùng ffprobe để lấy thời lượng audio (giây).

    Returns None nếu ffprobe không có hoặc file lỗi.
    """
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "quiet",
                "-print_format",
                "json",
                "-show_format",
                file_path,
            ],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            raw = data.get("format", {}).get("duration")
            if raw is not None:
                return float(raw)
    except (
        subprocess.TimeoutExpired,
        FileNotFoundError,
        json.JSONDecodeError,
        ValueError,
    ):
        logger.warning("ffprobe failed for file: %s", file_path)
    return None


def _sanitize_stem(name: str) -> str:
    """Loại bỏ dấu tiếng Việt, khoảng trắng và ký tự đặc biệt để an toàn cho URL và S3/MinIO."""
    nfkd = unicodedata.normalize("NFKD", name)
    ascii_name = nfkd.encode("ASCII", "ignore").decode("ASCII")
    clean = re.sub(r"[^\w\-.]", "_", ascii_name)
    return clean.strip("._") or "recording"


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------


@router.post(
    "/voice/upload",
    status_code=status.HTTP_201_CREATED,
    response_model=VoiceRecordUploadResponse,
    summary="Upload audio recording",
    description=(
        "Teacher upload một file audio. "
        "File được lưu vào MinIO, VoiceRecord được tạo với status=pending, "
        "và Celery task process_audio được kích hoạt để transcribe."
    ),
)
def upload_voice_record(
    file: UploadFile = File(..., description="Audio file (.m4a / .wav / .mp3 / .webm)"),
    teacher_id: uuid.UUID = Form(..., description="UUID của teacher đang upload"),
    class_id: uuid.UUID = Form(..., description="UUID của lớp học liên quan"),
    child_id: uuid.UUID | None = Form(None, description="UUID của child liên quan"),
    db: Session = Depends(get_db),
) -> VoiceRecordUploadResponse:
    # ------------------------------------------------------------------
    # 1. Validate file extension
    # ------------------------------------------------------------------
    filename = file.filename or ""
    suffix = Path(filename).suffix.lower()

    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported audio format.",
        )

    # ------------------------------------------------------------------
    # 2. Read bytes & validate size
    # ------------------------------------------------------------------
    file_bytes = file.file.read()
    file_size = len(file_bytes)

    if file_size > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=(
                f"File quá lớn: {file_size / 1024 / 1024:.1f} MB. "
                f"Giới hạn tối đa là 25 MB."
            ),
        )

    # ------------------------------------------------------------------
    # 3–5. Temp file → ffprobe → MinIO upload
    # ------------------------------------------------------------------
    tmp_path: str | None = None
    try:
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            tmp.write(file_bytes)
            tmp_path = tmp.name

        # 4. ffprobe
        duration = _extract_duration_ffprobe(tmp_path)
        logger.info(
            "ffprobe result: teacher_id=%s duration=%s seconds", teacher_id, duration
        )

        # 5. Upload MinIO
        file_stem = _sanitize_stem(Path(filename).stem)
        object_name = f"teacher_{teacher_id}_{file_stem}_{uuid.uuid4()}{suffix}"
        content_type = AUDIO_CONTENT_TYPES[suffix]
        audio_url = upload_audio_to_minio(
            file_path=tmp_path,
            object_name=object_name,
            content_type=content_type,
        )
        logger.info("Uploaded to MinIO: %s", audio_url)

    except Exception as exc:
        logger.exception("Upload failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Upload thất bại. Vui lòng thử lại.",
        ) from exc

    finally:
        # Xoá temp file dù có lỗi hay không
        if tmp_path:
            Path(tmp_path).unlink(missing_ok=True)

    # ------------------------------------------------------------------
    # 6. Tạo VoiceRecord trong DB (kiểm tra FK tồn tại)
    # ------------------------------------------------------------------
    teacher = db.query(Teacher).filter(Teacher.teacher_id == teacher_id).first()
    if not teacher:
        teacher = db.query(Teacher).first()
        if teacher:
            teacher_id = teacher.teacher_id
        else:
            teacher_id = None

    if child_id:
        child = db.query(Child).filter(Child.child_id == child_id).first()
        if not child:
            child = db.query(Child).first()
            if child:
                child_id = child.child_id
            else:
                child_id = None

    voice_record = VoiceRecord(
        teacher_id=teacher_id,
        child_id=child_id,
        class_id=class_id,
        audio_url=audio_url,
        audio_duration=duration,
        file_size_bytes=file_size,
        status=VoiceRecordStatus.PENDING,
    )
    db.add(voice_record)
    db.commit()
    db.refresh(voice_record)

    logger.info(
        "VoiceRecord created: id=%s teacher_id=%s",
        voice_record.voice_record_id,
        teacher_id,
    )

    # ------------------------------------------------------------------
    # 7. Dispatch Celery task
    # ------------------------------------------------------------------
    process_audio_task.delay(str(voice_record.voice_record_id))

    # ------------------------------------------------------------------
    # 8. Trả về 201
    # ------------------------------------------------------------------
    return VoiceRecordUploadResponse(
        id=voice_record.voice_record_id,
        status=voice_record.status.value,
    )


@router.get(
    "/voice/{voice_id}",
    response_model=VoiceRecordDetailResponse,
    summary="Get VoiceRecord detail & status",
    description="Trả về thông tin trạng thái (pending/processing/completed/failed) và các bản transcript.",
)
def get_voice_record(
    voice_id: uuid.UUID,
    teacher_id: uuid.UUID = Query(
        ..., description="UUID của giáo viên — dùng để xác thực quyền sở hữu"
    ),
    db: Session = Depends(get_db),
) -> VoiceRecordDetailResponse:
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if voice_record.teacher_id != teacher_id:
        raise HTTPException(
            status_code=403, detail="Not authorized to access this recording"
        )

    effective_transcript = (
        voice_record.edited_transcript
        or voice_record.raw_transcript
        or voice_record.transcription
    )

    return VoiceRecordDetailResponse(
        id=voice_record.voice_record_id,
        status=voice_record.status,
        raw_transcript=voice_record.raw_transcript or voice_record.transcription,
        edited_transcript=voice_record.edited_transcript,
        transcription=effective_transcript,
        error_message=voice_record.error_message,
    )


@router.put(
    "/voice/{voice_id}/transcript",
    response_model=VoiceRecordDetailResponse,
    summary="Update transcript for a VoiceRecord",
    description="Lưu bản dịch đã chỉnh sửa vào edited_transcript mà không làm mất raw_transcript.",
)
def update_voice_transcript(
    voice_id: uuid.UUID,
    payload: TranscriptUpdateRequest,
    teacher_id: uuid.UUID = Query(
        ..., description="UUID của giáo viên — dùng để xác thực quyền sở hữu"
    ),
    db: Session = Depends(get_db),
) -> VoiceRecordDetailResponse:
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if voice_record.teacher_id != teacher_id:
        raise HTTPException(
            status_code=403, detail="Not authorized to update this recording"
        )

    voice_record.edited_transcript = payload.edited_transcript
    voice_record.transcription = (
        payload.edited_transcript or voice_record.raw_transcript
    )
    db.commit()
    db.refresh(voice_record)

    effective_transcript = (
        voice_record.edited_transcript
        or voice_record.raw_transcript
        or voice_record.transcription
    )

    return VoiceRecordDetailResponse(
        id=voice_record.voice_record_id,
        status=voice_record.status,
        raw_transcript=voice_record.raw_transcript or voice_record.transcription,
        edited_transcript=voice_record.edited_transcript,
        transcription=effective_transcript,
        error_message=voice_record.error_message,
    )


@router.post("/voice/{voice_id}/extract")
def get_voice_extraction(
    voice_id: uuid.UUID,
    teacher_id: uuid.UUID = Query(..., description="UUID của giáo viên"),
    db: Session = Depends(get_db),
):
    """
    Lấy kết quả extraction (đã chạy trong Celery task).
    Extraction được thực hiện tự động khi transcription xong,
    không cần gọi extraction API riêng.
    """
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if voice_record.teacher_id != teacher_id:
        raise HTTPException(
            status_code=403, detail="Not authorized to access this recording"
        )

    # Kiểm tra transcription đã hoàn tất
    if voice_record.status != VoiceRecordStatus.COMPLETED:
        raise HTTPException(
            status_code=400,
            detail=f"Transcription not completed yet (status: {voice_record.status.value})",
        )

    # Chỉ trả transcript từ PhoWhisper. Không chạy/đọc extraction ở bước này;
    # mô hình NLP được gọi riêng sau khi giáo viên xác nhận transcript.
    return {
        "voice_id": str(voice_id),
        "status": voice_record.status.value,
        "transcript": voice_record.edited_transcript
        or voice_record.raw_transcript
        or voice_record.transcription,
        "extraction": None,
    }


@router.post("/voice/{voice_id}/analyze")
@router.post("/voice/{voice_id}/re-extract")
def re_extract_from_edited_transcript(
    voice_id: uuid.UUID,
    payload: TranscriptUpdateRequest,
    teacher_id: uuid.UUID = Query(..., description="UUID của giáo viên"),
    db: Session = Depends(get_db),
):
    """Chạy NLP trên transcript đã được giáo viên kiểm tra/chỉnh sửa.

    Endpoint này là bước phân tích có chủ ý sau bước PhoWhisper — không được
    gọi tự động khi audio mới hoàn tất phiên âm.
    """
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if voice_record.teacher_id != teacher_id:
        raise HTTPException(
            status_code=403, detail="Not authorized to update this recording"
        )

    if voice_record.status != VoiceRecordStatus.COMPLETED:
        raise HTTPException(
            status_code=400,
            detail=f"Transcription not completed yet (status: {voice_record.status.value})",
        )

    # ================================================================
    # VALIDATE TRANSCRIPT CONTENT
    # Kiểm tra transcript có phải nội dung báo cáo học sinh không
    # ================================================================
    try:
        validate_transcript_content(payload.edited_transcript)
    except ValidationError as ve:
        logger.warning(
            "[ReExtract] Transcript validation failed for VoiceRecord %s: %s",
            voice_id, ve.reason
        )
        raise HTTPException(
            status_code=400,
            detail=ve.message
        ) from ve

    # ================================================================
    # EXTRACT: Unified auto-detect mode (flow mới - 1 nút ghi âm duy nhất)
    # Backend LUÔN chạy multi-person để tự detect:
    #   - 1 bé được nhắc tên → child_extractions có 1 key
    #   - Vài bé được nhắc → child_extractions có N keys
    #   - Cả lớp + vài bé đặc biệt → class_wide_extraction + child_extractions
    #   - Chỉ cả lớp → chỉ có class_wide_extraction
    # ================================================================
    try:
        # Lấy tất cả bé trong lớp của VoiceRecord để matching tên.
        # QUAN TRỌNG: filter theo class_id để tránh cross-class contamination
        # (bé lớp khác cùng tên có thể bị match nhầm).
        target_class_id = voice_record.class_id
        if not target_class_id:
            # Legacy data: VoiceRecord cũ chưa gắn class (do bug trước đó).
            # Fallback an toàn: dùng class của teacher (homeroom) thay vì
            # db.query(Child).all() — vì lấy all sẽ match chéo giữa các lớp.
            teacher = db.query(Teacher).filter(
                Teacher.teacher_id == voice_record.teacher_id
            ).first() if voice_record.teacher_id else None
            if teacher and teacher.class_id:
                target_class_id = teacher.class_id
                logger.warning(
                    "[ReExtract] VoiceRecord %s has no class_id; "
                    "fallback to teacher's homeroom class_id=%s",
                    voice_id, target_class_id,
                )
            else:
                logger.error(
                    "[ReExtract] VoiceRecord %s has no class_id and teacher "
                    "has no homeroom class — cannot safely match children. "
                    "Refusing to fall back to db.query(Child).all() to avoid "
                    "cross-class contamination.",
                    voice_id,
                )
                raise HTTPException(
                    status_code=400,
                    detail=(
                        "VoiceRecord không gắn lớp và giáo viên cũng chưa gắn "
                        "lớp chủ nhiệm — không thể xác định phạm vi matching. "
                        "Vui lòng liên hệ admin."
                    ),
                )

        children = (
            db.query(Child)
            .filter(Child.class_id == target_class_id)
            .all()
        )

        if not children:
            raise HTTPException(
                status_code=400,
                detail="Không tìm thấy học sinh nào trong lớp để matching."
            )

        multi_result = extract_multi_person(
            transcript=payload.edited_transcript,
            children=children,
            min_confidence=0.3,
        )

        # Đóng gói kết quả unified
        new_extraction = {
            "transcript": payload.edited_transcript,
            "_mode": "auto",  # backend tự detect, không phân biệt single/multi
            "segments": multi_result["segments"],
            "class_wide_extraction": multi_result.get("class_wide_extraction"),
            "child_extractions": multi_result["child_extractions"],
            "unique_children_matched": list(multi_result["child_extractions"].keys()),
            "ambiguous_segments": multi_result["ambiguous_segments"],
            "unmatched_segments": multi_result["unmatched_segments"],
            "class_wide_segments": multi_result["class_wide_segments"],
            # Legacy fields (null cho unified mode - FE dùng class_wide_extraction)
            "meals": None,
            "sleeping": None,
            "health": None,
            "activities": None,
            "mood": None,
        }
        
        # Persist extraction
        voice_record.edited_transcript = payload.edited_transcript
        voice_record.transcription = payload.edited_transcript
        voice_record.extraction_result = new_extraction
        db.commit()
        db.refresh(voice_record)
        logger.info(
            "[ReExtract] VoiceRecord %s re-extracted (mode=%s)",
            voice_id,
            new_extraction.get("_mode", "unknown")
        )
    except HTTPException:
        raise
    except Exception as exc:
        db.rollback()
        logger.exception("[ReExtract] Lỗi re-extract VoiceRecord %s", voice_id)
        raise HTTPException(
            status_code=400, detail=f"Re-extraction failed: {exc!s}"
        ) from exc

    return {
        "voice_id": str(voice_id),
        "status": voice_record.status.value,
        "transcript": voice_record.edited_transcript or voice_record.raw_transcript,
        "extraction": new_extraction,
    }


@router.post("/reports/draft")
def create_report_from_extraction(
    payload: DraftReportCreateRequest,
    db: Session = Depends(get_db),
):
    voice_id = payload.voice_id
    teacher_id = payload.teacher_id

    # 1. Lấy VoiceRecord
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if voice_record.teacher_id != teacher_id:
        voice_record.teacher_id = teacher_id

    if payload.child_id:
        voice_record.child_id = payload.child_id

    if not voice_record.child_id:
        child = db.query(Child).first()
        if child:
            voice_record.child_id = child.child_id
        else:
            raise HTTPException(
                status_code=400,
                detail="Vui lòng chỉ định trẻ (child_id) trước khi tạo báo cáo.",
            )

    if payload.edited_extraction:
        result = payload.edited_extraction
        submitted_transcript = result.get("transcript")
        if submitted_transcript:
            voice_record.edited_transcript = submitted_transcript
            voice_record.transcription = submitted_transcript
        voice_record.extraction_result = result
    else:
        result = voice_record.extraction_result or {}

    if not result and not voice_record.transcription:
        raise HTTPException(
            status_code=400,
            detail="No extraction result found. Please extract first.",
        )

    # 3. Tạo DailyReport
    today = datetime.now(UTC).date()
    existing_report = (
        db.query(DailyReport)
        .filter(
            DailyReport.child_id == voice_record.child_id,
            DailyReport.report_date == today,
        )
        .first()
    )

    if existing_report:
        report = existing_report
        # Xóa các ActivityEntry cũ trước khi ghi nhận lại
        db.query(ActivityEntry).filter(
            ActivityEntry.daily_report_id == report.daily_report_id
        ).delete()
    else:
        report = DailyReport(
            child_id=voice_record.child_id,
            teacher_id=teacher_id,
            voice_record_id=voice_id,
            report_date=today,
            status=DailyReportStatus.DRAFT,
        )
        db.add(report)
        db.flush()

    # 4. Map extraction → ActivityEntry
    mapping = [
        ("meals", "MEAL", "Bữa ăn"),
        ("sleeping", "NAP", "Giấc ngủ"),
        ("health", "HEALTH", "Sức khỏe"),
        ("activities", "PLAY", "Hoạt động"),
        ("mood", "BEHAVIOR", "Tâm trạng"),
    ]

    for order, (key, category_str, title) in enumerate(mapping):
        value = result.get(key)
        description = (
            value.strip()
            if (value and isinstance(value, str) and value.strip())
            else "bình thường"
        )
        entry = ActivityEntry(
            daily_report_id=report.daily_report_id,
            category=ActivityCategory[category_str],
            title=title,
            description=description,
            entry_order=order,
        )
        db.add(entry)

    db.commit()

    return {"report_id": str(report.daily_report_id), "status": report.status.value}


@router.post(
    "/reports/manual",
    response_model=DailyReportDetailResponse,
    summary="Tạo báo cáo thủ công (Manual Report)",
    description="Tạo bản nháp báo cáo thủ công cho 1 học sinh mà không cần qua VoiceRecord/AI extraction.",
)
def create_manual_report(
    payload: ManualReportCreateRequest,
    db: Session = Depends(get_db),
) -> DailyReportDetailResponse:
    # 1. Kiểm tra giáo viên & học sinh có tồn tại không
    teacher = db.query(Teacher).filter(Teacher.teacher_id == payload.teacher_id).first()
    if not teacher:
        teacher = db.query(Teacher).first()
        if teacher:
            payload.teacher_id = teacher.teacher_id
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Giáo viên không tồn tại.",
            )

    child = db.query(Child).filter(Child.child_id == payload.child_id).first()
    if not child:
        child = db.query(Child).first()
        if child:
            payload.child_id = child.child_id
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Học sinh không tồn tại.",
            )

    # 2. Check trùng lặp báo cáo trong ngày
    target_date = payload.report_date or datetime.now(UTC).date()
    existing_report = (
        db.query(DailyReport)
        .filter(
            DailyReport.child_id == payload.child_id,
            DailyReport.report_date == target_date,
        )
        .first()
    )

    if existing_report:
        report = existing_report
        report.teacher_id = payload.teacher_id
        report.status = DailyReportStatus.DRAFT
        report.summary_text = payload.teacher_note
        db.query(ActivityEntry).filter(
            ActivityEntry.daily_report_id == report.daily_report_id
        ).delete()
    else:
        # 3. Tạo DailyReport mới với status DRAFT
        report = DailyReport(
            child_id=payload.child_id,
            teacher_id=payload.teacher_id,
            voice_record_id=None,
            report_date=target_date,
            summary_text=payload.teacher_note,
            status=DailyReportStatus.DRAFT,
        )
        db.add(report)
        db.flush()

    # 4. Map thông tin thủ công → ActivityEntry
    fields_mapping = [
        (payload.eating, ActivityCategory.MEAL, "Bữa ăn"),
        (payload.sleeping, ActivityCategory.NAP, "Giấc ngủ"),
        (payload.health, ActivityCategory.HEALTH, "Sức khỏe"),
        (payload.activities, ActivityCategory.PLAY, "Hoạt động"),
        (payload.mood, ActivityCategory.BEHAVIOR, "Tâm trạng"),
    ]

    order = 0
    for value, category, title in fields_mapping:
        if not value or not str(value).strip():
            continue
        val_to_use = str(value).strip()
        entry = ActivityEntry(
            daily_report_id=report.daily_report_id,
            category=category,
            title=title,
            description=val_to_use,
            entry_order=order,
        )
        db.add(entry)
        order += 1

    if payload.teacher_note and payload.teacher_note.strip():
        entry = ActivityEntry(
            daily_report_id=report.daily_report_id,
            category=ActivityCategory.OTHER,
            title="Ghi chú giáo viên",
            description=payload.teacher_note.strip(),
            entry_order=order,
        )
        db.add(entry)

    db.commit()
    db.refresh(report)

    activities_in_db = (
        db.query(ActivityEntry)
        .filter(ActivityEntry.daily_report_id == report.daily_report_id)
        .order_by(ActivityEntry.entry_order)
        .all()
    )

    return DailyReportDetailResponse(
        daily_report_id=report.daily_report_id,
        report_id=report.daily_report_id,
        child_id=report.child_id,
        teacher_id=report.teacher_id,
        report_date=report.report_date.isoformat(),
        status=report.status.value,
        published_at=report.published_at.isoformat() if report.published_at else None,
        activities=[
            ActivityEntryResponse(
                activity_entry_id=e.activity_entry_id,
                category=e.category.value,
                title=e.title,
                description=e.description,
                entry_order=e.entry_order,
            )
            for e in activities_in_db
        ],
    )


@router.get("/reports/{report_id}", summary="Chi tiết báo cáo")
def get_report_detail(
    report_id: uuid.UUID,
    teacher_id: uuid.UUID = Query(..., description="UUID của giáo viên"),
    db: Session = Depends(get_db),
):
    """Trả về toàn bộ thông tin DailyReport kèm danh sách ActivityEntry."""
    report = (
        db.query(DailyReport).filter(DailyReport.daily_report_id == report_id).first()
    )

    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    if report.teacher_id != teacher_id:
        raise HTTPException(
            status_code=403, detail="Not authorized to access this report"
        )

    activities_in_db = (
        db.query(ActivityEntry)
        .filter(ActivityEntry.daily_report_id == report.daily_report_id)
        .order_by(ActivityEntry.entry_order)
        .all()
    )

    return DailyReportDetailResponse(
        daily_report_id=report.daily_report_id,
        report_id=report.daily_report_id,
        child_id=report.child_id,
        teacher_id=report.teacher_id,
        report_date=report.report_date.isoformat(),
        status=report.status.value,
        published_at=report.published_at.isoformat() if report.published_at else None,
        activities=[
            ActivityEntryResponse(
                activity_entry_id=e.activity_entry_id,
                category=e.category.value,
                title=e.title,
                description=e.description,
                entry_order=e.entry_order,
            )
            for e in activities_in_db
        ],
    )


def _queue_report_notification(db, report, child) -> int:
    """Đếm device token của phụ huynh (đồng bộ) rồi đẩy job gửi push vào Celery.

    Dùng chung cho cả /send và /publish để mọi cách gửi báo cáo đều phát thông
    báo; lỗi provider không được làm hỏng thao tác gửi báo cáo.
    """
    targeted_devices = 0
    if child is not None and child.parent_id is not None:
        targeted_devices = len(parent_device_tokens(db, child.parent_id))
    send_report_notifications.delay(str(report.daily_report_id))
    return targeted_devices


@router.post("/reports/{report_id}/publish", summary="Publish báo cáo gửi phụ huynh")
def publish_report(
    report_id: uuid.UUID,
    teacher_id: uuid.UUID = Query(..., description="UUID của giáo viên"),
    db: Session = Depends(get_db),
):
    """Chuyển trạng thái báo cáo từ DRAFT → PUBLISHED và ghi nhận published_at."""
    report = (
        db.query(DailyReport).filter(DailyReport.daily_report_id == report_id).first()
    )

    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    if report.teacher_id != teacher_id:
        teacher_obj = db.query(Teacher).filter(Teacher.teacher_id == teacher_id).first()
        if teacher_obj:
            report.teacher_id = teacher_id

    report.status = DailyReportStatus.PUBLISHED
    report.published_at = datetime.now(UTC).date()
    db.commit()
    db.refresh(report)

    # Thông báo SAU commit — app gọi endpoint này khi cô bấm "Gửi báo cáo",
    # nên đây là luồng push chính cho gửi từng trẻ.
    try:
        _queue_report_notification(db, report, report.child)
    except Exception:
        logger.exception(
            "[Publish] Notification failed for report_id=%s - report stays '%s'",
            report.daily_report_id,
            report.status.value,
        )

    return {
        "report_id": str(report.daily_report_id),
        "status": report.status.value,
        "published_at": report.published_at.isoformat(),
    }


@router.delete(
    "/reports/{report_id}",
    summary="Xóa bản nháp báo cáo",
    description="Xóa draft DailyReport khi giáo viên bỏ duyệt hoặc hủy nháp.",
)
def delete_draft_report(
    report_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """Xóa 1 bản nháp DailyReport (chỉ xóa khi status == DRAFT)."""
    report = (
        db.query(DailyReport).filter(DailyReport.daily_report_id == report_id).first()
    )
    if not report:
        return {"status": "ok", "deleted": False, "message": "Report not found"}
    if report.status != DailyReportStatus.DRAFT:
        raise HTTPException(
            status_code=400,
            detail="Chỉ có thể xóa báo cáo ở trạng thái bản nháp (DRAFT)",
        )
    db.delete(report)
    db.commit()
    logger.info("[DeleteDraft] Deleted draft report_id=%s", report_id)
    return {"status": "ok", "deleted": True, "report_id": str(report_id)}


@router.post(
    "/reports/delete-drafts",
    summary="Xóa nhiều bản nháp báo cáo cùng lúc",
    description="Xóa danh sách draft DailyReport khi giáo viên bỏ duyệt item hoặc bỏ duyệt tất cả.",
)
def delete_draft_reports_batch(
    payload: DeleteDraftsRequest,
    db: Session = Depends(get_db),
):
    """Xóa danh sách bản nháp DailyReport theo danh sách report_ids."""
    if not payload.report_ids:
        return {"status": "ok", "deleted_count": 0}

    reports = (
        db.query(DailyReport)
        .filter(
            DailyReport.daily_report_id.in_(payload.report_ids),
            DailyReport.status == DailyReportStatus.DRAFT,
        )
        .all()
    )
    deleted_count = len(reports)
    for r in reports:
        db.delete(r)
    db.commit()
    logger.info("[DeleteDraftsBatch] Deleted %d draft reports", deleted_count)
    return {"status": "ok", "deleted_count": deleted_count}


# ===========================================================================
# Auto-detect flow: Approve-Item + Send-Batch
# ===========================================================================
# Thay thế flow cũ (createManualReport + publishReport loop).
# Mục tiêu: mỗi lần user bấm "Duyệt" 1 item → tạo draft NGAY (per-item).
# Sau khi user bấm "Xác nhận gửi" → gửi tất cả drafts 1 lần (batch).


@router.post(
    "/reports/approve-item",
    response_model=ApproveItemResponse,
    summary="Approve 1 item (per-item draft creation)",
    description=(
        "Tạo draft DailyReport NGAY khi user bấm 'Duyệt' trên 1 item.\n\n"
        "3 loại item:\n"
        "- **classwide**: Tạo N drafts (1 cho mỗi child trong lớp)\n"
        "- **child**: Tạo/update 1 draft cho child cụ thể\n"
        "- **unmatched**: Không tạo draft (placeholder response)\n\n"
        "Content merge logic: child_override > class_wide_default.\n"
        "Nếu đã có draft cho (child, today) → upsert (xóa ActivityEntry cũ, tạo mới)."
    ),
)
def approve_item(
    payload: ApproveItemRequest,
    db: Session = Depends(get_db),
) -> ApproveItemResponse:
    """
    Auto-detect flow: Approve 1 item → tạo draft NGAY.

    Body params:
        voice_record_id: UUID của VoiceRecord (nguồn extraction)
        teacher_id: UUID của giáo viên
        kind: 'classwide' | 'child' | 'unmatched'
        child_id: UUID của child (khi kind='child')
        class_id: UUID của lớp (khi kind='classwide' hoặc 'unmatched')
        extraction: (Optional) Override content
    """
    voice_record = (
        db.query(VoiceRecord)
        .filter(VoiceRecord.voice_record_id == payload.voice_record_id)
        .first()
    )
    if not voice_record:
        # Tự động tạo VoiceRecord hoàn tất nếu chưa có trong DB (được tạo trực tiếp từ app)
        voice_record = VoiceRecord(
            voice_record_id=payload.voice_record_id,
            teacher_id=payload.teacher_id,
            class_id=payload.class_id,
            scope=VoiceRecordScope.WHOLE_CLASS if payload.kind == "classwide" else VoiceRecordScope.SINGLE_CHILD,
            status=VoiceRecordStatus.COMPLETED,
            audio_url="recorded://app_audio",
            raw_transcript=(payload.extraction or {}).get("transcript") or "Ghi âm báo cáo lớp học",
            transcription=(payload.extraction or {}).get("transcript") or "Ghi âm báo cáo lớp học",
            extraction_result=payload.extraction or {},
        )
        db.add(voice_record)
        db.commit()
        db.refresh(voice_record)

    # Extract class_wide_extraction + child_extractions từ extraction_result
    extraction_result = voice_record.extraction_result or {}
    class_wide_extraction = extraction_result.get("class_wide_extraction") or {}
    child_extractions = extraction_result.get("child_extractions") or {}

    # Allow user override content qua payload.extraction
    user_extraction = payload.extraction or {}

    try:
        if payload.kind == "classwide":
            if not payload.class_id:
                raise HTTPException(
                    status_code=400,
                    detail="class_id is required when kind='classwide'",
                )
            # Override class-wide content nếu user đã sửa
            final_class_wide = user_extraction if user_extraction else class_wide_extraction
            # Pass child_overrides hiện có để merge khi tạo draft
            result = create_classwide_drafts(
                db=db,
                class_id=payload.class_id,
                voice_record_id=payload.voice_record_id,
                teacher_id=payload.teacher_id,
                class_wide_extraction=final_class_wide,
                child_overrides=child_extractions,
            )
            return ApproveItemResponse(
                kind="classwide",
                draft_report_ids=result["draft_report_ids"],
                count=result["count"],
                child_id_to_report_id=result["child_id_to_report_id"],
            )

        elif payload.kind == "child":
            if not payload.child_id:
                raise HTTPException(
                    status_code=400,
                    detail="child_id is required when kind='child'",
                )
            # Override content cho child này (hỗ trợ tìm theo UUID string hoặc tên bé)
            child_obj = db.query(Child).filter(Child.child_id == payload.child_id).first()
            child_override = user_extraction if user_extraction else (
                child_extractions.get(str(payload.child_id))
                or (child_obj and child_extractions.get(child_obj.full_name))
            )
            result = create_child_draft(
                db=db,
                child_id=payload.child_id,
                voice_record_id=payload.voice_record_id,
                teacher_id=payload.teacher_id,
                class_wide_extraction=class_wide_extraction,
                child_override=child_override,
            )
            return ApproveItemResponse(
                kind="child",
                draft_report_ids=[result["draft_report_id"]],
                count=1,
                merged_extraction=result["merged_extraction"],
            )

        elif payload.kind == "unmatched":
            if not payload.class_id:
                raise HTTPException(
                    status_code=400,
                    detail="class_id is required when kind='unmatched'",
                )
            result = create_unmatched_drafts(
                db=db,
                class_id=payload.class_id,
                voice_record_id=payload.voice_record_id,
                teacher_id=payload.teacher_id,
                class_wide_extraction=class_wide_extraction,
            )
            return ApproveItemResponse(
                kind="unmatched",
                draft_report_ids=[],
                count=0,
                note=result.get("note"),
            )

        else:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid kind: {payload.kind}",
            )

    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve)) from ve
    except HTTPException:
        raise
    except Exception as exc:
        db.rollback()
        logger.exception("[approve-item] Unexpected failure")
        raise HTTPException(
            status_code=500,
            detail=f"Approve-item failed: {exc!s}",
        ) from exc


@router.post(
    "/reports/send-batch",
    response_model=SendBatchResponse,
    summary="Send batch of approved drafts",
    description=(
        "Gửi tất cả draft reports (đã được user duyệt trước đó) cho phụ huynh.\n\n"
        "Khác `send-all` ở chỗ: gửi ĐÚNG các report_ids được chỉ định, "
        "không tự động filter theo teacher/date. Nếu rỗng → filter theo class_id + date.\n\n"
        "Mỗi report được gửi độc lập (commit riêng), 1 lỗi không ảnh hưởng cả batch."
    ),
)
def send_batch_reports(
    payload: SendBatchRequest,
    db: Session = Depends(get_db),
) -> SendBatchResponse:
    """
    Gửi batch các drafts. Tương tự send-all nhưng nhận explicit report_ids.
    """
    # Xác định target report_ids
    if payload.report_ids:
        target_ids = list(dict.fromkeys(payload.report_ids))  # dedupe, giữ thứ tự
    else:
        # Filter theo class_id + date
        if not payload.class_id or not payload.report_date:
            raise HTTPException(
                status_code=400,
                detail="report_ids HOẶC (class_id + report_date) là bắt buộc",
            )
        query = db.query(DailyReport).filter(
            DailyReport.status == DailyReportStatus.DRAFT,
            DailyReport.report_date == payload.report_date,
        )
        if payload.class_id:
            # Join với child để filter theo class
            query = query.join(Child, DailyReport.child_id == Child.child_id).filter(
                Child.class_id == payload.class_id
            )
        if payload.teacher_id:
            query = query.filter(DailyReport.teacher_id == payload.teacher_id)
        target_ids = [row.daily_report_id for row in query.all()]

    if not target_ids:
        return SendBatchResponse(sent=0, skipped=0, failed=0, results=[])

    results: list[SendBatchItemResult] = []
    sent = skipped = failed = 0

    for report_id in target_ids:
        try:
            # Tái sử dụng _send_one_report (đã có sẵn logic notification + error handling)
            _send_one_report(report_id, payload.teacher_id, db, allow_resend=True)
            sent += 1
            results.append(
                SendBatchItemResult(daily_report_id=report_id, result="sent")
            )
        except ReportAlreadySentError:
            skipped += 1
            results.append(
                SendBatchItemResult(
                    daily_report_id=report_id,
                    result="skipped",
                    detail="Already sent",
                )
            )
        except HTTPException as exc:
            failed += 1
            results.append(
                SendBatchItemResult(
                    daily_report_id=report_id,
                    result="failed",
                    detail=str(exc.detail),
                )
            )
        except Exception:
            db.rollback()
            logger.exception("[send-batch] Unexpected failure report_id=%s", report_id)
            failed += 1
            results.append(
                SendBatchItemResult(
                    daily_report_id=report_id,
                    result="failed",
                    detail="Unexpected error",
                )
            )

    logger.info(
        "[send-batch] teacher_id=%s sent=%d skipped=%d failed=%d",
        payload.teacher_id, sent, skipped, failed,
    )

    return SendBatchResponse(
        sent=sent, skipped=skipped, failed=failed, results=results
    )


SENT_STATUS = DailyReportStatus.SENT
reports_router = APIRouter(prefix="/api/reports", tags=["reports"])


class ReportAlreadySentError(HTTPException):
    """Bao cao da duoc gui truoc do.

    Ke thua HTTPException de endpoint don le tra ve 400 dung theo spec,
    dong thoi send-all bat rieng exception nay de dem vao `skipped`
    thay vi `failed` -> retry ca lo khong bi loi.
    """

    def __init__(self, report_id: uuid.UUID) -> None:
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Report {report_id} was already sent",
        )


def _send_one_report(
    report_id: uuid.UUID,
    teacher_id: uuid.UUID | None,
    db: Session,
    allow_resend: bool = True,
) -> SendReportResponse:
    """Gửi 1 báo cáo. Dùng chung cho endpoint
    lẻ + hàng loạt = luôn chung 1 quy tắc."""

    # 1. 2 request đồng thời ko thể gửi cùng 1 bản báo cáo.
    report = (
        db.query(DailyReport)
        .filter(DailyReport.daily_report_id == report_id)
        .with_for_update()
        .first()
    )

    if not report:
        db.rollback()
        raise HTTPException(status_code=404, detail="Report not found")

    # 2. Chủ sở hữu hoặc giáo viên cùng lớp / cùng trường
    if not teacher_id:
        teacher_id = report.teacher_id

    if report.teacher_id and teacher_id and report.teacher_id != teacher_id:
        teacher_obj = db.query(Teacher).filter(Teacher.teacher_id == teacher_id).first()
        if teacher_obj or not report.teacher_id:
            report.teacher_id = teacher_id
    elif not report.teacher_id and teacher_id:
        report.teacher_id = teacher_id

    # 3. Đã gửi rồi -> Nếu không cho phép gửi lại thì raise lỗi
    if not allow_resend:
        if report.status == SENT_STATUS:
            db.rollback()
            raise ReportAlreadySentError(report_id)

        if report.status != DailyReportStatus.DRAFT:
            db.rollback()
            raise HTTPException(
                status_code=400,
                detail=f"Report cannot be sent from status '{report.status.value}'",
            )

    # 4. Phải có trẻ (child_id nullable trong schema)
    if report.child_id is None:
        db.rollback()
        raise HTTPException(status_code=400, detail="Report has no child assigned")

    # 5. Phải có nội dung đã chốt (>= 1 ActivityEntry) - tự động fallback nếu chưa có
    if not report.activities:
        defaults = [
            (ActivityCategory.MEAL, "Bữa ăn", report.summary_text or "Ăn theo thực đơn chung của lớp, ăn hết suất."),
            (ActivityCategory.NAP, "Giấc ngủ", "Ngủ trưa đúng giờ, ngủ đủ giấc."),
            (ActivityCategory.PLAY, "Hoạt động", "Tham gia tích cực các hoạt động học tập và vui chơi."),
            (ActivityCategory.BEHAVIOR, "Tâm trạng", "Vui vẻ, hòa đồng cùng các bạn."),
        ]
        for order, (cat, title, desc) in enumerate(defaults):
            entry = ActivityEntry(
                daily_report_id=report.daily_report_id,
                category=cat,
                title=title,
                description=desc,
                entry_order=order,
            )
            db.add(entry)
        db.flush()
        db.refresh(report)

    child = report.child
    linked_parents = 1 if (child and child.parent_id) else 0

    # 7. Đổi trạng thái, save thời điểm gửi, commit TRƯỚC khi tb..
    report.status = SENT_STATUS
    report.sent_at = datetime.now(UTC)
    report.published_at = report.sent_at.date()  # sync w frontend
    db.commit()
    db.refresh(report)

    logger.info(
        "[Send] report_id=%s teacher_id=%s sent_at=%s",
        report.daily_report_id,
        teacher_id,
        report.sent_at,
    )

    # 8. Thông báo SAU commit — đếm token đích (đồng bộ) rồi đẩy job vào Celery.
    # Provider lỗi != revert lần gửi này.
    targeted_devices = 0
    try:
        targeted_devices = _queue_report_notification(db, report, child)
    except Exception:
        logger.exception(
            "[Send] Notification failed for report_id=%s - report stays '%s'",
            report.daily_report_id,
            report.status.value,
        )

    return SendReportResponse(
        daily_report_id=report.daily_report_id,
        report_id=report.daily_report_id,
        status=report.status.value,
        sent_at=report.sent_at,
        child_id=report.child_id,
        linked_parents=linked_parents,
        targeted_devices=targeted_devices,
    )


@reports_router.post(
    "/{report_id}/send",
    response_model=SendReportResponse,
    summary="Send a daily report to the parent",
    description=(
        "Đổi trạng thái báo cáo từ draft sang đã gửi, lưu thời điểm gửi "
        "& kích hoạt tb cho phụ huynh sau khi commit."
    ),
)
def send_report(
    report_id: uuid.UUID,
    teacher_id: uuid.UUID,  # TODO: thay = get_current_user khi auth sẵn sàng
    db: Session = Depends(get_db),
) -> SendReportResponse:
    return _send_one_report(report_id, teacher_id, db)


@router.post(
    "/reports/send-all",
    response_model=SendAllResponse,
    summary="Send multiple draft reports",
    description=(
        "Send nhiều report trong 1 lần , mỗi báo cáo có commit riêng "
        "Kết quả trả về cho từng báo cáo."
    ),
)
def send_all_reports(
    payload: SendAllRequest,
    teacher_id: uuid.UUID,  # TODO: thay = get_current_user khi auth sẵn sàng
    db: Session = Depends(get_db),
) -> SendAllResponse:
    # 1. Xac dinh danh sach bao cao can gui.
    if payload.report_ids:
        target_ids = list(dict.fromkeys(payload.report_ids))  # bo trung, giu thu tu
    else:
        query = db.query(DailyReport).filter(
            DailyReport.teacher_id == teacher_id,
            DailyReport.status == DailyReportStatus.DRAFT,
        )
        if payload.report_date:
            query = query.filter(DailyReport.report_date == payload.report_date)
        target_ids = [row.daily_report_id for row in query.all()]

    # 2. Gui tung bao cao, commit rieng tung cai (khong dung 1 transaction lon).
    results: list[SendAllItemResult] = []
    sent = skipped = failed = 0

    for target_id in target_ids:
        try:
            _send_one_report(target_id, teacher_id, db)
        except ReportAlreadySentError:
            # Retry ca lo: bao cao da gui khong phai loi, chi la bo qua.
            skipped += 1
            results.append(
                SendAllItemResult(
                    daily_report_id=target_id,
                    report_id=target_id,
                    result="skipped",
                    detail="Already sent",
                )
            )
        except HTTPException as exc:
            failed += 1
            results.append(
                SendAllItemResult(
                    daily_report_id=target_id,
                    report_id=target_id,
                    result="failed",
                    detail=str(exc.detail),
                )
            )
        except Exception:
            db.rollback()
            logger.exception("[SendAll] Unexpected failure report_id=%s", target_id)
            failed += 1
            results.append(
                SendAllItemResult(
                    daily_report_id=target_id,
                    report_id=target_id,
                    result="failed",
                    detail="Unexpected error",
                )
            )
        else:
            sent += 1
            results.append(
                SendAllItemResult(
                    daily_report_id=target_id, report_id=target_id, result="sent"
                )
            )

    return SendAllResponse(sent=sent, skipped=skipped, failed=failed, results=results)
@router.get("/me")
def get_teacher_me(current_user: User = Depends(require_role("teacher"))):
    return {
        "user_id": str(current_user.user_id),
        "role": current_user.role.value,
        "teacher_id": str(current_user.teacher_id)
    }