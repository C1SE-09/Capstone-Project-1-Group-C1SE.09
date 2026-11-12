// TestParentAccount — tab Tài khoản + các sheet của màn Parent (Task 2).
// Phủ: 2 tab dưới bottom nav, hồ sơ phụ huynh, số ngày đồng hành,
// sheet sửa SĐT (validate + 409), sheet chi tiết bé, banner dị ứng, toggle push.

import 'dart:async';
import 'dart:math' as math;

import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_child_edit_screen.dart';
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
    this.gender,
  });

  /// Nếu khác null, updateMyPhone ném lỗi với status này.
  final int? phoneFailure;

  /// True → báo cáo gần đây đã đọc hết (badge phải tắt).
  final bool reportsRead;

  /// True → báo cáo hôm nay cũng nằm trong danh sách gần đây (như API thật trả).
  final bool sameReportForTodayAndRecent;

  /// Dị ứng của bé — seed ghi 'Không có' thay vì để trống.
  final String? allergies;
  final String? gender;

  int updateCalls = 0;
  String? lastPhone;
  int updateChildCalls = 0;
  Child? lastUpdatedChild;
  ClassDataException? childFailure;
  Completer<void>? childSaveGate;

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
    if (childSaveGate != null) await childSaveGate!.future;
    if (childFailure != null) throw childFailure!;
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
    final allergyStatus = allergies == null
        ? 'unknown'
        : {'không', 'không có'}.contains(allergies!.trim().toLowerCase())
            ? 'none'
            : 'present';
    return ChildOverview(
      child: Child(
        childId: 'child-1',
        classId: 'class-1',
        fullName: 'Trần Bảo Bảo',
        nickname: 'Bảo',
        dateOfBirth: DateTime(2023, 3, 12),
        gender: gender,
        medicalAllergies: allergies,
        allergyStatus: allergyStatus,
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
  Size size = const Size(1100, 3200),
}) async {
  tester.view.physicalSize = size;
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
    await tester.tap(find.byTooltip('Tài khoản'));
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

Color _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style!.color!;

Future<void> _openParentEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('parent-contact-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chỉnh sửa thông tin'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Garden Voice nav mặc định ở Tổng quan', (tester) async {
    await _pump(tester, _MockParentRepo(), openAccount: false);

    for (final label in ['Tổng quan', 'Báo cáo', 'Mở thông báo', 'Tài khoản']) {
      expect(find.byTooltip(label), findsOneWidget);
    }
    expect(find.text('Chào buổi sáng,'), findsOneWidget);
    expect(find.text('Thông tin liên hệ'), findsNothing);
  });

  testWidgets('tab Tài khoản hiện hồ sơ phụ huynh + liên hệ', (tester) async {
    await _pump(tester, _MockParentRepo());

    expect(find.text('Trần Văn Tuấn'), findsWidgets);
    expect(find.text('Phụ huynh bé Bảo'), findsOneWidget);
    expect(find.textContaining('128 ngày đồng hành cùng KinderLog'),
        findsOneWidget);
    expect(find.text('Thông tin liên hệ'), findsOneWidget);
    expect(find.text('Thông tin bé · Hồ sơ sức khỏe'), findsOneWidget);
    expect(find.text('Tùy chọn'), findsOneWidget);
    expect(find.text('Cài đặt & hỗ trợ'), findsOneWidget);
  });

  testWidgets('Tài khoản mở trang liên hệ và bộ chọn quan hệ riêng',
      (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('parent-contact-menu')));
    await tester.pumpAndSettle();
    expect(
        find.text('Tài khoản phụ huynh của bé Trần Bảo Bảo'), findsOneWidget);
    expect(find.text('Chỉnh sửa thông tin'), findsOneWidget);

    await tester.tap(find.text('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa thông tin liên hệ'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('parent-profile-relationship')));
    await tester.pumpAndSettle();
    expect(find.text('Người giám hộ'), findsOneWidget);
    await tester.tap(find.text('Mẹ'));
    await tester.pumpAndSettle();
    expect(find.text('Mẹ'), findsOneWidget);
  });

  testWidgets('sheet thông tin bé mở được hồ sơ thật và gọi giáo viên',
      (tester) async {
    await _pump(tester, _MockParentRepo());

    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Người đưa đón'), findsNothing);
    expect(find.text('Hồ sơ sức khỏe'), findsOneWidget);
    expect(find.text('Gọi giáo viên chủ nhiệm'), findsOneWidget);
  });

  testWidgets('tab Tài khoản hiện thông tin bé + cài đặt + đăng xuất',
      (tester) async {
    await _pump(tester, _MockParentRepo());

    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin bé'), findsOneWidget);
    expect(find.textContaining('Biệt danh: Bảo'), findsOneWidget);
    expect(find.text('Giáo viên chủ nhiệm'), findsOneWidget);
    expect(find.textContaining('Dị ứng · Đậu phộng'), findsOneWidget);

    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Thông báo đẩy'), findsOneWidget);
    expect(find.text('Giao diện'), findsNothing);
    expect(find.text('Về KinderLog'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
  });

  testWidgets('Tổng quan giữ dị ứng và badge chưa đọc', (tester) async {
    await _pump(tester, _MockParentRepo(), openAccount: false);

    expect(find.text('Dị ứng: Đậu phộng'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('garden-voice-parent-unread-badge')),
      findsOneWidget,
      reason: 'còn báo cáo chưa đọc thì chuông phải có badge',
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
      expect(find.textContaining('Dị ứng:'), findsNothing);

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

      expect(find.text('Dị ứng: đậu phộng'), findsOneWidget);
    },
  );

  testWidgets('badge tắt khi mọi báo cáo đã đọc', (tester) async {
    await _pump(tester, _MockParentRepo(reportsRead: true), openAccount: false);

    expect(
      find.byKey(const ValueKey('garden-voice-parent-unread-badge')),
      findsNothing,
    );
  });

  testWidgets(
      'badge không đếm trùng báo cáo hôm nay nằm trong danh sách gần đây',
      (tester) async {
    await _pump(
      tester,
      _MockParentRepo(sameReportForTodayAndRecent: true),
      openAccount: false,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('garden-voice-parent-unread-badge')),
        matching: find.text('1'),
      ),
      findsOneWidget,
      reason: 'cùng 1 báo cáo thì không được đếm 2',
    );
  });

  testWidgets('tài khoản Garden Voice giữ tương phản khi app ở theme tối',
      (tester) async {
    await _pump(tester, _MockParentRepo(), theme: kinderThemeDark());

    final title = find.text('Tài khoản').first;
    final palette = tester.element(title).k;
    expect(
      _contrast(_textColor(tester, 'Tài khoản'), palette.canvas),
      greaterThanOrEqualTo(4.5),
      reason: 'tiêu đề tài khoản trên nền Garden Voice',
    );
  });

  testWidgets('ấn vào SĐT phụ huynh tự động copy và hiện thông báo',
      (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('parent-contact-menu')));
    await tester.pumpAndSettle();
    expect(find.text('0901 ••• 567'), findsOneWidget);
    await tester.tap(find.text('0901 ••• 567'));
    await tester.pumpAndSettle();

    expect(find.text('Đã sao chép số điện thoại'), findsOneWidget);
    expect(find.text('Chỉnh sửa thông tin'), findsOneWidget);
  });

  testWidgets('sheet sửa thông tin phụ huynh từ chối số sai định dạng',
      (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await _openParentEditor(tester);
    expect(find.text('Sửa thông tin liên hệ'), findsOneWidget);

    final phoneFinder = find.widgetWithText(TextField, 'Số điện thoại *');
    await tester.enterText(phoneFinder, '12345');
    await tester.pumpAndSettle();

    final save =
        tester.widget<KButton>(find.widgetWithText(KButton, 'Lưu thay đổi'));
    expect(save.onPressed, isNull,
        reason: 'số sai định dạng thì nút Lưu phải tắt');
    expect(repo.updateCalls, 0);
  });

  testWidgets('sheet sửa thông tin phụ huynh lưu số, email và quan hệ hợp lệ',
      (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await _openParentEditor(tester);

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
    expect(find.text('0987 ••• 321'), findsOneWidget);
    expect(find.text('tuan.new@…'), findsOneWidget);
    expect(find.text('Chỉnh sửa thông tin'), findsOneWidget);
  });

  testWidgets('sheet sửa thông tin phụ huynh hiện lỗi khi backend trả 409',
      (tester) async {
    final repo = _MockParentRepo(phoneFailure: 409);
    await _pump(tester, repo);

    await _openParentEditor(tester);

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

  testWidgets(
      'trang chỉnh sửa thông tin bé lưu và cập nhật cả hồ sơ lẫn tài khoản',
      (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Chỉnh sửa thông tin bé'), findsOneWidget);
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh sửa thông tin bé'), findsOneWidget);
    expect(find.text('Trần Bảo Bảo'), findsWidgets);
    expect(find.text('Bảo'), findsWidgets);

    final nicknameFinder = find.byKey(const ValueKey('child-edit-nickname'));
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
    expect(find.textContaining('Biệt danh: Bảo Bối'), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Biệt danh: Bảo Bối'), findsOneWidget);
  });

  testWidgets('trang chỉnh sửa thông tin bé chặn lưu khi họ tên rỗng',
      (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();

    final nameFinder = find.byKey(const ValueKey('child-edit-name'));
    await tester.enterText(nameFinder, '   ');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(find.text('Họ và tên của bé không được để trống.'), findsOneWidget);
    expect(repo.updateChildCalls, 0);
  });

  testWidgets('sheet thông tin bé có lối chỉnh sửa và hồ sơ sức khỏe',
      (tester) async {
    await _pump(tester, _MockParentRepo());

    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Xem chi tiết'), findsNothing);
    expect(find.byTooltip('Chỉnh sửa thông tin bé'), findsOneWidget);
    expect(find.text('Hồ sơ sức khỏe'), findsOneWidget);
  });

  testWidgets('bút chì mở trang sửa bé riêng, hủy giữ nguyên hồ sơ',
      (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo, size: const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();

    final title = find.text('Chỉnh sửa thông tin bé');
    expect(ModalRoute.of(tester.element(title)), isA<PageRoute<dynamic>>());
    expect(tester.element(title).k.isGardenVoice, isTrue);
    expect(find.widgetWithText(KButton, 'Hủy'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('child-edit-nickname')), 'Chưa lưu');
    await tester.tap(find.widgetWithText(KButton, 'Hủy'));
    await tester.pumpAndSettle();

    expect(repo.updateChildCalls, 0);
    expect(find.text('Thông tin bé'), findsOneWidget);
    expect(find.textContaining('Biệt danh: Bảo'), findsOneWidget);
    expect(find.textContaining('Chưa lưu'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'lưu hồ sơ bé cho phép xóa biệt danh và giữ giới tính chưa khai báo',
      (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);
    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('child-edit-nickname')), '');
    await tester.enterText(
        find.byKey(const ValueKey('child-edit-allergies')), '');
    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(repo.updateChildCalls, 1);
    expect(repo.lastUpdatedChild?.nickname, '');
    expect(repo.lastUpdatedChild?.medicalAllergies, '');
    expect(repo.lastUpdatedChild?.gender, isNull);
    expect(find.text('Thông tin bé'), findsOneWidget);
    expect(find.textContaining('Biệt danh:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'lưu bé bị lỗi giữ dữ liệu để thử lại, chỉ đóng trang khi thành công',
      (tester) async {
    final repo = _MockParentRepo()
      ..childFailure =
          const ClassDataException('Không lưu được', statusCode: 500);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('child-edit-nickname'));
    await tester.enterText(field, 'Bảo Bối');
    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh sửa thông tin bé'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, 'Bảo Bối');
    expect(repo.updateChildCalls, 1);
    expect(repo.lastUpdatedChild, isNull);
    repo.childFailure = null;
    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(repo.updateChildCalls, 2);
    expect(find.text('Chỉnh sửa thông tin bé'), findsNothing);
    expect(find.textContaining('Biệt danh: Bảo Bối'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('đang lưu bé khóa form và không gửi trùng hoặc đóng giữa chừng',
      (tester) async {
    final gate = Completer<void>();
    final repo = _MockParentRepo()..childSaveGate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    await _pump(tester, repo);
    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pump();

    expect(repo.updateChildCalls, 1);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('child-edit-name')))
            .enabled,
        isFalse);
    expect(
        tester.widget<KButton>(find.widgetWithText(KButton, 'Hủy')).onPressed,
        isNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Chỉnh sửa thông tin bé'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(repo.updateChildCalls, 1);
    expect(find.text('Chỉnh sửa thông tin bé'), findsNothing);
    expect(find.text('Thông tin bé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chọn ngày sinh mới gửi đúng ngày tới API và cập nhật hồ sơ',
      (tester) async {
    final repo = _MockParentRepo();
    await _pump(tester, repo);
    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('child-edit-dob')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('Chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(repo.lastUpdatedChild?.dateOfBirth, DateTime(2023, 3, 15));
    expect(find.textContaining('15/03/2023'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('không đổi mã giới tính cũ khi chỉ sửa biệt danh',
      (tester) async {
    final repo = _MockParentRepo(gender: 'unknown');
    await _pump(tester, repo);
    await tester.tap(find.byKey(const ValueKey('parent-child-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin bé'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('child-edit-nickname')), 'Bảo Bối');
    await tester.tap(find.widgetWithText(KButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(repo.lastUpdatedChild?.gender, 'unknown');
    expect(repo.lastUpdatedChild?.nickname, 'Bảo Bối');
    expect(tester.takeException(), isNull);
  });

  testWidgets('trang sửa bé dùng được ở 320dp, chữ 200% và có bàn phím',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      builder: (context, page) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: page!,
      ),
      home: GardenVoiceScope(
        child: ParentChildEditScreen(
          child: const Child(childId: 'child-1', fullName: 'Trần Bảo Bảo'),
          parentId: 'parent-1',
          repository: _MockParentRepo(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final save = find.widgetWithText(KButton, 'Lưu thay đổi');
    expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(440));
    final nickname = find.byKey(const ValueKey('child-edit-nickname'));
    await tester.ensureVisible(nickname);
    await tester.enterText(nickname, 'Bảo');
    await tester.drag(
        find.byKey(const ValueKey('child-edit-scroll')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(nickname).controller!.text, 'Bảo');
    expect(tester.takeException(), isNull);
  });
}
