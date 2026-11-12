import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_notifications.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_overview.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme_controller.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Nunito')
          ..addFont(
              rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf')))
        .load();
    final fonts = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await fonts.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'kinderlog-theme-mode': 'dark'});
    await SessionManagementService.instance.saveSession(const AppSession(
      accessToken: 'test-only-access',
      refreshToken: 'test-only-refresh',
      sessionId: 'test-only-session',
      role: 'parent',
    ));
  });

  Future<void> openMain(WidgetTester tester) async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = _FixtureHttp();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      HttpOverrides.global = previous;
      await SessionManagementService.instance.clearSession();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appRouter.go('/parent');
    await tester.pumpWidget(const RepaintBoundary(
        key: ValueKey('main-runtime-capture'), child: MyApp()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mở thông báo'), findsOneWidget);
  }

  testWidgets('main.dart stays light despite saved dark and Android dark',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await ThemeController.instance.load();
    await openMain(tester);
    final nav = find.byKey(const ValueKey('garden-voice-parent-navigation'));
    expect(Theme.of(tester.element(nav)).brightness, Brightness.light);
    expect((tester.widget<DecoratedBox>(nav).decoration as BoxDecoration).color,
        KPalette.gardenVoice.navigationSurface);
    expect(ThemeController.instance.value, ThemeMode.light);
  });

  testWidgets('theme settings do not offer unapproved dark or system mode',
      (tester) async {
    await ThemeController.instance.load();
    await tester.pumpWidget(MaterialApp(
        theme: kinderTheme(),
        home: const GardenVoiceScope(child: Scaffold(body: ThemeSelector()))));
    expect(find.text('Tối'), findsNothing);
    expect(find.text('Theo máy'), findsNothing);
    await ThemeController.instance.set(ThemeMode.dark);
    expect(ThemeController.instance.value, ThemeMode.light);
  });

  testWidgets(
      'main.dart overview hides navigation and reclaims the bottom viewport',
      (tester) async {
    await ThemeController.instance.load();
    await openMain(tester);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    final list = find.descendant(
        of: find.byType(GardenVoiceParentOverview),
        matching: find.byType(ListView));
    final viewport = tester.getRect(list);
    expect(viewport.bottom, 640);
    final nav = find.byKey(const ValueKey('garden-voice-parent-navigation'));
    final shown = tester.getRect(nav);
    await tester.drag(list, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(tester.getRect(nav).top, greaterThan(640));
    expect(tester.getRect(list), viewport);
    await tester.drag(list, const Offset(0, 70));
    await tester.pumpAndSettle();
    expect(tester.getRect(nav), shown);
    expect(tester.getRect(list), viewport);
  });

  testWidgets(
      'main.dart real router and HTTP repositories animate and reclaim bottom area',
      (tester) async {
    ThemeController.instance.value = ThemeMode.light;
    await openMain(tester);
    final pill = find.byKey(const ValueKey('navigation-selected-indicator'));
    final start = tester.getRect(pill);
    await _capture(tester, 'main-parent-before');
    await tester.tap(find.byTooltip('Mở thông báo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final moving = tester.getRect(pill);
    final end = tester.getRect(find.byTooltip('Mở thông báo'));
    expect(moving.left, greaterThan(start.left));
    expect(moving.left, lessThan(end.left));
    await _capture(tester, 'main-parent-moving-80ms');
    await tester.pumpAndSettle();
    expect(tester.getRect(pill), end);
    await _capture(tester, 'main-parent-selected');
    final list = find.descendant(
        of: find.byType(ParentNotifications), matching: find.byType(ListView));
    expect(tester.getRect(list).bottom, 844);
    await tester.drag(list, const Offset(0, -250));
    await tester.pumpAndSettle();
    final nav = find.byKey(const ValueKey('garden-voice-parent-navigation'));
    expect(tester.getRect(nav).top, greaterThan(844));
    await _capture(tester, 'main-parent-hidden');
    await tester.drag(list, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(tester.getRect(nav).top, 768);
    await _capture(tester, 'main-parent-shown');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('UI_CAPTURE_DIR');
  if (directory.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('main-runtime-capture')));
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(directory).createSync(recursive: true);
    File('$directory/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

// Chỉ mock biên HTTP; MyApp, router và repository production giữ nguyên.
class _FixtureHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client();
}

class _Client implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Request(url);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.url);
  final Uri url;
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<HttpClientResponse> close() async => _Response(_body(url));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  void forEach(void Function(String, List<String>) action) =>
      action('content-type', ['application/json']);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(Object body) : bytes = utf8.encode(jsonEncode(body));
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  HttpHeaders get headers => _Headers();
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Object _body(Uri uri) {
  if (uri.path.endsWith('/reports')) {
    final reports = List.generate(
        30,
        (i) => {
              'daily_report_id': 'fixture-$i',
              'child_id': 'fixture-child',
              'report_date': DateTime(2026, 11, 4)
                  .subtract(Duration(days: i))
                  .toIso8601String(),
              'status': 'published',
              'summary_text': 'Báo cáo thử nghiệm',
            });
    return {'today_report': reports.first, 'recent_reports': reports};
  }
  if (uri.path.endsWith('/child')) {
    return {
      'child': {
        'child_id': 'fixture-child',
        'full_name': 'Bé thử nghiệm',
        'class_id': 'fixture-class'
      },
      'class_name': 'Mầm 1',
      'teacher_name': 'Cô thử nghiệm'
    };
  }
  if (uri.path.contains('/api/parent/')) {
    return {'parent_id': 'fixture-parent', 'full_name': 'Phụ huynh thử nghiệm'};
  }
  return {};
}
