// frontend/lib/core/utils/api_config.dart
// =========================================================
// Cấu hình URL backend dùng chung cho tất cả repository.
//
// - Ưu tiên cao nhất: --dart-define=API_BASE_URL=... (dùng khi deploy production,
//   backend không còn nằm trên PC dev nữa).
// - Dev (mọi nền tảng: web, desktop, Android emulator, Android thiết bị thật):
//   localhost — với Android, traffic đi qua `adb reverse tcp:8000 tcp:8000`
//   bắc từ điện thoại/emulator về PC. Task "adb reverse" trong .vscode tự chạy
//   khi mở project nên không cần cấu hình IP, không phụ thuộc Wi-Fi.

/// Base URL của FastAPI backend.
String get kApiBaseUrl {
  const envUrl = String.fromEnvironment('API_BASE_URL');
  if (envUrl.isNotEmpty) {
    return envUrl;
  }
  // Dev: backend luôn chạy trên máy dev — Android đi qua adb reverse (xem chú thích đầu file).
  return 'http://localhost:8000';
}

