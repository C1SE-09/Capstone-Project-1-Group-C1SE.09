// frontend/lib/presentation/pages/login_page.dart
// =========================================================
// Màn hình đăng nhập (MVP): tạm thời có 2 nút để vào vai
// Teacher và Parent. Sau này thay bằng Firebase Auth thật.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / ảnh nền
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'lib/assets/images/background.jpg',
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'ADARK',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Quản lý báo cáo mầm non',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),

              // ── Login as Teacher ──────────────────────────
              FilledButton(
                // onPressed: () => context.go('/teacher'),
                onPressed: () => context.go('/teacher'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Đăng nhập Giáo viên'),
              ),
              const SizedBox(height: 12),

              // ── Login as Parent ───────────────────────────
              OutlinedButton(
                onPressed: () => context.go('/parent'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Đăng nhập Phụ huynh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
