import os
import logging
import torch
from faster_whisper import WhisperModel

# Khởi tạo logger cho module này, dùng để ghi log lỗi hoặc thông tin trong quá trình chạy
logger = logging.getLogger(__name__)


def _detect_device():
    """
    Tự động phát hiện thiết bị tốt nhất để chạy mô hình.

    Returns:
        tuple(str, str): (device, compute_type)
            - ("cuda", "float16") nếu có GPU NVIDIA hỗ trợ CUDA.
            - ("cpu",  "int8")    nếu không có GPU.
    """
    if torch.cuda.is_available():
        gpu_name = torch.cuda.get_device_name(0)
        logger.info(f"[STT] Phát hiện GPU: {gpu_name} — chạy bằng CUDA với float16.")
        return "cuda", "float16"
    else:
        logger.info("[STT] Không tìm thấy GPU — chạy bằng CPU với int8.")
        return "cpu", "int8"


class STTService:
    """
    Dịch vụ Speech-to-Text (STT) sử dụng mô hình Whisper thông qua thư viện faster-whisper.
    Hỗ trợ nhận dạng giọng nói tiếng Việt và nhiều ngôn ngữ khác.
    Tự động chọn GPU (CUDA/float16) nếu có, fallback về CPU (int8) nếu không.
    """

    def __init__(self, model_size="small", device="auto", compute_type="auto", language="vi"):
        """
        Khởi tạo STTService và tải mô hình Whisper vào bộ nhớ.

        Args:
            model_size (str):    Kích thước mô hình Whisper. Các lựa chọn: "tiny", "base", "small", "medium", "large".
                                 Mô hình nhỏ hơn thì nhanh hơn nhưng kém chính xác hơn. Mặc định: "small".
            device (str):        Thiết bị chạy mô hình.
                                 - "auto"  → tự động phát hiện GPU, fallback về CPU (khuyến nghị).
                                 - "cuda"  → ép buộc dùng GPU (lỗi nếu không có CUDA).
                                 - "cpu"   → ép buộc dùng CPU.
                                 Mặc định: "auto".
            compute_type (str):  Kiểu tính toán, ảnh hưởng đến tốc độ và bộ nhớ.
                                 - "auto"    → tự động chọn theo device ("float16" cho GPU, "int8" cho CPU).
                                 - "float16" → độ chính xác cao, phù hợp GPU.
                                 - "int8"    → tiết kiệm RAM, phù hợp CPU.
                                 Mặc định: "auto".
            language (str):      Mã ngôn ngữ mặc định dùng để nhận dạng. Mặc định: "vi" (tiếng Việt).
        """
        # Lưu ngôn ngữ mặc định để dùng khi transcribe không truyền language
        self.language = language

        # Tự động phát hiện device và compute_type nếu được đặt là "auto"
        if device == "auto" or compute_type == "auto":
            auto_device, auto_compute = _detect_device()
            device = auto_device if device == "auto" else device
            compute_type = auto_compute if compute_type == "auto" else compute_type

        # Lưu lại để có thể kiểm tra sau (ví dụ: log, debug)
        self.device = device
        self.compute_type = compute_type

        logger.info(f"[STT] Khởi tạo mô hình '{model_size}' trên {device.upper()} với compute_type={compute_type}.")

        # Tải mô hình Whisper — bước này có thể mất vài giây lần đầu do tải file model
        self.model = WhisperModel(model_size, device=device, compute_type=compute_type)

    def transcribe(self, audio_path, language=None):
        """
        Chuyển đổi file âm thanh thành văn bản (Speech-to-Text).

        Args:
            audio_path (str): Đường dẫn tuyệt đối đến file âm thanh cần nhận dạng.
                              Hỗ trợ các định dạng: .wav, .mp3, .m4a, v.v.
            language (str):   Mã ngôn ngữ để nhận dạng (ví dụ: "vi", "en").
                              Nếu None, sẽ dùng ngôn ngữ mặc định đã cấu hình lúc khởi tạo.

        Returns:
            str: Chuỗi văn bản đã được nhận dạng từ file âm thanh.

        Raises:
            FileNotFoundError: Nếu file âm thanh không tồn tại tại đường dẫn đã cho.
        """
        # Kiểm tra file âm thanh có tồn tại không trước khi xử lý
        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"Audio file not found: {audio_path}")

        # Ưu tiên ngôn ngữ được truyền vào, nếu không thì dùng ngôn ngữ mặc định
        lang = language or self.language

        # Gọi model để nhận dạng âm thanh
        # beam_size=5: dùng thuật toán beam search với 5 nhánh để cân bằng tốc độ và độ chính xác
        # Kết quả trả về là một iterator các đoạn (segments) và metadata (info)
        segments, info = self.model.transcribe(audio_path, language=lang, beam_size=5)

        # Ghép tất cả các đoạn văn bản lại thành một chuỗi hoàn chỉnh, loại bỏ khoảng trắng thừa
        return " ".join(seg.text.strip() for seg in segments).strip()


def get_stt_service(model_size="small", device="auto", compute_type="auto", language="vi"):
    """
    Factory function để tạo một instance STTService với cấu hình tùy chỉnh.
    Thường dùng cho dependency injection trong FastAPI (Depends).

    Args:
        model_size (str):    Kích thước mô hình Whisper. Mặc định: "small".
        device (str):        Thiết bị chạy mô hình ("auto", "cuda", "cpu"). Mặc định: "auto".
        compute_type (str):  Kiểu tính toán ("auto", "float16", "int8"). Mặc định: "auto".
        language (str):      Ngôn ngữ nhận dạng mặc định. Mặc định: "vi".

    Returns:
        STTService: Một instance mới của STTService đã được khởi tạo.
    """
    return STTService(model_size=model_size, device=device, compute_type=compute_type, language=language)


# Singleton instance dùng chung toàn app — tự động chọn GPU nếu có
stt_service = get_stt_service()