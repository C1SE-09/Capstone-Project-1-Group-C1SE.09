import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/attendance_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_shell.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _parentSession = AppSession(
  accessToken: 'test-access',
  refreshToken: 'test-refresh',
  sessionId: 'test-session',
  role: 'parent',
  parentId: 'parent-1',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final push = PushNotificationService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManagementService.instance.saveSession(_parentSession);
    appRouter.go('/parent');
  });

  tearDown(() async {
    await push.deleteCurrentDevice();
    await SessionManagementService.instance.clearSession();
  });

  for (final type in ['report_sent', 'report_updated']) {
    testWidgets('$type mở đúng report_id và child_id sau khi dựng UI', (tester) async {
      push.handleNotificationTap(RemoteMessage(data: {
        'type': type,
        'report_id': 'report-old',
        'child_id': 'child-2',
      }));
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      final uri = appRouter.routeInformationProvider.value.uri;
      expect(uri.path, '/parent');
      expect(uri.queryParameters['reportId'], 'report-old');
      expect(uri.queryParameters['childId'], 'child-2');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('thông báo bé vắng mở thông tin đúng bé và ngày', (tester) async {
    push.handleNotificationTap(const RemoteMessage(data: {
      'type': 'attendance_absent',
      'child_id': 'child-2',
      'date': '2026-10-20',
    }));
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump();

    final uri = appRouter.routeInformationProvider.value.uri;
    expect(uri.path, '/parent');
    expect(uri.queryParameters['childId'], 'child-2');
    expect(uri.queryParameters['attendanceDate'], '2026-10-20');
  });

  testWidgets('nhắc điểm danh mở đúng lớp và ngày của giáo viên', (tester) async {
    await SessionManagementService.instance.saveSession(const AppSession(
      accessToken: 'test-access',
      refreshToken: 'test-refresh',
      sessionId: 'teacher-session',
      role: 'teacher',
      teacherId: 'teacher-1',
    ));
    push.handleNotificationTap(const RemoteMessage(data: {
      'type': 'attendance_reminder',
      'class_id': 'class-2',
      'date': '2026-10-20',
    }));
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump();

    final uri = appRouter.routeInformationProvider.value.uri;
    expect(uri.path, '/teacher');
    expect(uri.queryParameters['classId'], 'class-2');
    expect(uri.queryParameters['attendanceDate'], '2026-10-20');
  });

  testWidgets('chạm lại cùng thông báo tạo lần mở mới', (tester) async {
    const message = RemoteMessage(data: {
      'type': 'report_sent',
      'report_id': 'report-1',
      'child_id': 'child-1',
    });
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    push.handleNotificationTap(message);
    await tester.pump();
    final first = appRouter.routeInformationProvider.value.uri;
    push.handleNotificationTap(message);
    await tester.pump();

    expect(appRouter.routeInformationProvider.value.uri, isNot(first));
  });

  testWidgets('payload thiếu ID không mở báo cáo khác', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    push.handleNotificationTap(const RemoteMessage(data: {'type': 'report_sent'}));
    await tester.pump();

    expect(appRouter.routeInformationProvider.value.uri.toString(), '/parent');
    expect(tester.takeException(), isNull);
  });

  testWidgets('không đưa giáo viên vào màn báo cáo phụ huynh', (tester) async {
    await SessionManagementService.instance.saveSession(const AppSession(
      accessToken: 'test-access',
      refreshToken: 'test-refresh',
      sessionId: 'teacher-session',
      role: 'teacher',
    ));
    appRouter.go('/teacher');
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    push.handleNotificationTap(const RemoteMessage(data: {
      'type': 'report_sent',
      'report_id': 'report-1',
      'child_id': 'child-1',
    }));
    await tester.pump();

    expect(appRouter.routeInformationProvider.value.uri.path, '/teacher');
  });

  testWidgets('giữ đích đến qua đăng nhập cho tới khi đích đã hiển thị', (tester) async {
    await SessionManagementService.instance.clearSession();
    push.handleNotificationTap(const RemoteMessage(data: {
      'type': 'report_updated',
      'report_id': 'report-old',
      'child_id': 'child-2',
    }));
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump();
    expect(appRouter.routeInformationProvider.value.uri.path, '/login');

    await SessionManagementService.instance.saveSession(_parentSession);
    final target = Uri.parse(push.pendingLocationFor('parent')!);
    expect(target.queryParameters['reportId'], 'report-old');
    expect(target.queryParameters['childId'], 'child-2');
    expect(push.pendingLocationFor('parent'), isNotNull);
    push.completePendingNotification('old-notification');
    expect(push.pendingLocationFor('parent'), isNotNull);
    push.completePendingNotification(target.queryParameters['notification']);
    expect(push.pendingLocationFor('parent'), isNull);
  });

  testWidgets('chạm Xem khi đang foreground không tự hết phiên theo đồng hồ', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_session_expires_at', 0);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    push.handleNotificationTap(const RemoteMessage(data: {
      'type': 'report_sent', 'report_id': 'report-1', 'child_id': 'child-1',
    }));
    await tester.pump();

    expect(SessionManagementService.instance.isLoggedIn, isTrue);
    expect(appRouter.routeInformationProvider.value.uri.queryParameters['reportId'], 'report-1');
  });

  testWidgets('server từ chối phiên vẫn giữ đích đến cho lần đăng nhập lại', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    push.handleNotificationTap(const RemoteMessage(data: {
      'type': 'report_updated', 'report_id': 'report-old', 'child_id': 'child-2',
    }));
    await tester.pump();
    // Mô phỏng callback phiên bị server thu hồi sau khi đã điều hướng.
    await SessionManagementService.instance.clearSession();
    appRouter.go('/login');
    await SessionManagementService.instance.saveSession(_parentSession);

    expect(push.pendingLocationFor('parent'), isNotNull);
  });

  testWidgets('mở push không xóa bản điểm danh chưa lưu ở màn đang mở', (tester) async {
    await SessionManagementService.instance.saveSession(const AppSession(
      accessToken: 'test-access', refreshToken: 'test-refresh',
      sessionId: 'teacher-session', role: 'teacher',
    ));
    appRouter.go('/teacher?classId=class-2');
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(TeacherShell))).push(MaterialPageRoute<void>(
      builder: (_) => const AttendanceScreen(
        classId: 'class-2', className: 'Mầm B', date: '2026-10-20',
        roster: [ui.Child(id: 'child-1', name: 'Bé An', status: ui.ReportStatus.none,
          present: true, time: '', severity: ui.Severity.none)],
        initialRecords: {'child-1': ui.AttendanceStatus.arrived},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bé An'));
    await tester.pumpAndSettle();

    push.handleNotificationTap(const RemoteMessage(data: {
      'type': 'attendance_reminder', 'class_id': 'class-2', 'date': '2026-10-21',
    }));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceScreen, skipOffstage: false), findsOneWidget);
    appRouter.pop();
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton<ui.AttendanceStatus>>(
      find.byType(DropdownButton<ui.AttendanceStatus>),
    );
    expect(dropdown.value, ui.AttendanceStatus.absent);
    expect(tester.takeException(), isNull);
  });

  for (final data in <Map<String, dynamic>>[
    {'type': 'unknown'},
    {'type': 'report_updated', 'report_id': 42, 'child_id': 'child-1'},
    {'type': 'attendance_absent', 'child_id': 'child-1', 'date': '2026-02-31'},
    {'type': 'attendance_reminder', 'date': '2026-10-20'},
  ]) {
    testWidgets('bỏ qua payload không hợp lệ $data', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      push.handleNotificationTap(RemoteMessage(data: data));
      await tester.pump();
      expect(appRouter.routeInformationProvider.value.uri.toString(), '/parent');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('router mở đích mới mà không hiện sheet cũ, kể cả API không khả dụng', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();
    showModalBottomSheet<void>(
      context: tester.element(find.byType(ParentFlow)),
      builder: (_) => const Text('Sheet thông báo cũ'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sheet thông báo cũ'), findsOneWidget);

    push.handleNotificationTap(const RemoteMessage(data: {
      'type': 'report_updated', 'report_id': 'report-old', 'child_id': 'child-2',
    }));
    await tester.pumpAndSettle();

    final flow = tester.widget<ParentFlow>(find.byType(ParentFlow));
    expect(flow.childId, 'child-2');
    expect(flow.initialReportId, 'report-old');
    expect(find.text('Sheet thông báo cũ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
