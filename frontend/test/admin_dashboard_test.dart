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

    // Verify 3 KPI Metric Cards (Đã loại bỏ card ghi âm giọng nói)
    expect(find.text('Tổng số học sinh'), findsOneWidget);
    expect(find.text('342 bé'), findsOneWidget);
    expect(find.text('Tiến độ báo cáo ngày'), findsOneWidget);
    expect(find.text('83.3%'), findsOneWidget);
    expect(find.text('Nhân sự & Phụ huynh'), findsOneWidget);
    expect(find.text('Giáo viên'), findsOneWidget);
    expect(find.text('Phụ huynh'), findsOneWidget);

    // Verify removed components
    expect(find.text('Bản ghi âm giọng nói'), findsNothing);
    expect(find.text('Hàng đợi xử lý giọng nói STT'), findsNothing);
    expect(find.text('Tình trạng hạ tầng máy chủ'), findsNothing);

    // Verify Table & Classes
    expect(find.text('Tiến độ báo cáo theo lớp học trong ngày'), findsOneWidget);
    expect(find.text('Mầm 1'), findsOneWidget);
    expect(find.text('Chồi 1'), findsOneWidget);
    expect(find.text('Lá 1'), findsOneWidget);

    // Verify 7-day Trend Chart Card
    expect(find.text('Xu hướng báo cáo 7 ngày gần nhất'), findsOneWidget);
    expect(find.textContaining('Xanh: đã gửi, Vàng: bản nháp'), findsOneWidget);
  });

  testWidgets('AdminDashboardScreen overview tab does not have search field, features tab has search field', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(onLogout: () {}));
    await tester.pumpAndSettle();

    // In Overview Tab: search field is NOT present
    expect(find.byType(TextField), findsNothing);

    // Navigate to Features Tab: search field is present
    await tester.tap(find.text('Chức năng'));
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
  });

  testWidgets('AdminDashboardScreen logout button in account tab invokes onLogout callback', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool loggedOut = false;
    await tester.pumpWidget(buildTestWidget(onLogout: () {
      loggedOut = true;
    }));
    await tester.pumpAndSettle();

    // Navigate to Account Tab
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();

    // Verify mobile header is NOT visible in account tab
    expect(find.byType(TextField), findsNothing);

    // Find and tap the logout button in Account tab
    final logoutButton = find.text('Đăng xuất tài khoản quản trị');
    expect(logoutButton, findsOneWidget);
    await tester.ensureVisible(logoutButton);
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    // Confirm in the dialog
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();

    expect(loggedOut, isTrue);
  });

  testWidgets('AdminDashboardScreen features tab does not show school name or notification button, and shows refresh button', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: AdminDashboardScreen(
          onLogout: () {},
          repository: _FakeAdminRepository(),
          schoolName: 'Trường Mầm Non Hướng Dương',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In Overview Tab: school name control is NOT present
    expect(find.text('Trường Mầm Non Hướng Dương'), findsNothing);

    // Navigate to Features Tab
    await tester.tap(find.text('Chức năng'));
    await tester.pumpAndSettle();

    // Verify school name is not displayed
    expect(find.text('Trường Mầm Non Hướng Dương'), findsNothing);
    // Verify notification button is not displayed
    expect(find.byIcon(Icons.notifications_none), findsNothing);
    // Verify refresh button is present
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    // Verify there is no DropdownButtonFormField for school switching
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    // Verify there is NO "Quay lại" button
    expect(find.text('Quay lại'), findsNothing);
  });

  testWidgets('AdminDashboardScreen account tab has bug report option', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(onLogout: () {}));
    await tester.pumpAndSettle();

    // Navigate to Account Tab
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();

    // Verify bug report item exists
    expect(find.text('Báo cáo lỗi & Góp ý'), findsOneWidget);
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
  });

  testWidgets('AdminDashboardScreen account tab displays School Admin role', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(onLogout: () {}));
    await tester.pumpAndSettle();

    // Navigate to Account Tab
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();

    // Verify role is School Admin
    expect(find.text('School Admin'), findsOneWidget);
    expect(find.text('Toàn quyền Super Admin'), findsNothing);
  });

  testWidgets('AdminDashboardScreen add teacher dialog has username and password fields', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(onLogout: () {}));
    await tester.pumpAndSettle();

    // Navigate to Features Tab
    await tester.tap(find.text('Chức năng'));
    await tester.pumpAndSettle();

    // Tap Add Teacher button in header
    final addBtn = find.text('Thêm giáo viên');
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Verify dialog fields
    expect(find.text('Tài khoản đăng nhập *'), findsOneWidget);
    expect(find.text('Mật khẩu *'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Hủy bỏ'));
    await tester.pumpAndSettle();
  });

  testWidgets('AdminDashboardScreen add parent dialog has username and password fields', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(onLogout: () {}));
    await tester.pumpAndSettle();

    // Navigate to Features Tab
    await tester.tap(find.text('Chức năng'));
    await tester.pumpAndSettle();

    // Switch to Parents category
    await tester.tap(find.text('Phụ huynh'));
    await tester.pumpAndSettle();

    // Tap Add Parent button in header
    final addBtn = find.text('Thêm phụ huynh');
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // Verify dialog fields
    expect(find.text('Tài khoản đăng nhập *'), findsOneWidget);
    expect(find.text('Mật khẩu *'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Hủy bỏ'));
    await tester.pumpAndSettle();
  });
}


