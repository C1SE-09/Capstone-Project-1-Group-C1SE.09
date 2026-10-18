import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refresh bị xóa phiên trong lúc ghi storage không khôi phục lại token',
      () async {
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final values = <String, Object>{};
    final writeStarted = Completer<void>();
    final releaseWrite = Completer<bool>();
    var holdWrite = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') return Map<String, Object>.from(values);
      final arguments = call.arguments as Map;
      final key = arguments['key'] as String;
      if (call.method == 'remove') {
        values.remove(key);
      } else if (call.method.startsWith('set')) {
        values[key] = arguments['value'] as Object;
        if (holdWrite && key == 'flutter.app_session_access_token') {
          writeStarted.complete();
          return releaseWrite.future;
        }
      }
      return true;
    });
    // Chỉ mở HTTP loopback của test; binding mặc định trả 400 cho mọi HTTP.
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final service = SessionManagementService.instance;
    addTearDown(() async {
      if (!releaseWrite.isCompleted) releaseWrite.complete(true);
      await service.clearSession();
      await server.close(force: true);
      HttpOverrides.global = previousOverrides;
      messenger.setMockMethodCallHandler(channel, null);
    });
    server.listen((request) async {
      await request.drain<void>();
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'access_token': 'refreshed-access',
          'refresh_token': 'refreshed-token'
        }));
      await request.response.close();
    });
    await service.saveSession(const AppSession(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      sessionId: 'session-test',
      role: 'parent',
    ));
    holdWrite = true;
    String? returnedToken;
    Object? refreshError;
    final refreshed = service
        .refreshAccessToken(Dio(BaseOptions(
          baseUrl: 'http://127.0.0.1:${server.port}',
        )))
        .then<void>((token) => returnedToken = token,
            onError: (Object error) => refreshError = error);
    await writeStarted.future.timeout(const Duration(seconds: 5));
    await service.clearSession();
    releaseWrite.complete(true);
    await refreshed;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_session_refresh_token'), isNull);
    expect(values['flutter.app_session_refresh_token'], isNull);
    expect(service.isLoggedIn, isFalse);
    expect(returnedToken, isNull);
    expect(refreshError, isA<SessionExpiredException>());
  });
}
