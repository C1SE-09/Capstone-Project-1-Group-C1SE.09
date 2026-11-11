# [Build][ParentRequests] triển khai đơn nghỉ/báo trễ và UI phụ huynh

> **Cập nhật ghép develop 29/10:** thay hướng dẫn revision cũ bằng head `f1b2c3d4e5f6` (giữ lịch sử `f0a1b2c3d4e5`, nối thêm medication từ develop `8c42606`). API nhiều bé, hủy đơn và các cập nhật health/medicine/emergency của nhóm được giữ. Module `leave_request.py` là implementation chung; `leave_requests.py` chỉ giữ import tương thích. UI một bé đi qua adapter vào cùng service batch, không có luồng ghi dữ liệu độc lập.

## Lưu ý sau ghép

- Python `leave_id` ánh xạ cột DB `request_id`; `action_at` ánh xạ `reviewed_at`. Không rename/xóa cột trên DB hiện có.
- `approved_by` lưu tài khoản User; migration mới backfill từ Teacher cũ và giữ nguyên audit cũ.
- API/Flutter hiểu `cancelled` là **Đã hủy**, không chuyển thành pending/rejected.
- Duyệt nghỉ chỉ thêm ngày chưa có điểm danh; không ghi đè bản ghi giáo viên đã lưu. Giờ báo trễ vẫn chỉ là ETA.
- Hủy đơn chỉ tự hoàn tác hàng excused có `source_leave_id` đúng, chưa check-in; thao tác điểm danh thủ công gỡ liên kết nguồn. Dữ liệu cũ chưa có nguồn không tự xóa, tránh mất điểm danh thật.
- Khi rollback code, các cột nullable/audit mới và ETA dùng chung được giữ; không xóa dữ liệu để ép schema về hình thức cũ.
- Chưa chạy migration/VPS; cần kiểm tra schema thực và backup trước khi triển khai. Head mới từ chối schema khóa khác lịch sử migration thay vì tự rename dữ liệu.
- Model dặn thuốc dùng `medication_request`; migration f1 bổ sung cột/enum cho đúng bảng này. Bảng `medication_requests` từ nhánh c7 vẫn giữ nguyên, không tự copy/xóa hồ sơ giữa hai bảng khi chưa đối soát dữ liệu thực.

## Giao diện và nghiệp vụ

Chuẩn thiết kế: Figma `9RurF0HiJlYLVDV7ljp2bH`, trang phụ huynh `2:2`, các frame `2:44`, `25:8`, `25:53`, `29:2`, `29:39`, `29:60`.

- Tổng quan có **Xin nghỉ / Báo trễ**; mở lịch sử đơn của đúng bé đang xem.
- Nghỉ một/nhiều ngày hoặc đi trễ một ngày với giờ dự kiến; lý do 3–1000 ký tự, khoảng nghỉ tối đa 366 ngày.
- Cả hai loại đều chờ giáo viên duyệt/từ chối. Giờ đến dự kiến không phải giờ check-in.
- Sau 07:30 theo UTC+07:00, nếu đơn ảnh hưởng hôm nay, API trả `409 meal_warning_required`. Chỉ gửi lại với `meal_warning_acknowledged=true` sau khi phụ huynh đồng ý cảnh báo tiền ăn. Không tính/thu tiền ăn trong feature này.
- Chặn giao khoảng ngày với đơn pending/approved của cùng bé, kể cả cha và mẹ gửi cùng lúc: khóa row `child` trong transaction trước kiểm tra trùng. Đơn rejected cho phép nộp lại.
- Duyệt nghỉ chỉ thêm ngày vắng chưa có bản ghi hoặc cập nhật ghi chú trên ngày vắng chưa check-in; không đổi bản ghi present/late hoặc có check-in thực. Duyệt đi trễ không tạo điểm danh.
- UI notification dùng pill nhỏ, scrollbar ngang, hàng đã đọc phẳng, navigation gọn. Cột phụ huynh tối đa 480dp trên Chrome rộng, không làm thay đổi teacher/admin shell.

## API (JWT bắt buộc)

| Method / đường dẫn | Mục đích |
|---|---|
| `POST /api/leave-requests/parent` | Tạo đơn cho bé được liên kết; endpoint mới ngăn server cũ lưu báo trễ thành đơn nghỉ |
| `GET /api/leave-requests/mine?child_id=...&status=...&offset=0&limit=20` | Lịch sử có phân trang; bỏ status để lấy tất cả |
| `GET /api/leave-requests/{id}` | Chi tiết mới nhất; parent của bé/teacher của lớp/admin |
| `GET /api/leave-requests/class/{class_id}?tab=pending` | Giáo viên xem đơn lớp; `reviewed` gồm cả duyệt và từ chối |
| `POST /api/leave-requests/{id}/approve` | Duyệt một lần |
| `POST /api/leave-requests/{id}/reject` | Từ chối với `reject_reason` |
| `POST /api/leave-requests/attachments?child_id=...` | Upload multipart `file` |
| `GET /api/leave-requests/attachments/{child_id}/{attachment_id}` | Đọc ảnh sau kiểm quyền, không cache công khai |

Trường tạo đơn cũ giữ nguyên; thêm `request_type` (`absence` mặc định hoặc `late_arrival`), `expected_arrival_time` (`HH:mm:ss`, chỉ late), `meal_warning_acknowledged` (mặc định false). `class_id` không được giả mạo; server xác định lớp từ hồ sơ bé.

Backend mới vẫn nhận `POST /api/leave-requests` để tương thích caller cũ. Frontend mới chỉ gửi tới `/parent`; nếu server cũ trả 404/405, hiện yêu cầu cập nhật backend, tuyệt đối không fallback POST tới endpoint cũ. Chỉ kiểm tra response sau khi POST tới endpoint cũ là quá muộn: server có thể đã tạo sai loại đơn.

Lỗi nghiệp vụ `409` có `detail: {code,message}`; mã `meal_warning_required`, `overlapping_request`. Dữ liệu sai `422`, không đủ quyền `403`, storage lỗi `503`. Flutter không tự retry POST khi kết quả mạng chưa rõ; hãy xem lại lịch sử trước khi gửi lại.

Ảnh JPEG/PNG/WebP <=5 MiB, MIME/chữ ký được kiểm tra. Bucket riêng tư là `<MINIO_BUCKET>-leave-requests`, không dùng helper audio public. Tham chiếu ảnh là đường dẫn API tương đối, gắn bé/người upload, không chấp nhận URL bên ngoài. Frontend tải bytes có JWT, không đưa Bearer tới host tùy ý.

## Đưa lên server

Chưa tự deploy hoặc migrate VPS. Trước khi dùng frontend mới với dữ liệu thật, triển khai backend mới và chạy từ repo root **trên server có Docker**:

```powershell
docker compose exec api alembic upgrade head
```

Revision `d2e3f4a5b6c7` hợp nhất hai head cũ và thêm ba cột; các đơn cũ mặc định `absence`. Không xóa/reset dữ liệu.

- Chỉ migrate DB: không cần restart/rebuild.
- API Python cần chạy code mới: compose dev hiện có tự reload; nếu server tắt reload, restart service API sau khi đưa code lên.
- Không đổi requirements/Dockerfile nên không cần rebuild image riêng. Sau cập nhật Python backend, restart worker để nạp lại các module/ORM dùng chung: `docker compose restart worker`.
- Flutter hot restart/chạy lại từ **frontend/**. Không cần Docker trên PC; app dùng API VPS theo cấu hình hiện có.
- Quyền MinIO của API cần tạo/đọc bucket riêng tư và bảo đảm bucket này không có policy public. Kiểm tra retention/lifecycle ảnh y tế theo chính sách của trường trước khi vận hành lâu dài.

## Kiểm thử và giới hạn

Tests: `backend/tests/test_leave_requests.py`, `backend/tests/test_leave_request_migration.py`; Flutter `parent_request_repository_test.dart`, `parent_requests_test.dart`, `teacher_request_type_test.dart`, `parent_notifications_test.dart`, `parent_navigation_bar_test.dart` và các test report/push/account liên quan.

Test backend dùng SQLite tạm và biên dịch SQL PostgreSQL để kiểm lock/upsert; chưa kiểm race trên PostgreSQL thật hoặc MinIO thật. Ảnh render kiểm UI bằng Flutter test renderer/font thật, không phải ảnh chụp Android. `flutter build web` chỉ chứng minh compile web, không chứng minh API VPS đang online.

Chưa thêm push khi tạo/xử lý đơn hoặc kho lịch sử thông báo sức khỏe/điểm danh. Kết quả duyệt có trong lịch sử/chi tiết khi tải lại; không tuyên bố đã giao FCM. Không build APK, không sửa Figma. Các failure login/session có sẵn và các module ML thiếu package trong môi trường host được báo riêng, không bỏ/skips test để làm xanh.

### Kết quả kiểm tra local ngày 28/10/2026

- Backend: **139 passed** (`test_leave_requests.py`, `test_leave_request_migration.py`, `test_child_access.py`, `test_health_profile.py`), gồm 93 test mới cho đơn/migration. Ruff toàn backend: pass.
- Flutter full suite: **179 passed, 11 failed, 0 skipped**. 11 failure trùng baseline trước thay đổi, không phát sinh failure mới. `flutter analyze`: không có issue.
- `flutter build web --no-pub`: pass; không đòi Docker trên PC.
- Render offline dùng font thật: history/absence/late/detail/rejected/submitted light/dark/text scale 2 và notification mobile/wide. Đây không phải kiểm thử phần cứng Android.
- Hai Important từ review độc lập đã có regression RED→GREEN: 401 làm mới token nhưng không replay POST, và migration cũ tạo enum hai lần. Thêm guard endpoint mới để server cũ không lưu báo trễ thành nghỉ học.

11 failure Flutter baseline:
1. `login_and_parent_test.dart`: LoginScreen renders card UI with username, password, remember me, and log in button.
2. `remember_login_test.dart`: checkbox mặc định tắt và không tự gửi yêu cầu đăng nhập.
3. `remember_login_test.dart`: checkbox không tràn ở 320.0, dark=false, text=2.0.
4. `remember_login_test.dart`: checkbox không tràn ở 375.0, dark=false, text=1.0.
5. `remember_login_test.dart`: checkbox không tràn ở 375.0, dark=true, text=1.0.
6. `remember_login_test.dart`: checkbox không tràn ở 768.0, dark=false, text=1.0.
7. `remember_login_test.dart`: checkbox không tràn ở 1440.0, dark=false, text=1.0.
8. `remember_login_test.dart`: chọn nhớ và login thành công mới ghi vào kho mã hóa.
9. `remember_login_test.dart`: login không chọn nhớ không lưu tài khoản hoặc mật khẩu.
10. `remember_login_test.dart`: bản ghi không hợp lệ không làm hỏng form hoặc điền nhầm dữ liệu.
11. `session_management_test.dart`: Phiên khôi phục tối đa 1 giờ — login đặt hạn 1 giờ và refresh không kéo dài thời hạn đó.

Backend full-suite collection chưa chạy tiếp được vì môi trường test lightweight thiếu dependency có sẵn của dự án:
- `test_health_exam.py`: thiếu `openpyxl`.
- `test_notifications.py`, `test_schedule.py`, `test_teacher.py`: thiếu `ctranslate2`.
- `test_push_notifications_e2e.py`: thiếu `torch`.

Không sửa hoặc bỏ các test trên để làm xanh. Không thay dependency dự án; chỉ bổ sung Alembic/Ruff vào virtualenv test tạm.
