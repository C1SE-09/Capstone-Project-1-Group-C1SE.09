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
import subprocess
import tempfile
import uuid
from datetime import datetime, timezone
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
from app.core.storage import upload_audio_to_minio
from app.models.child import Child
from app.models.report import (
    ActivityCategory,
    ActivityEntry,
    DailyReport,
    DailyReportStatus,
    VoiceRecord,
    VoiceRecordStatus,
)
from app.models.user import Teacher
from app.schemas.report import (
    ActivityEntryResponse,
    DailyReportDetailResponse,
    DraftReportCreateRequest,
    ManualReportCreateRequest,
    SendAllItemResult,
    SendAllRequest,
    SendAllResponse,
    SendReportResponse,
    TranscriptUpdateRequest,
    VoiceRecordDetailResponse,
    VoiceRecordUploadResponse,
)
from app.services.extraction_service import extract_from_transcript
from app.services.notification_service import notification_service
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
    file: UploadFile = File(..., description="Audio file (.m4a / .wav / .mp3 / .webm)"),  # noqa: B008
    teacher_id: uuid.UUID = Form(..., description="UUID của teacher đang upload"),  # noqa: B008
    class_id: uuid.UUID = Form(..., description="UUID của lớp học liên quan"),  # noqa: B008
    child_id: uuid.UUID | None = Form(None, description="UUID của child liên quan"),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
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
        file_stem = Path(filename).stem or "recording"
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
    teacher_id: uuid.UUID = Query(  # noqa: B008
        ..., description="UUID của giáo viên — dùng để xác thực quyền sở hữu"
    ),
    db: Session = Depends(get_db),  # noqa: B008
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
    teacher_id: uuid.UUID = Query(  # noqa: B008
        ..., description="UUID của giáo viên — dùng để xác thực quyền sở hữu"
    ),
    db: Session = Depends(get_db),  # noqa: B008
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
    teacher_id: uuid.UUID = Query(..., description="UUID của giáo viên"),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
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
    teacher_id: uuid.UUID = Query(..., description="UUID của giáo viên"),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
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

    # Re-extract từ transcript đã chỉnh sửa. Chỉ persist nếu model chạy thành công.
    try:
        new_extraction = extract_from_transcript(payload.edited_transcript)
        # Model chỉ trả về các nhãn thực thể (meals/sleeping/...), nên bổ sung
        # transcript đã chỉnh sửa để frontend không ghi đè thành null.
        new_extraction["transcript"] = payload.edited_transcript
        voice_record.edited_transcript = payload.edited_transcript
        voice_record.transcription = payload.edited_transcript
        voice_record.extraction_result = new_extraction
        db.commit()
        db.refresh(voice_record)
        logger.info(
            "[ReExtract] VoiceRecord %s re-extracted từ edited transcript", voice_id
        )
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
    db: Session = Depends(get_db),  # noqa: B008
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
    today = datetime.now(timezone.utc).date()
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

    order = 0
    for key, category_str, title in mapping:
        value = result.get(key)
        if value:
            entry = ActivityEntry(
                daily_report_id=report.daily_report_id,
                category=ActivityCategory[category_str],
                title=title,
                description=value,
                entry_order=order,
            )
            db.add(entry)
            order += 1

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
    db: Session = Depends(get_db),  # noqa: B008
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
    today = datetime.now(timezone.utc).date()
    existing_report = (
        db.query(DailyReport)
        .filter(
            DailyReport.child_id == payload.child_id,
            DailyReport.report_date == today,
        )
        .first()
    )

    if existing_report:
        report = existing_report
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
            report_date=today,
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
        (payload.teacher_note, ActivityCategory.OTHER, "Ghi chú giáo viên"),
    ]

    order = 0
    for value, category, title in fields_mapping:
        if value and value.strip():
            entry = ActivityEntry(
                daily_report_id=report.daily_report_id,
                category=category,
                title=title,
                description=value.strip(),
                entry_order=order,
            )
            db.add(entry)
            order += 1

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
    teacher_id: uuid.UUID = Query(..., description="UUID của giáo viên"),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
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


@router.post("/reports/{report_id}/publish", summary="Publish báo cáo gửi phụ huynh")
def publish_report(
    report_id: uuid.UUID,
    teacher_id: uuid.UUID = Query(..., description="UUID của giáo viên"),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
):
    """Chuyển trạng thái báo cáo từ DRAFT → PUBLISHED và ghi nhận published_at."""
    report = (
        db.query(DailyReport).filter(DailyReport.daily_report_id == report_id).first()
    )

    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    if report.teacher_id != teacher_id:
        raise HTTPException(
            status_code=403, detail="Not authorized to publish this report"
        )

    report.status = DailyReportStatus.PUBLISHED
    report.published_at = datetime.now(timezone.utc).date()
    db.commit()
    db.refresh(report)

    return {
        "report_id": str(report.daily_report_id),
        "status": report.status.value,
        "published_at": report.published_at.isoformat(),
    }


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
    teacher_id: uuid.UUID,
    db: Session,
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

    # 2. Chủ sở hữu. Không sài `if teacher_id and ...`: bỏ qua check khi
    # thiếu teacher_id
    if report.teacher_id != teacher_id:
        db.rollback()
        raise HTTPException(
            status_code=403, detail="Not authorized to send this report"
        )

    # 3. Đã gửi rồi -> Trả 400
    if report.status == SENT_STATUS:
        db.rollback()
        raise ReportAlreadySentError(report_id)

    # 4. Chỉ gửi được từ draft
    if report.status != DailyReportStatus.DRAFT:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail=f"Report cannot be sent from status '{report.status.value}'",
        )

    # 5.  Phải có trẻ (child_id nullable trong schema)
    if report.child_id is None:
        db.rollback()
        raise HTTPException(status_code=400, detail="Report has no child assigned")

    # 6. Phải có nội dung đã chốt (>= 1 ActivityEntry).
    if not report.activities:
        db.rollback()
        raise HTTPException(status_code=400, detail="Report has no finalized content")

    child = report.child
    child_name = (child.nickname or child.full_name) if child else "be"
    linked_parents = 1 if (child and child.parent_id) else 0

    # 7. Đổi trạng thái, save thời điểm gửi, commit TRƯỚC khi tb..
    report.status = SENT_STATUS
    report.sent_at = datetime.now(timezone.utc)
    report.published_at = report.sent_at.date()  # sync w frontend
    db.commit()
    db.refresh(report)

    logger.info(
        "[Send] report_id=%s teacher_id=%s sent_at=%s",
        report.daily_report_id,
        teacher_id,
        report.sent_at,
    )

    # 8. Thông báo SAU commit. Provider lỗi != revert lần gửi này.
    targeted_devices = 0
    try:
        targeted_devices = notification_service.notify_report_sent(
            report_id=str(report.daily_report_id),
            child_id=str(report.child_id),
            child_name=child_name,
            linked_parents=linked_parents,
        )
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
    db: Session = Depends(get_db),  # noqa: B008
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
    db: Session = Depends(get_db),  # noqa: B008
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
