import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_tabs.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_notifications.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/attendance_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_overview.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/domain/entities/child/child.dart' as domain;
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/navigation_review_app.dart';

void main() {
  testWidgets('teacher keeps health filter on tab return', (tester) async {
    await tester.pumpWidget(const NavigationReviewApp());
    await tester.pumpAndSettle();
    tester
        .widget<GardenVoiceTeacherOverview>(
            find.byType(GardenVoiceTeacherOverview))
        .onHealth!();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ClassListScreen>(find.byType(ClassListScreen))
            .initialHealthOnly,
        isTrue);
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lớp'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ClassListScreen>(find.byType(ClassListScreen))
            .initialHealthOnly,
        isTrue);
  });

  testWidgets('changing child resets notification filters and retained state',
      (tester) async {
    var childId = 'child-a';
    late StateSetter update;
    final repository = _MultiChildDashboard();
    await tester.pumpWidget(MaterialApp(
        theme: kinderTheme(),
        home: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return ParentFlow(childId: childId, repository: repository);
        })));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mở thông báo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sức khỏe'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo sức khỏe.'), findsOneWidget);
    update(() => childId = 'child-b');
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo sức khỏe.'), findsNothing);
    expect(find.text('Mới'), findsOneWidget);
  });

  for (final parent in [false, true]) {
    testWidgets(
        '${parent ? 'parent' : 'teacher'} overview supports scroll hiding',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const NavigationReviewApp());
      await tester.pumpAndSettle();
      if (parent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await tester.pumpAndSettle();
      }
      final list = find.byType(ListView).first;
      final nav = find.byKey(
          ValueKey('garden-voice-${parent ? 'parent' : 'teacher'}-navigation'));
      final before = tester.getRect(list);
      expect(before.bottom, 640);
      await tester.drag(list, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(tester.getRect(nav).top, greaterThan(640));
      expect(tester.getRect(list), before);
    });

    testWidgets(
        '${parent ? 'parent' : 'teacher'} hides without losing body area and retains tabs',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const NavigationReviewApp());
      await tester.pumpAndSettle();
      if (parent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip(parent ? 'Mở thông báo' : 'Báo cáo'));
      await tester.pumpAndSettle();
      final page = find.byType(parent ? ParentNotifications : HistoryScreen);
      final list =
          find.descendant(of: page, matching: find.byType(ListView)).first;
      final viewport = tester.getRect(list);
      expect(viewport.bottom, 844);
      final nav = find.byKey(
          ValueKey('garden-voice-${parent ? 'parent' : 'teacher'}-navigation'));
      final visible = tester.getRect(nav);
      final state = tester.state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first);
      await tester.drag(list, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.getRect(nav).top, greaterThanOrEqualTo(844));
      expect(tester.getRect(list), viewport);
      await tester.drag(list, const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(tester.getRect(nav), visible);
      final offset = state.position.pixels;
      await tester.tap(find.byTooltip('Tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(parent ? 'Mở thông báo' : 'Báo cáo'));
      await tester.pumpAndSettle();
      final restored = tester.state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first);
      expect(restored.position.pixels, offset);
      final beforeAction = restored.position.pixels;
      await tester.tap(find.byTooltip(parent ? 'Báo cáo' : 'Ghi âm'));
      await tester.pumpAndSettle();
      expect(parent ? find.byType(BottomSheet) : find.byType(RecordHubScreen),
          findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(restored.position.pixels, beforeAction);
      expect(tester.getRect(nav), visible);
      if (!parent) {
        await tester.tap(find.byTooltip('Lớp'));
        await tester.pumpAndSettle();
        final field = find.byType(EditableText).hitTestable().first;
        final focus = tester.widget<EditableText>(field).focusNode;
        await tester.tap(field);
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        await tester.tap(find.byTooltip('Tài khoản'));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isFalse);
        expect(focus.canRequestFocus, isFalse);
        await tester.tap(find.byTooltip('Lớp'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Điểm danh'));
        await tester.pumpAndSettle();
        final attendanceState = tester.state(find.byType(AttendanceScreen));
        await tester.tap(find.byTooltip('Ghi âm'));
        await tester.pumpAndSettle();
        expect(find.byType(RecordHubScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
            tester.state(find.byType(AttendanceScreen)), same(attendanceState));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Báo cáo'));
        await tester.pumpAndSettle();
        final afterReload = tester.state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first);
        expect(afterReload.position.pixels, beforeAction);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _MultiChildDashboard extends NavigationReviewDashboard {
  @override
  Future<ChildOverview> getChildOverviewForParent(
          String parentId, String childId) async =>
      ChildOverview(
          child: domain.Child(
              childId: childId, fullName: childId, classId: 'review-class'),
          className: 'Mầm 1',
          teacherName: 'Cô Mai');
}
