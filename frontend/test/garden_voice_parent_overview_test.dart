import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-VariableFont_wght.ttf'));
    await font.load();
  });

  testWidgets('Garden Voice parent overview giữ dữ liệu thật và action hiện có',
      (tester) async {
    var reportOpened = false;
    var notificationsOpened = false;
    var timetableOpened = false;
    var requestsOpened = false;
    var medicationOpened = false;
    final report = DailyReport(
      dailyReportId: 'report-1',
      childId: 'child-1',
      teacherId: 'teacher-1',
      reportDate: DateTime(2026, 11, 5),
      status: ReportStatus.published,
      eating: 'Ăn hết suất cơm, uống đủ nước',
      sleeping: 'Ngủ ngon · 12:00 – 13:45',
      activitiesText: 'Vẽ tranh mùa thu · rất hứng thú',
      summaryText: 'Hôm nay An ăn ngoan, gia đình theo dõi thêm giúp cô nhé.',
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: Scaffold(
          body: GardenVoiceParentOverview(
            parent:
                const Parent(parentId: 'parent-1', fullName: 'Nguyễn Văn Tuấn'),
            overview: const ChildOverview(
              child: Child(
                childId: 'child-1',
                classId: 'class-1',
                fullName: 'Nguyễn Minh An',
              ),
              className: 'Mầm 1',
              teacherName: 'Cô Nguyễn Thị Mai',
            ),
            report: report,
            unreadCount: 2,
            onOpenReport: (_) => reportOpened = true,
            onOpenNotifications: () => notificationsOpened = true,
            onOpenTimetable: () => timetableOpened = true,
            onOpenRequests: () => requestsOpened = true,
            onOpenMedication: () => medicationOpened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn Tuấn'), findsOneWidget);
    expect(find.text('Nguyễn Minh An'), findsOneWidget);
    expect(find.text('Cô Nguyễn Thị Mai'), findsOneWidget);
    expect(find.text('Báo cáo hôm nay'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Giấc ngủ'), findsOneWidget);
    expect(find.text('Hoạt động'), findsOneWidget);
    expect(find.text('Lịch học'), findsOneWidget);
    expect(find.text('Xin nghỉ · Trễ'), findsOneWidget);
    expect(find.text('Dặn thuốc'), findsOneWidget);
    expect(find.textContaining('Lời nhắn của'), findsOneWidget);
    expect(find.textContaining('Đã đến lớp'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('garden-voice-parent-child-card')),
          )
          .dy,
      closeTo(94, 1),
    );

    await tester.tap(find.byTooltip('Thông báo'));
    await tester.tap(find.text('Ăn uống'));
    await tester.tap(find.text('Lịch học'));
    await tester.tap(find.text('Xin nghỉ · Trễ'));
    await tester.tap(find.text('Dặn thuốc'));

    expect(reportOpened, isTrue);
    expect(notificationsOpened, isTrue);
    expect(timetableOpened, isTrue);
    expect(requestsOpened, isTrue);
    expect(medicationOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Garden Voice parent overview không tràn ở 320dp chữ 200%',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: GardenVoiceParentOverview(
            parent:
                const Parent(parentId: 'parent-1', fullName: 'Nguyễn Văn Tuấn'),
            overview: const ChildOverview(
              child: Child(
                childId: 'child-1',
                classId: 'class-1',
                fullName: 'Nguyễn Minh An',
              ),
              className: 'Mầm 1',
              teacherName: 'Cô Nguyễn Thị Mai',
            ),
            report: DailyReport(
              dailyReportId: 'report-1',
              reportDate: DateTime(2026, 11, 5),
              status: ReportStatus.published,
              eating: 'Ăn hết suất cơm, uống đủ nước',
              sleeping: 'Ngủ ngon · 12:00 – 13:45',
              activitiesText: 'Vẽ tranh mùa thu · rất hứng thú',
            ),
            unreadCount: 0,
            onOpenReport: (_) {},
            onOpenNotifications: () {},
            onOpenTimetable: () {},
            onOpenRequests: () {},
            onOpenMedication: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo hôm nay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Garden Voice parent shortcuts stay horizontal at 360dp phone width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: Scaffold(
          body: GardenVoiceParentOverview(
            parent:
                const Parent(parentId: 'parent-1', fullName: 'Trần Văn Tuấn'),
            overview: const ChildOverview(
              child: Child(
                childId: 'child-1',
                classId: 'class-1',
                fullName: 'Trần Gia Bảo',
              ),
              className: 'Mầm A',
              teacherName: 'Cô Nguyễn Thị Mai',
            ),
            report: null,
            unreadCount: 0,
            onOpenReport: (_) {},
            onOpenNotifications: () {},
            onOpenTimetable: () {},
            onOpenRequests: () {},
            onOpenMedication: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final schedulePos = tester.getTopLeft(find.text('Lịch học'));
    final leavePos = tester.getTopLeft(find.text('Xin nghỉ · Trễ'));
    final medPos = tester.getTopLeft(find.text('Dặn thuốc'));
    expect(schedulePos.dy, closeTo(leavePos.dy, 2));
    expect(leavePos.dy, closeTo(medPos.dy, 2));
    expect(schedulePos.dx, lessThan(leavePos.dx));
    expect(leavePos.dx, lessThan(medPos.dx));
    expect(tester.takeException(), isNull);
  });
}
