import 'package:flutter/material.dart';

abstract final class KColors {
  static const canvas = Color(0xFFF6F4EF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFEFECE5);
  static const ink = Color(0xFF2A2926);
  static const inkSoft = Color(0xFF605D57);
  static const inkFaint = Color(0xFF8F8B83);
  static const line = Color(0xFFE7E3DA);
  static const lineStrong = Color(0xFFD9D4C9);
  static const brand = Color(0xFF16665A);
  static const brandStrong = Color(0xFF114F46);
  static const brandTint = Color(0xFFE6EFEC);
  static const ok = Color(0xFF3F8B5C);
  static const okTint = Color(0xFFE7F1EA);
  static const warn = Color(0xFFB0791B);
  static const warnDeep = Color(0xFF8A5E12);
  static const warnTint = Color(0xFFF6EED9);
  static const bad = Color(0xFFBB4A34);
  static const badTint = Color(0xFFF6E6E1);
  static const info = Color(0xFF4B6F8C);
  static const infoTint = Color(0xFFE7EEF3);
}

abstract final class KSpace {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
}

abstract final class KRadii {
  static const card = 12.0;
  static const control = 9.0;
}

ThemeData kinderTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KColors.brand,
    primary: KColors.brand,
    surface: KColors.surface,
    error: KColors.bad,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'BeVietnamPro',
    colorScheme: scheme,
    scaffoldBackgroundColor: KColors.canvas,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, height: 1.25, fontWeight: FontWeight.w700, color: KColors.ink),
      headlineMedium: TextStyle(fontSize: 22, height: 1.3, fontWeight: FontWeight.w700, color: KColors.ink),
      titleLarge: TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w600, color: KColors.ink),
      titleMedium: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: KColors.ink),
      bodyLarge: TextStyle(fontSize: 14, height: 1.5, color: KColors.ink),
      bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: KColors.inkSoft),
      bodySmall: TextStyle(fontSize: 12, height: 1.45, color: KColors.inkFaint),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: KColors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: KColors.line),
        borderRadius: BorderRadius.all(Radius.circular(KRadii.card)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: KColors.line, thickness: 1, space: 1),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: KColors.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: TextStyle(color: KColors.inkFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(KRadii.control)),
        borderSide: BorderSide(color: KColors.lineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(KRadii.control)),
        borderSide: BorderSide(color: KColors.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(KRadii.control)),
        borderSide: BorderSide(color: KColors.brand, width: 1.5),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: KColors.ink,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(color: Colors.white, fontFamily: 'BeVietnamPro'),
      shape: StadiumBorder(),
    ),
  );
}
