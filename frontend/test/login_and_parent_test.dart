import 'package:adark_frontend/features/kindergarten_dashboard/screens/auth_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockParentDashboardRepository extends HttpDashboardRepository {
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
      eating: 'Ăn hết 2 bát cơm, uống đủ sữa.',
      sleeping: 'Ngủ trưa 120 phút sâu giấc.',
      activitiesText: 'Học vẽ hoa và vận động ngoài trời.',
      mood: 'Vui vẻ hòa đồng.',
      summaryText: 'Bé ngoan, tích cực phát biểu.',
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
        dailyReportId: 'rep-0',
        childId: childId,
        teacherId: 'teacher-1',
        reportDate: DateTime.now().subtract(const Duration(days: 1)),
        status: ReportStatus.published,
        eating: 'Ăn hết suất cơm.',
        sleeping: 'Ngủ đúng giờ.',
      ),
    ];
  }

  @override
  Future<DailyReport> markReportAsRead(String reportId) async {
    return DailyReport(
      dailyReportId: reportId,
      reportDate: DateTime.now(),
      status: ReportStatus.read,
    );
  }
}

void main() {
  testWidgets('LoginScreen renders card UI with username, password, remember me, and log in button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: LoginScreen(
          onLogin: (_) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Logo
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('KinderLog'), findsOneWidget);

    // Verify Fields & Controls
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('ĐĂNG NHẬP'), findsOneWidget);

    // Verify deleted items per user request
    expect(find.text('Ghi nhớ đăng nhập'), findsNothing);
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? '), findsNothing);
    expect(find.text('Đăng ký ngay'), findsNothing);

    // Verify demo buttons are not present
    expect(find.text('Tài khoản mẫu:'), findsNothing);
    expect(find.text('Giáo viên (Cô Mai)'), findsNothing);
    expect(find.text('Phụ huynh (Bé Bảo)'), findsNothing);

    // Enter username into field
    await tester.enterText(find.byType(TextField).first, 'parent_tuan');
    await tester.pumpAndSettle();

    // Verify text field updated
    expect(find.text('parent_tuan'), findsOneWidget);
  });

  testWidgets('ParentFlow displays child and parent name cleanly inside Scaffold without yellow underline',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: ParentFlow(
          repository: MockParentDashboardRepository(),
          onLogout: () {},
        ),
      ),
    );

    // Initial pump shows circular loading inside scaffold
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Settle future
    await tester.pumpAndSettle();

    // Verify parent name and child name
    expect(find.text('Xin chào,'), findsOneWidget);
    expect(find.text('Trần Văn Tuấn'), findsOneWidget);
    expect(find.text('Trần Bảo Bảo'), findsWidgets);
    expect(find.text('Lớp Mầm A · Cô Nguyễn Thị Mai'), findsOneWidget);
    expect(find.text('Báo cáo hôm nay'), findsOneWidget);
    expect(find.text('Đã có báo cáo'), findsOneWidget);

    // Verify Scaffold ancestor is present (prevents yellow underline bug)
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('ParentFlow opening report marks it as read and displays Đã đọc status badge',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: ParentFlow(
          repository: MockParentDashboardRepository(),
          onLogout: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initially "Đã gửi" is visible in recent reports
    expect(find.text('Đã gửi'), findsWidgets);

    // Tap on recent report to open detail
    await tester.tap(find.byIcon(Icons.chevron_right).last);
    await tester.pumpAndSettle();

    // Verify report detail screen is displayed with 'Báo cáo hằng ngày' and 'Đã đọc' badge
    expect(find.text('Báo cáo hằng ngày'), findsOneWidget);
    expect(find.text('Đã đọc'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    // Verify back on home screen and recent report status is now updated to "Đã đọc"
    expect(find.text('Đã đọc'), findsOneWidget);
  });

  testWidgets('ParentFlow clicking logout shows confirmation popup and handles Cancel/Logout',
      (WidgetTester tester) async {
    var loggedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: ParentFlow(
          repository: MockParentDashboardRepository(),
          onLogout: () {
            loggedOut = true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify logout button is visible
    final logoutBtn = find.byTooltip('Đăng xuất');
    expect(logoutBtn, findsOneWidget);

    // Tap logout button
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();

    // Verify confirmation popup text and action buttons are displayed
    expect(find.text('Bạn có muốn đăng xuất không ?'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsWidgets);
    expect(loggedOut, isFalse);

    // Tap Hủy -> popup dismissed, loggedOut still false
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn có muốn đăng xuất không ?'), findsNothing);
    expect(loggedOut, isFalse);

    // Tap logout button again
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();

    // Tap Đăng xuất inside popup
    await tester.tap(find.widgetWithText(KButton, 'Đăng xuất'));
    await tester.pumpAndSettle();

    // Verify logout callback invoked
    expect(loggedOut, isTrue);
  });

  testWidgets('ParentFlow displays timetable action and navigates to TimetableScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: ParentFlow(
          repository: MockParentDashboardRepository(),
          onLogout: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify timetable button is visible on child card
    expect(find.text('Thời khóa biểu của lớp'), findsOneWidget);
    expect(find.byTooltip('Thời khóa biểu'), findsOneWidget);

    // Tap on timetable button
    await tester.tap(find.text('Thời khóa biểu của lớp'));
    await tester.pumpAndSettle();

    // Verify TimetableScreen is opened
    expect(find.text('Thời khóa biểu'), findsOneWidget);
  });
}

