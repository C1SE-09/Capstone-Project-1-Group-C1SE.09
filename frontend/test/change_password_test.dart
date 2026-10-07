import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/change_password_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({this.shouldFail = false, this.errorMessage});

  bool shouldFail;
  String? errorMessage;
  bool changePasswordCalled = false;
  String? lastCurrentPassword;
  String? lastNewPassword;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalled = true;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;

    if (shouldFail) {
      throw AuthException(errorMessage ?? 'Mật khẩu hiện tại không chính xác.');
    }
  }
}

void main() {
  late FakeAuthRepository fakeAuthRepo;

  setUp(() {
    fakeAuthRepo = FakeAuthRepository();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('ChangePasswordScreen renders correctly with 3 password fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        ChangePasswordScreen(authRepository: fakeAuthRepo),
      ),
    );

    expect(find.text('Đổi mật khẩu'), findsNWidgets(2)); // AppBar + Button
    expect(find.text('Mật khẩu hiện tại'), findsOneWidget);
    expect(find.text('Mật khẩu mới'), findsOneWidget);
    expect(find.text('Xác nhận mật khẩu mới'), findsOneWidget);
  });

  testWidgets('Displays validation errors when submitting empty form',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        ChangePasswordScreen(authRepository: fakeAuthRepo),
      ),
    );

    final submitBtn = find.widgetWithText(KButton, 'Đổi mật khẩu');
    expect(submitBtn, findsOneWidget);

    await tester.tap(submitBtn);
    await tester.pump();

    expect(find.text('Vui lòng nhập mật khẩu hiện tại.'), findsOneWidget);
  });

  testWidgets('Displays error when confirm password does not match new password',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        ChangePasswordScreen(authRepository: fakeAuthRepo),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'oldpass123');
    await tester.enterText(fields.at(1), 'newpass123');
    await tester.enterText(fields.at(2), 'mismatchpass');

    final submitBtn = find.widgetWithText(KButton, 'Đổi mật khẩu');
    await tester.tap(submitBtn);
    await tester.pump();

    expect(find.text('Mật khẩu xác nhận không trùng khớp.'), findsOneWidget);
  });

  testWidgets('Calls changePassword on AuthRepository when form is valid',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        ChangePasswordScreen(authRepository: fakeAuthRepo),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'oldpass123');
    await tester.enterText(fields.at(1), 'newpass456');
    await tester.enterText(fields.at(2), 'newpass456');

    final submitBtn = find.widgetWithText(KButton, 'Đổi mật khẩu');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(fakeAuthRepo.changePasswordCalled, isTrue);
    expect(fakeAuthRepo.lastCurrentPassword, 'oldpass123');
    expect(fakeAuthRepo.lastNewPassword, 'newpass456');
    expect(find.text('Đổi mật khẩu thành công!'), findsOneWidget);
  });
}
