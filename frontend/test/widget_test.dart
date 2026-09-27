import 'package:flutter_test/flutter_test.dart';
import 'package:adark_frontend/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('KinderLog'), findsOneWidget);
  });
}

