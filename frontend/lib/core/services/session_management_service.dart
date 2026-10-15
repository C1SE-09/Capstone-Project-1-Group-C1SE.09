// frontend/lib/core/services/session_management_service.dart
// ==============================================================================
// HƯỚNG DẪN TÍCH HỢP CHI TIẾT VÀO CÁC FILE HIỆN CÓ CỦA FLUTTER FRONTEND
// ==============================================================================
// Nếu bạn muốn tích hợp Session Management vào luồng app hiện tại, đây là 3 file
// cụ thể trong dự án của bạn kèm dòng code cần thêm/sửa:
//
// ------------------------------------------------------------------------------
// 1. FILE: frontend/lib/main.dart
// ------------------------------------------------------------------------------
// [Vị trí: hàm main() dòng 8-20]
// - MỤC ĐÍCH: Nạp lại phiên đã lưu trước khi vẽ giao diện (Auto-login như Facebook).
// - THÊM DÒNG:
//     Future<void> main() async {
//       WidgetsFlutterBinding.ensureInitialized();
//       await ThemeController.instance.load();
//
//       // >>> THÊM 1 DÒNG NÀY VÀO ĐÂY <<<
//       await SessionManagementService.instance.loadPersistedSession();
//
//       try {
//         await Firebase.initializeApp();
//         ...
//       }
//       runApp(const MyApp());
//     }
//
// ------------------------------------------------------------------------------
// 2. FILE: frontend/lib/core/routing/app_router.dart
// ------------------------------------------------------------------------------
// [Vị trí: khai báo GoRouter dòng 13-18]
// - MỤC ĐÍCH: Nếu đã có phiên thì vào thẳng Dashboard, nếu chưa thì mới vào /login.
// - CŨ (dòng 15):
//     initialLocation: '/login',
// - MỚI:
//     initialLocation: SessionManagementService.instance.isLoggedIn
//         ? (SessionManagementService.instance.currentSession?.role == 'teacher'
//             ? '/class-select'
//             : '/parent')
//         : '/login',
//
// [Vị trí: hàm _goLogin() dòng 45-50]
// - MỤC ĐÍCH: Dọn sạch phiên khi đăng xuất.
// - THÊM DÒNG:
//     Future<void> _goLogin() async {
//       await PushNotificationService.instance.deleteCurrentDevice();
//       await SessionManagementService.instance.clearSession(); // >>> THÊM DÒNG NÀY <<<
//       AuthRepository().logout();
//       appRouter.go('/login');
//     }
//
// ------------------------------------------------------------------------------
// 3. FILE: frontend/lib/data/repositories/auth_repository.dart
// ------------------------------------------------------------------------------
// [Vị trí: hàm khởi tạo AuthRepository dòng 49-59]
// - MỤC ĐÍCH: Tự động gắn Interceptor để Silent Refresh khi gặp lỗi 401.
// - THÊM VÀO CONSTRUCTOR:
//     AuthRepository({Dio? dio, String? baseUrl})
//         : _dio = dio ??
//               Dio(
//                 BaseOptions(
//                   baseUrl: baseUrl ?? kApiBaseUrl,
//                   connectTimeout: const Duration(seconds: 10),
//                   receiveTimeout: const Duration(seconds: 10),
//                   headers: {'Content-Type': 'application/json'},
//                 ),
//               ) {
//       // >>> THÊM DÒNG NÀY VÀO ĐÂY <<<
//       _dio.interceptors.add(
//         SessionManagementService.instance.createDioInterceptor(_dio),
//       );
//     }
//
// [Vị trí: sau khi gọi API login thành công dòng 85]
// - MỤC ĐÍCH: Lưu access token, refresh token và session_id xuống bộ nhớ máy.
// - THÊM DÒNG:
//     currentUser = user;
//     // >>> THÊM ĐOẠN NÀY <<<
//     await SessionManagementService.instance.saveSession(
//       AppSession(
//         accessToken: user.token,
//         refreshToken: (data is Map ? data['refresh_token'] : null) ?? '',
//         sessionId: (data is Map ? data['session_id'] : null) ?? '',
//         role: user.role,
//         userId: user.userId,
//         teacherId: user.teacherId,
//         parentId: user.parentId,
//       ),
//     );
// ==============================================================================

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ngoại lệ chứa thông điệp thân thiện với người dùng (User-friendly message).
/// Đảm bảo không bao giờ hiển thị stack trace hay mã lỗi code thô lên màn hình.
class UserFacingException implements Exception {
  final String userMessage;
  final int? statusCode;

  const UserFacingException(this.userMessage, {this.statusCode});

  @override
  String toString() => userMessage;
}

/// Ngoại lệ khi mất kết nối mạng.
class OfflineException extends UserFacingException {
  const OfflineException([
    super.message = 'Không có kết nối mạng. Vui lòng kiểm tra Wifi/4G của bạn.',
  ]);
}

/// Ngoại lệ khi phiên làm việc hết hạn và cần đăng nhập lại.
class SessionExpiredException extends UserFacingException {
  const SessionExpiredException([
    super.message = 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.',
  ]) : super(statusCode: 401);
}

/// Dữ liệu phiên đăng nhập lưu trong máy
class AppSession {
  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final String role;
  final String? userId;
  final String? teacherId;
  final String? parentId;
  final String? deviceName;

  const AppSession({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.role,
    this.userId,
    this.teacherId,
    this.parentId,
    this.deviceName,
  });

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'session_id': sessionId,
        'role': role,
        'user_id': userId,
        'teacher_id': teacherId,
        'parent_id': parentId,
        'device_name': deviceName,
      };

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      role: json['role'] as String? ?? 'teacher',
      userId: json['user_id'] as String?,
      teacherId: json['teacher_id'] as String?,
      parentId: json['parent_id'] as String?,
      deviceName: json['device_name'] as String?,
    );
  }

  AppSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? sessionId,
    String? role,
    String? userId,
    String? teacherId,
    String? parentId,
    String? deviceName,
  }) {
    return AppSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      userId: userId ?? this.userId,
      teacherId: teacherId ?? this.teacherId,
      parentId: parentId ?? this.parentId,
      deviceName: deviceName ?? this.deviceName,
    );
  }
}

/// Service Quản lý Phiên làm việc độc lập
class SessionManagementService {
  // Singleton pattern
  static final SessionManagementService instance =
      SessionManagementService._internal();

  factory SessionManagementService() => instance;

  SessionManagementService._internal();

  AppSession? _currentSession;
  Completer<String?>? _refreshCompleter;

  // Khóa lưu trong storage
  static const String _keyAccessToken = 'app_session_access_token';
  static const String _keyRefreshToken = 'app_session_refresh_token';
  static const String _keySessionId = 'app_session_id';
  static const String _keyRole = 'app_session_role';
  static const String _keyUserId = 'app_session_user_id';
  static const String _keyTeacherId = 'app_session_teacher_id';
  static const String _keyParentId = 'app_session_parent_id';
  static const String _keyDeviceName = 'app_session_device_name';

  /// Lấy session hiện tại trong bộ nhớ RAM
  AppSession? get currentSession => _currentSession;

  /// Kiểm tra xem người dùng có phiên hoạt động hay không
  bool get isLoggedIn =>
      _currentSession != null && _currentSession!.refreshToken.isNotEmpty;

  // ──────────────────────────────────────────────────────────────────────────
  // 1. LƯU VÀ ĐỌC PHIÊN TỪ BỘ NHỚ THIẾT BỊ
  // ──────────────────────────────────────────────────────────────────────────

  /// Tải phiên đã lưu khi mở app (Dùng trong Splash Screen / App Startup)
  Future<AppSession?> loadPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_keyRefreshToken);

      if (refreshToken == null || refreshToken.isEmpty) {
        _currentSession = null;
        return null;
      }

      _currentSession = AppSession(
        accessToken: prefs.getString(_keyAccessToken) ?? '',
        refreshToken: refreshToken,
        sessionId: prefs.getString(_keySessionId) ?? '',
        role: prefs.getString(_keyRole) ?? 'teacher',
        userId: prefs.getString(_keyUserId),
        teacherId: prefs.getString(_keyTeacherId),
        parentId: prefs.getString(_keyParentId),
        deviceName: prefs.getString(_keyDeviceName),
      );

      return _currentSession;
    } catch (_) {
      // Trường hợp lỗi đọc storage, trả về null nhẹ nhàng, không gây crash
      return null;
    }
  }

  /// Lưu phiên làm việc mới sau khi Đăng nhập thành công
  Future<void> saveSession(AppSession session) async {
    _currentSession = session;
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_keyAccessToken, session.accessToken),
        prefs.setString(_keyRefreshToken, session.refreshToken),
        prefs.setString(_keySessionId, session.sessionId),
        prefs.setString(_keyRole, session.role),
        if (session.userId != null)
          prefs.setString(_keyUserId, session.userId!)
        else
          prefs.remove(_keyUserId),
        if (session.teacherId != null)
          prefs.setString(_keyTeacherId, session.teacherId!)
        else
          prefs.remove(_keyTeacherId),
        if (session.parentId != null)
          prefs.setString(_keyParentId, session.parentId!)
        else
          prefs.remove(_keyParentId),
        if (session.deviceName != null)
          prefs.setString(_keyDeviceName, session.deviceName!)
        else
          prefs.remove(_keyDeviceName),
      ]);
    } catch (_) {
      // Bỏ qua lỗi phụ trợ
    }
  }

  /// Cập nhật cặp Access Token & Refresh Token mới (Sau khi Silent Refresh)
  Future<void> updateTokens({
    required String newAccessToken,
    required String newRefreshToken,
  }) async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, newAccessToken);
      await prefs.setString(_keyRefreshToken, newRefreshToken);
    } catch (_) {}
  }

  /// Xóa sạch phiên khi người dùng bấm ĐĂNG XUẤT chủ động
  Future<void> clearSession() async {
    _currentSession = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_keyAccessToken),
        prefs.remove(_keyRefreshToken),
        prefs.remove(_keySessionId),
        prefs.remove(_keyRole),
        prefs.remove(_keyUserId),
        prefs.remove(_keyTeacherId),
        prefs.remove(_keyParentId),
        prefs.remove(_keyDeviceName),
      ]);
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. TỰ ĐỘNG LÀM MỚI TOKEN (SILENT REFRESH) QUA DIO
  // ──────────────────────────────────────────────────────────────────────────

  /// Gọi endpoint /api/auth/refresh để lấy access token mới
  /// Tuyệt đối KHÔNG xóa phiên nếu gặp lỗi mạng (Offline)
  Future<String> refreshAccessToken(Dio dio) async {
    final session = _currentSession;
    if (session == null || session.refreshToken.isEmpty) {
      throw const SessionExpiredException();
    }

    // Nếu đang có một request refresh khác đang chạy, chờ kết quả của nó (tránh gửi nhiều lần)
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      final token = await _refreshCompleter!.future;
      if (token != null) return token;
      throw const SessionExpiredException();
    }

    _refreshCompleter = Completer<String?>();

    try {
      // Dùng một instance Dio sạch không gắn Interceptor để tránh vòng lặp vô hạn
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: dio.options.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        '/api/auth/refresh',
        data: {
          'session_id': session.sessionId,
          'refresh_token': session.refreshToken,
        },
      );

      final data = response.data;
      if (data is Map && data['access_token'] != null) {
        final newAccessToken = data['access_token'].toString();
        final newRefreshToken = (data['refresh_token'] ?? session.refreshToken).toString();

        await updateTokens(
          newAccessToken: newAccessToken,
          newRefreshToken: newRefreshToken,
        );

        _refreshCompleter?.complete(newAccessToken);
        return newAccessToken;
      }

      throw const SessionExpiredException();
    } on DioException catch (e) {
      // 1. Kiểm tra nếu là lỗi mạng / mất kết nối (Offline) -> GIỮ NGUYÊN PHIÊN
      if (_isNetworkError(e)) {
        _refreshCompleter?.complete(null);
        throw const OfflineException();
      }

      // 2. Nếu Backend trả về 401 hoặc 403 (Phiên thực sự đã hết hạn hoặc bị đá)
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await clearSession();
        _refreshCompleter?.complete(null);
        throw const SessionExpiredException();
      }

      // Các lỗi khác -> thông báo chung, không xóa phiên
      _refreshCompleter?.complete(null);
      throw const UserFacingException(
        'Không thể làm mới phiên làm việc. Vui lòng thử lại sau.',
      );
    } catch (e) {
      _refreshCompleter?.complete(null);
      if (e is UserFacingException) rethrow;
      throw const UserFacingException(
        'Đã xảy ra sự cố xác thực. Vui lòng đăng nhập lại.',
      );
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Kiểm tra nhanh các mã lỗi mất mạng của Dio
  bool _isNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. DIO INTERCEPTOR CHUẨN ĐỂ TÍCH HỢP VÀO CODEBASE CỦA BẠN
  // ──────────────────────────────────────────────────────────────────────────

  /// Gọi khi phiên hết hạn hẳn (server từ chối cả refresh token). Đặt một lần ở
  /// main.dart, vì interceptor nằm ở tầng dữ liệu nên không tự điều hướng được.
  static void Function()? onSessionExpiredGlobally;

  /// Tạo Dio Interceptor giúp tự động gắn Access Token và Silent Refresh khi 401
  QueuedInterceptor createDioInterceptor(
    Dio dio, {
    void Function()? onSessionExpired,
  }) {
    return QueuedInterceptorsWrapper(
      onRequest: (options, handler) {
        // Gắn access token vào header nếu có
        final token = _currentSession?.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException err, handler) async {
        // Nếu lỗi 401 và không phải là request đăng nhập/refresh
        final isAuthEndpoint = err.requestOptions.path.contains('/auth/login') ||
            err.requestOptions.path.contains('/auth/refresh');

        if (err.response?.statusCode == 401 && !isAuthEndpoint) {
          try {
            // Thử làm mới token ngầm
            final newToken = await refreshAccessToken(dio);

            // Thử lại request ban đầu với token mới
            final retryOptions = err.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newToken';

            final response = await dio.fetch(retryOptions);
            return handler.resolve(response);
          } on OfflineException {
            // Đang ngoại tuyến -> trả về lỗi ngoại tuyến thân thiện
            return handler.reject(err);
          } on SessionExpiredException {
            // Phiên hết hạn -> gọi callback để UI điều hướng về login
            (onSessionExpired ?? onSessionExpiredGlobally)?.call();
            return handler.reject(err);
          } catch (_) {
            return handler.reject(err);
          }
        }

        return handler.next(err);
      },
    );
  }
}
