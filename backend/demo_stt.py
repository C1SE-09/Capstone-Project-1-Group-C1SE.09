import sys
from pathlib import Path

# Đảm bảo in tiếng Việt không bị lỗi encoding trên Windows Terminal
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, OSError):
        pass

# Thêm thư mục backend vào sys.path
backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.services.stt_service import get_stt_service


def main():
    # Đường dẫn file âm thanh cần test
    audio_path = str(backend_dir / "tests" / "audio_samples" / "test1.wav")

    svc = get_stt_service()

    print(f"Đang nạp mô hình và xử lý file âm thanh: {audio_path}")
    print(
        f"Thiết bị phần cứng  : {svc.device.upper()} ({'GPU Nvidia' if svc.device == 'cuda' else 'CPU'})"
    )
    print("-" * 60)

    try:
        text = svc.transcribe(audio_path)
        print("\n" + "=" * 60)
        print("KẾT QUẢ NỘI DUNG VĂN BẢN (STT OUTPUT):")
        print("=" * 60)
        print(text)
        print("=" * 60)
    except (RuntimeError, ValueError, FileNotFoundError, OSError) as e:
        print(f"❌ Lỗi khi xử lý file: {e}")


if __name__ == "__main__":
    main()
