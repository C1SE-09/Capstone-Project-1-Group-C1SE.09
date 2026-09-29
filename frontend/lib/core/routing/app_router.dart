import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/auth_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/login'),
    GoRoute(path: '/login', builder: (context, state) => const _LoginRoute()),
    GoRoute(path: '/class-select', builder: (context, state) => Scaffold(body: SafeArea(child: ClassSelectScreen(onPick: (classId) => appRouter.go(Uri(path: '/teacher', queryParameters: {'classId': classId}).toString()))))),
    GoRoute(path: '/teacher', builder: (context, state) => TeacherShell(onLogout: _goLogin, classId: state.uri.queryParameters['classId'] ?? 'aaaaaaaa-0000-0000-0000-000000000001')),
    GoRoute(path: '/parent', builder: (context, state) => const ParentFlow()),
  ],
);

void _goLogin() => appRouter.go('/login');

class _LoginRoute extends StatelessWidget {
  const _LoginRoute();

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: LoginScreen(
        onLogin: (role) => appRouter.go(role.name == 'teacher' ? '/class-select' : '/parent'),
      )));
}
