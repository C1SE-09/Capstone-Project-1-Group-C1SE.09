# Kiểm thử tính năng Push Notification (FCM)

**Phạm vi:** Scope A — phụ huynh chạm thông báo sẽ mở thẳng báo cáo hôm nay.
**Luồng:** cô bấm gửi báo cáo → API đẩy job vào Celery (queue `notifications`) → worker gọi FCM tới **tất cả** device token của hộ gia đình → điện thoại hiện thông báo.
**Người test:** 1 máy Android thật **hoặc** emulator có Google Play services.

Tài khoản seed: phụ huynh `tuan / 123456` · giáo viên `comai / 123456`.

---

## 0. Điều kiện cần (làm một lần)

```powershell
docker compose up -d                                  # api + worker + db + redis + minio
docker compose exec api alembic upgrade head          # tạo bảng device_tokens
Invoke-RestMethod http://localhost:8000/api/health    # → status: ok
```

Cần có sẵn:
- `frontend/android/app/google-services.json` (app Android `com.example.adark_frontend` đã đăng ký trên Firebase)
- `backend/kinderlog_firebase_service.json` (service account, đã `.gitignore`)
- `.env` có dòng: `FIREBASE_CREDENTIALS_PATH=/app/kinderlog_firebase_service.json`
  → sau khi sửa `.env` phải chạy lại: `docker compose up -d api worker`

Log worker phải hiện: `[queues]` có `notifications`.

---

## Option A — Điện thoại Android thật

1. Bật **Developer options → USB debugging**, cắm cáp, chấp nhận hộp thoại RSA.
   Kiểm tra: `flutter devices`.
2. **Quan trọng:** địa chỉ `10.0.2.2` chỉ đúng cho emulator. Với máy thật, trỏ app về IP LAN của PC:
   ```powershell
   ipconfig     # lấy IPv4, ví dụ 192.168.1.20
   flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.20:8000
   ```
   Điện thoại và PC phải cùng Wi-Fi; cho phép cổng 8000 qua Windows Firewall nếu được hỏi.
3. **Phía phụ huynh:** đăng nhập `tuan / 123456` → bấm **Cho phép** khi hệ thống hỏi quyền thông báo.
4. **Checkpoint 1 — token đã đăng ký:**
   ```powershell
   docker compose exec db psql -U kinderlog -d kinderlog -c "SELECT device_type, left(token,24) AS token, created_at FROM device_tokens ORDER BY created_at DESC;"
   ```
5. **Kích hoạt gửi báo cáo** — chọn 1 trong 2 cách:
   - **Trong app (khuyến nghị):** logout → đăng nhập `comai / 123456` → chọn lớp → chọn trẻ → soạn báo cáo → **Gửi báo cáo** → xác nhận.
   - **Chỉ qua backend** (không cần thiết bị thứ hai):
     ```powershell
     # lấy 1 báo cáo nháp + teacher id
     docker compose exec db psql -U kinderlog -d kinderlog -t -A -c "SELECT daily_report_id FROM daily_report WHERE status='draft' LIMIT 1;"
     docker compose exec db psql -U kinderlog -d kinderlog -t -A -c "SELECT teacher_id FROM teacher LIMIT 1;"

     # gửi (tự phát thông báo)
     Invoke-RestMethod -Method Post "http://localhost:8000/api/reports/<REPORT_ID>/send?teacher_id=<TEACHER_ID>"
     ```
6. **Theo dõi luồng:** `docker compose logs -f worker` → mong đợi dòng `[Notify] … sent=1 removed=0`.
7. **Kết quả mong đợi trên điện thoại:**
   - Thông báo **“Báo cáo mới cho bé …”** hiện trong vài giây.
   - App **đang mở** (foreground): hiện SnackBar kèm nút **“Xem”** — đúng thiết kế.
   - **Chạm** thông báo (hoặc “Xem”) → app mở thẳng báo cáo hôm nay.
8. **Checkpoint 2 — đăng xuất:** phụ huynh logout → dòng token biến mất khỏi `device_tokens`.

---

## Option B — Emulator (để thành viên nhóm test)

1. Emulator phải dùng **Google Play system image** (ví dụ `mixi_phone`, tag `google_apis_playstore`). Image AOSP không nhận được FCM.
   - Chạy: `flutter emulators --launch mixi_phone` (hoặc Android Studio → Device Manager).
2. Trong `frontend/`: `flutter run -d emulator-5554`
   - **Không cần** `--dart-define` vì emulator dùng `10.0.2.2` mặc định.
3. Làm lại bước 3 → 8 của Option A.
4. Nếu chỉ giao APK cho thành viên: `flutter build apk --debug`
   → `adb install -r build\app\outputs\flutter-apk\app-debug.apk`
   (backend trên cùng PC vẫn phải chạy; emulator gọi qua `10.0.2.2:8000`).

---

## Công cụ kiểm tra bổ sung

**Bắn thử 1 token trực tiếp** (chứng minh FCM tới thiết bị mà không cần luồng báo cáo):

```powershell
$login = Invoke-RestMethod -Method Post http://localhost:8000/api/auth/login -ContentType "application/json" -Body '{"username":"tuan","password":"123456"}'
Invoke-RestMethod -Method Post http://localhost:8000/api/notifications/test -ContentType "application/json" -Headers @{ Authorization = "Bearer $($login.access_token)" } -Body '{"token":"<token lấy từ DB>","title":"Test","body":"Kiểm tra push"}'
```

**Xem token đang có:**
```powershell
docker compose exec db psql -U kinderlog -d kinderlog -c "SELECT user_id, device_type, token FROM device_tokens;"
```

---

## Xử lý sự cố

| Hiện tượng | Nguyên nhân → cách sửa |
|---|---|
| `device_tokens` trống | Chưa bấm “Cho phép” ở hộp thoại quyền / chưa đăng nhập bằng phụ huynh / app không gọi được API (máy thật phải dùng IP LAN qua `--dart-define`) |
| Worker log: `no_device_tokens` | Phụ huynh chưa đăng nhập trên thiết bị nào |
| Worker log: `report_not_found` / `invalid_report_id` | Sai report id |
| Task RETRY kèm `UndefinedTable` | Chưa chạy `alembic upgrade head` |
| `FIREBASE_CREDENTIALS_PATH is not configured` | Thiếu trong `.env` → `docker compose up -d api worker` |
| `sent=1` nhưng máy không hiện thông báo | Emulator thiếu Play services / pin đang tối ưu hóa / quyền thông báo bị tắt |
| Chỉ thấy SnackBar, không có thông báo hệ thống | Bình thường khi app đang mở (foreground) |
| Chạm thông báo không mở báo cáo | Phải là app phụ huynh; deep-link mở `/parent?report=today` |
| `sent=0 removed=1` | Token đã chết (gỡ app/đổi máy) — hệ thống tự xoá, đăng nhập lại để đăng ký token mới |

---

## Trạng thái tính năng

**Đã kiểm chứng (server-side):**
- 36/36 backend tests pass, ruff sạch.
- Luồng thật: API → Redis → worker → **gọi FCM thật** → token hỏng bị tự xoá (`removed=1`).
- Cả 2 đường gửi đều phát thông báo: `/api/reports/{id}/send` và `/api/teacher/reports/{id}/publish` (nút “Gửi báo cáo” trong app).

**Chưa kiểm chứng:** nhận thông báo trên thiết bị thật (cần điện thoại/emulator có Play services đang chạy).

*Tài liệu này đi kèm tính năng push-notification. Khi test gặp lỗi, gửi triệu chứng + log để cùng sửa.*
