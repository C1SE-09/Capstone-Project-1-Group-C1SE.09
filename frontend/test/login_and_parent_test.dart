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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

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

    // Verify Figma welcome and brand
    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
    expect(find.text('KinderLog'), findsOneWidget);
    expect(find.byKey(const ValueKey('loginIllustration')), findsOneWidget);

    // Verify Fields & Controls
    expect(find.text('TÊN ĐĂNG NHẬP'), findsOneWidget);
    expect(find.text('MẬT KHẨU'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    final usernameBox = find
        .ancestor(
          of: find.text('TÊN ĐĂNG NHẬP'),
          matching: find.byType(Container),
        )
        .first;
    final passwordBox = find
        .ancestor(
          of: find.text('MẬT KHẨU'),
          matching: find.byType(Container),
        )
        .first;
    expect(tester.getSize(passwordBox), tester.getSize(usernameBox));

    // Giữ Login đã duyệt; chỉ nhận font Nunito từ upstream.
    expect(find.text('Lưu mật khẩu'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Lưu mật khẩu')).style?.fontWeight,
      FontWeight.w600,
    );
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.text('Khám phá KinderLog'), findsOneWidget);
    expect(find.text('Giáo viên'), findsOneWidget);
    expect(find.text('Phụ huynh'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('Khám phá KinderLog')))
        .textTheme.bodyMedium?.fontFamily, 'Nunito');
    expect(find.text('Ứng dụng dành cho:'), findsNothing);
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
    expect(find.text('Chào buổi sáng,'), findsOneWidget);
    expect(find.text('Trần Văn Tuấn'), findsOneWidget);
    expect(find.text('Trần Bảo Bảo'), findsWidgets);
    expect(find.text('Cô Nguyễn Thị Mai'), findsOneWidget);
    expect(find.text('Báo cáo hôm nay'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);

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

    // Card báo cáo hôm nay mở sheet từ dữ liệu thật.
    expect(find.text('Ăn uống'), findsOneWidget);

    // Tap on recent report to open detail
    await tester.tap(find.text('Ăn uống'));
    await tester.pumpAndSettle();

    // Verify report sheet is displayed with 'Báo cáo hằng ngày' and 'Đã đọc' badge
    expect(find.text('Báo cáo hằng ngày'), findsOneWidget);
    // Mở dạng sheet: badge trong sheet + pill của danh sách phía sau đều là 'Đã đọc'
    expect(find.text('Đã đọc'), findsWidgets);

    // Tap back button
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    // Quay về tổng quan sau khi đánh dấu đã đọc.
    expect(find.text('Báo cáo hôm nay'), findsOneWidget);
  });

  testWidgets('ParentFlow clicking logout shows confirmation popup and handles Cancel/Logout',
      (WidgetTester tester) async {
    var loggedOut = false;

    // Màn Tài khoản dài — dựng ở viewport cao để nút đăng xuất cuối tab được build.
    tester.view.physicalSize = const Size(1100, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    // Nút đăng xuất nằm ở cuối tab Tài khoản
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();

    final logoutBtn = find.widgetWithText(KButton, 'Đăng xuất');
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

    // Tap Đăng xuất inside popup (nút thứ hai, sau nút ở tab Tài khoản)
    await tester.tap(find.widgetWithText(KButton, 'Đăng xuất').last);
    await tester.pumpAndSettle();

    // Verify logout callback invoked
    expect(loggedOut, isTrue);
  });

  testWidgets('ParentFlow displays timetable action and navigates to TimetableScreen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

    // Garden Voice giữ shortcut lịch học cho luồng hiện có.
    expect(find.text('Lịch học'), findsOneWidget);

    // Tap on timetable button
    await tester.tap(find.text('Lịch học'));
    await tester.pumpAndSettle();

    // Verify TimetableScreen is opened
    expect(find.text('Thời khóa biểu'), findsOneWidget);
  });
}

