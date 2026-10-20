#!/usr/bin/env bash
# ==============================================================================
#  Cài đặt Celery worker + PhoWhisper STT trên RunPod (GPU)
#  Chạy 1 LẦN DUY NHẤT. Chạy lại cũng được (idempotent).
#
#  Dùng:
#    cd /workspace/kinderlog/backend
#    bash runpod/setup-worker.sh <IP_VPS>
#
#  Ví dụ:
#    bash runpod/setup-worker.sh 160.191.87.202
# ==============================================================================
set -euo pipefail

VPS_IP="${1:-}"
if [[ -z "$VPS_IP" ]]; then
  echo "❌ Thiếu IP VPS. Dùng: bash runpod/setup-worker.sh <IP_VPS>" >&2
  exit 1
fi

REPO_DIR="/workspace/kinderlog/backend"
cd "$REPO_DIR"

log() { echo -e "\n\033[1;36m==> $1\033[0m"; }

# ── 1. Thư viện hệ thống ────────────────────────────────────────────────────
log "1/5 Cài ffmpeg, git, python3-venv"
apt-get update -qq
apt-get install -y -qq ffmpeg git python3-venv build-essential

# ── 2. Virtualenv ───────────────────────────────────────────────────────────
log "2/5 Tạo virtualenv"
python3 -m venv venv
source venv/bin/activate
pip install -q --upgrade pip setuptools wheel

# ── 3. Thư viện Python ─────────────────────────────────────────────────────
# Bỏ torch/torchvision/torchaudio: worker STT chỉ cần ctranslate2, không cần
# PyTorch. Giữ lại sẽ tốn ~5GB và nhiều phút tải không cần thiết.
log "3/5 Cài thư viện Python (bỏ torch — STT không cần)"
# Regex cũ '^(torch|...)[[:space:]]' KHÔNG khớp "torch>=2.1.0" (sau "torch" là ">"
# chứ không phải khoảng trắng) → torch vẫn được cài, ăn ~7GB.
# Pattern đúng: tên package + ký tự so sánh hoặc khoảng trắng, hoặc hết dòng.
grep -vE '^(torch|torchvision|torchaudio)([[:space:]]|[<>=!~]|$)' requirements.txt > requirements-worker.txt
echo "    Đã loại bỏ khỏi requirements:" && grep -E '^(torch|torchvision|torchaudio)([[:space:]]|[<>=!~]|$)' requirements.txt || echo "    (không có gì để bỏ)"
echo "    Còn lại trong requirements-worker.txt:"
grep -cE '^[^#[:space:]]' requirements-worker.txt | sed 's/^/      /;s/$/ package/'
pip install -q -r requirements-worker.txt

# ── 4. Kiểm tra CUDA ────────────────────────────────────────────────────────
log "4/5 Kiểm tra GPU"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
python - <<'PY'
import ctranslate2
n = ctranslate2.get_cuda_device_count()
print(f"    ctranslate2 CUDA device count: {n}")
if n == 0:
    raise SystemExit("❌ CTranslate2 không thấy GPU. Kiểm tra lại GPU đã chọn khi deploy.")
print("    ✅ GPU sẵn sàng")
PY

# ── 5. Tải model về trước ────────────────────────────────────────────────────
log "5/5 Tải model PhoWhisper-large-ct2 (~3GB, 3-5 phút)"
python - <<'PY'
from huggingface_hub import snapshot_download
p = snapshot_download("vudang449/PhoWhisper-large-ct2")
print(f"    Model tại: {p}")
PY

# ── 6. Sinh file .env ───────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
  log "Sinh .env"
  cat > .env <<EOF
# ── Sinh tự động bởi runpod/setup-worker.sh ──────────────────────────────
# Host đã đổi từ tên service Docker (db/redis/minio) sang IP VPS
# để pod ngoài Internet gọi được.
DATABASE_URL=postgresql+psycopg://kinderlog:CHANGE_ME_DB@${VPS_IP}:5432/kinderlog
REDIS_URL=redis://${VPS_IP}:6379/0
SECRET_KEY=CHANGE_ME_SECRET
JWT_SECRET_KEY=CHANGE_ME_JWT
MINIO_ENDPOINT=${VPS_IP}:9000
MINIO_USER=minioadmin
MINIO_PASSWORD=minioadmin123
MINIO_BUCKET=audio
MINIO_SECURE=false
PHOWHISPER_MODEL_ID=vudang449/PhoWhisper-large-ct2
EOF
  echo "    Đã tạo .env — SỬA 4 dòng CHANGE_ME trước khi chạy worker:"
  echo "      - DATABASE_URL (mật khẩu DB)"
  echo "      - SECRET_KEY"
  echo "      - JWT_SECRET_KEY"
else
  log ".env đã tồn tại, giữ nguyên"
fi

echo -e "\n\033[1;32m✅ Cài đặt xong.\033[0m"
echo "Bước tiếp theo:"
echo "  1. Sửa các dòng CHANGE_ME trong $REPO_DIR/.env"
echo "  2. bash runpod/start-worker.sh"