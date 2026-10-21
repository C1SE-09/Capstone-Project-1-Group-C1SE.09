#!/usr/bin/env bash
# ==============================================================================
#  Cài đặt Celery worker + PhoWhisper STT trên RunPod (GPU)
#  Chạy 1 LẦN DUY NHẤT cho mỗi pod mới. Chạy lại cũng được (idempotent).
#
#  Dùng:
#    cd /workspace/kinderlog/backend
#    bash runpod/setup-worker.sh <IP_VPS>
#
#  Ví dụ:
#    bash runpod/setup-worker.sh 160.191.87.202
#
#  ── Nguyên tắc: MỌI THỨ NẶNG ĐỀU NẰM TRÊN NETWORK VOLUME ────────────────
#  RunPod chỉ mount Network Volume ở /workspace. Container disk (/) bị XOÁ SẠCH
#  khi pod bị terminate (hết credits). Vì vậy:
#    - model, tokenizer, ffmpeg static, cache pip, cache HF, cache apt → /workspace
#    - git, build-essential, python3-venv                → container disk (chỉ
#      dùng lúc setup, không cần khi chạy)
#
#  Sau khi setup xong, mỗi lần bật pod chỉ cần:
#    bash runpod/start-worker.sh
#  (Tắt pod → bật lại cũng vậy, không tải lại gì cả.)
#
#  ── Tuỳ chọn vị trí venv ──────────────────────────────────────────────────
#  Mặc định venv nằm trên Network Volume (sống sót qua terminate).
#  Network Volume là ổ NFS nên import Python chậm hơn ~nhiều lần so với ổ local.
#  Nếu bạn chấp nhận việc pod bị terminate thì mất venv (nhưng cache pip vẫn
#  còn trên NV → cài lại KHÔNG tải lại gì), đặt venv lên container disk để
#  chạy nhanh hơn:
#    KINDERLOG_VENV_DIR=/opt/kinderlog-venv bash runpod/setup-worker.sh <IP_VPS>
# ==============================================================================
set -euo pipefail

VPS_IP="${1:-}"
if [[ -z "$VPS_IP" ]]; then
  echo "❌ Thiếu IP VPS. Dùng: bash runpod/setup-worker.sh <IP_VPS>" >&2
  exit 1
fi

NV_ROOT="/workspace/kinderlog"

# Tự dò thư mục chứa backend. Repo có thể được clone theo 2 kiểu:
#   /workspace/kinderlog/            ← chứa app/, requirements.txt
#   /workspace/kinderlog/backend/    ← clone cả monorepo, backend nằm trong con
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
  echo "❌ Không tìm thấy thư mục backend (có app/ + requirements.txt) trong $NV_ROOT" >&2
  echo "   Hãy clone repo trước rồi chạy lại script này." >&2
  exit 1
fi
cd "$REPO_DIR"

# Venv: mặc định trên NV. Đổi qua KINDERLOG_VENV_DIR nếu muốn để container disk.
VENV_DIR="${KINDERLOG_VENV_DIR:-$REPO_DIR/venv}"
VENV_ON_NV=1
[[ "$VENV_DIR" == "$NV_ROOT"/* ]] || VENV_ON_NV=0

log() { echo -e "\n\033[1;36m==> $1\033[0m"; }

# Lưu IP VPS để start-worker.sh tự phục hồi được khi thiếu venv.
echo "$VPS_IP" > "$NV_ROOT/vps_ip"

# ── 0. Cache pip + HF + apt trên Network Volume ─────────────────────────────
# Mặc định chúng nằm ở ~/.cache (=/root/.cache) và /var/cache/apt → container
# disk → mất khi pod bị terminate. Ép về NV để lần cài lại sau không phải
# tải lại ~2GB wheel.
export PIP_CACHE_DIR="$NV_ROOT/.pip-cache"
export HF_HOME="$NV_ROOT/.hf-cache"
# Apt: giữ file .deb + danh sách package trên NV. Nhờ vậy sau khi pod bị
# terminate, `apt-get install git` (để git pull code mới) chạy gần như tức thì,
# không tải lại từ internet.
APT_CACHE_DIR="$NV_ROOT/.apt-cache"
APT_LISTS_DIR="$NV_ROOT/.apt-lists"
mkdir -p "$PIP_CACHE_DIR" "$HF_HOME" "$APT_CACHE_DIR/partial" "$APT_LISTS_DIR"
APT_OPTS=(
  -o "Dir::Cache::archives=$APT_CACHE_DIR/"
  -o "Dir::State::lists=$APT_LISTS_DIR/"
  -o "APT::Install-Recommends=false"
)

# ── 1. Thư viện hệ thống (container disk — chỉ cần lúc setup) ─────────────────
log "1/6 Cài ffmpeg, git, python3-venv, build-essential"
# apt-get update có thể fail khi mất mạng — không nên chặn setup. Nếu cache
# .deb + danh sách package đã nằm trên NV thì apt-get install vẫn chạy offline.
apt-get update -qq "${APT_OPTS[@]}" || echo "⚠️  apt-get update thất bại (mất mạng?) — dùng cache apt trên NV"
apt-get install -y -qq "${APT_OPTS[@]}" ffmpeg git python3-venv build-essential curl xz-utils tmux \
  || echo "⚠️  apt-get install thất bại — nếu thiếu python3-venv thì bước tạo venv sẽ báo lỗi."
# KHÔNG chạy `apt-get clean` — file .deb nằm trong cache trên NV là thứ giúp
# cài lại nhanh sau này (git...). Dọn cache apt chỉ khi NV sắp đầu:
#   rm -rf /workspace/kinderlog/.apt-cache/*
du -sh "$APT_CACHE_DIR" 2>/dev/null || true

# ── 2. ffmpeg static trên Network Volume ────────────────────────────────────
# ffmpeg là thứ DUY NHẤT từ apt mà worker cần lúc chạy. Nếu chỉ cài bằng apt
# thì pod bị recreate là mất → mọi task STT fail (không decode được .m4a/.mp3).
# Giải pháp: tải bản static (1 file nhị phân, không phụ thuộc .so hệ thống)
# đặt trên NV, rồi start-worker.sh trỏ PATH vào đó.
FFMPEG_DIR="$NV_ROOT/bin"
mkdir -p "$FFMPEG_DIR"
if [[ -x "$FFMPEG_DIR/ffmpeg" ]]; then
  log "2/6 ffmpeg static đã có trên NV — bỏ qua"
else
  log "2/6 Tải ffmpeg static (~80MB) về Network Volume"
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  ok=0
  # Nguồn 1: johnvansickle (bản static ổn định, không phụ thuộc .so hệ thống)
  if curl -fsSL --retry 3 -o "$TMP_DIR/ffmpeg.tar.xz" \
      https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz \
      && tar -xJf "$TMP_DIR/ffmpeg.tar.xz" -C "$TMP_DIR" 2>/dev/null; then
    ok=1
  fi
  # Nguồn 2: BtbN build trên GitHub (dự phòng)
  if [[ "$ok" -eq 0 ]]; then
    echo "    Nguồn 1 thất bại, thử BtbN/GitHub..."
    if curl -fsSL --retry 3 -o "$TMP_DIR/ffmpeg.tar.xz" \
        https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz \
        && tar -xJf "$TMP_DIR/ffmpeg.tar.xz" -C "$TMP_DIR" 2>/dev/null; then
      ok=1
    fi
  fi
  if [[ "$ok" -eq 1 ]]; then
    # Tên thư mục giải nén khác nhau giữa các nguồn, nên dò bằng find:
    #   ffmpeg-release-amd64-static/ffmpeg
    #   ffmpeg-master-latest-linux64-gpl/bin/ffmpeg
    SRC_FFMPEG="$(find "$TMP_DIR" -type f -name ffmpeg -perm -u+x | head -n 1)"
    SRC_FFPROBE="$(find "$TMP_DIR" -type f -name ffprobe -perm -u+x | head -n 1)"
    if [[ -n "$SRC_FFMPEG" ]]; then
      install -m 0755 "$SRC_FFMPEG" "$FFMPEG_DIR/ffmpeg"
    fi
    if [[ -n "$SRC_FFPROBE" ]]; then
      install -m 0755 "$SRC_FFPROBE" "$FFMPEG_DIR/ffprobe"
    fi
  fi
  rm -rf "$TMP_DIR"
  trap - EXIT
  if [[ -x "$FFMPEG_DIR/ffmpeg" ]]; then
    "$FFMPEG_DIR/ffmpeg" -version | head -n 1
  else
    echo "⚠️  Không tải được ffmpeg static — sẽ dùng ffmpeg của container (apt)." >&2
    echo "    Nếu pod bị terminate, ffmpeg sẽ mất. Có thể thử lại script này." >&2
  fi
fi

# ── 3. Virtualenv ───────────────────────────────────────────────────────────
# Venv phụ thuộc python của container: nếu đổi RunPod image (khác phiên bản
# python) thì venv có thể hỏng — start-worker.sh sẽ báo lỗi rõ ràng.
log "3/6 Tạo virtualenv ($VENV_DIR)"
if [[ "$VENV_ON_NV" -eq 1 ]]; then
  echo "    (trên Network Volume — chậm hơn chút nhưng sống lâu hơn)"
else
  echo "    (trên container disk — nhanh hơn, nhưng mất khi pod bị terminate)"
fi
if [[ ! -f "$VENV_DIR/bin/python" ]]; then
  python3 -m venv "$VENV_DIR"
fi
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
pip install -q --upgrade pip setuptools wheel

# ── 4. Thư viện Python ─────────────────────────────────────────────────────
# Bỏ torch/torchvision/torchaudio: worker STT chỉ cần ctranslate2, không cần
# PyTorch. Giữ lại sẽ tốn ~7GB và nhiều phút tải không cần thiết.
log "4/6 Cài thư viện Python (bỏ torch — STT không cần)"
# Regex cũ '^(torch|...)[[:space:]]' KHÔNG khớp "torch>=2.1.0" (sau "torch" là ">"
# chứ không phải khoảng trắng) → torch vẫn được cài, ăn ~7GB.
# Pattern đúng: tên package + ký tự so sánh hoặc khoảng trắng, hoặc hết dòng.
grep -vE '^(torch|torchvision|torchaudio)([[:space:]]|[<>=!~]|$)' requirements.txt > requirements-worker.txt
echo "    Đã loại bỏ khỏi requirements:" && grep -E '^(torch|torchvision|torchaudio)([[:space:]]|[<>=!~]|$)' requirements.txt || echo "    (không có gì để bỏ)"
echo "    Còn lại trong requirements-worker.txt:"
grep -cE '^[^#[:space:]]' requirements-worker.txt | sed 's/^/      /;s/$/ package/'
# Dùng cache trên NV: nếu phải cài lại (venv bị mất) thì KHÔNG tải lại wheel.
pip install -r requirements-worker.txt

# Venv cũ (setup trước đây) có thể đã cài torch. `pip install` KHÔNG tự gỡ
# package không còn nằm trong requirements → torch vẫn nằm trong venv trên NV
# và chiếm ~7GB vô ích. Gỡ thủ công nếu còn.
if pip list 2>/dev/null | grep -qiE '^(torch|torchvision|torchaudio)[[:space:]]'; then
  echo "    Phát hiện torch cũ trong venv — gỡ để tiết kiệm ~7GB NV"
  pip uninstall -y torch torchvision torchaudio 2>&1 | tail -3 || true
fi

# ── 5. Kiểm tra CUDA ────────────────────────────────────────────────────────
log "5/6 Kiểm tra GPU"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
python - <<'PY'
import ctranslate2
n = ctranslate2.get_cuda_device_count()
print(f"    ctranslate2 CUDA device count: {n}")
if n == 0:
    raise SystemExit("❌ CTranslate2 không thấy GPU. Kiểm tra lại GPU đã chọn khi deploy.")
print("    ✅ GPU sẵn sàng")
PY

# ── 6. Tải model về Network Volume ──────────────────────────────────────────
# Tải vào backend/models/PhoWhisper-large-ct2 (trên NV) thay vì ~/.cache
# huggingface (container disk). stt_service.py tự ưu tiên local path này khi
# thấy file model.bin → worker không bao giờ cần tải lại model.
log "6/6 Tải model PhoWhisper-large-ct2 (~3GB, 3-5 phút) vào Network Volume"
MODEL_DIR="$REPO_DIR/models/PhoWhisper-large-ct2"
mkdir -p "$MODEL_DIR"
MODEL_DIR="$MODEL_DIR" python - <<'PY'
import os
import shutil

from huggingface_hub import hf_hub_download, snapshot_download

MODEL_DIR = os.environ["MODEL_DIR"]

p = snapshot_download(
    "vudang449/PhoWhisper-large-ct2",
    local_dir=MODEL_DIR,
)
print(f"    Model tại: {p}")

# Repo vudang449/PhoWhisper-large-ct2 KHÔNG có tokenizer.json (chỉ có
# config.json, model.bin, vocabulary.json). faster-whisper khi thiếu file này
# sẽ tải tokenizer của openai/whisper-tiny từ internet LÚC worker đang chạy
# → mỗi pod mới lại tải lại, và offline thì fail.
# Tải sẵn vào thư mục model (trên NV) để faster-whisper dùng file local.
tok = hf_hub_download("openai/whisper-tiny", "tokenizer.json")
shutil.copy(tok, os.path.join(MODEL_DIR, "tokenizer.json"))
print(f"    Tokenizer: {os.path.join(MODEL_DIR, 'tokenizer.json')}")
PY
for f in model.bin config.json vocabulary.json tokenizer.json; do
  if [[ ! -f "$MODEL_DIR/$f" ]]; then
    echo "❌ Thiếu file $f trong $MODEL_DIR" >&2
    exit 1
  fi
done
du -sh "$MODEL_DIR"

# ── 7. Sinh file .env (trên NV → không mất) ─────────────────────────────────
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

# ── 8. Báo cáo dung lượng Network Volume ────────────────────────────────────
log "Dung lượng đã dùng"
du -sh "$NV_ROOT"/bin "$NV_ROOT"/.pip-cache "$NV_ROOT"/.hf-cache "$NV_ROOT"/.apt-cache "$MODEL_DIR" 2>/dev/null || true
[[ "$VENV_ON_NV" -eq 1 ]] && du -sh "$VENV_DIR" 2>/dev/null || true
df -h /workspace | tail -n 1

echo -e "\n\033[1;32m✅ Cài đặt xong.\033[0m"
echo "Bước tiếp theo:"
echo "  1. Sửa các dòng CHANGE_ME trong $REPO_DIR/.env"
echo "  2. bash runpod/start-worker.sh"
echo
echo "  Lần sau bật pod mới: chỉ cần chạy 'bash runpod/start-worker.sh',"
echo "  không phải tải lại model/venv/ffmpeg."
