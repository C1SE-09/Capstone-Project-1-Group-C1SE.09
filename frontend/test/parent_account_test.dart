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
    this.allergies = 'Đậu phộng',
  });

  /// Nếu khác null, updateMyPhone ném lỗi với status này.
  final int? phoneFailure;

  /// True → báo cáo gần đây đã đọc hết (badge phải tắt).
  final bool reportsRead;

  /// True → báo cáo hôm nay cũng nằm trong danh sách gần đây (như API thật trả).
  final bool sameReportForTodayAndRecent;

  /// Dị ứng của bé — seed ghi 'Không có' thay vì để trống.
  final String? allergies;

  int updateCalls = 0;
  String? lastPhone;
  int updateChildCalls = 0;
  Child? lastUpdatedChild;

  @override
  Future<Child> updateChildInfo({
    required String parentId,
    required String childId,
    String? fullName,
    String? nickname,
    DateTime? dateOfBirth,
    String? gender,
    String? medicalAllergies,
  }) async {
    updateChildCalls++;
    lastUpdatedChild = Child(
      childId: childId,
      classId: 'class-1',
      fullName: fullName ?? 'Trần Bảo Bảo',
      nickname: nickname,
      dateOfBirth: dateOfBirth,
      gender: gender,
      medicalAllergies: medicalAllergies,
    );
    return lastUpdatedChild!;
  }

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
        medicalAllergies: allergies,
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

  String? lastEmail;
  String? lastRelationship;

  @override
  Future<void> updateMyPhone(String parentId, String phone) =>
      updateParentProfile(parentId, phone: phone);

  @override
  Future<void> updateParentProfile(
    String parentId, {
    String? phone,
    String? email,
    String? relationship,
  }) async {
    updateCalls++;
    if (phone != null) lastPhone = phone;
    lastEmail = email;
    lastRelationship = relationship;
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

  testWidgets(
    'seed ghi "Không có" → không hiện banner Tổng quan, không hiện hàng Dị ứng',
    (tester) async {
      await _pump(
        tester,
        _MockParentRepo(allergies: 'Không có'),
        openAccount: false,
      );
      expect(find.text('Lưu ý sức khỏe'), findsNothing);

      await _pump(tester, _MockParentRepo(allergies: 'Không có'));
      expect(find.text('Dị ứng'), findsNothing);
      expect(find.text('Không có'), findsNothing);
    },
  );

  testWidgets(
    'bỏ tiền tố "Dị ứng" — không thành "Dị ứng Dị ứng đậu phộng"',
    (tester) async {
      await _pump(
        tester,
        _MockParentRepo(allergies: 'Dị ứng đậu phộng'),
        openAccount: false,
      );

      expect(find.text('Bé bị dị ứng đậu phộng'), findsOneWidget);
      expect(
        find.text('Cập nhật trong Hồ sơ sức khỏe để cô giáo lưu ý.'),
        findsOneWidget,
      );
    },
  );

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

  testWidgets('ấn vào SĐT phụ huynh tự động copy và hiện thông báo', (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await tester.tap(find.text('0901234567'));
    await tester.pumpAndSettle();

    expect(find.text('Đã sao chép số điện thoại'), findsOneWidget);
    expect(find.text('Chỉnh sửa thông tin'), findsNothing);
  });

  testWidgets('sheet sửa thông tin phụ huynh từ chối số sai định dạng', (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa thông tin'), findsOneWidget);

    final phoneFinder = find.widgetWithText(TextField, 'Số điện thoại *');
    await tester.enterText(phoneFinder, '12345');
    await tester.pumpAndSettle();

    final save = tester.widget<KButton>(find.widgetWithText(KButton, 'Lưu thay đổi'));
    expect(save.onPressed, isNull, reason: 'số sai định dạng thì nút Lưu phải tắt');
    expect(repo.updateCalls, 0);
  });

  testWidgets('sheet sửa thông tin phụ huynh lưu số, email và quan hệ hợp lệ', (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();

    final phoneFinder = find.widgetWithText(TextField, 'Số điện thoại *');
    await tester.enterText(phoneFinder, '0987654321');

    final emailFinder = find.widgetWithText(TextField, 'Email');
    await tester.enterText(emailFinder, 'tuan.new@gmail.com');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.lastPhone, '0987654321');
    expect(repo.lastEmail, 'tuan.new@gmail.com');
    expect(find.text('0987654321'), findsWidgets);
    expect(find.text('tuan.new@gmail.com'), findsOneWidget);
    expect(find.text('Chỉnh sửa thông tin'), findsNothing);
  });

  testWidgets('sheet sửa thông tin phụ huynh hiện lỗi khi backend trả 409', (tester) async {
    final repo = _MockParentRepo(phoneFailure: 409);
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();

    final phoneFinder = find.widgetWithText(TextField, 'Số điện thoại *');
    await tester.enterText(phoneFinder, '0987654321');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(find.text('Số điện thoại đã được sử dụng'), findsOneWidget);
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

  testWidgets('sheet chỉnh sửa thông tin bé lưu thông tin và cập nhật giao diện', (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    // Mở sheet sửa thông tin bé từ icon lớn ở tên bé
    expect(find.byTooltip('Chỉnh sửa thông tin bé'), findsOneWidget);
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh sửa thông tin bé'), findsOneWidget);
    expect(find.text('Trần Bảo Bảo'), findsWidgets);
    expect(find.text('Bảo'), findsWidgets);

    final nicknameFinder = find.widgetWithText(TextField, 'Tên gọi ở nhà (Biệt danh)');
    await tester.enterText(nicknameFinder, 'Bảo Bối');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bé trai (Nam)'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(repo.updateChildCalls, 1);
    expect(repo.lastUpdatedChild?.nickname, 'Bảo Bối');
    expect(repo.lastUpdatedChild?.gender, 'male');
    expect(find.text('Chỉnh sửa thông tin bé'), findsNothing);
    expect(find.text('Biệt danh: Bảo Bối'), findsOneWidget);
  });

  testWidgets('sheet chỉnh sửa thông tin bé chặn lưu khi họ tên rỗng', (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();

    final nameFinder = find.widgetWithText(TextField, 'Họ và tên của bé *');
    await tester.enterText(nameFinder, '   ');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(find.text('Họ và tên của bé không được để trống.'), findsOneWidget);
    expect(repo.updateChildCalls, 0);
  });

  testWidgets('card thông tin bé chỉ có icon edit lớn ở tên bé, không có nút xem chi tiết và sửa thông tin', (tester) async {
    await _pump(tester, _MockParentRepo());

    // 2 nút ở dưới đáy card đã bị xóa
    expect(find.text('Xem chi tiết'), findsNothing);
    expect(find.text('Sửa thông tin'), findsNothing);

    // Icon edit lớn ở header tên bé
    expect(find.byTooltip('Chỉnh sửa thông tin bé'), findsOneWidget);

    // Toàn màn hình có 3 icon edit: hero phụ huynh, tên bé, dòng hồ sơ sức khỏe
    final editIcons = find.byIcon(Icons.edit_outlined);
    expect(editIcons, findsNWidgets(3));
  });
}


