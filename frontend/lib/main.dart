import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';

final ThemeData appTheme = kinderTheme();


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        routerConfig: appRouter,
        theme: appTheme,
        debugShowCheckedModeBanner: false,
      );
}
