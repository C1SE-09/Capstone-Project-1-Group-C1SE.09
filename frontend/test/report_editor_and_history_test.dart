import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;
import 'package:adark_frontend/features/kindergarten_dashboard/screens/report_editor.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_tabs.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockDashboardRepository extends HttpDashboardRepository {
  @override
  Future<Teacher> getCurrentTeacher() async {
    return const Teacher(
      teacherId: 'teacher-1',
      fullName: 'Cô Hoàng Hà',
      email: 'ha@example.com',
      classId: 'class-1',
    );
  }

  @override
  Future<DailyReport?> getTodayReport(
    String childId,
    DateTime date, {
    bool includeDraft = true,
  }) async {
    return DailyReport(
      dailyReportId: 'rep-today',
      childId: childId,
      teacherId: 'teacher-1',
      reportDate: date,
      status: ReportStatus.draft,
      eating: 'Ăn hết bát cơm súp',
      sleeping: 'Ngủ đủ giấc 120 phút',
      health: 'Sức khỏe tốt, không sốt',
      mood: 'Hào hứng, vui vẻ',
      activitiesText: 'Vẽ tranh phong cảnh',
      summaryText: 'Bé rất ngoan hôm nay',
    );
  }

  @override
  Future<List<DailyReport>> getRecentReports(
    String childId, {
    int limit = 7,
    bool includeDraft = true,
  }) async {
    return [
      DailyReport(
        dailyReportId: 'draft-1',
        childId: childId,
        teacherId: 'teacher-1',
        reportDate: DateTime(2026, 10, 2),
        status: ReportStatus.draft,
        eating: 'Ăn nửa bát',
        sleeping: 'Ngủ 60 phút',
        health: 'Hơi ho nhẹ buổi sáng',
        mood: 'Bình thường',
        activitiesText: 'Chơi xếp hình',
        summaryText: 'Cần theo dõi thêm cơn ho',
      ),
      DailyReport(
        dailyReportId: 'sent-1',
        childId: childId,
        teacherId: 'teacher-1',
        reportDate: DateTime(2026, 10, 1),
        status: ReportStatus.published,
        eating: 'Ăn ngoan',
        sleeping: 'Ngủ ngon',
        health: 'Khỏe mạnh',
      ),
    ];
  }
}

class MockClassDataRepository extends HttpClassDataRepository {
  @override
  Future<ClassInfo> getClassInfo(String classId) async {
    return const ClassInfo(
      classId: 'class-1',
      schoolId: 'school-1',
      name: 'Mầm 1',
    );
  }
}

void main() {
  testWidgets('ReportEditorScreen displays health field and populates from todayReport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockRepo = MockDashboardRepository();
    final mockClassRepo = MockClassDataRepository();
    final child = ui.Child(
      id: 'child-1',
      name: 'Nguyễn Văn An',
      status: ui.ReportStatus.draft,
      severity: ui.Severity.none,
      present: true,
      time: '08:00',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportEditorScreen(
          child: child,
          repository: mockRepo,
          classRepository: mockClassRepo,
          onSent: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Sức khỏe field exists and loaded from todayReport
    expect(find.text('Sức khỏe'), findsOneWidget);
    expect(find.text('Sức khỏe tốt, không sốt'), findsOneWidget);

    // Verify other fields loaded
    expect(find.text('Ăn hết bát cơm súp'), findsOneWidget);
    expect(find.text('Ngủ đủ giấc 120 phút'), findsOneWidget);
    expect(find.text('Hào hứng, vui vẻ'), findsOneWidget);
    expect(find.text('Vẽ tranh phong cảnh'), findsOneWidget);
    expect(find.text('Bé rất ngoan hôm nay'), findsOneWidget);
  });

  testWidgets('ReportEditorScreen populates from initialReport (e.g. past draft from history)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockRepo = MockDashboardRepository();
    final mockClassRepo = MockClassDataRepository();
    final child = ui.Child(
      id: 'child-1',
      name: 'Trần Thị Bích',
      status: ui.ReportStatus.draft,
      severity: ui.Severity.none,
      present: true,
      time: '08:00',
    );

    final pastDraft = DailyReport(
      dailyReportId: 'draft-past',
      childId: 'child-1',
      reportDate: DateTime(2026, 9, 28),
      status: ReportStatus.draft,
      eating: 'Cháo gà hạt sen',
      sleeping: 'Ngủ trưa 90 phút',
      health: 'Đã hết sốt, da dẻ hồng hào',
      mood: 'Vui chơi năng động',
      activitiesText: 'Hát bài ca đi học',
      summaryText: 'Bé tiến bộ nhiều',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportEditorScreen(
          child: child,
          initialReport: pastDraft,
          readOnly: false,
          repository: mockRepo,
          classRepository: mockClassRepo,
          onSent: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sức khỏe'), findsOneWidget);
    expect(find.text('Đã hết sốt, da dẻ hồng hào'), findsOneWidget);
    expect(find.text('Cháo gà hạt sen'), findsOneWidget);
    expect(find.text('28/09/2026'), findsOneWidget);
    expect(find.text('Lưu nháp'), findsOneWidget);
  });

  testWidgets('HistoryScreen loads drafts, filters by Bản nháp, and passes report to onOpenReport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockRepo = MockDashboardRepository();
    final children = <ui.Child>[
      ui.Child(
        id: 'child-1',
        name: 'Nguyễn Văn An',
        status: ui.ReportStatus.draft,
        severity: ui.Severity.none,
        present: true,
        time: '08:00',
      ),
    ];

    ui.Child? tappedChild;
    DailyReport? tappedReport;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryScreen(
            children: children,
            repository: mockRepo,
            onOpenReport: (c, r) {
              tappedChild = c;
              tappedReport = r;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify filter chip "Bản nháp"
    final draftChip = find.widgetWithText(FilterChipButton, 'Bản nháp');
    expect(draftChip, findsOneWidget);

    // Switch filter to "Bản nháp"
    await tester.tap(draftChip);
    await tester.pumpAndSettle();

    // Verify the draft row is visible
    expect(find.text('Nguyễn Văn An'), findsOneWidget);

    // Tap on the draft row
    await tester.tap(find.text('Nguyễn Văn An'));
    await tester.pumpAndSettle();

    // Verify onOpenReport was called with the child AND the draft DailyReport
    expect(tappedChild, isNotNull);
    expect(tappedChild!.name, 'Nguyễn Văn An');
    expect(tappedReport, isNotNull);
    expect(tappedReport!.dailyReportId, 'draft-1');
    expect(tappedReport!.health, 'Hơi ho nhẹ buổi sáng');
    expect(tappedReport!.status, ReportStatus.draft);
  });
}
