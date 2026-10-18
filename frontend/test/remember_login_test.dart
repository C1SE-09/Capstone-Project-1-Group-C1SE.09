// Thông tin giả; chỉ mock HTTP và kho mã hóa của nền tảng, giữ nguyên logic app.
import 'dart:convert';

import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/auth_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rememberedKey = 'app_remembered_login';
const _expiresKey = 'app_session_expires_at';
const _savedUsername = 'teacher.demo';
const _savedPassword = 'demo-password';
const _storage = FlutterSecureStorage();

class _UnavailableRememberedLoginRepository extends AuthRepository {
  _UnavailableRememberedLoginRepository(Dio dio) : super(dio: dio);

  @override
  Future<({String username, String password})?> readRememberedLogin() async =>
      throw PlatformException(code: 'storage_unavailable');

  @override
  Future<void> saveRememberedLogin(
          {required String username, required String password}) async =>
      throw PlatformException(code: 'storage_unavailable');

  @override
  Future<void> clearRememberedLogin() async =>
      throw PlatformException(code: 'storage_unavailable');
}

class _AuthAdapter implements HttpClientAdapter {
  _AuthAdapter({this.rejectLogin = false});

  final bool rejectLogin;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(rejectLogin
          ? {'detail': 'Thông tin đăng nhập không chính xác.'}
          : {
              'access_token': 'access-test',
              'refresh_token': 'refresh-test',
              'session_id': 'session-test',
              'token_type': 'bearer',
              'role': 'teacher',
              'user_id': 'user-test',
              'teacher_id': 'teacher-test',
              'username': (options.data as Map?)?['username'],
            }),
      rejectLogin ? 401 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await SessionManagementService.instance.clearSession();
    AuthRepository.currentUser = null;
  });

  Future<void> seedCredentials() => _storage.write(
        key: _rememberedKey,
        value: jsonEncode({
          'username': _savedUsername,
          'password': _savedPassword,
        }),
      );

  Future<_AuthAdapter> pumpLogin(WidgetTester tester,
      {bool rejectLogin = false, bool storageUnavailable = false}) async {
    final adapter = _AuthAdapter(rejectLogin: rejectLogin);
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: LoginScreen(
        authRepository: storageUnavailable
            ? _UnavailableRememberedLoginRepository(dio)
            : AuthRepository(dio: dio),
        onLogin: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    return adapter;
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('ĐĂNG NHẬP'));
    await tester.tap(find.text('ĐĂNG NHẬP'));
    await tester.pumpAndSettle();
  }

  testWidgets('checkbox mặc định tắt và không tự gửi yêu cầu đăng nhập',
      (tester) async {
    final adapter = await pumpLogin(tester);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    expect(adapter.requests, isEmpty);
  });

  for (final (width, dark, scale) in [
    (320.0, false, 2.0),
    (375.0, false, 1.0),
    (375.0, true, 1.0),
    (768.0, false, 1.0),
    (1440.0, false, 1.0),
  ]) {
    testWidgets('checkbox không tràn ở $width, dark=$dark, text=$scale',
        (tester) async {
      tester.view.physicalSize = Size(width, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: dark ? kinderThemeDark() : kinderTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: LoginScreen(onLogin: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Nhớ tài khoản'), findsOneWidget);
      expect(tester.getSize(find.byType(CheckboxListTile)).height,
          greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('điền lại tài khoản và mật khẩu nhưng vẫn chờ bấm Đăng nhập',
      (tester) async {
    await seedCredentials();
    final adapter = await pumpLogin(tester);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, _savedUsername);
    expect(fields[1].controller!.text, _savedPassword);
    expect(fields[1].obscureText, isTrue);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue);
    expect(adapter.requests, isEmpty);
    await submit(tester);
    expect(SessionManagementService.instance.isLoggedIn, isTrue);
  });

  testWidgets('chọn nhớ và login thành công mới ghi vào kho mã hóa',
      (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.byType(TextField).first, '  teacher.demo  ');
    await tester.enterText(find.byType(TextField).last, _savedPassword);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(await _storage.read(key: _rememberedKey), isNull);
    await submit(tester);
    expect(jsonDecode((await _storage.read(key: _rememberedKey))!), {
      'username': _savedUsername,
      'password': _savedPassword,
    });
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs
            .getKeys()
            .map(prefs.get)
            .whereType<String>()
            .any((value) => value.contains(_savedPassword)),
        isFalse);
  });

  testWidgets('bỏ chọn xóa thông tin đã nhớ ngay, không cần login tiếp',
      (tester) async {
    await seedCredentials();
    final adapter = await pumpLogin(tester);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(await _storage.read(key: _rememberedKey), isNull);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('login không chọn nhớ không lưu tài khoản hoặc mật khẩu',
      (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.byType(TextField).first, _savedUsername);
    await tester.enterText(find.byType(TextField).last, _savedPassword);
    await submit(tester);
    expect(SessionManagementService.instance.isLoggedIn, isTrue);
    expect(await _storage.read(key: _rememberedKey), isNull);
  });

  testWidgets('login sai không ghi đè thông tin đúng đã nhớ', (tester) async {
    await seedCredentials();
    final before = await _storage.read(key: _rememberedKey);
    await pumpLogin(tester, rejectLogin: true);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        _savedUsername);
    await tester.enterText(find.byType(TextField).first, 'other.demo');
    await tester.enterText(find.byType(TextField).last, 'wrong-password');
    await submit(tester);
    expect(find.text('Thông tin đăng nhập không chính xác.'), findsOneWidget);
    expect(await _storage.read(key: _rememberedKey), before);
    expect(SessionManagementService.instance.isLoggedIn, isFalse);
  });

  testWidgets('xóa phiên không xóa thông tin nhớ đăng nhập', (tester) async {
    await seedCredentials();
    await SessionManagementService.instance.saveSession(const AppSession(
      accessToken: 'access-test',
      refreshToken: 'refresh-test',
      sessionId: 'session-test',
      role: 'teacher',
    ));
    await SessionManagementService.instance.clearSession();
    await pumpLogin(tester);
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        _savedPassword);
    expect(SessionManagementService.instance.isLoggedIn, isFalse);
  });

  testWidgets('bản ghi không hợp lệ không làm hỏng form hoặc điền nhầm dữ liệu',
      (tester) async {
    await _storage.write(key: _rememberedKey, value: '{not-json');
    await pumpLogin(tester);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kho mã hóa lỗi vẫn login được và không lưu mật khẩu thuần',
      (tester) async {
    await pumpLogin(tester, storageUnavailable: true);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled, isTrue);
    await tester.enterText(find.byType(TextField).first, _savedUsername);
    await tester.enterText(find.byType(TextField).last, _savedPassword);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await submit(tester);
    expect(SessionManagementService.instance.isLoggedIn, isTrue);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(await _storage.read(key: _rememberedKey), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs
            .getKeys()
            .map(prefs.get)
            .whereType<String>()
            .any((value) => value.contains(_savedPassword)),
        isFalse);
  });

  Future<void> pumpExpiredApp(WidgetTester tester) async {
    await seedCredentials();
    await SessionManagementService.instance.saveSession(const AppSession(
      accessToken: 'access-test',
      refreshToken: 'refresh-test',
      sessionId: 'session-test',
      role: 'test-role',
    ));
    AuthRepository.currentUser =
        const AuthUser(token: 'access-test', role: 'teacher');
    appRouter.go('/login');
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _expiresKey,
        DateTime.now()
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch);
  }

  testWidgets('đang foreground quá hạn không tự văng', (tester) async {
    await pumpExpiredApp(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(SessionManagementService.instance.isLoggedIn, isTrue);
    expect(AuthRepository.currentUser, isNotNull);
  });

  testWidgets('deep link báo cáo không bỏ qua login khi không còn phiên',
      (tester) async {
    appRouter.go('/login');
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    appRouter.go('/parent?report=today');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(SessionManagementService.instance.isLoggedIn, isFalse);
  });

  testWidgets('chỉ mất focus rồi quay lại không được tính là thoát app',
      (tester) async {
    await pumpExpiredApp(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(SessionManagementService.instance.isLoggedIn, isTrue);
  });

  testWidgets('quay lại từ nền trước hạn vẫn giữ phiên', (tester) async {
    await pumpExpiredApp(tester);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_expiresKey,
        DateTime.now().add(const Duration(minutes: 1)).millisecondsSinceEpoch);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(SessionManagementService.instance.isLoggedIn, isTrue);
    expect(AuthRepository.currentUser, isNotNull);
  });

  for (final background in [
    AppLifecycleState.hidden,
    AppLifecycleState.paused
  ]) {
    testWidgets('quay từ $background sau hạn xóa token, giữ thông tin nhớ',
        (tester) async {
      await pumpExpiredApp(tester);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        if (background == AppLifecycleState.paused) ...[
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
        ],
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(SessionManagementService.instance.isLoggedIn, isFalse);
      expect(AuthRepository.currentUser, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_session_access_token'), isNull);
      expect(prefs.getString('app_session_refresh_token'), isNull);
      expect(await _storage.read(key: _rememberedKey), isNotNull);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  }
}
