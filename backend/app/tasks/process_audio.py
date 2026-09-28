"""Celery task: run PhoWhisper STT and save its raw transcript.

The LSTM/BIO extraction model is intentionally run later, after the teacher
reviews and confirms the transcript in the frontend.
"""

import logging
import os
import shutil
import subprocess
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


def _normalize_audio(src_path: str) -> str:
    """
    Chuẩn hoá audio bất kỳ (.m4a / .mp3 / .webm / .wav) về WAV 16kHz mono.

    PhoWhisper (faster-whisper) chỉ giải mã chắc chắn với WAV PCM; các định dạng
    nén như .m4a (AAC) hoặc .webm (Opus) cần ffmpeg để chuyển đổi trước khi STT.
    Trả về đường dẫn file WAV mới, hoặc chính src_path nếu ffmpeg không khả dụng.
    """
    suffix = os.path.splitext(src_path)[1].lower()
    if suffix == ".wav":
        return src_path

    fd, dst_path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)

    try:
        result = subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-v",
                "error",
                "-i",
                src_path,
                "-ac",
                "1",  # mono
                "-ar",
                "16000",  # 16 kHz
                "-acodec",
                "pcm_s16le",
                dst_path,
            ],
            capture_output=True,
            text=True,
            timeout=300,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        logger.warning("[Process] ffmpeg không khả dụng (%s), dùng file gốc", exc)
        _safe_remove(dst_path)
        return src_path

    if result.returncode != 0 or not os.path.exists(dst_path):
        logger.warning(
            "[Process] ffmpeg chuyển đổi thất bại (%s): %s",
            suffix,
            (result.stderr or "").strip()[:500],
        )
        _safe_remove(dst_path)
        return src_path

    if os.path.getsize(dst_path) == 0:
        logger.warning("[Process] ffmpeg tạo file rỗng cho %s", suffix)
        _safe_remove(dst_path)
        return src_path

    logger.info("[Process] Đã chuyển %s → WAV 16kHz mono", suffix)
    return dst_path


def _safe_remove(path: str | None) -> None:
    """Xoá file nếu tồn tại, bỏ qua lỗi hệ thống tệp."""
    if path and os.path.exists(path):
        try:
            os.remove(path)
        except OSError:
            pass


@celery_app.task(name="process_audio_task", acks_late=True, queue="audio")
def process_audio_task(voice_record_id: str) -> dict:
    """Run PhoWhisper STT only, save transcript, and mark completed.

    NLP extraction happens later, only after teacher confirmation.
    """
    record_id = uuid.UUID(voice_record_id)
    tmp_path: str | None = None
    normalized_path: str | None = None
    db = SessionLocal()

    try:
        record = db.get(VoiceRecord, record_id)
        if not record:
            raise ValueError(f"VoiceRecord {voice_record_id} không tồn tại.")

        # 1. Cập nhật trạng thái bắt đầu xử lý
        record.status = VoiceRecordStatus.PROCESSING
        record.error_message = None
        db.commit()
        logger.info("[Process] Bắt đầu xử lý VoiceRecord %s", voice_record_id)

        # 2. Tải file từ MinIO
        tmp_path = _download_audio(record.audio_url)
        logger.info("[Process] Tải file từ MinIO thành công: %s", voice_record_id)

        # 2b. Chuẩn hoá sang WAV 16kHz mono (.m4a/.webm/.mp3 → .wav)
        normalized_path = _normalize_audio(tmp_path)

        # 3. STT: PhoWhisper chuyển audio → transcript
        raw_transcript = stt_service.transcribe(normalized_path)
        logger.info("[Process] STT hoàn tất: %d ký tự", len(raw_transcript))

        # 4. Chỉ lưu transcript PhoWhisper.
        # Model NLP chỉ được gọi sau khi giáo viên chỉnh sửa transcript
        # và bấm "Gửi cho model phân tích" trên frontend.
        record.raw_transcript = raw_transcript
        record.transcription = raw_transcript
        record.edited_transcript = None
        record.extraction_result = None
        record.status = VoiceRecordStatus.COMPLETED
        db.commit()
        logger.info(
            "[Process] VoiceRecord %s lưu transcript thành công", voice_record_id
        )

        return {
            "voice_record_id": voice_record_id,
            "status": VoiceRecordStatus.COMPLETED.value,
            "transcript_length": len(raw_transcript),
            "extraction_keys": [],
        }

    except Exception:
        db.rollback()
        logger.exception("[Process] Lỗi xử lý VoiceRecord %s", voice_record_id)
        try:
            failed_record = db.get(VoiceRecord, record_id)
            if failed_record:
                failed_record.status = VoiceRecordStatus.FAILED
                failed_record.error_message = traceback.format_exc()
                db.commit()
                logger.error(
                    "[Process] Đánh dấu FAILED cho VoiceRecord %s", voice_record_id
                )
        except SQLAlchemyError:
            logger.exception("[Process] Lỗi DB khi cập nhật FAILED")
            db.rollback()
        raise

    finally:
        db.close()
        _safe_remove(tmp_path)
        if normalized_path and normalized_path != tmp_path:
            _safe_remove(normalized_path)
