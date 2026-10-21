#!/usr/bin/env bash
# ==============================================================================
#  Chạy Celery worker trên RunPod (GPU)
#  Chạy mỗi lần bật pod.
#
#  Dùng:
#    cd /workspace/kinderlog/backend
#    bash runpod/start-worker.sh
#
#  Script này KHÔNG cài gì, KHÔNG tải gì: mọi thứ (venv, model, tokenizer,
#  ffmpeg) đã nằm sẵn trên Network Volume từ lần chạy setup-worker.sh đầu.
#  Nếu thiếu gì, script tự gọi setup-worker.sh để phục hồi (dùng cache trên
#  NV nên không tải lại gì).
# ==============================================================================
set -euo pipefail

NV_ROOT="/workspace/kinderlog"

# Tự dò thư mục chứa backend (xem setup-worker.sh để giải thích).
resolve_repo_dir() {
  local base="$1"
  if [[ -f "$base/requirements.txt" && -d "$base/app" ]]; then
    echo "$base"
  elif [[ -f "$base/backend/requirements.txt" && -d "$base/backend/app" ]]; then
    echo "$base/backend"
  else
    echo ""
  fi
}
REPO_DIR="$(resolve_repo_dir "$NV_ROOT")"
if [[ -z "$REPO_DIR" ]]; then
  echo "❌ Không tìm thấy thư mục backend trong $NV_ROOT" >&2
  exit 1
fi
cd "$REPO_DIR"

VENV_DIR="${KINDERLOG_VENV_DIR:-$REPO_DIR/venv}"

log() { echo -e "\n\033[1;36m==> $1\033[0m"; }

# ── Cache HF trên NV ────────────────────────────────────────────────────────
export HF_HOME="$NV_ROOT/.hf-cache"

# ── Tự phục hồi nếu thiếu venv ──────────────────────────────────────────────
VPS_IP="$(cat "$NV_ROOT/vps_ip" 2>/dev/null || true)"
if [[ ! -f "$VENV_DIR/bin/python" ]]; then
  if [[ -z "$VPS_IP" ]]; then
    echo "❌ Chưa có virtualenv và không biết IP VPS để cài lại." >&2
    echo "   Chạy: bash runpod/setup-worker.sh <IP_VPS>" >&2
    exit 1
  fi
  log "Chưa có virtualenv — tự chạy setup-worker.sh (dùng cache trên NV, không tải lại)"
  bash runpod/setup-worker.sh "$VPS_IP"
fi

# ── git (tiện cho git pull code mới) ─────────────────────────────────────────
# git cài trên container disk → mất khi pod bị terminate. Cài lại từ cache .deb
# trên NV (không tải lại từ internet). Worker KHÔNG cần git → lỗi ở đây không
# chặn việc chạy worker.
if ! command -v git >/dev/null 2>&1; then
  APT_CACHE_DIR="$NV_ROOT/.apt-cache"
  APT_LISTS_DIR="$NV_ROOT/.apt-lists"
  if [[ -d "$APT_CACHE_DIR" ]]; then
    echo "==> Thiếu git — cài lại từ cache apt trên Network Volume..."
    APT_OPTS=(
      -o "Dir::Cache::archives=$APT_CACHE_DIR/"
      -o "Dir::State::lists=$APT_LISTS_DIR/"
    )
    apt-get update -qq "${APT_OPTS[@]}" >/dev/null 2>&1 || true
    apt-get install -y -qq "${APT_OPTS[@]}" git >/dev/null 2>&1 \
      || echo "    (không cài được git — worker vẫn chạy bình thường)"
  fi
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# ── Kiểm tra model trên NV ──────────────────────────────────────────────────
MODEL_DIR="$REPO_DIR/models/PhoWhisper-large-ct2"
if [[ ! -f "$MODEL_DIR/model.bin" || ! -f "$MODEL_DIR/tokenizer.json" ]]; then
  echo "❌ Chưa có model đầy đủ tại $MODEL_DIR" >&2
  echo "   Chạy: bash runpod/setup-worker.sh <IP_VPS>" >&2
  exit 1
fi

# Venv phụ thuộc python của container. Nếu image đổi phiên bản python, venv
# có thể hỏng — phát hiện sớm để biết phải setup lại.
if ! python -c "import ctranslate2" >/dev/null 2>&1; then
  echo "❌ Venv không dùng được (đổi image/python version?)." >&2
  echo "   Chạy lại: bash runpod/setup-worker.sh <IP_VPS>" >&2
  exit 1
fi

# ── ffmpeg: bản static trên NV, không phụ thuộc container disk ──────────────
if [[ -x "$NV_ROOT/bin/ffmpeg" ]]; then
  export PATH="$NV_ROOT/bin:$PATH"
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "❌ Không tìm thấy ffmpeg (cả trên NV lẫn trong container)." >&2
  echo "   Chạy lại: bash runpod/setup-worker.sh <IP_VPS>" >&2
  exit 1
fi
echo "==> ffmpeg: $(command -v ffmpeg)"

# ── Thư viện CUDA của pip package (nằm trong venv) ──────────────────────────
# Phải resolve đường dẫn thật: biến "python3.*" KHÔNG được glob expand trong
# LD_LIBRARY_PATH nên bản cũ trỏ tới path sai và CUDA lib không được nạp.
NV_SITE="$(python -c 'import site; print(site.getsitepackages()[0])')"
CUDA_LIBS=""
for pkg in cublas cudnn; do
  if [[ -d "$NV_SITE/nvidia/$pkg/lib" ]]; then
    CUDA_LIBS="$CUDA_LIBS:$NV_SITE/nvidia/$pkg/lib"
  fi
done
if [[ -n "$CUDA_LIBS" ]]; then
  export LD_LIBRARY_PATH="${CUDA_LIBS#:}:${LD_LIBRARY_PATH:-}"
fi

# Model đã nằm trên NV → không cần network lúc load.
export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-1}"

# --pool=prefork + concurrency=1: nạp đúng 1 model vào VRAM, tránh OOM.
exec celery \
  -A app.tasks.celery_app.celery_app worker \
  --loglevel=info \
  --concurrency=1 \
  --pool=prefork \
  -Q audio,notifications
