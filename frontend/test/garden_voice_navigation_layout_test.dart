import 'dart:math' as math;

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_navigation.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final parent in [false, true]) {
    final role = parent ? 'parent' : 'teacher';
    final labels = parent
        ? ['Tổng quan', 'Báo cáo', 'Mở thông báo', 'Tài khoản']
        : ['Tổng quan', 'Lớp', 'Ghi âm', 'Báo cáo', 'Tài khoản'];
    final selectedIndices = parent ? [0, 2, 3] : [0, 1, 3, 4];
    for (final width in [320.0, 390.0, 412.0, 480.0, 768.0]) {
      testWidgets('$role geometry and end clearance at ${width}dp',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final selected in selectedIndices) {
          await tester.pumpWidget(MaterialApp(
            theme: kinderTheme(),
            home: Scaffold(
              bottomNavigationBar: parent
                  ? GardenVoiceParentNavigation(
                      selected: GardenVoiceParentDestination.values[selected],
                      onSelected: (_) {},
                    )
                  : GardenVoiceTeacherNavigation(
                      selected: GardenVoiceTeacherDestination.values[selected],
                      onSelected: (_) {},
                    ),
            ),
          ));
          await tester.pumpAndSettle();
          final shell = find.byKey(ValueKey('garden-voice-$role-navigation'));
          final rect = tester.getRect(shell);
          final shellWidth = math.min(362.0, width - 28);
          expect(rect.size, Size(shellWidth, 60));
          expect(rect.left, closeTo((width - shellWidth) / 2, .001));
          expect(rect.bottom, 828);
          final decoration =
              tester.widget<DecoratedBox>(shell).decoration as BoxDecoration;
          expect(decoration.color, const Color(0xFFF1F7F6));
          expect((decoration.border! as Border).top.color,
              const Color(0xFFB5D4CE));
          expect(
              decoration.borderRadius, BorderRadius.circular(parent ? 24 : 30));
          final itemWidth =
              (shellWidth - 12 - 3 * (labels.length - 1) - (parent ? 2 : 0)) /
                  labels.length;
          var left = rect.left + 6;
          for (var i = 0; i < labels.length; i++) {
            final item = find.byTooltip(labels[i]);
            final bounds = tester.getRect(item);
            final expectedWidth = itemWidth + (parent && i == selected ? 2 : 0);
            expect(bounds.left, closeTo(left, .001));
            expect(bounds.top, closeTo(rect.top + 6, .001));
            expect(bounds.width, closeTo(expectedWidth, .001));
            expect(bounds.height, 48);
            expect(bounds.width, greaterThanOrEqualTo(48));
            if (i == selected) {
              final indicator =
                  find.byKey(const ValueKey('navigation-selected-indicator'));
              expect(tester.getRect(indicator), bounds);
              final background = tester
                  .widget<DecoratedBox>(indicator)
                  .decoration as BoxDecoration;
              expect(background.color, const Color(0xFFCBE9DE));
              if (parent) {
                expect((background.border! as Border).top,
                    const BorderSide(color: Color(0xFFA1CFC0)));
              } else {
                expect(background.border, isNull);
              }
            }
            left += expectedWidth + 3;
          }
          expect(rect.right - tester.getRect(find.byTooltip(labels.last)).right,
              closeTo(6, .001));
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('$role handles system bottom inset once at 200% text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: kinderTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: parent
              ? GardenVoiceParentNavigation(
                  selected: GardenVoiceParentDestination.account,
                  onSelected: (_) {},
                )
              : GardenVoiceTeacherNavigation(
                  selected: GardenVoiceTeacherDestination.account,
                  onSelected: (_) {},
                ),
        ),
      ));
      final shell = find.byKey(ValueKey('garden-voice-$role-navigation'));
      expect(tester.getRect(shell).bottom, 844 - 24 - 16);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$role dark colors survive nested GardenVoiceScope',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: kinderThemeDark(),
        home: GardenVoiceScope(
          child: Scaffold(
            bottomNavigationBar: parent
                ? GardenVoiceParentNavigation(
                    selected: GardenVoiceParentDestination.home,
                    onSelected: (_) {},
                  )
                : GardenVoiceTeacherNavigation(
                    selected: GardenVoiceTeacherDestination.home,
                    onSelected: (_) {},
                  ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final shell = find.byKey(ValueKey('garden-voice-$role-navigation'));
      final decoration =
          tester.widget<DecoratedBox>(shell).decoration as BoxDecoration;
      expect(decoration.color, KPalette.dark.surface);
      expect(
          (decoration.border! as Border).top.color, KPalette.dark.lineStrong);
      final loader = tester
          .widget<SvgPicture>(find.byType(SvgPicture).first)
          .bytesLoader as SvgAssetLoader;
      expect(loader.colorMapper, isNotNull);
      expect(
        loader.colorMapper!
            .substitute(null, 'path', 'stroke', KPalette.gardenVoice.brand),
        KPalette.dark.brand,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
