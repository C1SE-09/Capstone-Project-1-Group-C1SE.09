import logging
import os
import sys
import threading
from typing import Literal

import ctranslate2
from faster_whisper import WhisperModel

logger = logging.getLogger(__name__)


def _setup_nvidia_dll_paths() -> None:
    """Thêm các thư mục nvidia/*/bin vào DLL directory và PATH trên Windows để CTranslate2 load cuBLAS/cuDNN."""
    if sys.platform != "win32":
        return

    candidate_sp: set[str] = set()
    try:
        import site

        candidate_sp.update(site.getsitepackages())
    except (AttributeError, ImportError, OSError):
        pass
    try:
        ct2_dir = os.path.dirname(ctranslate2.__file__)
        candidate_sp.add(os.path.dirname(ct2_dir))
    except (AttributeError, ImportError, OSError):
        pass

    for sp in candidate_sp:
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


_setup_nvidia_dll_paths()

DEFAULT_MODEL_ID = "vudang449/PhoWhisper-large-ct2"
MODEL_ID = os.getenv("PHOWHISPER_MODEL_ID", DEFAULT_MODEL_ID)

COMPUTE_TYPE = "int8"
LANGUAGE = "vi"

Device = Literal["auto", "cuda", "cpu"]


def cuda_available() -> bool:
    """Tra ve True khi CTranslate2 nhin thay it nhat mot GPU CUDA."""
    try:
        return ctranslate2.get_cuda_device_count() > 0
    except (RuntimeError, AttributeError):
        logger.warning("[STT] Khong the kiem tra CUDA bang CTranslate2.", exc_info=True)
        return False


def _create_model(model_id: str, device: Literal["cuda", "cpu"]) -> WhisperModel:
    """Tao WhisperModel CTranslate2 voi INT8 tren device duoc chon."""
    kwargs: dict[str, object] = {
        "device": device,
        "compute_type": COMPUTE_TYPE,
        "num_workers": 1,
    }
    if device == "cpu":
        kwargs["cpu_threads"] = 0
    return WhisperModel(model_id, **kwargs)


class STTService:
    """Nhan audio va tra ve duy nhat raw transcript tieng Viet."""

    def __init__(self, model_id: str = MODEL_ID, device: Device = "auto") -> None:
        self.model_id = model_id
        self.device, self.model = self._load_model(device)

    def _load_model(self, requested_device: Device) -> tuple[str, WhisperModel]:
        """Uu tien CUDA INT8 va tu dong chuyen sang CPU INT8 khi can."""
        should_try_cuda = requested_device in {"auto", "cuda"} and cuda_available()

        if should_try_cuda:
            try:
                logger.info("[STT] Dang nap %s tren CUDA.", self.model_id)
                return "cuda", _create_model(self.model_id, "cuda")
            except (RuntimeError, ValueError, OSError) as exc:
                logger.warning("[STT] CUDA load that bai: %s. Fallback sang CPU.", exc)

        elif requested_device == "cuda":
            logger.warning("[STT] Khong tim thay CUDA. Fallback sang CPU.")

        logger.info("[STT] Dang nap %s tren CPU.", self.model_id)
        try:
            return "cpu", _create_model(self.model_id, "cpu")
        except (RuntimeError, ValueError, OSError) as exc:
            raise RuntimeError(f"Khong the nap model tren CPU: {exc}") from exc

    def _do_transcribe(self, audio_path: str) -> str:
        segments, _ = self.model.transcribe(
            audio_path,
            language=LANGUAGE,
            vad_filter=True,
            vad_parameters={"min_silence_duration_ms": 500},
            beam_size=5,
            condition_on_previous_text=False,
        )
        return "".join(seg.text for seg in segments).strip()

    def transcribe(self, audio_path: str) -> str:
        """Nhan dien giong noi tu file audio, tra ve text tieng Viet."""
        if not os.path.isfile(audio_path):
            raise FileNotFoundError(f"Khong tim thay file: {audio_path}")
        if os.path.getsize(audio_path) == 0:
            raise ValueError(f"File audio rong: {audio_path}")

        try:
            transcript = self._do_transcribe(audio_path)
        except RuntimeError as exc:
            if self.device == "cuda":
                logger.warning(
                    "[STT] LOI CUDA khi transcribe (%s). Dang fallback sang CPU...", exc
                )
                self.device = "cpu"
                self.model = _create_model(self.model_id, "cpu")
                transcript = self._do_transcribe(audio_path)
            else:
                raise

        logger.info("[STT] Hoan tat tren %s: %d ky tu.", self.device, len(transcript))
        return transcript


# Singleton: chi nap model mot lan duy nhat
_instance: STTService | None = None
_instance_lock = threading.Lock()


def get_stt_service() -> STTService:
    """Tra ve singleton STTService (lazy-load, thread-safe)."""
    global _instance
    if _instance is None:
        with _instance_lock:
            if _instance is None:
                _instance = STTService()
    return _instance


class _LazySTTService:
    """Proxy de goi stt_service.transcribe(path) ma van lazy-load model."""

    def transcribe(self, audio_path: str) -> str:
        return get_stt_service().transcribe(audio_path)


stt_service = _LazySTTService()
