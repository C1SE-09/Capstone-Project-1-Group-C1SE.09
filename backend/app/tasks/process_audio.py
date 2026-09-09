"""Celery task chạy PhoWhisper và lưu raw transcript vào VoiceRecord.

Luồng trạng thái của schema hiện tại:
    pending -> processing -> completed
                          -> failed (nếu có lỗi)

Task này chỉ nhận dạng audio thành text. Không phân tích, tóm tắt hay chỉnh sửa text.
"""

from __future__ import annotations

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
    """Tải audio từ object storage vào file tạm và trả về đường dẫn file.

    Dữ liệu được copy theo luồng thay vì đọc toàn bộ vào RAM. Đuôi file được
    giữ lại để FFmpeg/CTranslate2 nhận biết đúng định dạng audio.
    """
    url_without_query = audio_url.partition("?")[0]
    suffix = os.path.splitext(url_without_query)[1] or ".wav"
    file_descriptor, temporary_path = tempfile.mkstemp(suffix=suffix)
    os.close(file_descriptor)

    try:
        with (
            urlopen(audio_url, timeout=60) as response,
            open(temporary_path, "wb") as temporary_file,
        ):
            shutil.copyfileobj(response, temporary_file)
    except (HTTPError, URLError, OSError):
        try:
            os.remove(temporary_path)
        except OSError:
            logger.warning("[STT task] Không thể xóa file tải lỗi: %s", temporary_path)
        raise

    return temporary_path


@celery_app.task(
    name="process_audio_task",
    acks_late=True,
    reject_on_worker_lost=True,
    queue="audio",
)
def process_audio_task(voice_record_id: str) -> dict[str, str]:
    """Nhận dạng audio của VoiceRecord và chỉ lưu raw transcript.

    ``voice_record_id`` là chuỗi UUID vì khóa chính thực tế của model
    VoiceRecord là PostgreSQL UUID, không phải integer.
    """
    try:
        record_id = uuid.UUID(voice_record_id)
    except ValueError as exc:
        raise ValueError(f"voice_record_id không hợp lệ: {voice_record_id!r}") from exc

    temporary_path: str | None = None
    db = SessionLocal()

    try:
        record = db.get(VoiceRecord, record_id)
        if record is None:
            raise ValueError(f"VoiceRecord {voice_record_id} không tồn tại.")

        # Commit ngay để API/client quan sát được worker đã bắt đầu xử lý.
        record.status = VoiceRecordStatus.PROCESSING
        record.error_message = None
        db.commit()

        temporary_path = _download_audio(record.audio_url)
        raw_transcript = stt_service.transcribe(temporary_path)

        # PhoWhisper chỉ tạo text thô; model phân tích khác sẽ dùng field này.
        record.raw_transcript = raw_transcript
        record.status = VoiceRecordStatus.COMPLETED
        db.commit()

        logger.info(
            "[STT task] Hoàn tất VoiceRecord %s: %d ký tự.",
            voice_record_id,
            len(raw_transcript),
        )
        return {
            "voice_record_id": voice_record_id,
            "status": VoiceRecordStatus.COMPLETED.value,
        }

    except Exception:
        error_traceback = traceback.format_exc()
        logger.exception("[STT task] Xử lý VoiceRecord %s thất bại.", voice_record_id)

        # Transaction xử lý chính có thể đã lỗi, vì vậy phải rollback trước khi
        # mở transaction mới để lưu trạng thái error.
        try:
            db.rollback()
            failed_record = db.get(VoiceRecord, record_id)
            if failed_record is not None:
                failed_record.status = VoiceRecordStatus.FAILED
                failed_record.error_message = error_traceback
                db.commit()
        except SQLAlchemyError:
            db.rollback()
            logger.exception("[STT task] Không thể lưu trạng thái error vào DB.")
        raise

    finally:
        db.close()
        if temporary_path:
            try:
                os.remove(temporary_path)
            except FileNotFoundError:
                pass
            except OSError:
                logger.warning("[STT task] Không thể xóa file tạm: %s", temporary_path)
