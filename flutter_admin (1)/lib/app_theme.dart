import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand = Color(0xFF1F7A68);
  static const brandStrong = Color(0xFF176454);
  static const brandTint = Color(0xFFE7F4F0);
  static const warning = Color(0xFFD99A2B);
  static const warningTint = Color(0xFFFFF4D8);
  static const danger = Color(0xFFC94F56);
  static const dangerTint = Color(0xFFFFECEC);
  static const success = Color(0xFF2D8A60);
  static const successTint = Color(0xFFE8F6EE);
  static const info = Color(0xFF4578B5);
}

ThemeData kinderTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: brightness,
    primary: dark ? const Color(0xFF77CFB9) : AppColors.brand,
    error: dark ? const Color(0xFFFFB3B5) : AppColors.danger,
    surface: dark ? const Color(0xFF19211F) : Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF101614) : const Color(0xFFF7F9F8),
    dividerColor: dark ? const Color(0xFF303B38) : const Color(0xFFE3E9E6),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: dark ? const Color(0xFF303B38) : const Color(0xFFE3E9E6),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? Colors.white12 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? Colors.white12 : Colors.black12),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      indicatorColor: dark
          ? AppColors.brand.withAlpha(61)
          : AppColors.brandTint,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight:
              states.contains(WidgetState.selected) ? FontWeight.w700 : null,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
