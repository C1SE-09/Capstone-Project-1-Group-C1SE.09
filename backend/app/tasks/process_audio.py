from __future__ import annotations

import logging
import os
import tempfile
import traceback
import uuid
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

from app.core.database import SessionLocal
from app.models.report import VoiceRecord, VoiceRecordStatus
from app.services.stt_service import stt_service
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def _download_audio(audio_url: str) -> str:
    """Tải file audio từ URL (MinIO) về file tạm trên disk, trả về đường dẫn file tạm."""
    # Suy ra extension từ URL (bỏ query string) để STTService nhận đúng codec
    url_path = audio_url.split("?")[0]
    _, ext = os.path.splitext(url_path)
    suffix = ext if ext else ".wav"

    # delete=False để STTService có thể mở file sau khi đóng file descriptor
    tmp_fd, tmp_path = tempfile.mkstemp(suffix=suffix)
    try:
        os.close(tmp_fd)
        logger.debug("[process_audio] Đang tải audio: %s -> %s", audio_url, tmp_path)
        with urlopen(audio_url, timeout=60) as resp, open(tmp_path, "wb") as f:
            f.write(resp.read())
    except (OSError, URLError, HTTPError) as e:
        # Dọn dẹp file tạm nếu download thất bại
        try:
            os.remove(tmp_path)
        except OSError:
            pass
        raise

    return tmp_path


@celery_app.task(
    name="process_audio_task",
    bind=True,
    max_retries=0,      # Không tự retry — lỗi GPU/STT cần can thiệp thủ công
    acks_late=True,     # Chỉ ACK sau khi task hoàn thành, tránh mất task khi crash
    queue="audio",      # Queue riêng để scale STT worker độc lập
)
def process_audio_task(self, voice_record_id: str) -> dict:
    logger.info("[process_audio_task] Bắt đầu xử lý voice_record_id=%s", voice_record_id)

    try:
        record_uuid = uuid.UUID(voice_record_id)
    except ValueError as exc:
        raise ValueError(f"voice_record_id không hợp lệ: {voice_record_id!r}") from exc

    tmp_path: str | None = None
    db = SessionLocal()

    try:
        # 1. Load VoiceRecord từ DB
        record: VoiceRecord | None = (
            db.query(VoiceRecord)
            .filter(VoiceRecord.voice_record_id == record_uuid)
            .first()
        )
        if record is None:
            raise ValueError(f"VoiceRecord id={voice_record_id} không tồn tại trong DB.")

        # 2. Cập nhật trạng thái PROCESSING để client thấy ngay
        record.status = VoiceRecordStatus.PROCESSING
        record.error_message = None  # Xóa lỗi cũ nếu đây là lần retry thành công
        db.commit()
        db.refresh(record)

        # 3. Tải audio từ MinIO về file tạm
        tmp_path = _download_audio(record.audio_url)

        # 4. Transcribe bằng STTService (PhoWhisper)
        raw_transcript = stt_service.transcribe(tmp_path)
        logger.info("[process_audio_task] Transcribe hoàn thành: %d ký tự  id=%s",
                    len(raw_transcript), voice_record_id)

        # 5. Lưu kết quả và đánh dấu COMPLETED
        record.transcription = raw_transcript
        record.status = VoiceRecordStatus.COMPLETED
        db.commit()

        logger.info("[process_audio_task] COMPLETED  voice_record_id=%s", voice_record_id)
        return {
            "voice_record_id": voice_record_id,
            "status": "completed",
            "transcript": raw_transcript,  # Chỉ text, không phân tích
        }

    except Exception as exc:
        tb = traceback.format_exc()
        logger.error("[process_audio_task] LỖI voice_record_id=%s:\n%s", voice_record_id, tb)

        # Dùng transaction mới để ghi FAILED (tránh bị rollback cùng transaction lỗi)
        try:
            db.rollback()
            err_record = (
                db.query(VoiceRecord)
                .filter(VoiceRecord.voice_record_id == record_uuid)
                .first()
            )
            if err_record is not None:
                err_record.status = VoiceRecordStatus.FAILED
                err_record.error_message = tb[:4096]  # Giới hạn 4 KB
                db.commit()
        except (OSError, RuntimeError) as db_exc:
            logger.error("[process_audio_task] Không thể ghi FAILED vào DB: %s", db_exc)

        raise

    finally:
        # Luôn đóng DB session và xóa file tạm dù thành công hay thất bại
        db.close()
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
                logger.debug("[process_audio_task] Đã xóa file tạm: %s", tmp_path)
            except OSError as e:
                logger.warning("[process_audio_task] Không thể xóa file tạm %s: %s", tmp_path, e)
