import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme_controller.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance,
        builder: (context, mode, _) => MaterialApp.router(
          routerConfig: appRouter,
          theme: kinderTheme(),
          darkTheme: kinderThemeDark(),
          themeMode: mode,
          debugShowCheckedModeBanner: false,
        ),
      );
}
