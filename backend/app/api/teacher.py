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

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.storage import upload_audio_to_minio
from app.models.report import (
    ActivityCategory,
    ActivityEntry,
    DailyReport,
    DailyReportStatus,
    VoiceRecord,
    VoiceRecordStatus,
)
from app.schemas.report import (
    DraftReportCreateRequest,
    TranscriptUpdateRequest,
    VoiceRecordDetailResponse,
    VoiceRecordUploadResponse,
)
from app.services.extraction_service import extract_from_transcript
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
    child_id: uuid.UUID = Form(..., description="UUID của child liên quan"),  # noqa: B008
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
    # 6. Tạo VoiceRecord trong DB
    # ------------------------------------------------------------------
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
    teacher_id: uuid.UUID | None = None,
    db: Session = Depends(get_db),  # noqa: B008
) -> VoiceRecordDetailResponse:
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if teacher_id and voice_record.teacher_id != teacher_id:
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
    teacher_id: uuid.UUID | None = None,
    db: Session = Depends(get_db),  # noqa: B008
) -> VoiceRecordDetailResponse:
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if teacher_id and voice_record.teacher_id != teacher_id:
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
    )


@router.post("/voice/{voice_id}/extract")
def extract_voice(
    voice_id: uuid.UUID,
    teacher_id: uuid.UUID,  # TODO: replace with get_current_user when auth is ready
    db: Session = Depends(get_db),  # noqa: B008
):
    # 1. Lấy VoiceRecord từ DB
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    # 2. Check not found
    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    # 3. Verify ownership
    if voice_record.teacher_id != teacher_id:
        raise HTTPException(
            status_code=403, detail="Not authorized to access this recording"
        )

    # 4. Check status == "done"
    if voice_record.status != VoiceRecordStatus.COMPLETED:
        raise HTTPException(status_code=400, detail="Transcript not ready")

    # 5. Lấy transcript (edited > raw)
    transcript = (
        voice_record.edited_transcript
        or voice_record.raw_transcript
        or voice_record.transcription
    )
    if not transcript:
        raise HTTPException(status_code=400, detail="No transcript found")

    # 6. Gọi extraction
    result = extract_from_transcript(transcript)

    # 7. Lưu vào DB
    voice_record.extraction_result = result
    db.commit()

    # 8. Return
    return {
        "voice_id": voice_id,
        "extraction": result,
    }

@router.post("/reports/draft")
def create_report_from_extraction(
    voice_id: uuid.UUID,
    teacher_id: uuid.UUID,
    payload: DraftReportCreateRequest | None = None,
    db: Session = Depends(get_db),  # noqa: B008
):
    # 1. Lấy VoiceRecord
    voice_record = (
        db.query(VoiceRecord).filter(VoiceRecord.voice_record_id == voice_id).first()
    )

    if not voice_record:
        raise HTTPException(status_code=404, detail="VoiceRecord not found")

    if voice_record.teacher_id != teacher_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    if not voice_record.child_id:
        raise HTTPException(status_code=400, detail="Please assign a child before creating report")

    if payload and payload.edited_extraction:
        result = payload.edited_extraction
        voice_record.extraction_result = result
    else:
        result = voice_record.extraction_result

    if not result:
        raise HTTPException(
            status_code=400,
            detail="No extraction result found. Please extract first.",
        )

    # 3. Tạo DailyReport
    today = datetime.now(timezone.utc).date()
    existing_report = db.query(DailyReport).filter(
        DailyReport.child_id == voice_record.child_id,
        DailyReport.report_date == today
    ).first()
    
    if existing_report:
        report = existing_report
        # Xoá các ActivityEntry cũ của báo cáo này trước khi ghi nhận lại
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
    
    return {
        "report_id": str(report.daily_report_id),
        "status": report.status.value
    }