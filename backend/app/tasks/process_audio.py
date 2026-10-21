"""Celery task: run PhoWhisper STT and save its raw transcript.

The LSTM/BIO extraction model is intentionally run later, after the teacher
reviews and confirms the transcript in the frontend.
"""

import logging
import os
import shutil
import subprocess
import tempfile
import uuid
from urllib.parse import quote, urlsplit, urlunsplit
from urllib.request import urlopen

from sqlalchemy.exc import SQLAlchemyError

from app.core.database import SessionLocal
from app.core.storage import fetch_audio_from_minio
from app.models.report import VoiceRecord, VoiceRecordStatus
from app.services.stt_service import stt_service
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


class AudioFetchError(RuntimeError):
    """Không tải được file ghi âm từ kho lưu trữ (lỗi hạ tầng, không phải lỗi âm thanh)."""


def _download_over_http(audio_url: str, dest_path: str) -> None:
    """Tải audio bằng HTTP ẩn danh (bucket public-read)."""
    parts = urlsplit(audio_url)
    encoded_path = quote(parts.path, safe="/:@&=+$,-_.!~*'()")
    safe_url = urlunsplit(
        (parts.scheme, parts.netloc, encoded_path, parts.query, parts.fragment)
    )
    with urlopen(safe_url, timeout=60) as resp, open(dest_path, "wb") as out_file:
        shutil.copyfileobj(resp, out_file)


def _download_audio(audio_url: str) -> str:
    """
    Tải file âm thanh từ kho lưu trữ về đĩa đệm tạm.

    Ưu tiên HTTP GET (nhanh, không cần credentials). Nếu thất bại — thường do
    hostname trong ``audio_url`` không phân giải được từ worker, hoặc bucket
    không public — sẽ thử lại bằng MinIO SDK với credentials của backend.
    """
    suffix = os.path.splitext(audio_url.partition("?")[0])[1] or ".wav"
    last_error: Exception | None = None

    for attempt in ("http", "sdk"):
        fd, tmp_path = tempfile.mkstemp(suffix=suffix)
        os.close(fd)
        try:
            if attempt == "http":
                _download_over_http(audio_url, tmp_path)
            else:
                fetch_audio_from_minio(audio_url, tmp_path)

            if os.path.getsize(tmp_path) == 0:
                raise OSError("File tải về rỗng")

            logger.info(
                "[Process] Tải audio qua %s: %s",
                "HTTP" if attempt == "http" else "MinIO SDK",
                audio_url,
            )
            return tmp_path
        except Exception as exc:
            # Bắt rộng có chủ đích: hai cơ chế tải (urllib và MinIO SDK) ném
            # loại lỗi khác nhau — HTTPError/URLError/OSError cho urllib,
            # S3Error/MinioException cho SDK. Mục tiêu là thử hết phương án
            # còn lại rồi mới báo lỗi tổng hợp.
            last_error = exc
            _safe_remove(tmp_path)
            logger.warning(
                "[Process] Tải audio qua %s thất bại (%s: %s)",
                "HTTP" if attempt == "http" else "MinIO SDK",
                type(exc).__name__,
                exc,
            )

    raise AudioFetchError(
        f"Không tải được file ghi âm từ kho lưu trữ ({audio_url}): {last_error}"
    )


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


def _friendly_error(exc: Exception) -> str:
    """
    Chuyển lỗi kỹ thuật thành thông báo ghi đúng nguyên nhân.

    Trước đây mọi lỗi không chứa từ khoá "micro/giọng nói" đều bị gộp thành
    "micro thu không được âm thanh", khiến lỗi hạ tầng (không tải được file từ
    MinIO) hiện ra trên UI như một lỗi âm thanh và rất khó chẩn đoán.
    """
    if isinstance(exc, AudioFetchError):
        return (
            "Máy chủ xử lý không tải được file ghi âm. "
            "Vui lòng thử lại hoặc liên hệ quản trị viên."
        )
    if isinstance(exc, FileNotFoundError):
        return f"Không tìm thấy file ghi âm: {exc}"
    if isinstance(exc, ValueError):
        # Lỗi do chính STT service ném ra (âm thanh quá nhỏ / không có tiếng nói).
        return str(exc).strip()
    return (
        "Hệ thống không xử lý được file ghi âm. "
        "Vui lòng thử lại hoặc liên hệ quản trị viên."
    )


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

        # 2. Tải file từ MinIO (HTTP, fallback sang MinIO SDK)
        tmp_path = _download_audio(record.audio_url)

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

    except Exception as exc:
        db.rollback()
        logger.exception("[Process] Lỗi xử lý VoiceRecord %s", voice_record_id)
        try:
            failed_record = db.get(VoiceRecord, record_id)
            if failed_record:
                failed_record.status = VoiceRecordStatus.FAILED
                failed_record.error_message = _friendly_error(exc)
                db.commit()
                logger.error(
                    "[Process] Đánh dấu FAILED cho VoiceRecord %s: %s",
                    voice_record_id,
                    failed_record.error_message,
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
