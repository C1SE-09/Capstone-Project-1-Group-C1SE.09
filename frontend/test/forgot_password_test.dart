import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/forgot_password_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class MockAuthRepository extends AuthRepository {
  @override
  Future<String> requestPasswordReset(String email) async {
    if (email == 'error@gmail.com') {
      throw const AuthException('Email không tồn tại trong hệ thống.');
    }
    return 'Mã xác thực đã được gửi.';
  }

  @override
  Future<String> verifyResetCode({
    required String email,
    required String resetCode,
  }) async {
    if (resetCode != '123456') {
      throw const AuthException('Mã xác thực không hợp lệ hoặc đã hết hạn.');
    }
    return 'Mã xác thực đã được xác nhận thành công.';
  }

  @override
  Future<String> resetPassword({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw const AuthException('Mật khẩu quá ngắn.');
    }
    return 'Đặt lại mật khẩu thành công!';
  }
}

void main() {
  testWidgets('ForgotPasswordScreen completes entire 3-step reset password flow',
      (WidgetTester tester) async {
    final mockRepo = MockAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: ForgotPasswordScreen(
          authRepository: mockRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // --- STEP 1: Verify Email input screen ---
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.text('GỬI MÃ XÁC THỰC'), findsOneWidget);

    // Enter email
    await tester.enterText(find.byType(TextField).first, 'parent@gmail.com');
    await tester.tap(find.text('GỬI MÃ XÁC THỰC'));
    await tester.pumpAndSettle();

    // --- STEP 2: Verify OTP input screen ---
    expect(find.text('Xác thực mã OTP'), findsOneWidget);
    expect(find.text('XÁC NHẬN MÃ OTP'), findsOneWidget);

    // Enter OTP
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.ensureVisible(find.text('XÁC NHẬN MÃ OTP'));
    await tester.tap(find.text('XÁC NHẬN MÃ OTP'));
    await tester.pumpAndSettle();

    // --- STEP 3: Verify New Password screen ---
    expect(find.text('Đặt mật khẩu mới'), findsOneWidget);
    expect(find.text('CẬP NHẬT MẬT KHẨU'), findsOneWidget);

    // Enter new password and confirmation
    await tester.enterText(find.byType(TextField).at(0), '12345678');
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.ensureVisible(find.text('CẬP NHẬT MẬT KHẨU'));
    await tester.tap(find.text('CẬP NHẬT MẬT KHẨU'));
    await tester.pumpAndSettle();

    // Verify Success Dialog is shown
    expect(find.text('Thành công'), findsOneWidget);
    expect(find.text('ĐĂNG NHẬP NGAY'), findsOneWidget);
  });
}
