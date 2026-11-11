import 'dart:async';

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

class PendingAuthRepository extends MockAuthRepository {
  final request = Completer<String>();

  @override
  Future<String> requestPasswordReset(String email) => request.future;
}

void main() {
  testWidgets('forgot-password button communicates while email request loads',
      (WidgetTester tester) async {
    final repository = PendingAuthRepository();
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: ForgotPasswordScreen(authRepository: repository),
    ));
    await tester.enterText(find.byType(TextField).first, 'teacher@example.com');
    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pump();

    expect(find.text('Đang gửi mã...'), findsOneWidget);

    repository.request.complete('Mã xác thực đã được gửi.');
    await tester.pumpAndSettle();
  });

  testWidgets('forgot-password email input uses the live GV KInput tokens',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: ForgotPasswordScreen(authRepository: MockAuthRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(find.text('Đặt lại mật khẩu qua email'), findsOneWidget);
    expect(find.text('Bước 1/3 · Nhập email'), findsOneWidget);
    expect(find.text('Gửi mã xác nhận'), findsOneWidget);
    expect(find.text('Email đăng nhập'), findsOneWidget);
    expect(find.text('KinderLog'), findsNothing);
    final label = tester.widget<Text>(find.text('Email đăng nhập'));
    expect(label.style?.fontFamily, 'Nunito');
    expect(label.style?.fontSize, 14);
    expect(label.style?.fontWeight, FontWeight.w700);
    expect(label.style?.height, 1.4);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.style?.fontFamily, 'Nunito');
    expect(field.style?.fontSize, 14);
    expect(field.style?.height, 1.4);
    final decoration = field.decoration!;
    expect(decoration.filled, isTrue);
    expect(decoration.fillColor, Colors.white);
    expect(decoration.contentPadding,
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14));
    expect(tester.getSize(find.byType(InputDecorator).first).height, 48);
    final border = decoration.enabledBorder! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(14));
    expect(border.borderSide.color, const Color(0xFFC7DEDA));
  });

  testWidgets(
      'Garden Voice forgot-password step scrolls at 320dp and 200% text',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ForgotPasswordScreen(authRepository: MockAuthRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bước 1/3 · Nhập email'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ForgotPasswordScreen completes entire 3-step reset password flow',
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
    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(find.text('Gửi mã xác nhận'), findsOneWidget);

    // Enter email
    await tester.enterText(find.byType(TextField).first, 'parent@gmail.com');
    await tester.tap(find.text('Gửi mã xác nhận'));
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
