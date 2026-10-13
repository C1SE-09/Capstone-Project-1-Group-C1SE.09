import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adark_frontend/data/repositories/http_admin_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/admin_dashboard_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class _FakeAdminRepository extends HttpAdminRepository {
  @override
  Future<AdminOverviewStatsDto> getDashboardOverviewStats({DateTime? targetDate}) async {
    return AdminOverviewStatsDto(
      totalSchools: 2,
      totalClasses: 14,
      totalChildren: 342,
      totalTeachers: 24,
      totalParents: 320,
      todayReportsCount: 342,
      todaySentReportsCount: 285,
      todayDraftReportsCount: 57,
      todayCompletionRate: 83.3,
      totalVoiceRecords: 1250,
      todayVoiceRecords: 148,
    );
  }

  @override
  Future<List<AdminClassProgressDto>> getDashboardClassesProgress({DateTime? targetDate}) async {
    return [
      AdminClassProgressDto(
        classId: 'c1',
        className: 'Mầm 1',
        gradeLabel: 'Khối 2–3 tuổi',
        teacherName: 'Cô Nguyễn Thu Thảo',
        totalChildren: 25,
        reportedChildren: 23,
        pendingChildren: 2,
        completionRate: 92.0,
      ),
      AdminClassProgressDto(
        classId: 'c2',
        className: 'Chồi 1',
        gradeLabel: 'Khối 3–4 tuổi',
        teacherName: 'Cô Phạm Mai Anh',
        totalChildren: 28,
        reportedChildren: 25,
        pendingChildren: 3,
        completionRate: 89.0,
      ),
      AdminClassProgressDto(
        classId: 'c3',
        className: 'Lá 1',
        gradeLabel: 'Khối 4–5 tuổi',
        teacherName: 'Cô Đỗ Minh Hương',
        totalChildren: 30,
        reportedChildren: 29,
        pendingChildren: 1,
        completionRate: 97.0,
      ),
    ];
  }

  @override
  Future<AdminVoiceStatsDto> getDashboardVoiceStats() async {
    return AdminVoiceStatsDto(
      totalRecords: 1250,
      completedRecords: 142,
      pendingRecords: 4,
      failedRecords: 2,
      totalDurationSeconds: 13500.0,
    );
  }

  @override
  Future<List<AdminReportTrendDto>> getDashboardReportTrends({int days = 7}) async {
    return [
      AdminReportTrendDto(reportDate: '08/10', totalReports: 309, sentReports: 238, draftReports: 71),
      AdminReportTrendDto(reportDate: '14/10', totalReports: 342, sentReports: 285, draftReports: 57),
    ];
  }

  @override
  Future<AdminSystemHealthDto> getDashboardSystemHealth() async {
    return AdminSystemHealthDto(
      databaseStatus: 'healthy',
      redisStatus: 'healthy',
      apiStatus: 'healthy',
      serverTime: '21:05:00 UTC+7',
    );
  }

  @override
  Future<List<AdminClassDto>> getClasses() async => [];

  @override
  Future<List<AdminChildDto>> getChildren() async => [];

  @override
  Future<List<AdminTimeSlotDto>> getTimeSlots() async => [];

  @override
  Future<List<AdminTeacherDto>> getTeachers() async => [];

  @override
  Future<List<AdminParentDto>> getParents() async => [];

  @override
  Future<List<AdminScheduleDto>> getSchedules({int? dayOfWeek}) async => [];
}

void main() {
  Widget buildTestWidget({required VoidCallback onLogout}) {
    return MaterialApp(
      theme: kinderTheme(),
      home: AdminDashboardScreen(
        onLogout: onLogout,
        repository: _FakeAdminRepository(),
      ),
    );
  }

  testWidgets('AdminDashboardScreen renders KPI cards, table, and charts', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(onLogout: () {}));
    await tester.pumpAndSettle();

    // Verify Brand Logo & Overview Title
    expect(find.text('KinderLog'), findsWidgets);
    expect(find.text('Tổng quan hệ thống'), findsOneWidget);

    // Verify 4 KPI Metric Cards
    expect(find.text('Tổng số học sinh'), findsOneWidget);
    expect(find.text('342 bé'), findsOneWidget);
    expect(find.text('Tiến độ báo cáo ngày'), findsOneWidget);
    expect(find.text('83.3%'), findsOneWidget);
    expect(find.text('Bản ghi âm giọng nói'), findsOneWidget);
    expect(find.text('148 file hôm nay'), findsOneWidget);
    expect(find.text('Nhân sự & Phụ huynh'), findsOneWidget);
    expect(find.text('24 giáo viên'), findsOneWidget);

    // Verify Table & Classes
    expect(find.text('Tiến độ báo cáo theo lớp học trong ngày'), findsOneWidget);
    expect(find.text('Mầm 1'), findsOneWidget);
    expect(find.text('Chồi 1'), findsOneWidget);
    expect(find.text('Lá 1'), findsOneWidget);

    // Verify Right Widgets
    expect(find.text('Hàng đợi xử lý giọng nói STT'), findsOneWidget);
    expect(find.text('Tình trạng hạ tầng'), findsOneWidget);
    expect(find.text('Cơ sở dữ liệu (PostgreSQL)'), findsOneWidget);

    // Verify 7-day Trend Chart Card
    expect(find.text('Xu hướng báo cáo 7 ngày gần nhất'), findsOneWidget);
    expect(find.text('Đã gửi phụ huynh'), findsOneWidget);
    expect(find.text('Bản nháp'), findsOneWidget);
  });

  testWidgets('AdminDashboardScreen search filters the class list', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(onLogout: () {}));
    await tester.pumpAndSettle();

    // Prior to search: all classes visible
    expect(find.text('Mầm 1'), findsOneWidget);
    expect(find.text('Chồi 1'), findsOneWidget);

    // Enter search query
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Chồi');
    await tester.pumpAndSettle();

    // Filtered result
    expect(find.text('Chồi 1'), findsOneWidget);
    expect(find.text('Mầm 1'), findsNothing);
  });

  testWidgets('AdminDashboardScreen logout button invokes onLogout callback', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool loggedOut = false;
    await tester.pumpWidget(buildTestWidget(onLogout: () {
      loggedOut = true;
    }));
    await tester.pumpAndSettle();

    // Find and tap the logout button
    final logoutButton = find.byTooltip('Đăng xuất');
    expect(logoutButton, findsOneWidget);
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(loggedOut, isTrue);
  });
}
