"""Script tải trước model PhoWhisper-large-ct2 về máy cục bộ.

Chạy:
    python backend/download_model.py
"""
import os
import sys
import subprocess

def main() -> None:
    # 1. Kiểm tra và tự động cài huggingface_hub nếu chưa có
    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        print("[*] Đang cài đặt thư viện huggingface_hub và hf_transfer để tải tốc độ cao...")
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "-U", "huggingface_hub", "hf_transfer"]
        )
        from huggingface_hub import snapshot_download

    repo_id = os.getenv("PHOWHISPER_MODEL_ID", "vudang449/PhoWhisper-large-ct2")
    target_dir = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "models", "PhoWhisper-large-ct2")
    )
    os.makedirs(target_dir, exist_ok=True)

    print("=" * 65)
    print(f" Mô hình tải: {repo_id}")
    print(f" Thư mục lưu: {target_dir}")
    print(" Dung lượng:   ~3.1 GB (CTranslate2 INT8/FP16 weights)")
    print("=" * 65)

    # Bật tăng tốc tải đa luồng
    os.environ["HF_HUB_ENABLE_HF_TRANSFER"] = "1"

    try:
        snapshot_download(
            repo_id=repo_id,
            local_dir=target_dir,
            local_dir_use_symlinks=False,
        )
        print("\n" + "=" * 65)
        print("[Thành công] Đã tải toàn bộ file model PhoWhisper về máy!")
        print(f"Vị trí lưu: {target_dir}")
        print("=" * 65)
    except Exception as exc:
        print(f"\n[Lỗi khi tải]: {exc}", file=sys.stderr)
        print("\nThử tải lại mà không dùng hf_transfer:")
        os.environ.pop("HF_HUB_ENABLE_HF_TRANSFER", None)
        snapshot_download(
            repo_id=repo_id,
            local_dir=target_dir,
            local_dir_use_symlinks=False,
        )

if __name__ == "__main__":
    main()
