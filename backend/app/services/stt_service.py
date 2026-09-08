from __future__ import annotations

import logging
import os

from faster_whisper import WhisperModel

logger = logging.getLogger(__name__)

# Model PhoWhisper-small trên HuggingFace Hub (định dạng CTranslate2)
# faster-whisper tự tải về ~/.cache/huggingface lần đầu, cache lại cho các lần sau
_MODEL_ID = "vinai/PhoWhisper-small"


def _cuda_available() -> bool:
    """Kiểm tra GPU CUDA qua ctranslate2."""
    try:
        import ctranslate2  # noqa: PLC0415
        return ctranslate2.get_cuda_device_count() > 0
    except (ImportError, AttributeError, RuntimeError):
        return False


def _load_model(model_id: str = _MODEL_ID) -> tuple[WhisperModel, str]:
    """Tải WhisperModel: thử CUDA (int8) trước, fallback CPU (int8) nếu thất bại."""
    if _cuda_available():
        try:
            logger.info("[STT] CUDA khả dụng — đang tải '%s' trên CUDA (int8).", model_id)
            model = WhisperModel(model_id, device="cuda", compute_type="int8")
            logger.info("[STT] Tải model thành công trên CUDA.")
            return model, "cuda"
        except RuntimeError as cuda_err:
            logger.warning("[STT] Load model trên CUDA thất bại: %s. Fallback về CPU (int8).", cuda_err)
    else:
        logger.warning("[STT] CUDA không khả dụng. Fallback về CPU (int8).")

    # Fallback: tải trên CPU
    logger.info("[STT] Đang tải '%s' trên CPU (int8).", model_id)
    try:
        model = WhisperModel(model_id, device="cpu", compute_type="int8")
        logger.info("[STT] Tải model thành công trên CPU.")
        return model, "cpu"
    except RuntimeError as cpu_err:
        raise RuntimeError(
            f"[STT] Không thể tải model '{model_id}' trên cả CUDA lẫn CPU: {cpu_err}"
        ) from cpu_err


class STTService:
    """Dịch vụ Speech-to-Text dùng PhoWhisper-small qua faster-whisper."""

    def __init__(self, model_id: str = _MODEL_ID, language: str = "vi") -> None:
        self.language = language
        self.model, self.device = _load_model(model_id)

    def transcribe(self, audio_path: str) -> str:
        """Chuyển file âm thanh thành văn bản. Trả về chuỗi rỗng nếu audio im lặng."""
        # Kiểm tra file tồn tại và không rỗng trước khi gọi model
        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"[STT] File audio không tìm thấy: {audio_path}")

        file_size = os.path.getsize(audio_path)
        if file_size == 0:
            raise ValueError(f"[STT] File audio rỗng (0 byte): {audio_path}")

        logger.debug("[STT] Bắt đầu transcribe: path=%s  size=%d bytes  device=%s",
                     audio_path, file_size, self.device)

        try:
            # vad_filter=True: dùng Silero VAD để lọc khoảng im lặng, giảm hallucination
            segments, info = self.model.transcribe(
                audio_path,
                language=self.language,
                beam_size=5,
                vad_filter=True,
                vad_parameters={"min_silence_duration_ms": 500},
            )
            # Consume toàn bộ generator trước khi ra khỏi scope
            texts = [seg.text.strip() for seg in segments]
            transcript = " ".join(t for t in texts if t)
        except (FileNotFoundError, ValueError):
            raise
        except Exception as exc:
            # Lỗi từ ffmpeg / ctranslate2 (file hỏng, codec lạ,…)
            raise ValueError(f"[STT] Không thể xử lý file audio '{audio_path}': {exc}") from exc

        logger.info("[STT] Hoàn thành: %d segment(s), %d ký tự, ngôn ngữ=%s(%.0f%%), thời lượng=%.1fs",
                    len(texts), len(transcript), info.language,
                    info.language_probability * 100, info.duration)
        return transcript


def _create_singleton() -> STTService:
    """Khởi tạo singleton, raise ngay nếu load thất bại để worker biết khi khởi động."""
    try:
        service = STTService()
        logger.info("[STT] stt_service singleton sẵn sàng (device=%s).", service.device)
        return service
    except Exception as exc:
        logger.critical(
            "[STT] KHÔNG THỂ KHỞI TẠO STTService: %s\n"
            "Mọi yêu cầu transcribe sẽ thất bại cho đến khi worker khởi động lại.",
            exc,
        )
        raise


# Singleton — load model đúng 1 lần khi module được import
# FastAPI endpoint và Celery task dùng chung instance này
stt_service: STTService = _create_singleton()
