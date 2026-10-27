// Test: chạm push notification (Scope A) mở thẳng báo cáo hôm nay.
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockParentRepository extends HttpDashboardRepository {
  @override
  Future<Parent> getCurrentParent() async {
    return const Parent(
      parentId: 'parent-1',
      fullName: 'Trần Văn Tuấn',
      phone: '0901234567',
    );
  }

  @override
  Future<ChildOverview> getPrimaryChildOverview(String parentId) async {
    return ChildOverview(
      child: Child(
        childId: 'child-1',
        classId: 'class-1',
        fullName: 'Trần Bảo Bảo',
        nickname: 'Bảo Bảo',
        dateOfBirth: DateTime(2020, 1, 1),
        gender: 'male',
      ),
      className: 'Mầm A',
      teacherName: 'Cô Nguyễn Thị Mai',
    );
  }

  @override
  Future<DailyReport?> getTodayReport(
    String childId,
    DateTime date, {
    bool includeDraft = true,
  }) async {
    return DailyReport(
      dailyReportId: 'rep-1',
      childId: childId,
      teacherId: 'teacher-1',
      reportDate: date,
      status: ReportStatus.published,
      eating: 'Ăn hết suất.',
      sleeping: 'Ngủ ngon.',
      activitiesText: 'Vẽ và xếp hình.',
      mood: 'Vui vẻ.',
      summaryText: 'Bé ngoan.',
    );
  }

  @override
  Future<List<DailyReport>> getRecentReports(
    String childId, {
    int limit = 7,
    bool includeDraft = true,
  }) async {
    return const [];
  }

  @override
  Future<DailyReport> markReportAsRead(String reportId) async {
    return DailyReport(
      dailyReportId: reportId,
      childId: 'child-1',
      teacherId: 'teacher-1',
      reportDate: DateTime.now(),
      status: ReportStatus.read,
      eating: 'Ăn hết suất.',
      sleeping: 'Ngủ ngon.',
      activitiesText: 'Vẽ và xếp hình.',
      mood: 'Vui vẻ.',
      summaryText: 'Bé ngoan.',
    );
  }
}

class _NotificationRepository extends _MockParentRepository {
  _NotificationRepository({this.missingReport = false});
  final bool missingReport;
  final opened = <String>[];
  bool failOverview = false;

  @override
  Future<ChildOverview> getChildOverviewForParent(String parentId, String childId) async {
    if (failOverview) throw const ClassDataException('Temporarily unavailable', statusCode: 503);
    return ChildOverview(
      child: Child(childId: childId, fullName: 'Bé thứ hai', dateOfBirth: DateTime(2020)),
      className: 'Mầm B',
      teacherName: 'Cô Lan',
    );
  }

  @override
  Future<DailyReport> getParentReport(String reportId) async {
    if (missingReport) throw const ClassDataException('Report not found', statusCode: 404);
    return DailyReport(
      dailyReportId: reportId,
      childId: 'child-2',
      reportDate: DateTime(2026, 9, 1),
      status: ReportStatus.published,
      summaryText: 'Nội dung báo cáo cũ của bé thứ hai',
    );
  }

  @override
  Future<DailyReport> markReportAsRead(String reportId) async {
    opened.add(reportId);
    return (await getParentReport(reportId)).copyWith(status: ReportStatus.read);
  }
}

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: kinderTheme(), home: child);

  for (final reportNotification in [true, false]) {
    testWidgets('thử lại dữ liệu vẫn mở thông báo ${reportNotification ? 'báo cáo' : 'bé vắng'}', (tester) async {
      final repository = _NotificationRepository()..failOverview = true;
      await tester.pumpWidget(wrap(ParentFlow(
        repository: repository, childId: 'child-2',
        initialReportId: reportNotification ? 'report-old' : null,
        initialAttendanceDate: reportNotification ? null : '2026-10-20',
      )));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);

      repository.failOverview = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      if (reportNotification) {
        expect(find.text('Nội dung báo cáo cũ của bé thứ hai'), findsOneWidget);
        expect(repository.opened, ['report-old']);
      } else {
        expect(find.textContaining('Thông báo bé vắng'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mở đúng báo cáo cũ của bé thứ hai thay vì báo cáo hôm nay', (tester) async {
    final repository = _NotificationRepository();
    await tester.pumpWidget(wrap(ParentFlow(
      repository: repository,
      childId: 'child-2',
      initialReportId: 'report-old',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo hằng ngày'), findsOneWidget);
    expect(find.text('Nội dung báo cáo cũ của bé thứ hai'), findsOneWidget);
    expect(repository.opened, ['report-old']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('báo cáo đã xóa hiện thông báo thay vì mở nhầm báo cáo', (tester) async {
    await tester.pumpWidget(wrap(ParentFlow(
      repository: _NotificationRepository(missingReport: true),
      childId: 'child-2',
      initialReportId: 'deleted',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo hằng ngày'), findsNothing);
    expect(find.text('Không thể mở báo cáo này. Vui lòng thử lại sau.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thông báo điểm danh phụ huynh có đúng tên bé và ngày', (tester) async {
    await tester.pumpWidget(wrap(ParentFlow(
      repository: _NotificationRepository(),
      childId: 'child-2',
      initialAttendanceDate: '2026-10-20',
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('20/10/2026'), findsWidgets);
    expect(find.textContaining('Thông báo bé vắng'), findsOneWidget);
    expect(find.text('Báo cáo hằng ngày'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initialOpenReport = true mở thẳng báo cáo hôm nay', (tester) async {
    await tester.pumpWidget(
      wrap(ParentFlow(repository: _MockParentRepository(), initialOpenReport: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo hằng ngày'), findsOneWidget);
  });

  testWidgets('không có cờ push thì vẫn ở màn hình chính', (tester) async {
    await tester.pumpWidget(
      wrap(ParentFlow(repository: _MockParentRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo hôm nay'), findsOneWidget);
    expect(find.text('Báo cáo hằng ngày'), findsNothing);
  });

  testWidgets('chạm thông báo khi màn phụ huynh đang mở vẫn mở báo cáo', (tester) async {
    final repository = _MockParentRepository();
    await tester.pumpWidget(wrap(ParentFlow(repository: repository)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      wrap(ParentFlow(repository: repository, initialOpenReport: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo hằng ngày'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
