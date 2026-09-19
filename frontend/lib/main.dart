import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/data/notifiers.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, _) {
        return MaterialApp.router(
          routerConfig: AppRouter.router,
          debugShowCheckedModeBanner: false,
          // Dùng theme tập trung (màu Figma) thay vì khai báo trực tiếp
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        );
      },
    );
  }
}
