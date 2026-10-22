# RunPod worker setup (STT dùng GPU)

Hai file này để deploy Celery worker + PhoWhisper STT lên RunPod.

## Nguyên tắc: mọi thứ nặng nằm trên Network Volume

RunPod chỉ mount Network Volume (NV) ở `/workspace`. Container disk (`/`) bị
xoá sạch khi pod bị **terminate** (hết credits, hoặc bấm Terminate).

| Thứ | Nằm ở đâu | Mất khi terminate? |
|---|---|---|
| Model `PhoWhisper-large-ct2` (~3GB) | `/workspace/kinderlog/backend/models/` | Không |
| `tokenizer.json` | cùng thư mục model | Không |
| `ffmpeg` static (~80MB) | `/workspace/kinderlog/bin/` | Không |
| `venv/` (mặc định) | `/workspace/kinderlog/backend/venv` | Không |
| `.env` | `/workspace/kinderlog/backend/.env` | Không |
| Cache pip (~2–3GB wheel) | `/workspace/kinderlog/.pip-cache/` | Không |
| Cache HuggingFace | `/workspace/kinderlog/.hf-cache/` | Không |
| Cache apt (file `.deb`) | `/workspace/kinderlog/.apt-cache/` | Không |
| `git`, `build-essential`, `python3-venv`, `ffmpeg` (bản apt) | container disk | Có — nhưng chỉ cần lúc setup |

Hệ quả: **sau lần setup đầu tiên, mỗi lần bật pod chỉ cần chạy
`start-worker.sh`** — không tải lại model, không cài lại venv, không tải lại
ffmpeg. Đây là đúng cả khi bạn **tắt pod** lẫn khi pod bị **terminate** (hết
credits), vì mọi thứ worker cần đều nằm trên Network Volume.

Vì sao cứ `git`, `build-essential`, `python3-venv` vẫn nằm trên container disk?

- `build-essential` và `python3-venv` chỉ dùng lúc tạo venv → venv đã có trên
  NV thì không cần nữa.
- `git` chỉ dùng để `git pull` cập nhật code. Sau khi pod bị terminate, `git`
  biến mất → `start-worker.sh` tự cài lại từ cache `.deb` trên NV (không tải
  lại từ internet).
- `ffmpeg` bản apt chỉ là dự phòng; bản **static** trên NV là thứ worker
  thực sự dùng.

### Về cache pip

Cache pip **không** giúp ích lúc worker đang chạy (lúc chạy không cài gì
cả). Giá trị thật của nó là *khả năng phục hồi*: phần nặng nhất còn lại sau
khi bỏ `torch` là `nvidia-cublas-cu12` + `nvidia-cudnn-cu12` (~2–3GB wheel).
Nếu mai mốt đổi image RunPod (python đổi version → venv hỏng), `pip install`
sẽ lấy lại wheel từ cache trên NV → không tải lại 3GB, chỉ mất thời gian
unzip. Đánh đổi: ~2–3GB NV + ghi NFS chậm lúc `pip install`.

## Chuẩn bị trên VPS (chạy 1 lần)

Mở 3 cổng để pod ngoài Internet gọi được:

```bash
ssh root@<VPS_IP>
ufw allow 5432/tcp   # Postgres
ufw allow 6379/tcp   # Redis
ufw allow 9000/tcp   # MinIO
exit
```

## Cài trên pod (chạy 1 lần / mỗi pod mới)

```bash
ssh root@49.233.35.42 -p 38915 -i ~/.ssh/id_ed25519

# Cài đặt 1 lần
mkdir -p /workspace/kinderlog && cd /workspace/kinderlog
git clone https://github.com/<user>/<repo>.git backend
cd backend
bash runpod/setup-worker.sh 160.191.87.202
```

Script setup sẽ:

1. Cài `ffmpeg`, `git`, `python3-venv`, `build-essential` (container disk), đồng
   thời đẩy cache `.deb` + danh sách package lên NV để cài lại sau nhanh.
2. Tải **ffmpeg static** về `/workspace/kinderlog/bin/` — để worker luôn có
   ffmpeg dù pod có bị recreate hay không. Có 2 nguồn dự phòng
   (johnvansickle → BtbN/GitHub).
3. Tạo `venv/` và cài thư viện Python (đã bỏ `torch` — STT không cần).
4. Kiểm tra GPU + CUDA qua CTranslate2.
5. Tải model `vudang449/PhoWhisper-large-ct2` vào `backend/models/`.
   `stt_service.py` tự ưu tiên local path này (check `model.bin`) nên worker
   không bao giờ tải model từ HuggingFace lúc chạy.
   Script cũng tải sẵn `tokenizer.json` (repo model không có file này —
   nếu thiếu, `faster-whisper` sẽ tải tokenizer từ internet lúc worker chạy).
6. Sinh file `.env` với các dòng `CHANGE_ME_*`.

Lấy giá trị thật từ VPS bằng cách SSH vào VPS và chạy:

```bash
cat /root/Capstone-Project-1-Group-C1SE.09/.env
```

Mở file `.env` trong pod, sửa 3 dòng:

- `DATABASE_URL` — thay `CHANGE_ME_DB` bằng mật khẩu Postgres
- `SECRET_KEY`
- `JWT_SECRET_KEY`

## Chạy worker (mỗi lần bật pod)

```bash
cd /workspace/kinderlog/backend
bash runpod/start-worker.sh
```

Script start tự kiểm tra `venv`, `model.bin`, `tokenizer.json`, `ffmpeg` và
in ra cảnh báo nếu thiếu. Nếu venv bị mất (pod bị recreate với image khác),
nó tự gọi `setup-worker.sh` để cài lại — nhờ cache pip trên NV nên **không
tải lại wheel nào**. Nếu `git` biến mất (pod bị terminate), nó cài lại từ cache
apt trên NV.

> **Worker trên pod chỉ nghe queue `audio`** (chuyển giọng nói → chữ, cần GPU).
> Queue `notifications` do worker trên VPS xử lý — xem `docker-compose.yml`.
> Nhờ vậy pod không phải cài Firebase, và VPS không phải nạp model 2.9GB.

> **Tắt pod xong bật lại:** chạy đúng 1 lệnh trên là đủ, không tải lại gì:
> ```bash
> cd /workspace/kinderlog/backend && bash runpod/start-worker.sh
> ```

Thấy log:

```
[INFO] Ready to receive tasks
[INFO] Connected to redis://160.191.87.202:6379/0
```

là thành công.

## Tuỳ chọn: đặt venv lên container disk (nhanh hơn)

Network Volume là ổ NFS nên import Python chậm hơn ổ local. Nếu bạn chấp
nhận việc mất venv khi pod bị terminate (cache pip vẫn còn trên NV nên cài
lại không tải lại gì), đặt venv lên container disk:

```bash
KINDERLOG_VENV_DIR=/opt/kinderlog-venv bash runpod/setup-worker.sh 160.191.87.202
```

Khi đó mỗi lần bật pod, chạy:

```bash
KINDERLOG_VENV_DIR=/opt/kinderlog-venv bash runpod/start-worker.sh
```

## Chạy nền (để thoát SSH không tắt worker)

```bash
apt-get install -y tmux
tmux new -s worker
bash runpod/start-worker.sh
# Ctrl+B rồi D → thoát tmux, worker vẫn chạy
# tmux attach -t worker → vào lại
```

## Dừng

```bash
# Trong pod, nếu chạy trực tiếp: Ctrl+C
# Trong tmux: tmux attach -t worker → Ctrl+C

# Hoặc trên giao diện RunPod:
#   Pods → kinderlog-worker → Stop
```

> **Stop vs Terminate:** `Stop` giữ nguyên container disk. `Terminate` xoá sạch
> container disk — nhưng mọi thứ quan trọng đều nằm trên Network Volume nên
> vẫn còn.

## Lưu ý chi phí

- RTX 2000 Ada: $0.24/giờ = $5.76/ngày nếu để chạy liên tục
- Container disk 50GB: ~$5/tháng khi pod đang chạy
- Network Volume: tính phí theo dung lượng, khuyến nghị **30GB** (venv ~5GB,
  model ~3GB, cache pip ~2-3GB, cache apt ~0.3GB, ffmpeg ~80MB)
- Sau mỗi lần test: **Stop pod** trên giao diện RunPod

Nếu NV sắp đầy, dọn cache pip (venv vẫn chạy bình thường):

```bash
pip cache purge    # nhớ set PIP_CACHE_DIR=/workspace/kinderlog/.pip-cache
```

## Kiểm tra nhanh worker có hoạt động

Trong pod, chạy:

```bash
cd /workspace/kinderlog/backend && source venv/bin/activate
celery -A app.tasks.celery_app.celery_app call ping --queue audio
```

Phải có `--queue audio`: task `ping` không có trong `task_routes` nên mặc
định rơi vào queue `celery`, mà worker trên pod không nghe queue đó → lệnh
không có phản hồi dù worker vẫn chạy bình thường.
