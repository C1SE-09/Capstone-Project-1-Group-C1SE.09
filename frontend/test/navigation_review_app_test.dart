import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_navigation.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/navigation_review_app.dart';

void main() {
  testWidgets('Android preview switches role and theme without a backend',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const NavigationReviewApp());
    await tester.pumpAndSettle();
    expect(find.byType(GardenVoiceTeacherNavigation), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pumpAndSettle();
    expect(find.byType(GardenVoiceParentNavigation), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(
        Theme.of(tester.element(find.byType(GardenVoiceParentNavigation)))
            .brightness,
        Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
