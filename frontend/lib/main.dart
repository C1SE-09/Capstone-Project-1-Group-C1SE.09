import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  // Chỉ khôi phục phiên còn trong hạn 1 giờ trước khi dựng giao diện.
  await SessionManagementService.instance.loadPersistedSession();
  // Phiên hết hạn hẳn (server từ chối refresh) -> về màn đăng nhập, thay vì để
  // màn hình hiện lỗi mà người dùng không biết phải làm gì.
  SessionManagementService.onSessionExpiredGlobally = () {
    AuthRepository.currentUser = null;
    appRouter.go('/login');
  };
  // Khởi tạo Firebase cho push notification. Bọc try/catch để app vẫn chạy
  // khi chưa có google-services.json hoặc trên nền tảng không hỗ trợ.
  try {
    await Firebase.initializeApp();
    await PushNotificationService.instance.init();
  } catch (error) {
    debugPrint('Firebase init skipped: $error');
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLifecycleListener _lifecycleListener;
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    _lifecycleListener =
        AppLifecycleListener(onStateChange: _onLifecycleChanged);
  }

  Future<void> _onLifecycleChanged(AppLifecycleState state) async {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      final service = SessionManagementService.instance;
      if (await service.expireSessionIfNeeded() &&
          service.currentSession == null &&
          mounted) {
        AuthRepository.currentUser = null;
        appRouter.go('/login');
      }
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance,
        builder: (context, mode, _) => MaterialApp.router(
          routerConfig: appRouter,
          theme: kinderTheme(),
          darkTheme: kinderThemeDark(),
          themeMode: mode,
          scaffoldMessengerKey: PushNotificationService.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
        ),
      );
}
