// Test: chạm push notification (Scope A) mở thẳng báo cáo hôm nay.
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
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

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: kinderTheme(), home: child);

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
}
