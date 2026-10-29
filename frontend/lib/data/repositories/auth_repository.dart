// frontend/lib/data/repositories/auth_repository.dart
// =========================================================
// Repository xử lý xác thực đăng nhập qua API POST /api/auth/login

import 'dart:convert';
import 'dart:math';

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  const AuthUser({
    required this.token,
    this.tokenType = 'bearer',
    required this.role,
    this.userId,
    this.username,
    this.teacherId,
    this.parentId,
  });

  final String token;
  final String tokenType;
  final String role; // 'teacher' | 'parent' | 'admin'
  final String? userId;
  final String? username;
  final String? teacherId;
  final String? parentId;

  factory AuthUser.fromJson(Map<String, dynamic> json,
      {String? fallbackUsername}) {
    return AuthUser(
      token: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      role: json['role'] as String? ?? 'teacher',
      userId: json['user_id'] as String?,
      username: (json['username'] as String?) ?? fallbackUsername,
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
            ) {
    // Interceptor tự gắn access token và silent refresh khi gặp 401. Nó chạy sau
    // các call site tự set header, nên token dùng luôn là bản mới nhất.
    _dio.interceptors.add(
      SessionManagementService.instance.createDioInterceptor(_dio),
    );
  }

  final Dio _dio;

  static const String _keyDeviceId = 'app_session_device_id';
  static const String _keyRememberedLogin = 'app_remembered_login';
  // shortcut: WebCrypto chỉ phục vụ web demo trên HTTPS/localhost; bỏ khi ngừng bản web.
  static const _rememberedLoginStorage = FlutterSecureStorage();

  Future<({String username, String password})?> readRememberedLogin() async {
    final raw = await _rememberedLoginStorage.read(key: _keyRememberedLogin);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is Map &&
          data['username'] is String &&
          data['password'] is String &&
          (data['username'] as String).trim().isNotEmpty &&
          (data['password'] as String).isNotEmpty) {
        return (
          username: (data['username'] as String).trim(),
          password: data['password'] as String,
        );
      }
    } on FormatException {
      // Bản ghi hỏng không được dùng để điền form.
    }
    await clearRememberedLogin();
    return null;
  }

  /// Chỉ gọi sau khi server xác thực thành công và người dùng đã chọn ghi nhớ.
  Future<void> saveRememberedLogin({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      throw const AuthException('Thông tin ghi nhớ đăng nhập không hợp lệ.');
    }
    await _rememberedLoginStorage.write(
      key: _keyRememberedLogin,
      value: jsonEncode({'username': username.trim(), 'password': password}),
    );
  }

  Future<void> clearRememberedLogin() =>
      _rememberedLoginStorage.delete(key: _keyRememberedLogin);

  /// Id thiết bị ổn định cho ngưỡng "tối đa 4 thiết bị" của backend: sinh 1 lần
  /// rồi giữ trong máy. Không dùng token FCM vì token đó xoay vòng, một máy sẽ
  /// bị tính thành nhiều thiết bị.
  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyDeviceId);
    if (saved != null && saved.isNotEmpty) return saved;
    final rand = Random();
    final id =
        List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
    await prefs.setString(_keyDeviceId, id);
    return id;
  }

  /// Tên thiết bị hiển thị. Không kèm model vì cần thêm plugin device_info.
  String _deviceName() {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.android) return 'Android';
    if (platform == TargetPlatform.iOS) return 'iOS';
    return 'Máy tính';
  }

  /// Đăng nhập tài khoản với username & password qua POST /api/auth/login.
  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    final deviceId = await _deviceId();
    final deviceName = _deviceName();
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {
          'username': username.trim(),
          'password': password,
          'device_id': deviceId,
          'device_name': deviceName,
        },
      );

      final data = response.data;
      final AuthUser user;
      if (data is Map<String, dynamic>) {
        user = AuthUser.fromJson(data, fallbackUsername: username.trim());
      } else if (data is Map) {
        user = AuthUser.fromJson(Map<String, dynamic>.from(data),
            fallbackUsername: username.trim());
      } else {
        throw const AuthException('Dữ liệu phản hồi không hợp lệ.');
      }
      currentUser = user;
      // Khôi phục phiên trong 1 giờ; refresh token vẫn phục vụ thao tác foreground.
      final raw = data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      await SessionManagementService.instance.saveSession(
        AppSession(
          accessToken: raw['access_token']?.toString() ?? user.token,
          refreshToken: raw['refresh_token']?.toString() ?? '',
          sessionId: raw['session_id']?.toString() ?? '',
          role: user.role,
          userId: user.userId,
          teacherId: user.teacherId,
          parentId: user.parentId,
          deviceName: deviceName,
        ),
      );
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
          detailMsg ??
              'Đăng nhập không thành công. Quý phụ huynh và thầy cô vui lòng kiểm tra lại thông tin đăng nhập hoặc thử lại sau.',
          statusCode: status,
        );
      }
      throw const AuthException(
        'Không thể kết nối đến máy chủ. Quý phụ huynh và thầy cô vui lòng kiểm tra lại kết nối mạng Wifi/4G.',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
          'Đã xảy ra sự cố ngoài ý muốn. Vui lòng thử lại sau ít phút.');
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

  /// Gửi yêu cầu mã xác thực qua email
  Future<String> requestPasswordReset(String email) async {
    try {
      final response = await _dio.post(
        '/api/auth/forgot-password',
        data: {'email': email.trim().toLowerCase()},
      );
      final data = response.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Mã xác thực đã được gửi. Vui lòng kiểm tra hòm thư của bạn.';
    } on DioException catch (e) {
      _handleDioError(e, 'Không thể gửi yêu cầu đặt lại mật khẩu.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
          'Đã xảy ra sự cố ngoài ý muốn. Vui lòng thử lại sau ít phút.');
    }
  }

  /// Xác thực mã OTP 6 số
  Future<String> verifyResetCode({
    required String email,
    required String resetCode,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/verify-reset-code',
        data: {
          'email': email.trim().toLowerCase(),
          'reset_code': resetCode.trim(),
        },
      );
      final data = response.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Xác thực mã thành công.';
    } on DioException catch (e) {
      _handleDioError(e, 'Mã xác thực không hợp lệ hoặc đã hết hạn.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
          'Đã xảy ra sự cố ngoài ý muốn. Vui lòng thử lại sau ít phút.');
    }
  }

  /// Đặt lại mật khẩu mới
  Future<String> resetPassword({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/reset-password',
        data: {
          'email': email.trim().toLowerCase(),
          'reset_code': resetCode.trim(),
          'new_password': newPassword,
        },
      );
      final data = response.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Đặt lại mật khẩu thành công!';
    } on DioException catch (e) {
      _handleDioError(e, 'Đặt lại mật khẩu không thành công.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
          'Đã xảy ra sự cố ngoài ý muốn. Vui lòng thử lại sau ít phút.');
    }
  }

  /// Đổi mật khẩu tài khoản qua POST /api/auth/change-password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    bool logoutOtherDevices = true,
  }) async {
    final token = currentUser?.token;
    if (token == null || token.isEmpty) {
      throw const AuthException(
          'Bạn chưa đăng nhập hoặc phiên làm việc đã hết hạn.');
    }

    try {
      await _dio.post(
        '/api/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'logout_other_devices': logoutOtherDevices,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } on DioException catch (e) {
      _handleDioError(e, 'Đổi mật khẩu thất bại.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
          'Đã xảy ra sự cố ngoài ý muốn. Vui lòng thử lại sau ít phút.');
    }
  }

  Never _handleDioError(DioException e, String fallbackMsg) {
    if (e.response != null) {
      final status = e.response?.statusCode;
      final resData = e.response?.data;
      String? detailMsg;
      if (resData is Map && resData['detail'] != null) {
        detailMsg = resData['detail'].toString();
      }
      throw AuthException(detailMsg ?? fallbackMsg, statusCode: status);
    }
    throw const AuthException(
      'Không thể kết nối đến máy chủ. Quý phụ huynh và thầy cô vui lòng kiểm tra lại kết nối mạng Wifi/4G.',
    );
  }
}
