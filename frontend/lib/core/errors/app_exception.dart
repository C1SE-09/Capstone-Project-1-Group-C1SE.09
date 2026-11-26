/// Giao diện chuẩn cho toàn bộ ngoại lệ nghiệp vụ trong ứng dụng KinderLog.
///
/// Giúp [getFriendlyErrorMessage] kiểm tra bằng `error is AppException` an toàn
/// với `--obfuscate` khi build release (thay vì so sánh `runtimeType.toString()`).
abstract interface class AppException implements Exception {
  /// Thông điệp lỗi nghiệp vụ.
  String get message;

  /// Mã trạng thái HTTP nếu ngoại lệ xuất phát từ phản hồi mạng.
  int? get statusCode;

  /// Thông điệp ưu tiên hiển thị trực tiếp cho người dùng (nếu khác [message]).
  String? get userMessage;
}
