import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/parent_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parent_request_repository_test.dart' show RequestTransport, jsonBody;

class _InboxRepository extends HttpDashboardRepository {
  _InboxRepository(
      {this.empty = false, this.failRead = false, DailyReport? report})
      : latest = report ??
            DailyReport.fromJson({
              'daily_report_id': 'report-new',
              'child_id': 'child-1',
              'report_date': '2026-10-20',
              'published_at': '2026-10-20',
              'status': 'sent',
              'summary_text': 'Bé tham gia hoạt động cùng các bạn.',
            });

  final bool empty;
  final bool failRead;
  final openedReports = <String>[];
  final DailyReport latest;

  @override
  Future<Parent> getCurrentParent() async => const Parent(
        parentId: 'parent-1',
        fullName: 'Trần Văn Tuấn',
        phone: '0901234567',
      );

  @override
  Future<ChildOverview> getPrimaryChildOverview(String parentId) async =>
      ChildOverview(
        child: Child(
          childId: 'child-1',
          classId: 'class-1',
          fullName: 'Trần Bảo Bảo',
          dateOfBirth: DateTime(2020),
        ),
        className: 'Mầm A',
        teacherName: 'Cô Nguyễn Thị Mai',
      );

  @override
  Future<DailyReport?> getTodayReport(String childId, DateTime date,
          {bool includeDraft = true}) async =>
      empty ? null : latest;

  @override
  Future<List<DailyReport>> getRecentReports(String childId,
          {int limit = 7, bool includeDraft = true}) async =>
      empty
          ? []
          : [
              DailyReport(
                dailyReportId: 'report-old',
                childId: childId,
                reportDate: DateTime(2026, 10, 19),
                status: ReportStatus.read,
              ),
              latest,
              latest.copyWith(
                  dailyReportId: 'draft', status: ReportStatus.draft),
              latest.copyWith(
                  dailyReportId: 'archived', status: ReportStatus.archived),
            ];

  @override
  Future<DailyReport> markReportAsRead(String reportId) async {
    if (failRead) throw StateError('Không kết nối được API');
    openedReports.add(reportId);
    return latest.copyWith(status: ReportStatus.read);
  }
}

const _latestTitle = 'Báo cáo ngày 20/10/2026 của bé Trần Bảo Bảo';
const _olderTitle = 'Báo cáo ngày 19/10/2026 của bé Trần Bảo Bảo';

Future<void> _openInbox(
  WidgetTester tester,
  _InboxRepository repository, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = false,
}) async {
  // Chỉ kiểm tra responsive của inbox, không kéo lỗi layout tổng quan cũ vào đây.
  tester.view.physicalSize = const Size(768, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  Widget app(double scale) => MaterialApp(
        theme: dark ? kinderThemeDark() : kinderTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ParentFlow(repository: repository),
      );
  await tester.pumpWidget(app(1));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Thông báo'));
  await tester.pumpAndSettle();
  tester.view.physicalSize = size;
  await tester.pumpWidget(app(textScale));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await fonts.load();
  });

  testWidgets('entry tổng quan mở lịch sử đúng bé, quay lại vẫn mở được chuông',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final transport = RequestTransport((_) => jsonBody({
          'items': [],
          'total': 0,
          'offset': 0,
          'limit': 20,
        }));
    final requests = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: ParentFlow(
          repository: _InboxRepository(), leaveRequestRepository: requests),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Xin nghỉ / Báo trễ'), 300);
    await tester.tap(find.text('Xin nghỉ / Báo trễ'));
    await tester.pumpAndSettle();
    expect(find.text('Xin phép nghỉ / báo trễ'), findsOneWidget);
    expect(find.text('Chưa có đơn nào'), findsOneWidget);
    expect(transport.requests.single.queryParameters['child_id'], 'child-1');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Thông báo'), -300);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Tất cả'), findsOneWidget);
  });

  testWidgets('pill gọn theo Figma, không cắt Điểm danh ở màn 390',
      (tester) async {
    await _openInbox(tester, _InboxRepository());
    final last = tester.getRect(find.widgetWithText(ChoiceChip, 'Điểm danh'));
    expect(last.right, lessThanOrEqualTo(370));
    expect(find.widgetWithText(OutlinedButton, 'Xem chi tiết'), findsNothing);
    expect(
        tester
            .getSize(find.byKey(const ValueKey('parent-bottom-navigation')))
            .height,
        lessThanOrEqualTo(56));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chrome rộng giữ cột mobile và có entry Xin nghỉ / Báo trễ',
      (tester) async {
    await _openInbox(tester, _InboxRepository(), size: const Size(1440, 1000));
    final frame =
        tester.getRect(find.byKey(const ValueKey('parent-mobile-frame')));
    expect(frame.width, lessThanOrEqualTo(480));
    expect(frame.center.dx, 720);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xin nghỉ / Báo trễ'));
    expect(find.text('Xin nghỉ / Báo trễ'), findsOneWidget);
  });

  testWidgets('published_at chỉ có ngày không bị hiển thị thành giờ 00:00',
      (tester) async {
    final now = DateTime.now();
    final day = now.toIso8601String().split('T').first;
    final shortDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';
    await _openInbox(
        tester,
        _InboxRepository(
            report: DailyReport.fromJson({
          'daily_report_id': 'report-today',
          'child_id': 'child-1',
          'report_date': day,
          'published_at': day,
          'status': 'sent',
        })));

    expect(find.text('00:00'), findsNothing);
    expect(find.text(shortDate), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('inbox có tương phản và vùng chạm truy cập được, dark=$dark',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _openInbox(tester, _InboxRepository(), dark: dark);
        final label = find.text('BÁO CÁO NGÀY').first;
        final foreground =
            tester.widget<Text>(label).style!.color!.computeLuminance();
        final background = tester
            .widget<KCard>(
                find.ancestor(of: label, matching: find.byType(KCard)))
            .color!
            .computeLuminance();
        final contrast = foreground > background
            ? (foreground + .05) / (background + .05)
            : (background + .05) / (foreground + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('chuông mở inbox, khử trùng và sắp xếp báo cáo, ẩn bản nháp',
      (tester) async {
    await _openInbox(tester, _InboxRepository());

    expect(find.widgetWithText(ChoiceChip, 'Tất cả'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Báo Cáo'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Sức khoẻ'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Điểm danh'), findsOneWidget);
    expect(find.text('BÁO CÁO NGÀY'), findsNWidgets(2));
    expect(find.text(_latestTitle), findsOneWidget);
    expect(find.text(_olderTitle), findsOneWidget);
    expect(tester.getTopLeft(find.text(_latestTitle)).dy,
        lessThan(tester.getTopLeft(find.text(_olderTitle)).dy));
    expect(find.byType(ParentNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cuộn ngang tới bộ lọc và chỉ hiện đúng nhóm được chọn',
      (tester) async {
    await _openInbox(tester, _InboxRepository(), size: const Size(320, 844));

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar).first);
    expect(scrollbar.thumbVisibility, isTrue);
    expect(scrollbar.trackVisibility, isTrue);
    expect(scrollbar.controller!.position.maxScrollExtent, greaterThan(0));
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(scrollbar.controller!.offset, greaterThan(0));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Điểm danh'));
    await tester.pumpAndSettle();
    expect(find.text(_latestTitle), findsNothing);
    expect(find.text('Chưa có thông báo điểm danh.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sức khoẻ'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo sức khoẻ.'), findsOneWidget);

    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(350, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Báo Cáo'));
    await tester.pumpAndSettle();
    expect(find.text(_latestTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mở chi tiết đúng báo cáo và cập nhật đã đọc, giữ bộ lọc',
      (tester) async {
    final repository = _InboxRepository();
    await _openInbox(tester, repository);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Báo Cáo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_latestTitle));
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo hằng ngày'), findsOneWidget);
    expect(find.text('Bé tham gia hoạt động cùng các bạn.'), findsOneWidget);
    expect(repository.openedReports, ['report-new']);
    await tester.tap(find.byTooltip('Quay lại').last);
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Báo Cáo'))
            .selected,
        isTrue);
    expect(find.text(_latestTitle), findsOneWidget);
    expect(
        tester
            .widget<Badge>(
                find.byKey(const ValueKey('parent-unread-badge-selected')))
            .isLabelVisible,
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lỗi đánh dấu đã đọc không làm mất thông báo chưa đọc',
      (tester) async {
    await _openInbox(tester, _InboxRepository(failRead: true));
    await tester.tap(find.text(_latestTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quay lại').last);
    await tester.pumpAndSettle();

    expect(find.text(_latestTitle), findsOneWidget);
    expect(
        tester
            .widget<Badge>(
                find.byKey(const ValueKey('parent-unread-badge-selected')))
            .isLabelVisible,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quay lại bằng nút và nút hệ thống về tổng quan', (tester) async {
    await _openInbox(tester, _InboxRepository());
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Báo cáo hôm nay'), findsOneWidget);

    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Báo cáo hôm nay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cài đặt mở tab tài khoản hiện có', (tester) async {
    await _openInbox(tester, _InboxRepository(), size: const Size(768, 1600));
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<ParentNavigationBar>(find.byType(ParentNavigationBar))
            .selectedIndex,
        1);
    expect(find.widgetWithText(ChoiceChip, 'Tất cả'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inbox rỗng không tràn màn hẹp khi chữ lớn và theme tối',
      (tester) async {
    await _openInbox(tester, _InboxRepository(empty: true),
        size: const Size(320, 640), textScale: 2, dark: true);

    expect(find.text('Chưa có thông báo.'), findsOneWidget);
    expect(find.byType(ParentNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nội dung và nút chi tiết không tràn ở 320 với chữ lớn',
      (tester) async {
    await _openInbox(tester, _InboxRepository(),
        size: const Size(320, 844), textScale: 2);

    expect(find.text(_latestTitle), findsOneWidget);
    expect(find.text('BÁO CÁO NGÀY'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
