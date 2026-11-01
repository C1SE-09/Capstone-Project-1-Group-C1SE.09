// TestSessionManagement — phủ 4 AC của tính năng quản lý phiên:
//   AC1: mở lại app đã đăng nhập thì vào thẳng, không qua màn đăng nhập
//   AC2: repository tự làm mới phiên ngầm khi gặp 401
//   AC4/AC6: mỗi máy gửi 1 device_id ổn định để backend đếm đúng số thiết bị

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
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
      expect(initialRouteFor(sessionWithRole('admin')), '/login');
      expect(initialRouteFor(sessionWithRole('vai-tro-la')), '/login');
    });

    test('mở lại app đọc được phiên đã lưu trong máy', () async {
      SharedPreferences.setMockInitialValues({
        'app_session_access_token': 'access-cu',
        'app_session_refresh_token': 'refresh-cu',
        'app_session_id': 'sid-cu',
        'app_session_role': 'parent',
        'app_session_parent_id': 'parent-1',
        'app_session_expires_at':
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
      });

      final loaded =
          await SessionManagementService.instance.loadPersistedSession();

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
        'app_session_expires_at':
            DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
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
        reason:
            'cùng một máy mà đổi device_id thì backend đếm thành 2 thiết bị',
      );
      expect((adapter.requests.first.data as Map)['device_name'], isNotEmpty);
    });

    test('login lưu phiên để lần sau vào thẳng', () async {
      final (auth, _) = repo();

      final user = await auth.login(username: 'tuan', password: '123456');

      expect(user.role, 'parent');
      expect(SessionManagementService.instance.isLoggedIn, isTrue);
      expect(
          SessionManagementService.instance.currentSession?.sessionId, 'sid-1');
      expect(
        SessionManagementService.instance.currentSession?.refreshToken,
        'refresh-moi',
        reason: 'thiếu refresh token thì không làm mới phiên ngầm được',
      );
    });
  });

  group('Phiên khôi phục tối đa 1 giờ', () {
    Map<String, Object> savedSession({int? expiresAt}) => {
          'app_session_access_token': 'access-cu',
          'app_session_refresh_token': 'refresh-cu',
          'app_session_id': 'sid-cu',
          'app_session_role': 'parent',
          if (expiresAt != null) 'app_session_expires_at': expiresAt,
        };

    test('không khôi phục token sau 60 phút', () async {
      SharedPreferences.setMockInitialValues(savedSession(
        expiresAt: DateTime.now().millisecondsSinceEpoch,
      ));
      expect(await SessionManagementService.instance.loadPersistedSession(),
          isNull);
      expect(SessionManagementService.instance.isLoggedIn, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_session_refresh_token'), isNull);
    });

    test('phiên cũ không có thời hạn phải đăng nhập lại một lần', () async {
      SharedPreferences.setMockInitialValues(savedSession());
      expect(await SessionManagementService.instance.loadPersistedSession(),
          isNull);
      expect(SessionManagementService.instance.isLoggedIn, isFalse);
    });

    test('khôi phục phiên khi còn thời hạn', () async {
      SharedPreferences.setMockInitialValues(savedSession(
        expiresAt: DateTime.now()
            .add(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      ));
      expect(
          (await SessionManagementService.instance.loadPersistedSession())
              ?.sessionId,
          'sid-cu');
    });

    test('login đặt hạn 1 giờ và refresh không kéo dài thời hạn đó', () async {
      final before =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
      await SessionManagementService.instance.saveSession(const AppSession(
        accessToken: 'access-moi',
        refreshToken: 'refresh-moi',
        sessionId: 'sid-moi',
        role: 'parent',
      ));
      final after =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      final expiresAt = prefs.getInt('app_session_expires_at');
      expect(expiresAt, isNotNull);
      expect(expiresAt, inInclusiveRange(before, after));
      await SessionManagementService.instance.updateTokens(
        newAccessToken: 'access-refresh',
        newRefreshToken: 'refresh-refresh',
      );
      expect(prefs.getInt('app_session_expires_at'), expiresAt);
    });
  });

  group('AC2 — repository tự làm mới phiên ngầm', () {
    test('lỗi refresh tạm thời không làm request cùng phiên điều hướng login',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = Completer<HttpRequest>();
      server.listen(received.complete);
      final service = SessionManagementService.instance;
      await service.saveSession(const AppSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        sessionId: 'same-session',
        role: 'parent',
      ));
      var expired = 0;
      Dio client() {
        final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'))
          ..httpClientAdapter =
              _FakeAdapter((_) async => ResponseBody.fromString('{}', 401));
        dio.interceptors.add(service.createDioInterceptor(dio,
            onSessionExpired: () => expired++));
        return dio;
      }

      final first = expectLater(
          client().get('/api/parent/profile'), throwsA(isA<DioException>()));
      final second = expectLater(
          client().get('/api/parent/reports'), throwsA(isA<DioException>()));
      final request = await received.future.timeout(const Duration(seconds: 5));
      await request.drain<void>();
      request.response.statusCode = 503;
      await request.response.close();
      await Future.wait([first, second]);
      expect(expired, 0);
      expect(service.currentSession?.sessionId, 'same-session');
    });

    test('phiên mới không chờ refresh đang chạy của phiên cũ', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final receivedOld = Completer<HttpRequest>();
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        if (body['session_id'] == 'old-session') {
          receivedOld.complete(request);
        } else {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'access_token': 'new-refreshed',
              'refresh_token': 'new-refresh'
            }));
          await request.response.close();
        }
      });
      final service = SessionManagementService.instance;
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'));
      await service.saveSession(const AppSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        sessionId: 'old-session',
        role: 'parent',
      ));
      final oldAssertion = expectLater(service.refreshAccessToken(dio),
          throwsA(isA<SessionExpiredException>()));
      final oldRequest =
          await receivedOld.future.timeout(const Duration(seconds: 5));
      await service.clearSession();
      await service.saveSession(const AppSession(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        sessionId: 'new-session',
        role: 'teacher',
      ));
      final newAssertion = expectLater(
          service.refreshAccessToken(dio), completion('new-refreshed'));
      oldRequest.response.statusCode = 401;
      await oldRequest.response.close();
      await oldAssertion;
      await newAssertion;
      expect(service.currentSession?.accessToken, 'new-refreshed');
    });

    test('lỗi refresh cũ không điều hướng phiên mới về login', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = Completer<HttpRequest>();
      server.listen(received.complete);
      final service = SessionManagementService.instance;
      await service.saveSession(const AppSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        sessionId: 'old-session',
        role: 'parent',
      ));
      var expired = false;
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'))
        ..httpClientAdapter =
            _FakeAdapter((_) async => ResponseBody.fromString('{}', 401));
      dio.interceptors.add(service.createDioInterceptor(dio,
          onSessionExpired: () => expired = true));
      final assertion = expectLater(
          dio.get('/api/parent/profile'), throwsA(isA<DioException>()));
      final request = await received.future.timeout(const Duration(seconds: 5));
      await request.drain<void>();
      await service.clearSession();
      await service.saveSession(const AppSession(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        sessionId: 'new-session',
        role: 'teacher',
      ));
      request.response.statusCode = 401;
      await request.response.close();
      await assertion;
      expect(expired, isFalse);
      expect(service.currentSession?.sessionId, 'new-session');
    });

    for (final status in [200, 401]) {
      test('refresh cũ trả $status không ghi đè hoặc xóa phiên đăng nhập mới',
          () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final received = Completer<HttpRequest>();
        server.listen(received.complete);
        final service = SessionManagementService.instance;
        await service.saveSession(const AppSession(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          sessionId: 'old-session',
          role: 'parent',
        ));
        final refresh = service.refreshAccessToken(Dio(BaseOptions(
          baseUrl: 'http://127.0.0.1:${server.port}',
        )));
        final assertion =
            expectLater(refresh, throwsA(isA<SessionExpiredException>()));
        final request =
            await received.future.timeout(const Duration(seconds: 5));
        await request.drain<void>();
        await service.clearSession();
        await service.saveSession(const AppSession(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          sessionId: 'new-session',
          role: 'teacher',
        ));
        request.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'access_token': 'late-access',
            'refresh_token': 'late-refresh'
          }));
        await request.response.close();
        await assertion;
        expect(service.currentSession?.sessionId, 'new-session');
        expect(service.currentSession?.accessToken, 'new-access');
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_session_access_token'), 'new-access');
      });
    }

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

      for (final entry in opened.entries) {
        expect(
          entry.value.interceptors.length,
          greaterThanOrEqualTo(1),
          reason:
              '${entry.key} chưa gắn interceptor → hết hạn token là 401 giữa chừng',
        );
      }
    });

    test('phiên hết hạn hẳn thì gọi callback đưa về màn đăng nhập', () async {
      var navigated = false;
      SessionManagementService.onSessionExpiredGlobally = () {
        navigated = true;
      };
      addTearDown(
        () => SessionManagementService.onSessionExpiredGlobally = null,
      );

      // setUp đã xoá phiên nên refresh chắc chắn thất bại.
      final adapter = _FakeAdapter(
        (_) async => ResponseBody.fromString(
          '{}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(
        SessionManagementService.instance.createDioInterceptor(dio),
      );

      await expectLater(
        dio.get('/api/parent/profile'),
        throwsA(isA<DioException>()),
      );

      expect(
        navigated,
        isTrue,
        reason: 'không điều hướng thì người dùng kẹt ở màn hình lỗi',
      );
    });
  });

  group('AC5 — đổi mật khẩu đá thiết bị khác', () {
    test('gửi cờ logout_other_devices đúng lựa chọn của người dùng', () async {
      AuthRepository.currentUser = const AuthUser(
        token: 'access-1',
        role: 'parent',
      );
      addTearDown(() => AuthRepository.currentUser = null);

      final adapter = _FakeAdapter((_) async => _json({'message': 'ok'}));
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
        ..httpClientAdapter = adapter;
      final auth = AuthRepository(dio: dio);

      await auth.changePassword(
        currentPassword: 'cu123456',
        newPassword: 'moi123456',
        logoutOtherDevices: false,
      );
      await auth.changePassword(
        currentPassword: 'cu123456',
        newPassword: 'moi123456',
      );

      final bodies = adapter.requests.map((r) => r.data as Map).toList();
      expect(
        bodies[0]['logout_other_devices'],
        isFalse,
        reason: 'bỏ chọn mà vẫn gửi true thì máy khác vẫn bị đá oan',
      );
      expect(
        bodies[1]['logout_other_devices'],
        isTrue,
        reason: 'không truyền gì thì mặc định phải bật (AC5)',
      );
    });
  });
}
