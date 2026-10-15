// frontend/lib/core/utils/api_config.dart
// =========================================================
// Cấu hình URL backend dùng chung cho tất cả repository.
//
// - Ưu tiên cao nhất: --dart-define=API_BASE_URL=... (dùng khi deploy production,
//   backend không còn nằm trên PC dev nữa).
// - Dev (mọi nền tảng: web, desktop, Android emulator, Android thiết bị thật):
//   localhost — riêng Android phải tự bắc cầu: `.vscode/` bị gitignore nên KHÔNG
//   có task nào chạy hộ, và cầu mất mỗi lần rút/cắm lại máy:
//     adb reverse tcp:8000 tcp:8000
//   (adb không có trong PATH: %LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe)
//   Không bắc cầu được (máy khác mạng Wi-Fi) → truyền IP LAN của PC:
//     flutter run --dart-define=API_BASE_URL=http://<IP-LAN-PC>:8000

/// Base URL của FastAPI backend.
String get kApiBaseUrl {
  const envUrl = String.fromEnvironment('API_BASE_URL');
  if (envUrl.isNotEmpty) {
    return envUrl;
  }
  // Dev: backend luôn chạy trên máy dev — Android đi qua adb reverse (xem chú thích đầu file).
  return 'http://localhost:8000';
}

