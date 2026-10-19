// frontend/lib/core/utils/api_config.dart
// =========================================================
// Cấu hình URL backend dùng chung cho toàn bộ app Flutter.
//
// - Mặc định: Trỏ về server VPS production (https://160.191.87.202.sslip.io).
//   Hoạt động mượt mà 24/7 trên:
//     + Web (Chrome, Edge)
//     + Android Emulator & Thiết bị thật
//     + iOS & Desktop
// - Dev local (nếu muốn chuyển về máy tính):
//     flutter run --dart-define=API_BASE_URL=http://localhost:8000 (trên Chrome)
//     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 (trên Android Emulator)

/// URL máy chủ VPS chính thức (đã có HTTPS)
const String kDefaultVpsApiUrl = 'https://160.191.87.202.sslip.io';

/// Base URL của FastAPI backend.
String get kApiBaseUrl {
  const envUrl = String.fromEnvironment('API_BASE_URL');
  if (envUrl.isNotEmpty) {
    return envUrl;
  }

  // Mặc định kết nối thẳng tới VPS Backend (cả Chrome, Android Emulator và điện thoại thật đều kết nối được)
  return kDefaultVpsApiUrl;
}


