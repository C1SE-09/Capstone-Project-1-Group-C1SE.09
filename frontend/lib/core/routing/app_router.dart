import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/admin_dashboard_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/auth_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/change_password_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_shell.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/timetable_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/ui_types.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Màn hình mở đầu khi app khởi động (AC1): máy còn phiên thì vào thẳng đúng
/// màn theo vai trò, không thì về đăng nhập.
String initialRouteFor(AppSession? session) {
  if (session == null) return '/login';
  if (session.role == 'teacher') return '/class-select';
  if (session.role == 'parent') return '/parent';
  if (session.role == 'admin') return '/admin';
  return '/login';
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  redirect: (context, state) {
    final isPublicRoute = state.uri.path == '/login' || state.uri.path == '/forgot-password';
    if (!isPublicRoute && !SessionManagementService.instance.isLoggedIn) return '/login';
    return null;
  },
  // Đọc phiên đã nạp từ main() — top-level final nên chỉ chạy lần đầu appRouter
  // được đọc, tức sau khi loadPersistedSession() xong.
  initialLocation: initialRouteFor(
    SessionManagementService.instance.currentSession,
  ),
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/login'),
    GoRoute(path: '/login', builder: (context, state) => const _LoginRoute()),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => ForgotPasswordScreen(
        onBackToLogin: () => appRouter.go('/login'),
      ),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => AdminDashboardScreen(
        onLogout: _goLogin,
        username: AuthRepository.currentUser?.username,
      ),
    ),
    GoRoute(
        path: '/class-select',
        builder: (context, state) => Scaffold(
            body: SafeArea(
                child: ClassSelectScreen(
                    onPick: (classId) => appRouter.go(Uri(
                        path: '/teacher',
                        queryParameters: {'classId': classId}).toString()))))),
    GoRoute(
        path: '/teacher',
        pageBuilder: (context, state) => NoTransitionPage(
          key: ValueKey(state.uri.toString()),
          child: TeacherShell(
            onLogout: _goLogin,
            classId: state.uri.queryParameters['classId'] ??
                'aaaaaaaa-0000-0000-0000-000000000001',
            initialAttendanceDate: state.uri.queryParameters['attendanceDate'],
            notificationId: state.uri.queryParameters['notification'],
          ),
        )),
    GoRoute(
      path: '/timetable',
      builder: (context, state) => TimetableScreen(
        classId: state.uri.queryParameters['classId'] ??
            'aaaaaaaa-0000-0000-0000-000000000001',
        className: state.uri.queryParameters['className'] ?? 'Lớp học',
        isReadOnly: state.uri.queryParameters['isReadOnly'] == 'true',
      ),
    ),
    GoRoute(
      path: '/parent',
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.toString()),
        child: ParentFlow(
          onLogout: _goLogin,
          initialOpenReport: state.uri.queryParameters['report'] == 'today',
          initialReportId: state.uri.queryParameters['reportId'],
          childId: state.uri.queryParameters['childId'],
          initialAttendanceDate: state.uri.queryParameters['attendanceDate'],
          notificationId: state.uri.queryParameters['notification'],
        ),
      ),
    ),
    GoRoute(
        path: '/change-password',
        builder: (context, state) =>
            ChangePasswordScreen(onBack: () => appRouter.pop())),

    // ══════════════════════════════════════════════════════════
    // Bug Report feature (TASK: F-05)
    // TODO bạn của tôi: thay _PendingScreen(...) bằng screen thật
    // khi đã tạo file trong features/bug_report/screens/.
    //
    // User (teacher/parent) chỉ CẦN gửi bug — không xem lại.
    // Admin xem + xử lý tất cả bug.
    // ══════════════════════════════════════════════════════════
    // 1. Form báo cáo mới (user: teacher/parent)
    GoRoute(
      path: '/bug-report/new',
      builder: (context, state) => const _PendingScreen(
        label: 'Bug Report Form — TODO: thay bằng BugReportFormScreen()',
      ),
    ),
    // 2. Danh sách tất cả báo cáo (admin only — guard ở screen level)
    GoRoute(
      path: '/admin/bug-reports',
      builder: (context, state) => const _PendingScreen(
        label: 'Admin Bug Reports — TODO: thay bằng AdminReportsListScreen()',
      ),
    ),
    // 3. Chi tiết 1 báo cáo (admin only)
    GoRoute(
      path: '/admin/bug-reports/:id',
      builder: (context, state) => _PendingScreen(
        label:
            'Admin Bug Report Detail — TODO: thay bằng AdminReportDetailScreen(id: ${state.pathParameters['id']})',
      ),
    ),
  ],
);

Future<void> _goLogin() async {
  // Xoá device token TRƯỚC khi logout để request còn JWT hợp lệ.
  await PushNotificationService.instance.deleteCurrentDevice();
  // Logout trước khi xoá phiên local: request logout cần token để server revoke.
  await AuthRepository().logout();
  await SessionManagementService.instance.clearSession();
  appRouter.go('/login');
}

class _LoginRoute extends StatelessWidget {
  const _LoginRoute();

  @override
  Widget build(BuildContext context) => LoginScreen(
        onLogin: (role) {
          final target = PushNotificationService.instance.pendingLocationFor(role.name);
          if (target != null) {
            appRouter.go(target);
            return;
          }
          switch (role) {
            case UserRole.admin:
              appRouter.go('/admin');
              break;
            case UserRole.parent:
              appRouter.go('/parent');
              break;
            case UserRole.teacher:
              appRouter.go('/teacher');
              break;
          }
        },
        onForgotPassword: () => appRouter.push('/forgot-password'),
      );
}

/// Placeholder widget cho 3 route bug report mới.
/// Bạn của tôi: tìm và replace `_PendingScreen(...)` bằng screen thật.
class _PendingScreen extends StatelessWidget {
  const _PendingScreen({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coming soon')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
