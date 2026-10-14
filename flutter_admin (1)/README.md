# KinderLog Admin — Flutter

Phiên bản Flutter độc lập của trang quản trị KinderLog trong
`src/screens/AdminDashboard.tsx`.

## Chạy ứng dụng

Ứng dụng chỉ hỗ trợ giao diện điện thoại portrait. Tạo shell native Android và
iOS mà không thay đổi mã trong `lib/`:

```bash
cd flutter_admin
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

Ứng dụng không dùng package runtime ngoài Flutter SDK. Dữ liệu hiện được lưu
trong state của `AdminDashboard` để mô phỏng CRUD; thay lớp lưu trữ này bằng
repository/API thật khi tích hợp backend.

## Tính năng đã chuyển đổi

- Dashboard responsive cho mobile, tablet và desktop.
- Sidebar desktop và bottom navigation 3 mục trên mobile.
- Theme sáng/tối.
- Tìm kiếm và CRUD giáo viên, học sinh, phụ huynh, thời khóa biểu.
- Phát hiện trùng phòng hoặc giáo viên trong cùng khung giờ.
- Tài khoản quản trị, đổi mật khẩu và xác nhận đăng xuất.
