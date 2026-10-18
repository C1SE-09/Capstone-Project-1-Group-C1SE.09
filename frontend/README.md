# adark_frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Nhớ tài khoản và phiên 1 giờ

- **Nhớ tài khoản** mặc định tắt. Chọn rồi đăng nhập thành công mới lưu cả tài khoản
  và mật khẩu bằng `flutter_secure_storage`; bỏ chọn sẽ xóa thông tin đã nhớ.
- Hết phiên/đăng xuất chỉ xóa token, không xóa thông tin đã nhớ. Form điền sẵn nhưng
  vẫn phải bấm **Đăng nhập**; ứng dụng không tự gửi mật khẩu để đăng nhập ngầm.
- Phiên được khôi phục tối đa **1 giờ từ lần đăng nhập thành công**. Refresh token
  không kéo dài mốc này. Khi đang dùng app thì không tự văng; sau hạn, mở lại hoặc
  quay từ nền về sẽ yêu cầu login. Chỉ mất focus không được tính là đưa app xuống nền.
- Deep link/push không được bỏ qua login khi phiên đã bị xóa hoặc hết hạn lúc mở lại.
- Đây là hạn khôi phục phiên ở client, **không thay TTL JWT/refresh token backend**.
  Phiên từ bản cũ chưa có mốc hết hạn phải đăng nhập lại một lần sau cập nhật.
- Android không bật backup để tránh sao lưu dữ liệu mã hóa tách khỏi khóa trên máy.
  Sau khi thêm plugin, cần **dừng rồi chạy lại Flutter**, không chỉ hot reload.

### Web tạm phục vụ demo

WebCrypto chỉ hoạt động trên **HTTPS hoặc localhost**, dữ liệu thuộc cùng trình
duyệt/profile và origin (gồm port). Không có fallback lưu mật khẩu dạng rõ. Nếu kho
mã hóa không dùng được, login vẫn hoạt động và UI báo không lưu được lựa chọn.
WebCrypto không bảo vệ được trước XSS: chỉ dùng tài khoản demo trên thiết bị riêng.

Để không đổi port/profile giữa những lần chạy, có thể mở thủ công địa chỉ sau trong
cùng trình duyệt thay vì dùng profile Chrome tạm của Flutter:

```powershell
flutter run -d web-server --web-hostname=localhost --web-port=8080
# Mở http://localhost:8080 trong trình duyệt.
```

Không cần restart/rebuild Docker vì backend không thay đổi.

### Kiểm tra task (18/10/2026)

Chạy từ `frontend/`:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/remember_login_test.dart test/session_management_test.dart test/session_refresh_storage_race_test.dart test/login_and_parent_test.dart
flutter test --no-pub
flutter build apk --debug --no-pub
flutter build web --no-pub
```

Analyze, APK debug và web build đều đạt trên mã cuối. Nhóm test login/session:
**44 đạt**. Full suite: **99 đạt, 5 lỗi đã có trước task**:

- `admin_dashboard_test.dart`: `AdminDashboardScreen renders KPI cards, table, and charts`;
  `AdminDashboardScreen account tab has bug report option`.
- `bug_report_sheet_test.dart`: `BugReportBottomSheet does not let user pick category or severity`.
- `timetable_test.dart`: `hiển thị danh sách hoạt động và chip xung đột khi trùng khung giờ`;
  `isReadOnly=true không cho phép phụ huynh thêm/sửa/xóa lịch`.

Đã có test cho refresh cũ trả muộn khi đổi phiên và xóa phiên trong lúc ghi storage;
không bỏ qua/sửa các test ngoài phạm vi để làm xanh suite. Bản render widget login
đã kiểm tra ở 320/375/768/1440 px, light/dark và chữ 200% cho checkbox.

Smoke test WebCrypto thật: `flutter test --no-pub --platform chrome test/remember_login_browser_test.dart`.
Runner Chrome ở môi trường hiện tại bị treo ngay cả với test tối giản không import
code app; do đó **chưa xác nhận runtime WebCrypto/browser hoặc thiết bị Android thật**.
Các test VM dùng kho mã hóa giả của plugin; build thành công không thay thế smoke test trên thiết bị.
