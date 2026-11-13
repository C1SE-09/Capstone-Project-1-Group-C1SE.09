import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_notifications.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'parent_request_repository_test.dart' show RequestTransport, jsonBody;

class _ParentRepository extends HttpDashboardRepository {
  @override
  Future<Parent> getCurrentParent() async =>
      const Parent(parentId: 'parent-1', fullName: 'Nguyễn Văn Tuấn');

  @override
  Future<ChildOverview> getPrimaryChildOverview(String parentId) async =>
      const ChildOverview(
        child: Child(
          childId: 'child-1',
          classId: 'class-1',
          fullName: 'Nguyễn Minh An',
        ),
        className: 'Mầm 1',
        teacherName: 'Cô Nguyễn Thị Mai',
      );

  DailyReport _report(DateTime date) => DailyReport(
        dailyReportId: 'report-1',
        childId: 'child-1',
        teacherId: 'teacher-1',
        reportDate: date,
        status: ReportStatus.published,
        eating: 'Ăn hết suất',
        sleeping: 'Ngủ ngon',
        activitiesText: 'Vẽ tranh',
      );

  @override
  Future<DailyReport?> getTodayReport(
    String childId,
    DateTime date, {
    bool includeDraft = true,
  }) async =>
      _report(date);

  @override
  Future<List<DailyReport>> getRecentReports(
    String childId, {
    int limit = 7,
    bool includeDraft = true,
  }) async =>
      [_report(DateTime.now())];
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-ExtraBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-Black.ttf'));
    await font.load();
  });

  testWidgets('ParentFlow dùng Garden Voice navigation để mở thông báo',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: ParentFlow(repository: _ParentRepository(), onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GardenVoiceParentOverview), findsOneWidget);
    final navigation =
        find.byKey(const ValueKey('garden-voice-parent-navigation'));
    expect(navigation, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: navigation,
        matching: find.byTooltip('Mở thông báo'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ParentNotifications), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Thông báo').first).style?.fontSize,
      24,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Parent Requests mở trong Garden Voice scope', (tester) async {
    final transport =
        RequestTransport((_) => jsonBody({'items': [], 'total': 0}));
    final requests = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: ParentFlow(
        repository: _ParentRepository(),
        leaveRequestRepository: requests,
        onLogout: () {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xin nghỉ · Trễ'));
    await tester.pumpAndSettle();

    final title = tester.element(find.text('Xin phép nghỉ / báo trễ'));
    expect(Theme.of(title).textTheme.bodyMedium?.fontFamily, 'Nunito');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ParentFlow mở đơn nghỉ khi đến từ push đã duyệt',
      (tester) async {
    final transport =
        RequestTransport((_) => jsonBody({'items': [], 'total': 0}));
    final requests = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: ParentFlow(
        repository: _ParentRepository(),
        leaveRequestRepository: requests,
        initialOpenRequests: true,
        onLogout: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Xin phép nghỉ / báo trễ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
