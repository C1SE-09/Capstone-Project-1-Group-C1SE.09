// frontend/lib/data/repositories/http_notification_repository.dart
// =========================================================
// Đăng ký / xoá device token cho push notification (FCM).
// Backend: POST/DELETE /api/notifications/device-token (JWT bắt buộc).

import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';

abstract class NotificationRepository {
  Future<void> registerDeviceToken({required String token, String? deviceType});
  Future<void> deleteDeviceToken(String token);
}

class NotificationException implements Exception {
  const NotificationException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'NotificationException($statusCode): $message';
}

class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? kApiBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            )) {
    _dio.interceptors.add(
      SessionManagementService.instance.createDioInterceptor(_dio),
    );
  }

  final Dio _dio;

  Options get _options {
    final token = AuthRepository.currentUser?.token;
    if (token == null || token.isEmpty) return Options();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    String? deviceType,
  }) async {
    try {
      await _dio.post(
        '/api/notifications/device-token',
        data: {
          'token': token,
          if (deviceType != null) 'device_type': deviceType,
        },
        options: _options,
      );
    } on DioException catch (error) {
      throw NotificationException(
        'Không thể đăng ký nhận thông báo. Vui lòng thử lại sau.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<void> deleteDeviceToken(String token) async {
    try {
      await _dio.delete(
        '/api/notifications/device-token',
        data: {'token': token},
        options: _options,
      );
    } on DioException catch (error) {
      throw NotificationException(
        'Không thể xoá đăng ký thông báo. Vui lòng thử lại sau.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
