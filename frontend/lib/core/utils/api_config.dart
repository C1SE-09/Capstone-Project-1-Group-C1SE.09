// frontend/lib/core/utils/api_config.dart
// =========================================================
// Cấu hình URL backend dùng chung cho tất cả repository.
//
// - Flutter Web: sử dụng localhost (same machine as browser).
// - Android emulator: 10.0.2.2 là địa chỉ loopback tới máy host.
// - Thiết bị vật lý / tình huống khác: đổi kFoundBaseUrl cho phù hợp.

import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL của FastAPI backend.
String get kApiBaseUrl {
  if (kIsWeb) {
    return 'http://localhost:8000';
  }
  // Android emulator loopback
  return 'http://10.0.2.2:8000';
}
