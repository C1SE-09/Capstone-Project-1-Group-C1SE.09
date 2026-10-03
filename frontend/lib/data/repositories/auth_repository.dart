// frontend/lib/data/repositories/auth_repository.dart
// =========================================================
// Repository xử lý xác thực đăng nhập qua API POST /api/auth/login

import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:dio/dio.dart';

class AuthUser {
  const AuthUser({
    required this.token,
    this.tokenType = 'bearer',
    required this.role,
    this.userId,
    this.teacherId,
    this.parentId,
  });

  final String token;
  final String tokenType;
  final String role; // 'teacher' | 'parent' | 'admin'
  final String? userId;
  final String? teacherId;
  final String? parentId;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      token: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      role: json['role'] as String? ?? 'teacher',
      userId: json['user_id'] as String?,
      teacherId: json['teacher_id'] as String?,
      parentId: json['parent_id'] as String?,
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthRepository {
  static AuthUser? currentUser;

  AuthRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? kApiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final Dio _dio;

  /// Đăng nhập tài khoản với username & password qua POST /api/auth/login.
  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {
          'username': username.trim(),
          'password': password,
        },
      );

      final data = response.data;
      final AuthUser user;
      if (data is Map<String, dynamic>) {
        user = AuthUser.fromJson(data);
      } else if (data is Map) {
        user = AuthUser.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw const AuthException('Dữ liệu phản hồi không hợp lệ.');
      }
      currentUser = user;
      return user;
    } on DioException catch (e) {
      if (e.response != null) {
        final status = e.response?.statusCode;
        final resData = e.response?.data;
        String? detailMsg;
        if (resData is Map && resData['detail'] != null) {
          detailMsg = resData['detail'].toString();
        }
        if (status == 401) {
          throw AuthException(
            detailMsg ?? 'Tên đăng nhập hoặc mật khẩu không chính xác.',
            statusCode: status,
          );
        }
        throw AuthException(
          detailMsg ?? 'Đăng nhập không thành công (mã lỗi: $status).',
          statusCode: status,
        );
      }
      throw AuthException(
        'Không thể kết nối đến máy chủ backend ($kApiBaseUrl). Vui lòng kiểm tra kết nối mạng.',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Lỗi bất ngờ: $e');
    }
  }

  /// Đăng xuất tài khoản qua POST /api/auth/logout.
  Future<void> logout() async {
    final token = currentUser?.token;
    currentUser = null;
    if (token == null || token.isEmpty) return;

    try {
      await _dio.post(
        '/api/auth/logout',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } catch (_) {
      // Bỏ qua lỗi mạng khi logout để người dùng vẫn quay về màn đăng nhập
    }
  }
}
