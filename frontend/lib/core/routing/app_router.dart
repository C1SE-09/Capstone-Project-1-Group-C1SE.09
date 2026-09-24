// frontend/lib/core/routing/app_router.dart
// =========================================================
// GoRouter cấu hình toàn bộ điều hướng của app.

import 'package:adark_frontend/presentation/teacher/pages/class_detail_screen.dart';
import 'package:adark_frontend/presentation/auth/login_page.dart';
import 'package:adark_frontend/presentation/teacher/pages/activity_recording_screen.dart';
import 'package:adark_frontend/presentation/teacher/pages/teacher_bottom_navigation.dart';
import 'package:adark_frontend/presentation/parent/pages/parent_screen.dart';
import 'package:adark_frontend/presentation/recording/pages/extraction_results_screen.dart';
import 'package:adark_frontend/presentation/recording/pages/recording_screen.dart';
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
      GoRoute(
        path: '/teacher',
        builder: (context, state) => const TeacherBottomNavigation(initialIndex: 0),
      ),
      GoRoute(
          path: '/parent', builder: (context, state) => const ParentScreen()),
      // Chi tiết lớp (MÀN 2) — nhận classId qua `extra`
      GoRoute(
        path: '/class-detail',
        builder: (context, state) {
          final classId = state.extra as String? ?? 'aaaaaaaa-0000-0000-0000-000000000001';
          return ClassDetailScreen(classId: classId);
        },
      ),

      // ── Backend-related screens ──────────────────────────────
      GoRoute(
        path: '/recording',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return RecordingScreen(
            filePath: params['filePath'] ?? '',
            classId: params['classId'] ?? '',
            teacherId: params['teacherId'] ?? '',
            childId: params['childId'],
          );
        },
      ),
      GoRoute(
        path: '/teacher/activity-recording',
        builder: (context, state) {
          final classId = state.uri.queryParameters['classId'] ??
              'aaaaaaaa-0000-0000-0000-000000000001';
          return ActivityRecordingScreen(classId: classId);
        },
      ),
      GoRoute(
        path: '/extraction-results',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return ExtractionResultsScreen(
            voiceId: params['voiceId'] ?? '',
            teacherId: params['teacherId'] ?? '',
            childId: params['childId'],
            childName: params['childName'],
            childInitials: params['childInitials'],
            classTeacherInfo: params['classTeacherInfo'],
          );
        },
      ),

      // ── Các màn hình mới (TranscriptReviewScreen, ReportProcessingScreen)
      // được điều hướng qua Navigator.push do nhận Child object trực tiếp.
      // Không cần GoRoute riêng cho chúng.
    ],
  );
}
