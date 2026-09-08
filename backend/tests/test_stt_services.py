import os
import sys

# Thêm thư mục gốc của project (backend/) vào sys.path
# để Python có thể tìm thấy module "app.services.stt_service" khi chạy trực tiếp file này
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.stt_service import STTService


def test_transcribe():
    """
    Hàm kiểm thử thủ công cho STTService.
    Tạo một instance STTService với cấu hình mặc định, sau đó chạy nhận dạng
    trên file âm thanh mẫu và in kết quả ra console.
    """
    # Khởi tạo STTService với cấu hình mặc định:
    # model_size="small", device="cpu", compute_type="int8", language="vi"
    service = STTService()

    # Đường dẫn đến file âm thanh mẫu dùng để kiểm thử
    audio_path = r"C:\Users\Admin\Desktop\NCKH\Capstone-Project-1-Group-C1SE.09\backend\tests\audio_samples\test4.wav"

    if os.path.exists(audio_path):
        try:
            # Gọi hàm transcribe để chuyển đổi âm thanh thành văn bản
            text = service.transcribe(audio_path)
            # In kết quả nhận dạng nếu thành công
            print(f"[OK] Result: {text}")
        except (RuntimeError, ValueError, OSError) as e:
            # In thông báo lỗi nếu quá trình nhận dạng thất bại
            print(f"[ERROR] Error: {e}")
    else:
        # Thông báo nếu file âm thanh không tìm thấy tại đường dẫn đã chỉ định
        print(f"[NOT FOUND] File not found: {audio_path}")


# Chỉ chạy hàm test khi file được thực thi trực tiếp (không chạy khi được import)
if __name__ == "__main__":
    test_transcribe()