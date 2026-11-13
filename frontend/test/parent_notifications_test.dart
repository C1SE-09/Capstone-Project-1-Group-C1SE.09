import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart'
    show FilterChipButton;
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_navigation.dart';
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

class _MedicationRepository extends HttpMedicationRepository {
  int loads = 0;

  @override
  Future<List<MedicationDose>> getMedicationRequests(
      {required String childId, String? batchId}) async {
    loads++;
    return [];
  }
}

const _latestTitle = 'Báo cáo ngày thứ 3';
const _olderTitle = 'Báo cáo ngày thứ 2';

Finder _filter(String name) =>
    find.byKey(ValueKey('parent-notification-filter-$name'));

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
    final nunito = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-ExtraBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-Black.ttf'));
    await nunito.load();
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
    await tester.scrollUntilVisible(find.text('Xin nghỉ · Trễ'), 300);
    // Nav nổi che một phần viewport: đưa shortcut lên trên nav trước khi bấm.
    await Scrollable.ensureVisible(tester.element(find.text('Xin nghỉ · Trễ')),
        alignment: .5);
    await tester.pumpAndSettle();
    expect(find.text('Xin nghỉ · Trễ').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Xin nghỉ · Trễ'));
    await tester.pumpAndSettle();
    expect(find.text('Xin phép nghỉ / báo trễ'), findsOneWidget);
    expect(find.text('Chưa có đơn nào'), findsOneWidget);
    expect(transport.requests.single.queryParameters['child_id'], 'child-1');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Thông báo'), -300);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(_filter('all'), findsOneWidget);
  });

  testWidgets('tổng quan mở dặn thuốc cho đúng bé', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final medication = _MedicationRepository();
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: ParentFlow(
        repository: _InboxRepository(),
        medicationRepository: medication,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dặn thuốc'), 300);
    await Scrollable.ensureVisible(tester.element(find.text('Dặn thuốc')),
        alignment: .5);
    await tester.pumpAndSettle();
    expect(find.text('Dặn thuốc').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Dặn thuốc'));
    await tester.pumpAndSettle();
    expect(find.byType(ParentMedicationScreen), findsOneWidget);
    expect(medication.loads, 1);
  });

  testWidgets('pill gọn theo Figma, không cắt Đơn nghỉ ở màn 390',
      (tester) async {
    await _openInbox(tester, _InboxRepository());
    final last = tester.getRect(_filter('leave'));
    expect(last.right, lessThanOrEqualTo(390));
    expect(find.widgetWithText(OutlinedButton, 'Xem chi tiết'), findsNothing);
    expect(
        tester
            .getSize(
                find.byKey(const ValueKey('garden-voice-parent-navigation')))
            .height,
        equals(60));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chrome rộng giữ cột mobile và có entry Xin nghỉ · Trễ',
      (tester) async {
    await _openInbox(tester, _InboxRepository(), size: const Size(1440, 1000));
    final frame =
        tester.getRect(find.byKey(const ValueKey('parent-mobile-frame')));
    expect(frame.width, lessThanOrEqualTo(480));
    expect(frame.center.dx, 720);
    await tester.tap(find.byTooltip('Tổng quan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xin nghỉ · Trễ'));
    expect(find.text('Xin nghỉ · Trễ'), findsOneWidget);
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
        final label = find.text('BÁO CÁO').first;
        final foreground =
            tester.widget<Text>(label).style!.color!.computeLuminance();
        final background = tester
            .widget<Material>(
                find.ancestor(of: label, matching: find.byType(Material)).first)
            .color!
            .computeLuminance();
        final contrast = foreground > background
            ? (foreground + .05) / (background + .05)
            : (background + .05) / (foreground + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        for (final name in ['all', 'reports', 'health', 'leave']) {
          final chip = find.descendant(
              of: _filter(name), matching: find.byType(FilterChipButton));
          final text = find.descendant(of: chip, matching: find.byType(Text));
          final material =
              find.descendant(of: chip, matching: find.byType(Material)).first;
          final foreground = tester.widget<Text>(text).style!.color!;
          final surface = tester.widget<Material>(material).color!;
          final chipContrast =
              foreground.computeLuminance() > surface.computeLuminance()
                  ? (foreground.computeLuminance() + .05) /
                      (surface.computeLuminance() + .05)
                  : (surface.computeLuminance() + .05) /
                      (foreground.computeLuminance() + .05);
          expect(chipContrast, greaterThanOrEqualTo(4.5));
          expect(
              tester.getSemantics(_filter(name)).label, startsWith('Bộ lọc '));
        }
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

    expect(_filter('all'), findsOneWidget);
    expect(_filter('reports'), findsOneWidget);
    expect(_filter('health'), findsOneWidget);
    expect(_filter('leave'), findsOneWidget);
    expect(find.text('BÁO CÁO'), findsNWidgets(2));
    expect(find.text(_latestTitle), findsOneWidget);
    expect(find.text(_olderTitle), findsOneWidget);
    expect(tester.getTopLeft(find.text(_latestTitle)).dy,
        lessThan(tester.getTopLeft(find.text(_olderTitle)).dy));
    expect(find.byType(GardenVoiceParentNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inbox dùng cấu trúc Garden Voice và đánh dấu báo cáo chưa đọc',
      (tester) async {
    final repository = _InboxRepository();
    await _openInbox(tester, repository);

    expect(find.text('Mới'), findsOneWidget);
    expect(find.text('Trước đó'), findsOneWidget);
    expect(find.text('Đánh dấu đã đọc'), findsOneWidget);
    expect(_filter('leave'), findsOneWidget);

    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pumpAndSettle();

    expect(repository.openedReports, ['report-new']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cuộn ngang tới bộ lọc và chỉ hiện đúng nhóm được chọn',
      (tester) async {
    await _openInbox(tester, _InboxRepository(), size: const Size(320, 844));

    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(-350, 0));
    await tester.pumpAndSettle();

    await tester.tap(_filter('leave'));
    await tester.pumpAndSettle();
    expect(find.text(_latestTitle), findsNothing);
    expect(find.text('Chưa có đơn nghỉ mới.'), findsOneWidget);
    await tester.tap(_filter('health'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo sức khỏe.'), findsOneWidget);

    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(350, 0));
    await tester.pumpAndSettle();
    await tester.tap(_filter('reports'));
    await tester.pumpAndSettle();
    expect(find.text(_latestTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mở chi tiết đúng báo cáo và cập nhật đã đọc, giữ bộ lọc',
      (tester) async {
    final repository = _InboxRepository();
    await _openInbox(tester, repository);
    await tester.tap(_filter('reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_latestTitle));
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo ngày'), findsOneWidget);
    expect(find.text('Bé tham gia hoạt động cùng các bạn.'), findsNWidgets(2));
    expect(repository.openedReports, ['report-new']);
    await tester.tap(find.text('Đã đọc báo cáo ✓'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Semantics>(_filter('reports')).properties.selected,
      isTrue,
    );
    expect(find.text(_latestTitle), findsOneWidget);
    await tester.tap(find.byTooltip('Tổng quan'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('garden-voice-parent-unread-badge')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lỗi đánh dấu đã đọc không làm mất thông báo chưa đọc',
      (tester) async {
    await _openInbox(tester, _InboxRepository(failRead: true));
    await tester.tap(find.text(_latestTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Đóng báo cáo'));
    await tester.pumpAndSettle();

    expect(find.text(_latestTitle), findsOneWidget);
    await tester.tap(find.byTooltip('Tổng quan'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('garden-voice-parent-unread-badge')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('quay lại bằng nút và nút hệ thống về tổng quan', (tester) async {
    await _openInbox(tester, _InboxRepository());
    await tester.tap(find.byTooltip('Tổng quan'));
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
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<GardenVoiceParentNavigation>(
              find.byType(GardenVoiceParentNavigation))
          .selected,
      GardenVoiceParentDestination.account,
    );
    expect(_filter('all'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inbox rỗng không tràn màn hẹp khi chữ lớn và theme tối',
      (tester) async {
    await _openInbox(tester, _InboxRepository(empty: true),
        size: const Size(320, 640), textScale: 2, dark: true);

    expect(find.text('Chưa có thông báo.'), findsOneWidget);
    expect(find.byType(GardenVoiceParentNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nội dung và nút chi tiết không tràn ở 320 với chữ lớn',
      (tester) async {
    await _openInbox(tester, _InboxRepository(),
        size: const Size(320, 844), textScale: 2);

    expect(find.text(_latestTitle), findsOneWidget);
    expect(find.text('BÁO CÁO'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
