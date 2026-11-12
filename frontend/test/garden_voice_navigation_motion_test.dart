import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final parent in [false, true]) {
    testWidgets(
        '${parent ? 'parent' : 'teacher'} pill travels from visible position when rapid taps retarget it',
        (tester) async {
      var selected = 0;
      late StateSetter update;
      await tester.pumpWidget(MaterialApp(
        theme: kinderTheme(),
        home: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return Scaffold(
            bottomNavigationBar: parent
                ? GardenVoiceParentNavigation(
                    selected: GardenVoiceParentDestination.values[selected],
                    onSelected: (value) =>
                        setState(() => selected = value.index))
                : GardenVoiceTeacherNavigation(
                    selected: GardenVoiceTeacherDestination.values[selected],
                    onSelected: (value) =>
                        setState(() => selected = value.index)),
          );
        }),
      ));
      final pill = find.byKey(const ValueKey('navigation-selected-indicator'));
      expect(pill, findsOneWidget);
      final start = tester.getRect(pill);
      update(() => selected = parent ? 3 : 4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final moving = tester.getRect(pill);
      expect(moving.left, greaterThan(start.left));
      expect(moving.left,
          lessThan(tester.getRect(find.byTooltip('Tài khoản')).left));
      update(() => selected = parent ? 2 : 1);
      await tester.pump();
      expect(tester.getRect(pill).left, closeTo(moving.left, .01));
      await tester.pump(const Duration(milliseconds: 40));
      update(() => selected = parent ? 0 : 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(tester.getRect(pill),
          tester.getRect(find.byTooltip(parent ? 'Tổng quan' : 'Báo cáo')));
      expect(tester.takeException(), isNull);
    });
  }
}
