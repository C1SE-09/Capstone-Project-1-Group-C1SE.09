import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Garden Voice parent navigation giữ bốn action và vùng chạm 48px',
      (tester) async {
    final selected = <GardenVoiceParentDestination>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: Scaffold(
          bottomNavigationBar: GardenVoiceParentNavigation(
            selected: GardenVoiceParentDestination.home,
            onSelected: selected.add,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(
        find.byKey(const ValueKey('garden-voice-parent-navigation')),
      ),
      const Size(362, 60),
    );
    final activePill = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration! as BoxDecoration).color ==
              KPalette.gardenVoice.brandTint,
    );
    expect(activePill, findsOneWidget);
    expect(tester.getSize(activePill), const Size(48, 48));
    final navRect = tester.getRect(
      find.byKey(const ValueKey('garden-voice-parent-navigation')),
    );
    final pillRect = tester.getRect(activePill);
    expect(pillRect.left, greaterThan(navRect.left + 12));
    expect(pillRect.top, greaterThanOrEqualTo(navRect.top + 6));
    expect(pillRect.bottom, lessThanOrEqualTo(navRect.bottom - 6));
    for (final label in ['Tổng quan', 'Báo cáo', 'Mở thông báo', 'Tài khoản']) {
      expect(find.byTooltip(label), findsOneWidget);
      expect(tester.getSize(find.byTooltip(label)).height,
          greaterThanOrEqualTo(48));
    }

    await tester.tap(find.byTooltip('Báo cáo'));
    await tester.tap(find.byTooltip('Mở thông báo'));
    await tester.tap(find.byTooltip('Tài khoản'));

    expect(
      selected,
      [
        GardenVoiceParentDestination.reports,
        GardenVoiceParentDestination.notifications,
        GardenVoiceParentDestination.account,
      ],
    );
  });
}
