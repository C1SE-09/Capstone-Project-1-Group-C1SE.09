import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:dio/dio.dart';

/// Quản lý [Dio] dùng chung (singleton) cho toàn bộ tầng Repository.
///
/// - Tránh tạo 11 connection pool rời rạc khi nhiều màn hình khởi tạo Repository.
/// - Đảm bảo interceptor silent refresh chỉ được gắn tối đa 1 lần lên mỗi [Dio].
class ApiClient {
  ApiClient._internal();

  static final ApiClient instance = ApiClient._internal();

  static final Expando<bool> _attachedInterceptor = Expando<bool>('kinderlog_auth_interceptor');

  Dio? _sharedDio;

  /// Instance [Dio] mặc định dùng chung cho toàn bộ ứng dụng.
  Dio get dio {
    final existing = _sharedDio;
    if (existing != null) return existing;

    final created = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    attachSessionInterceptorIfNeeded(created);
    _sharedDio = created;
    return created;
  }

  /// Gắn interceptor xác thực lên [target] nếu chưa được gắn trước đó.
  static void attachSessionInterceptorIfNeeded(Dio target) {
    if (_attachedInterceptor[target] == true) return;
    _attachedInterceptor[target] = true;
    target.interceptors.add(
      SessionManagementService.instance.createDioInterceptor(target),
    );
  }

  /// Trả về [dio] tùy chỉnh (cho test), hoặc tạo [Dio] riêng nếu truyền [baseUrl]
  /// khác mặc định, ngược lại trả về [ApiClient.instance.dio] dùng chung.
  static Dio resolveDio({
    Dio? dio,
    String? baseUrl,
    Duration connectTimeout = const Duration(seconds: 20),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) {
    if (dio != null) {
      attachSessionInterceptorIfNeeded(dio);
      return dio;
    }
    if (baseUrl != null && baseUrl != kApiBaseUrl) {
      final scoped = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
          headers: {'Content-Type': 'application/json'},
        ),
      );
      attachSessionInterceptorIfNeeded(scoped);
      return scoped;
    }
    return instance.dio;
  }
}
