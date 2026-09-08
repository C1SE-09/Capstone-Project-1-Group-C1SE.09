import 'package:adark_frontend/presentation/layouts/main_layout.dart';
import 'package:adark_frontend/presentation/pages/admin_dashboard.dart';
import 'package:adark_frontend/presentation/pages/home_page.dart';
import 'package:adark_frontend/presentation/pages/login_page.dart';
import 'package:adark_frontend/presentation/pages/parent_dashboard.dart';
import 'package:adark_frontend/presentation/pages/profile_page.dart';
import 'package:adark_frontend/presentation/pages/teacher_dashboard.dart';
import 'package:adark_frontend/presentation/screens/recording_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/pages/setting_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

class AppRouter {
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/login'),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainLayout(child: child);
        },
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/teacher',
            builder: (context, state) => const TeacherDashboard(),
          ),
          GoRoute(
            path: '/parent',
            builder: (context, state) => const ParentDashboard(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboard(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingPage(),
          ),
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
        ],
      ),
    ],
  );
}
