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
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.storage import upload_audio_to_minio
from app.models.report import VoiceRecord, VoiceRecordStatus
from app.schemas.report import VoiceRecordUploadResponse
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
                "-v", "quiet",
                "-print_format", "json",
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
    except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError, ValueError):
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
            detail=(
                f"Định dạng file '{suffix}' không được hỗ trợ. "
                f"Chấp nhận: {', '.join(sorted(ALLOWED_EXTENSIONS))}"
            ),
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
        object_name = f"teacher_{teacher_id}_{uuid.uuid4()}{suffix}"
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
        child_id=None,          # Chưa gán cho bé cụ thể lúc upload
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
