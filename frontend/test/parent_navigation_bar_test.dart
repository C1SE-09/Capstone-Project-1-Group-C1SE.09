import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/parent_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await fonts.load();
  });
  testWidgets('thanh tab không cắt nhãn khi chữ lớn ở 320', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
          bottomNavigationBar: ParentNavigationBar(
        selectedIndex: 0,
        onSelected: (_) {},
        unreadCount: 1,
      )),
    ));
    await tester.pumpAndSettle();
    final bar =
        tester.getRect(find.byKey(const ValueKey('parent-bottom-navigation')));
    for (final label in ['Tổng quan', 'Tài khoản']) {
      final text = tester.getRect(find.text(label));
      expect(text.top, greaterThanOrEqualTo(bar.top));
      expect(text.bottom, lessThanOrEqualTo(bar.bottom));
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.getMaxIntrinsicHeight(paragraph.size.width),
          lessThanOrEqualTo(paragraph.size.height + .01));
    }
    expect(tester.takeException(), isNull);
  });
}
