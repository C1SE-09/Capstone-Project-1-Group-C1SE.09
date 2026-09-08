"""
app/tasks/process_audio.py
==========================
Celery task xử lý audio bất đồng bộ sau khi giáo viên upload file âm thanh.

Flow
----
    PENDING  ──► PROCESSING  ──► COMPLETED   (thành công)
                             └──► FAILED      (có exception)

Chi tiết
--------
1. Nhận ``voice_record_id`` (UUID str) từ API ngay sau khi upload xong.
2. Load ``VoiceRecord`` từ DB, xác nhận record tồn tại.
3. Cập nhật ``status = PROCESSING`` và flush để các client thấy ngay.
4. Tải file audio từ MinIO về file tạm trên disk.
5. Gọi ``stt_service.transcribe(tmp_path)`` để nhận văn bản.
6. Lưu kết quả vào ``VoiceRecord.transcription`` và đặt ``status = COMPLETED``.
7. Nếu bất kỳ bước nào ném exception:
   - Lưu traceback đầy đủ vào ``VoiceRecord.error_message``.
   - Đặt ``status = FAILED``.
   - Re-raise để Celery ghi nhận task thất bại (retry do caller quyết định).

Concurrency
-----------
Để tránh GPU OOM khi chạy nhiều inference song song, worker phải được khởi động
với ``--concurrency 2``:

    celery -A app.tasks.celery_app.celery_app worker \\
        --loglevel=info --concurrency 2 -Q audio

Worker command này giới hạn tối đa 2 STT task chạy đồng thời.
"""

from __future__ import annotations

import logging
import os
import tempfile
import traceback
import uuid
from urllib.request import urlretrieve

from app.core.database import SessionLocal
from app.models.report import VoiceRecord, VoiceRecordStatus
from app.services.stt_service import stt_service
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _download_audio(audio_url: str, suffix: str = ".wav") -> str:
    """
    Tải file audio từ URL (MinIO presigned / public URL) về file tạm trên disk.

    Parameters
    ----------
    audio_url : str
        URL công khai của file audio trên MinIO.
    suffix : str
        Đuôi file để ``tempfile`` tạo file tạm đúng extension.
        Được suy ra từ URL nếu có thể.

    Returns
    -------
    str
        Đường dẫn tuyệt đối đến file tạm đã tải về.

    Notes
    -----
    - Caller chịu trách nhiệm xóa file tạm sau khi dùng xong.
    - ``urlretrieve`` hoạt động với cả ``http://`` và ``https://``.
    """
    # Suy ra extension từ URL (vd: .m4a, .mp3, .wav)
    url_path = audio_url.split("?")[0]          # bỏ query string nếu có
    _, ext = os.path.splitext(url_path)
    if ext:
        suffix = ext

    # Tạo file tạm – delete=False để STTService có thể mở sau khi close
    tmp_fd, tmp_path = tempfile.mkstemp(suffix=suffix)
    os.close(tmp_fd)

    logger.debug("[process_audio] Đang tải audio từ %s → %s", audio_url, tmp_path)
    urlretrieve(audio_url, tmp_path)            # noqa: S310 (URL được lấy từ DB nội bộ)
    return tmp_path


# ---------------------------------------------------------------------------
# Celery Task
# ---------------------------------------------------------------------------

@celery_app.task(
    name="process_audio_task",
    bind=True,
    max_retries=0,          # Không tự retry – lỗi GPU/STT cần can thiệp thủ công
    acks_late=True,         # Chỉ ACK sau khi task hoàn thành (tránh mất task khi worker crash)
    queue="audio",          # Đưa vào queue riêng để dễ scale/priority
)
def process_audio_task(self, voice_record_id: str) -> dict:
    """
    Transcribe audio của một ``VoiceRecord`` và cập nhật kết quả vào DB.

    Parameters
    ----------
    voice_record_id : str
        UUID string của ``VoiceRecord`` cần xử lý.

    Returns
    -------
    dict
        ``{"voice_record_id": str, "status": "completed"}`` khi thành công.

    Raises
    ------
    Exception
        Re-raise bất kỳ exception nào để Celery đánh dấu task là FAILURE.
        Chi tiết traceback đã được lưu vào ``VoiceRecord.error_message``.
    """
    logger.info(
        "[process_audio_task] Bắt đầu xử lý voice_record_id=%s", voice_record_id
    )

    record_uuid = uuid.UUID(voice_record_id)
    tmp_path: str | None = None

    db = SessionLocal()
    try:
        # ------------------------------------------------------------------
        # 1. Load VoiceRecord
        # ------------------------------------------------------------------
        record: VoiceRecord | None = (
            db.query(VoiceRecord)
            .filter(VoiceRecord.voice_record_id == record_uuid)
            .first()
        )
        if record is None:
            raise ValueError(
                f"VoiceRecord với id={voice_record_id} không tồn tại trong DB."
            )

        # ------------------------------------------------------------------
        # 2. PENDING → PROCESSING
        # ------------------------------------------------------------------
        logger.info(
            "[process_audio_task] Cập nhật status → PROCESSING cho id=%s",
            voice_record_id,
        )
        record.status = VoiceRecordStatus.PROCESSING
        record.error_message = None          # xóa lỗi cũ nếu đây là lần retry thủ công
        db.commit()
        db.refresh(record)

        # ------------------------------------------------------------------
        # 3. Tải audio từ MinIO về file tạm
        # ------------------------------------------------------------------
        audio_url: str = record.audio_url
        logger.info(
            "[process_audio_task] Tải audio từ URL: %s", audio_url
        )
        tmp_path = _download_audio(audio_url)

        # ------------------------------------------------------------------
        # 4. STT: transcribe audio
        # ------------------------------------------------------------------
        logger.info(
            "[process_audio_task] Gọi STTService.transcribe() cho file: %s", tmp_path
        )
        raw_transcript: str = stt_service.transcribe(tmp_path)
        logger.info(
            "[process_audio_task] Transcription hoàn thành (%d ký tự) cho id=%s",
            len(raw_transcript),
            voice_record_id,
        )

        # ------------------------------------------------------------------
        # 5. Lưu transcript và cập nhật COMPLETED
        # ------------------------------------------------------------------
        record.transcription = raw_transcript
        record.status = VoiceRecordStatus.COMPLETED
        db.commit()

        logger.info(
            "[process_audio_task] Hoàn thành thành công voice_record_id=%s",
            voice_record_id,
        )
        return {"voice_record_id": voice_record_id, "status": "completed"}

    except Exception as exc:
        # ------------------------------------------------------------------
        # 6. Xử lý lỗi: lưu traceback → FAILED
        # ------------------------------------------------------------------
        tb = traceback.format_exc()
        logger.error(
            "[process_audio_task] LỖI khi xử lý voice_record_id=%s:\n%s",
            voice_record_id,
            tb,
        )

        # Cố gắng ghi lỗi vào DB – dùng transaction mới để tránh bị rollback
        try:
            db.rollback()
            record_for_error: VoiceRecord | None = (
                db.query(VoiceRecord)
                .filter(VoiceRecord.voice_record_id == record_uuid)
                .first()
            )
            if record_for_error is not None:
                record_for_error.status = VoiceRecordStatus.FAILED
                record_for_error.error_message = tb[:4096]   # giới hạn 4 KB
                db.commit()
        except Exception as db_exc:                          # noqa: BLE001
            logger.error(
                "[process_audio_task] Không thể cập nhật trạng thái FAILED vào DB: %s",
                db_exc,
            )

        raise exc   # re-raise để Celery đánh dấu task FAILURE

    finally:
        # ------------------------------------------------------------------
        # Dọn dẹp: đóng DB session và xóa file tạm
        # ------------------------------------------------------------------
        db.close()
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
                logger.debug("[process_audio_task] Đã xóa file tạm: %s", tmp_path)
            except OSError as e:
                logger.warning(
                    "[process_audio_task] Không thể xóa file tạm %s: %s", tmp_path, e
                )
