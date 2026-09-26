// frontend/lib/presentation/auth/login_page.dart
// =========================================================
// Màn hình đăng nhập (MVP): tạm thời có 2 nút để vào vai
// Teacher và Parent. Sau này thay bằng Firebase Auth thật.

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.appName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.appSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),

              // ── Login as Teacher ──────────────────────────
              FilledButton(
                onPressed: () => context.go('/teacher'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(l10n.loginAsTeacher),
              ),
              const SizedBox(height: 12),

              // ── Login as Parent ───────────────────────────
              OutlinedButton(
                onPressed: () => context.go('/parent'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(l10n.loginAsParent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
