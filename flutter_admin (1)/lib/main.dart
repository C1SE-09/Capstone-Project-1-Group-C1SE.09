import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_dashboard.dart';
import 'app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const KinderLogAdminApp());
}

class KinderLogAdminApp extends StatefulWidget {
  const KinderLogAdminApp({super.key});

  @override
  State<KinderLogAdminApp> createState() => _KinderLogAdminAppState();
}

class _KinderLogAdminAppState extends State<KinderLogAdminApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KinderLog Admin',
      theme: kinderTheme(Brightness.light),
      darkTheme: kinderTheme(Brightness.dark),
      themeMode: _themeMode,
      home: AdminDashboard(
        darkMode: _themeMode == ThemeMode.dark,
        onThemeChanged: (dark) => setState(
          () => _themeMode = dark ? ThemeMode.dark : ThemeMode.light,
        ),
      ),
    );
  }
}
