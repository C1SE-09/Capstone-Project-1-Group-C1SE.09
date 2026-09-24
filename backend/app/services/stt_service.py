"""backend/app/services/stt_service.py
Service quản lý mô hình Speech-to-Text PhoWhisper (Fast-Whisper / CTranslate2).
Tự động chọn GPU CUDA hoặc CPU fallback, hỗ trợ Singleton Lazy-Loading.
"""

import logging
import os
import shutil
import subprocess
import sys
import tempfile
import threading
from typing import Literal

import ctranslate2
from faster_whisper import WhisperModel

logger = logging.getLogger(__name__)

# --- Cấu hình DLL NVIDIA trên Windows ---
if sys.platform == "win32":
    try:
        import site

        for sp in site.getsitepackages():
            nvidia_dir = os.path.join(sp, "nvidia")
            if os.path.isdir(nvidia_dir):
                for sub in os.listdir(nvidia_dir):
                    bin_dir = os.path.join(nvidia_dir, sub, "bin")
                    if os.path.isdir(bin_dir):
                        try:
                            os.add_dll_directory(bin_dir)
                        except (AttributeError, OSError):
                            pass
                        if bin_dir not in os.environ.get("PATH", ""):
                            os.environ["PATH"] = (
                                bin_dir + os.path.pathsep + os.environ.get("PATH", "")
                            )
    except (AttributeError, ImportError, OSError):
        pass

MODEL_ID = os.getenv("PHOWHISPER_MODEL_ID", "vudang449/PhoWhisper-large-ct2")


def cuda_available() -> bool:
    """Kiểm tra GPU CUDA khả dụng cho CTranslate2."""
    try:
        return ctranslate2.get_cuda_device_count() > 0
    except (RuntimeError, AttributeError, ValueError):
        return False


def _ffmpeg_available() -> bool:
    """Kiểm tra ffmpeg có sẵn trên hệ thống."""
    return shutil.which("ffmpeg") is not None


def _convert_to_wav(src_path: str) -> str | None:
    """
    Chuyển audio (.m4a/.mp3/.webm/...) sang WAV 16kHz mono bằng ffmpeg.

    Trả về đường dẫn file WAV mới, hoặc None nếu không chuyển được.
    """
    if not _ffmpeg_available():
        return None

    dst_fd, dst_path = tempfile.mkstemp(suffix=".wav")
    os.close(dst_fd)
    try:
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                src_path,
                "-ac",
                "1",
                "-ar",
                "16000",
                "-f",
                "wav",
                dst_path,
            ],
            check=True,
            capture_output=True,
            timeout=300,
        )
        if os.path.getsize(dst_path) == 0:
            os.remove(dst_path)
            return None
        return dst_path
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError) as exc:
        logger.warning("[STT] Không chuyển được audio sang WAV: %s", exc)
        if os.path.exists(dst_path):
            try:
                os.remove(dst_path)
            except OSError:
                pass
        return None


class STTService:
    """Lớp dịch vụ nạp model PhoWhisper và nhận dạng giọng nói."""

    def __init__(
        self,
        model_id: str = MODEL_ID,
        device: Literal["auto", "cuda", "cpu"] = "auto",
    ) -> None:
        self.model_id = model_id
        self.device, self.model = self._load_model(device)

    def _load_model(self, requested_device: str) -> tuple[str, WhisperModel]:
        use_cuda = requested_device in {"auto", "cuda"} and cuda_available()
        if use_cuda:
            try:
                logger.info("[STT] Nạp mô hình PhoWhisper trên GPU (CUDA)")
                return "cuda", WhisperModel(
                    self.model_id, device="cuda", compute_type="int8", num_workers=1
                )
            except (RuntimeError, ValueError, OSError) as exc:
                logger.warning("[STT] CUDA error: %s. Fallback sang CPU", exc)

        logger.info("[STT] Nạp mô hình PhoWhisper trên CPU")
        return "cpu", WhisperModel(
            self.model_id,
            device="cpu",
            compute_type="int8",
            cpu_threads=0,
            num_workers=1,
        )

    def transcribe(self, audio_path: str) -> str:
        """Nhận dạng âm thanh từ file thành văn bản tiếng Việt."""
        if not os.path.isfile(audio_path):
            raise FileNotFoundError(f"Không tìm thấy file: {audio_path}")
        if os.path.getsize(audio_path) == 0:
            raise ValueError(f"File audio rỗng: {audio_path}")

        # Chuẩn hoá sang WAV trước khi nhận dạng để hỗ trợ .m4a/.mp3/.webm...
        normalized_path = None
        target_path = audio_path
        if not audio_path.lower().endswith(".wav"):
            normalized_path = _convert_to_wav(audio_path)
            if normalized_path:
                target_path = normalized_path

        try:
            return self._transcribe_path(target_path)
        finally:
            if normalized_path and os.path.exists(normalized_path):
                try:
                    os.remove(normalized_path)
                except OSError:
                    pass

    def _transcribe_path(self, audio_path: str) -> str:
        """Chạy model PhoWhisper trên một file audio đã đọc được."""
        try:
            segments, _ = self.model.transcribe(
                audio_path,
                language="vi",
                vad_filter=True,
                vad_parameters={"min_silence_duration_ms": 500},
                beam_size=5,
                condition_on_previous_text=False,
            )
            transcript = "".join(seg.text for seg in segments).strip()
            if not transcript:
                raise ValueError(
                    f"Nội dung file âm thanh rỗng hoặc không thể nhận dạng tiếng nói: {audio_path}"
                )
            return transcript
        except RuntimeError:
            if self.device == "cuda":
                logger.warning(
                    "[STT] Lỗi GPU trong lúc transcribe, fallback sang CPU..."
                )
                self.device = "cpu"
                self.model = WhisperModel(
                    self.model_id, device="cpu", compute_type="int8", cpu_threads=0
                )
                return self._transcribe_path(audio_path)
            raise


# --- Singleton & Lazy Loading ---
_instance: STTService | None = None
_lock = threading.Lock()


def get_stt_service() -> STTService:
    """Trả về Singleton STTService instance."""
    global _instance
    if _instance is None:
        with _lock:
            if _instance is None:
                _instance = STTService()
    return _instance


class _LazySTTService:
    def transcribe(self, audio_path: str) -> str:
        return get_stt_service().transcribe(audio_path)

    @property
    def device(self) -> str:
        return get_stt_service().device


stt_service = _LazySTTService()
