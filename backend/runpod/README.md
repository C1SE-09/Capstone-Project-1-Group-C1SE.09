# RunPod worker setup (STT dùng GPU)

Hai file này để deploy Celery worker + PhoWhisper STT lên RunPod.

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

Setup xong sẽ tạo file `.env` với các dòng `CHANGE_ME_*`. Lấy giá trị
thật từ VPS bằng cách SSH vào VPS và chạy:

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

Thấy log:
```
[INFO] Ready to receive tasks
[INFO] Connected to redis://160.191.87.202:6379/0
```

là thành công.

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

## Lưu ý chi phí

- RTX 2000 Ada: $0.24/giờ = $5.76/ngày nếu để chạy liên tục
- Container disk 50GB: ~$5/tháng khi pod đang chạy
- Pod KHÔNG có Network Volume → hết credits sẽ bị **terminate** (xóa sạch, mất model cache 3GB)
- Sau mỗi lần test: **Stop pod** trên giao diện RunPod

## Kiểm tra nhanh worker có hoạt động

Trong pod, chạy:

```bash
cd /workspace/kinderlog/backend && source venv/bin/activate
celery -A app.tasks.celery_app.celery_app call ping
# → nhận "pong" từ worker là OK
```
