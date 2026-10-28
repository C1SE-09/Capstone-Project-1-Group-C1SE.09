// frontend/lib/core/notifications/push_notification_service.dart
// =========================================================
// Push notification (FCM): mở đúng báo cáo hoặc thông báo điểm danh.
//
// - Đăng ký token cho phụ huynh/giáo viên và xoá khi đăng xuất.
// - App đang mở (foreground): hiện SnackBar kèm nút "Xem".
// - App nền / đã tắt: giữ đích đến cho tới khi UI và phiên đăng nhập sẵn sàng.
//
// Mọi thao tác đều "fail soft": thiếu cấu hình Firebase (google-services.json,
// nền tảng không hỗ trợ) thì app vẫn chạy bình thường.

import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/data/repositories/http_notification_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:adark_frontend/core/notifications/emergency_siren_service.dart';
import 'package:adark_frontend/domain/entities/health/emergency_alert_data.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/emergency_alert_summary_screen.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  /// Gắn vào MaterialApp.router để hiện SnackBar khi app đang mở.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  NotificationRepository repository = HttpNotificationRepository();

  bool _initialized = false;
  String? _currentToken;
  Uri? _pendingLocation;
  int _tapSequence = 0;

  Future<void> init() async {
    if (_initialized || Firebase.apps.isEmpty) return;
    _initialized = true;

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleNotificationTap);
    FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

    // Thông báo đã khởi chạy app từ trạng thái tắt hẳn.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      handleNotificationTap(initialMessage);
    }
    if (SessionManagementService.instance.isLoggedIn) {
      registerCurrentDevice();
    }
  }

  /// Phụ huynh nhận báo cáo/bé vắng, giáo viên nhận nhắc điểm danh.
  Future<void> registerCurrentDevice() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } catch (error) {
      debugPrint('Push registration skipped: $error');
    }
  }

  /// Gọi khi đăng xuất để ngừng nhận thông báo trên thiết bị này.
  Future<void> deleteCurrentDevice() async {
    _pendingLocation = null;
    if (Firebase.apps.isEmpty) return;
    try {
      final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _currentToken = null;
      await repository.deleteDeviceToken(token);
    } catch (error) {
      debugPrint('Push token cleanup skipped: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    _currentToken = token;
    try {
      await repository.registerDeviceToken(
        token: token,
        deviceType: defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : 'other',
      );
    } catch (error) {
      debugPrint('Push token registration failed: $error');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final isEmergency = message.data['type'] == 'health_incident_alert';
    if (isEmergency) {
      final alert = EmergencyAlertData.fromMap(message.data);
      // Kích hoạt còi hú báo động ngay lập tức
      EmergencySirenService.instance.playSiren();

      final context = scaffoldMessengerKey.currentContext;
      if (context != null) {
        EmergencyAlertSummaryScreen.showModal(context, alert);
        return;
      }
    }

    final title = message.notification?.title ??
        (isEmergency ? '🚨 CẢNH BÁO SỰ CỐ KHẨN CẤP!' : 'Thông báo mới');
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: isEmergency ? const Color(0xFFD32F2F) : null,
        duration: isEmergency ? const Duration(seconds: 30) : const Duration(seconds: 4),
        content: Text(
          title,
          style: TextStyle(
            fontWeight: isEmergency ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        action: SnackBarAction(
          label: isEmergency ? 'XEM & GỌI CÔ' : 'Xem',
          textColor: isEmergency ? Colors.yellowAccent : null,
          onPressed: () => handleNotificationTap(message),
        ),
      ),
    );
  }

  void handleNotificationTap(RemoteMessage message) {
    final location = _locationForMessage(message.data);
    if (location == null) return;
    _pendingLocation = location.replace(queryParameters: {
      ...location.queryParameters,
      'notification': '${++_tapSequence}',
    });
    // getInitialMessage có thể về trước runApp; không điều hướng trong lúc build.
    // https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessions = SessionManagementService.instance;
      if (!sessions.isLoggedIn) {
        appRouter.go('/login');
        return;
      }
      final target = pendingLocationFor(sessions.currentSession!.role);
      // Push giữ nguyên màn đang sửa; back quay lại bản nháp thay vì xóa route đó.
      if (target != null) appRouter.push(target);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Dùng sau đăng nhập để tiếp tục lần chạm push, không vượt qua guard vai trò.
  String? pendingLocationFor(String role) {
    final target = _pendingLocation;
    if (target == null) return null;
    final isParentPath =
        target.path == '/parent' || target.path.startsWith('/parent/');
    final expectedRole = isParentPath ? 'parent' : 'teacher';
    if (role != expectedRole) {
      _pendingLocation = null;
      return null;
    }
    return target.toString();
  }

  /// Chỉ bỏ đích đã hiển thị, không để request cũ xóa thông báo mới hơn.
  void completePendingNotification(String? notificationId) {
    if (notificationId != null &&
        _pendingLocation?.queryParameters['notification'] == notificationId) {
      _pendingLocation = null;
    }
  }

  Uri? _locationForMessage(Map<String, dynamic> data) {
    String? text(String key) {
      final value = data[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final type = text('type');
    if (type == 'health_incident_alert') {
      final alert = EmergencyAlertData.fromMap(data);
      return Uri(
        path: '/parent/emergency-alert',
        queryParameters: alert.toQueryParameters(),
      );
    }

    final childId = text('child_id');
    if (type == 'report_sent' || type == 'report_updated') {
      final reportId = text('report_id');
      if (reportId == null || childId == null) return null;
      return Uri(path: '/parent', queryParameters: {
        'reportId': reportId,
        'childId': childId,
      });
    }

    if (type != 'attendance_absent' && type != 'attendance_reminder') return null;
    final date = text('date');
    if (date == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date)?.toIso8601String().split('T').first != date) {
      return null;
    }
    if (type == 'attendance_absent' && childId != null) {
      return Uri(path: '/parent', queryParameters: {
        'childId': childId,
        'attendanceDate': date,
      });
    }
    final classId = text('class_id');
    if (type == 'attendance_reminder' && classId != null) {
      return Uri(path: '/teacher', queryParameters: {
        'classId': classId,
        'attendanceDate': date,
      });
    }
    return null;
  }
}
