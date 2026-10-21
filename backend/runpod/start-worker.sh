#!/usr/bin/env bash
# ==============================================================================
#  Chạy Celery worker trên RunPod (GPU)
#  Chạy mỗi lần bật pod.
#
#  Dùng:
#    cd /workspace/kinderlog/backend
#    bash runpod/start-worker.sh
# ==============================================================================
set -euo pipefail

REPO_DIR="/workspace/kinderlog/backend"
cd "$REPO_DIR"
source venv/bin/activate

# Thư viện CUDA của pip package. stt_service.py cũng tự dò lại, nhưng set
# sẵn ở đây để chắc chắn ctranslate2 tìm thấy cublas/cudnn.
#
# LƯU Ý: bash KHÔNG expand glob (python3.*) trong phép gán biến → path sẽ
# chứa dấu "*" và dynamic linker không tìm được → ctranslate2 load nhầm
# cuBLAS của hệ thống → lỗi CUBLAS_STATUS_INVALID_VALUE. Phải tìm đường
# dẫn thật bằng Python.
NVIDIA_SITE="$(python -c 'import site; print(site.getsitepackages()[0])')"
export LD_LIBRARY_PATH="${NVIDIA_SITE}/nvidia/cublas/lib:${NVIDIA_SITE}/nvidia/cudnn/lib:${LD_LIBRARY_PATH:-}"
echo "[start-worker] LD_LIBRARY_PATH=$LD_LIBRARY_PATH"

# --pool=prefork + concurrency=1: nạp đúng 1 model vào VRAM, tránh OOM.
exec celery \
  -A app.tasks.celery_app.celery_app worker \
  --loglevel=info \
  --concurrency=1 \
  --pool=prefork \
  -Q audio,notifications