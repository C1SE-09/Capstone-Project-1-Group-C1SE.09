// frontend/lib/core/notifications/push_notification_service.dart
// =========================================================
// Push notification (FCM) — Scope A: chạm thông báo mở báo cáo hôm nay.
//
// - Đăng ký device token sau khi đăng nhập (phụ huynh) và xoá khi đăng xuất.
// - App đang mở (foreground): hiện SnackBar kèm nút "Xem".
// - App nền / đã tắt: chạm thông báo mở thẳng /parent?report=today.
//
// Mọi thao tác đều "fail soft": thiếu cấu hình Firebase (google-services.json,
// nền tảng không hỗ trợ) thì app vẫn chạy bình thường.

import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/data/repositories/http_notification_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  /// Gắn vào MaterialApp.router để hiện SnackBar khi app đang mở.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  NotificationRepository repository = HttpNotificationRepository();

  bool _initialized = false;
  String? _currentToken;

  Future<void> init() async {
    if (_initialized || Firebase.apps.isEmpty) return;
    _initialized = true;

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

    // Thông báo đã khởi chạy app từ trạng thái tắt hẳn.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Gọi sau khi đăng nhập thành công (MVP: chỉ phụ huynh nhận push).
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
    final title = message.notification?.title ?? 'Thông báo mới';
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(title),
        action: SnackBarAction(
          label: 'Xem',
          onPressed: () => _handleNotificationTap(message),
        ),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (message.data['type'] == 'report_sent') {
      appRouter.go('/parent?report=today');
    }
  }
}
