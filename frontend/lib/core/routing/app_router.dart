// frontend/lib/core/routing/app_router.dart
// =========================================================
// GoRouter cấu hình toàn bộ điều hướng của app.
//
// (Sẽ thêm route /teacher và /parent ở bước cuối,
//  sau khi xây xong 2 màn hình tương ứng.)

import 'package:adark_frontend/presentation/pages/class_detail_screen.dart';
import 'package:adark_frontend/presentation/pages/login_page.dart';
import 'package:adark_frontend/presentation/pages/parent_screen.dart';
import 'package:adark_frontend/presentation/pages/teacher_screen.dart';
import 'package:adark_frontend/presentation/screens/extraction_results_screen.dart';
import 'package:adark_frontend/presentation/screens/recording_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

class AppRouter {
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      // ── Auth ────────────────────────────────────────────────
      GoRoute(path: '/', redirect: (context, state) => '/login'),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

      // ── Teacher & Parent (FIGMA UI) ─────────────────────────
      GoRoute(path: '/teacher', builder: (context, state) => const TeacherScreen()),
      GoRoute(path: '/parent', builder: (context, state) => const ParentScreen()),

      // Chi tiết lớp (MÀN 2) — nhận classId qua `extra`
      GoRoute(
        path: '/class-detail',
        builder: (context, state) {
          final classId = state.extra as String? ?? 'class-001';
          return ClassDetailScreen(classId: classId);
        },
      ),

      // ── Backend-related screens (giữ nguyên) ────────────────
      GoRoute(
        path: '/recording',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return RecordingScreen(
            filePath: params['filePath'] ?? '',
            classId: params['classId'] ?? '',
            teacherId: params['teacherId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/extraction-results',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return ExtractionResultsScreen(
            voiceId: params['voiceId'] ?? '',
            teacherId: params['teacherId'] ?? '',
          );
        },
      ),
    ],
  );
}