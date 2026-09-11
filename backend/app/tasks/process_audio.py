"""backend/app/tasks/process_audio.py
Celery task nhận dạng âm thanh (STT) chạy ngầm và lưu kết quả vào VoiceRecord.
"""

import logging
import os
import shutil
import tempfile
import traceback
import uuid
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

from sqlalchemy.exc import SQLAlchemyError

from app.core.database import SessionLocal
from app.models.report import VoiceRecord, VoiceRecordStatus
from app.services.stt_service import stt_service
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _download_audio(audio_url: str) -> str:
    """Tải file âm thanh từ URL lưu vào đĩa đệm tạm."""
    suffix = os.path.splitext(audio_url.partition("?")[0])[1] or ".wav"
    fd, tmp_path = tempfile.mkstemp(suffix=suffix)
    os.close(fd)
    try:
        with urlopen(audio_url, timeout=60) as resp, open(tmp_path, "wb") as out_file:
            shutil.copyfileobj(resp, out_file)
        return tmp_path
    except (HTTPError, URLError, OSError):
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass
        raise


@celery_app.task(name="process_audio_task", acks_late=True, queue="audio")
def process_audio_task(voice_record_id: str) -> dict[str, str]:
    """Celery Task: Chạy PhoWhisper phiên âm audio và cập nhật CSDL."""
    record_id = uuid.UUID(voice_record_id)
    tmp_path: str | None = None
    db = SessionLocal()

    try:
        record = db.get(VoiceRecord, record_id)
        if not record:
            raise ValueError(f"VoiceRecord {voice_record_id} không tồn tại.")

        # Cập nhật trạng thái bắt đầu xử lý
        record.status = VoiceRecordStatus.PROCESSING
        record.error_message = None
        db.commit()

        # Tải file & thực hiện phiên âm bằng PhoWhisper
        tmp_path = _download_audio(record.audio_url)
        record.raw_transcript = stt_service.transcribe(tmp_path)
        record.status = VoiceRecordStatus.COMPLETED
        db.commit()

        logger.info("[STT Task] Hoàn tất VoiceRecord %s (%d ký tự)", voice_record_id, len(record.raw_transcript))
        return {"voice_record_id": voice_record_id, "status": VoiceRecordStatus.COMPLETED.value}

    except Exception:
        db.rollback()
        logger.exception("[STT Task] Thất bại khi xử lý VoiceRecord %s", voice_record_id)
        try:
            failed_record = db.get(VoiceRecord, record_id)
            if failed_record:
                failed_record.status = VoiceRecordStatus.FAILED
                failed_record.error_message = traceback.format_exc()
                db.commit()
        except SQLAlchemyError:
            db.rollback()
        raise

    finally:
        db.close()
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass
