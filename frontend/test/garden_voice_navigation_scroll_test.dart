import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_navigation_scroll.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
        'overlay threshold, bottom hit testing, last item and reduced=$reduced',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: kinderTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!),
        home: Scaffold(
            body: GardenVoiceNavigationFrame(
          activeTab: 0,
          autoHide: true,
          navigation: GardenVoiceTeacherNavigation(
              selected: GardenVoiceTeacherDestination.home, onSelected: (_) {}),
          body: Builder(
              builder: (context) => ListView(
                    controller: controller,
                    padding: EdgeInsets.only(
                        bottom: 24 +
                            GardenVoiceNavigationFrame.bottomPaddingOf(
                                context)),
                    children: [
                      for (var i = 0; i < 50; i++)
                        SizedBox(
                            height: 64,
                            child: TextButton(
                                onPressed: () => taps++, child: Text('Row $i')))
                    ],
                  )),
        )),
      ));
      await tester.pumpAndSettle();
      final nav = find.byKey(const ValueKey('garden-voice-teacher-navigation'));
      final list = find.byType(ListView);
      final viewport = tester.getRect(list);
      expect(viewport.bottom, 820);
      final navRect = tester.getRect(nav);
      controller.jumpTo(128);
      await tester.pumpAndSettle();
      expect(tester.getRect(nav), navRect);
      void scroll(double delta, {bool horizontal = false}) {
        ScrollUpdateNotification(
          metrics: horizontal
              ? FixedScrollMetrics(
                  minScrollExtent: 0,
                  maxScrollExtent: 1000,
                  pixels: 100,
                  viewportDimension: 390,
                  axisDirection: AxisDirection.right,
                  devicePixelRatio: 1)
              : controller.position,
          context: tester.element(list),
          dragDetails: DragUpdateDetails(globalPosition: Offset.zero),
          scrollDelta: delta,
        ).dispatch(tester.element(list));
      }

      scroll(40, horizontal: true);
      scroll(9);
      scroll(10);
      await tester.pumpAndSettle();
      expect(tester.getRect(nav), navRect);
      scroll(1);
      await tester.pumpAndSettle();
      expect(tester.getRect(list), viewport);
      if (reduced) {
        expect(tester.getRect(nav), navRect);
      } else {
        expect(tester.getRect(nav).top, greaterThan(844));
        await tester.tapAt(const Offset(180, 780));
        expect(taps, 1);
        scroll(-10);
        scroll(9);
        await tester.pumpAndSettle();
        expect(tester.getRect(nav).top, greaterThan(844));
        scroll(-20);
        await tester.pumpAndSettle();
        expect(tester.getRect(nav), navRect);
      }
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Row 49')).bottom, lessThan(navRect.top));
      await tester.tap(find.text('Row 49'));
      expect(taps, reduced ? 1 : 2);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.getRect(nav), navRect);
      expect(tester.takeException(), isNull);
    });
  }
}
