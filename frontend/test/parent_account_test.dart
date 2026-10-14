// TestParentAccount — tab Tài khoản + các sheet của màn Parent (Task 2).
// Phủ: 2 tab dưới bottom nav, hồ sơ phụ huynh, số ngày đồng hành,
// sheet sửa SĐT (validate + 409), sheet chi tiết bé, banner dị ứng, toggle push.

import 'dart:math' as math;

import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockParentRepo extends HttpDashboardRepository {
  _MockParentRepo({
    this.phoneFailure,
    this.reportsRead = false,
    this.sameReportForTodayAndRecent = false,
  });

  /// Nếu khác null, updateMyPhone ném lỗi với status này.
  final int? phoneFailure;

  /// True → báo cáo gần đây đã đọc hết (badge phải tắt).
  final bool reportsRead;

  /// True → báo cáo hôm nay cũng nằm trong danh sách gần đây (như API thật trả).
  final bool sameReportForTodayAndRecent;

  int updateCalls = 0;
  String? lastPhone;

  @override
  Future<Parent> getCurrentParent() async => Parent(
    parentId: 'parent-1',
    fullName: 'Trần Văn Tuấn',
    phone: '0901234567',
    email: 'tuan.tran@gmail.com',
    relationship: 'Bố',
    createdAt: DateTime.now().subtract(const Duration(days: 128)),
  );

  @override
  Future<ChildOverview> getPrimaryChildOverview(String parentId) async {
    return ChildOverview(
      child: Child(
        childId: 'child-1',
        classId: 'class-1',
        fullName: 'Trần Bảo Bảo',
        nickname: 'Bảo',
        dateOfBirth: DateTime(2023, 3, 12),
        medicalAllergies: 'Đậu phộng',
      ),
      className: 'Mầm A',
      teacherName: 'Cô Nguyễn Thị Mai',
      teacherId: 'teacher-1',
      teacherPhone: '0987654321',
      roomNumber: 'Phòng 1',
    );
  }

  @override
  Future<DailyReport?> getTodayReport(
    String childId,
    DateTime date, {
    bool includeDraft = true,
  }) async {
    if (!sameReportForTodayAndRecent) return null;
    return DailyReport(
      dailyReportId: 'rep-today',
      childId: childId,
      teacherId: 'teacher-1',
      reportDate: DateTime.now(),
      status: ReportStatus.published,
      summaryText: 'Bảo hôm nay rất hăng hái vẽ tranh, con ăn hết suất.',
    );
  }

  @override
  Future<List<DailyReport>> getRecentReports(
    String childId, {
    int limit = 7,
    bool includeDraft = true,
  }) async {
    if (sameReportForTodayAndRecent) {
      return [
        DailyReport(
          dailyReportId: 'rep-today',
          childId: childId,
          teacherId: 'teacher-1',
          reportDate: DateTime.now(),
          status: ReportStatus.published,
          summaryText: 'Bảo hôm nay rất hăng hái vẽ tranh, con ăn hết suất.',
        ),
      ];
    }
    return [
      DailyReport(
        dailyReportId: 'rep-0',
        childId: childId,
        teacherId: 'teacher-1',
        reportDate: DateTime.now().subtract(const Duration(days: 1)),
        status: reportsRead ? ReportStatus.read : ReportStatus.published,
        summaryText: 'Bảo hôm nay rất hăng hái vẽ tranh, con ăn hết suất.',
      ),
    ];
  }

  @override
  Future<DailyReport> markReportAsRead(String reportId) async => DailyReport(
    dailyReportId: reportId,
    reportDate: DateTime.now(),
    status: ReportStatus.read,
  );

  @override
  Future<void> updateMyPhone(String parentId, String phone) async {
    updateCalls++;
    lastPhone = phone;
    if (phoneFailure != null) {
      throw ClassDataException('lỗi', statusCode: phoneFailure);
    }
  }
}

/// Màn parent cao, đủ chỗ dựng hết danh sách để không phải scroll trong test.
Future<void> _pump(
  WidgetTester tester,
  _MockParentRepo repo, {
  bool openAccount = true,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1100, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? kinderTheme(),
      home: ParentFlow(repository: repo, onLogout: () {}),
    ),
  );
  await tester.pumpAndSettle();
  if (openAccount) {
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
  }
}

// ── Tính tương phản WCAG để kiểm theme tối (review focus của plan) ──────────

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Trộn màu có alpha lên trên nền (mô phỏng chip mờ trên hero).
Color _over(Color fg, Color bg) => Color.from(
  alpha: 1,
  red: fg.r * fg.a + bg.r * (1 - fg.a),
  green: fg.g * fg.a + bg.g * (1 - fg.a),
  blue: fg.b * fg.a + bg.b * (1 - fg.a),
);

Color _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style!.color!;

Color _boxColor(WidgetTester tester, Key key) {
  final decoration = tester.widget<Container>(find.byKey(key)).decoration;
  return (decoration as BoxDecoration).color!;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('bottom nav có 2 tab, mặc định ở Tổng quan', (tester) async {
    await _pump(tester, _MockParentRepo(), openAccount: false);

    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('Xin chào,'), findsOneWidget);
    expect(find.text('Thông tin liên hệ'), findsNothing);
  });

  testWidgets('tab Tài khoản hiện hồ sơ phụ huynh + liên hệ', (tester) async {
    await _pump(tester, _MockParentRepo());

    expect(find.text('Trần Văn Tuấn'), findsWidgets);
    expect(find.text('Bố của Bảo'), findsOneWidget);
    expect(find.textContaining('128 ngày cùng con'), findsOneWidget);

    expect(find.text('Thông tin liên hệ'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('tuan.tran@gmail.com'), findsOneWidget);
    expect(find.text('Quan hệ với bé'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
  });

  testWidgets('tab Tài khoản hiện thông tin bé + cài đặt + đăng xuất', (tester) async {
    await _pump(tester, _MockParentRepo());

    expect(find.text('Thông tin bé'), findsOneWidget);
    expect(find.text('Biệt danh'), findsOneWidget);
    expect(find.text('Giáo viên chủ nhiệm'), findsOneWidget);
    expect(find.text('Dị ứng'), findsOneWidget);
    expect(find.text('Đậu phộng'), findsOneWidget);

    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Thông báo đẩy'), findsOneWidget);
    expect(find.text('Giao diện'), findsOneWidget);
    expect(find.text('Về KinderLog'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
  });

  testWidgets('Tổng quan có banner dị ứng và badge chưa đọc', (tester) async {
    await _pump(tester, _MockParentRepo(), openAccount: false);

    expect(find.text('Lưu ý sức khỏe'), findsOneWidget);
    expect(find.textContaining('Đậu phộng'), findsOneWidget);
    expect(
      tester
          .widget<Badge>(find.byKey(const ValueKey('parent-unread-badge-selected')))
          .isLabelVisible,
      isTrue,
      reason: 'còn báo cáo chưa đọc thì tab phải có badge',
    );
  });

  testWidgets('badge tắt khi mọi báo cáo đã đọc', (tester) async {
    await _pump(tester, _MockParentRepo(reportsRead: true), openAccount: false);

    expect(
      tester
          .widget<Badge>(find.byKey(const ValueKey('parent-unread-badge-selected')))
          .isLabelVisible,
      isFalse,
    );
  });

  testWidgets('badge không đếm trùng báo cáo hôm nay nằm trong danh sách gần đây', (tester) async {
    await _pump(
      tester,
      _MockParentRepo(sameReportForTodayAndRecent: true),
      openAccount: false,
    );

    final badge = tester.widget<Badge>(
      find.byKey(const ValueKey('parent-unread-badge-selected')),
    );
    expect((badge.label! as Text).data, '1', reason: 'cùng 1 báo cáo thì không được đếm 2');
  });

  testWidgets('hero Tài khoản đủ tương phản ở theme tối', (tester) async {
    await _pump(tester, _MockParentRepo(), theme: kinderThemeDark());

    final heroBg = _boxColor(tester, const ValueKey('parent-hero'));
    final chipBg = _over(_boxColor(tester, const ValueKey('parent-relation-chip')), heroBg);

    expect(
      _contrast(_textColor(tester, 'Trần Văn Tuấn'), heroBg),
      greaterThanOrEqualTo(4.5),
      reason: 'tên phụ huynh trên nền hero',
    );
    expect(
      _contrast(_textColor(tester, 'Bố của Bảo'), chipBg),
      greaterThanOrEqualTo(4.5),
      reason: 'chip quan hệ trên nền hero',
    );
    expect(
      _contrast(_textColor(tester, '128 ngày cùng con ở KinderLog'), heroBg),
      greaterThanOrEqualTo(4.5),
      reason: 'dòng số ngày trên nền hero',
    );
  });

  testWidgets('sheet sửa SĐT từ chối số sai định dạng', (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await tester.tap(find.text('0901234567'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa thông tin'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12345');
    await tester.pumpAndSettle();

    final save = tester.widget<KButton>(find.widgetWithText(KButton, 'Lưu'));
    expect(save.onPressed, isNull, reason: 'số sai định dạng thì nút Lưu phải tắt');
    expect(repo.updateCalls, 0);
  });

  testWidgets('sheet sửa SĐT lưu số hợp lệ và cập nhật màn', (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await tester.tap(find.text('0901234567'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0987654321');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.lastPhone, '0987654321');
    expect(find.text('0987654321'), findsWidgets);
    expect(find.text('Chỉnh sửa thông tin'), findsNothing);
  });

  testWidgets('sheet sửa SĐT hiện lỗi khi backend trả 409', (tester) async {
    final repo = _MockParentRepo(phoneFailure: 409);
    await _pump(tester, repo);

    await tester.tap(find.text('0901234567'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0987654321');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Số điện thoại đã được sử dụng'), findsOneWidget);
  });

  testWidgets('sheet chi tiết bé hiện phòng, ngày sinh và SĐT cô', (tester) async {
    await _pump(tester, _MockParentRepo());

    await tester.tap(find.text('Trần Bảo Bảo').first);
    await tester.pumpAndSettle();

    expect(find.text('Ngày sinh'), findsOneWidget);
    expect(find.text('12/03/2023'), findsOneWidget);
    expect(find.text('Phòng'), findsOneWidget);
    expect(find.text('Phòng 1'), findsOneWidget);
    expect(find.text('0987654321'), findsOneWidget);
  });

  testWidgets('toggle thông báo đẩy lưu lựa chọn xuống máy', (tester) async {
    await _pump(tester, _MockParentRepo());

    final toggle = find.byType(Switch);
    expect(toggle, findsOneWidget);
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('kinderlog-parent-push'), isFalse);
  });
}
