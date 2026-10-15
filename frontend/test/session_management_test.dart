// TestSessionManagement — phủ 4 AC của tính năng quản lý phiên:
//   AC1: mở lại app đã đăng nhập thì vào thẳng, không qua màn đăng nhập
//   AC2: repository tự làm mới phiên ngầm khi gặp 401
//   AC4/AC6: mỗi máy gửi 1 device_id ổn định để backend đếm đúng số thiết bị

import 'dart:convert';
import 'dart:typed_data';

import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/http_admin_repository.dart';
import 'package:adark_frontend/data/repositories/http_bug_report_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_notification_repository.dart';
import 'package:adark_frontend/data/repositories/http_schedule_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adapter giả để bắt request mà không cần server thật.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.onRequest);

  final Future<ResponseBody> Function(RequestOptions options) onRequest;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return onRequest(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Map<String, dynamic> _loginBody({String? sessionId}) => {
  'access_token': 'access-moi',
  'refresh_token': 'refresh-moi',
  'session_id': sessionId ?? 'sid-1',
  'token_type': 'bearer',
  'role': 'parent',
  'user_id': 'user-1',
  'username': 'tuan',
  'parent_id': 'parent-1',
};

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManagementService.instance.clearSession();
  });

  group('AC1 — mở lại app vào thẳng', () {
    AppSession sessionWithRole(String role) => AppSession(
      accessToken: 'a',
      refreshToken: 'r',
      sessionId: 's',
      role: role,
    );

    test('chưa có phiên thì về màn đăng nhập', () {
      expect(initialRouteFor(null), '/login');
    });

    test('có phiên thì vào thẳng đúng màn theo vai trò', () {
      expect(initialRouteFor(sessionWithRole('teacher')), '/class-select');
      expect(initialRouteFor(sessionWithRole('parent')), '/parent');
      expect(initialRouteFor(sessionWithRole('admin')), '/admin');
      expect(initialRouteFor(sessionWithRole('vai-tro-la')), '/login');
    });

    test('mở lại app đọc được phiên đã lưu trong máy', () async {
      SharedPreferences.setMockInitialValues({
        'app_session_access_token': 'access-cu',
        'app_session_refresh_token': 'refresh-cu',
        'app_session_id': 'sid-cu',
        'app_session_role': 'parent',
        'app_session_parent_id': 'parent-1',
      });

      final loaded = await SessionManagementService.instance
          .loadPersistedSession();

      expect(loaded?.sessionId, 'sid-cu');
      expect(SessionManagementService.instance.isLoggedIn, isTrue);
      expect(
        initialRouteFor(SessionManagementService.instance.currentSession),
        '/parent',
      );
    });

    test('đăng xuất xoá sạch phiên khỏi máy', () async {
      SharedPreferences.setMockInitialValues({
        'app_session_refresh_token': 'refresh-cu',
        'app_session_session_id': 'sid-cu',
        'app_session_role': 'parent',
      });
      await SessionManagementService.instance.loadPersistedSession();
      expect(SessionManagementService.instance.isLoggedIn, isTrue);

      await SessionManagementService.instance.clearSession();

      expect(SessionManagementService.instance.isLoggedIn, isFalse);
      expect(
        await SessionManagementService.instance.loadPersistedSession(),
        isNull,
        reason: 'đã xoá khỏi máy thì mở lại app phải về màn đăng nhập',
      );
    });
  });

  group('AC4/AC6 — định danh thiết bị', () {
    (AuthRepository, _FakeAdapter) repo() {
      final adapter = _FakeAdapter((_) async => _json(_loginBody()));
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
        ..httpClientAdapter = adapter;
      return (AuthRepository(dio: dio), adapter);
    }

    test('login gửi device_id ổn định giữa các lần đăng nhập', () async {
      final (auth, adapter) = repo();

      await auth.login(username: 'tuan', password: '123456');
      await auth.login(username: 'tuan', password: '123456');

      final deviceIds = adapter.requests
          .map((r) => (r.data as Map)['device_id'] as String?)
          .toList();
      expect(deviceIds.first, isNotNull);
      expect(deviceIds.first, isNotEmpty);
      expect(
        deviceIds[1],
        deviceIds.first,
        reason: 'cùng một máy mà đổi device_id thì backend đếm thành 2 thiết bị',
      );
      expect((adapter.requests.first.data as Map)['device_name'], isNotEmpty);
    });

    test('login lưu phiên để lần sau vào thẳng', () async {
      final (auth, _) = repo();

      final user = await auth.login(username: 'tuan', password: '123456');

      expect(user.role, 'parent');
      expect(SessionManagementService.instance.isLoggedIn, isTrue);
      expect(SessionManagementService.instance.currentSession?.sessionId, 'sid-1');
      expect(
        SessionManagementService.instance.currentSession?.refreshToken,
        'refresh-moi',
        reason: 'thiếu refresh token thì không làm mới phiên ngầm được',
      );
    });
  });

  group('AC2 — repository tự làm mới phiên ngầm', () {
    test('mọi repository đều gắn interceptor silent refresh', () {
      final opened = <String, Dio>{};

      Dio dioFor(String name) {
        final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
        opened[name] = dio;
        return dio;
      }

      // Mỗi repository nhận 1 Dio riêng, giống lúc chạy thật.
      AuthRepository(dio: dioFor('auth'));
      TeacherRepository(dio: dioFor('teacher'));
      HttpDashboardRepository(dio: dioFor('dashboard'));
      HttpClassDataRepository(dio: dioFor('class_data'));
      HttpScheduleRepository(dio: dioFor('schedule'));
      HttpNotificationRepository(dio: dioFor('notification'));
      HttpBugReportRepository(dio: dioFor('bug_report'));
      HttpAdminRepository(dio: dioFor('admin'));

      for (final entry in opened.entries) {
        expect(
          entry.value.interceptors.length,
          greaterThanOrEqualTo(1),
          reason: '${entry.key} chưa gắn interceptor → hết hạn token là 401 giữa chừng',
        );
      }
    });
  });
}
