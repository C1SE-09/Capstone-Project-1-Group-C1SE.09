import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Garden Voice navigation giữ năm action và vùng chạm 48px',
      (tester) async {
    final selected = <GardenVoiceTeacherDestination>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: Scaffold(
          bottomNavigationBar: GardenVoiceTeacherNavigation(
            selected: GardenVoiceTeacherDestination.home,
            onSelected: selected.add,
          ),
        ),
      ),
    );

    final navigation =
        find.byKey(const ValueKey('garden-voice-teacher-navigation'));
    expect(tester.getSize(navigation), const Size(362, 60));
    final activePill = find.byKey(const ValueKey('navigation-selected-indicator'));
    expect(activePill, findsOneWidget);
    expect(tester.getSize(activePill), const Size(67.6, 48));
    final navRect = tester.getRect(navigation);
    final pillRect = tester.getRect(activePill);
    expect(pillRect.left, navRect.left + 6);
    expect(pillRect.top, greaterThanOrEqualTo(navRect.top + 6));
    expect(pillRect.bottom, lessThanOrEqualTo(navRect.bottom - 6));
    for (final label in [
      'Tổng quan',
      'Lớp',
      'Ghi âm',
      'Báo cáo',
      'Tài khoản'
    ]) {
      expect(find.byTooltip(label), findsOneWidget);
      expect(tester.getSize(find.byTooltip(label)).height,
          greaterThanOrEqualTo(48));
    }

    await tester.tap(find.byTooltip('Lớp'));
    await tester.tap(find.byTooltip('Ghi âm'));
    await tester.tap(find.byTooltip('Báo cáo'));
    await tester.tap(find.byTooltip('Tài khoản'));

    expect(
      selected,
      [
        GardenVoiceTeacherDestination.classList,
        GardenVoiceTeacherDestination.record,
        GardenVoiceTeacherDestination.reports,
        GardenVoiceTeacherDestination.account,
      ],
    );
  });
}
