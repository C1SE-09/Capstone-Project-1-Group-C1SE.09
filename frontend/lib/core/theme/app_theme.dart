// frontend/lib/core/theme/app_theme.dart
// =========================================================
// Theme + bảng màu thiết kế (design tokens) lấy từ Figma.
//
// Khác với approach "constants rời" trước đây: giờ màu được
// GẮN vào ThemeData, nên View chỉ cần dùng Theme.of(context),
// không cần import hàng loạt hằng số màu.

import 'package:flutter/material.dart';

/// Bảng màu thiết kế từ Figma (chỉ dùng khi cần màu chính xác,
/// còn lại dùng ColorScheme từ ThemeData).
class AppColors {
  AppColors._(); // không cho khởi tạo

  static const Color primary = Color(0xFF16665A); // xanh chủ đạo
  static const Color primaryLight = Color(0xFFE6EFEC); // xanh nhạt (nền avatar/banner)
  static const Color background = Color(0xFFF6F4EF); // nền toàn màn (kem)
  static const Color surface = Color(0xFFFFFFFF); // card trắng
  static const Color surfaceAlt = Color(0xFFEFECE5); // nền icon circle
  static const Color divider = Color(0xFFE4E1DA); // đường kẻ

  static const Color textPrimary = Color(0xFF2A2926); // chữ đen đậm
  static const Color textSecondary = Color(0xFF605D57); // chữ xám
  static const Color textTertiary = Color(0xFF8F8B83); // chữ xám nhạt

  static const Color warningBg = Color(0xFFF6EED9); // nền badge "Bản nháp"
  static const Color warningFg = Color(0xFFB0791B); // chữ badge vàng
}

/// ThemeData của app (light + dark).
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return _base(Brightness.light);
  }

  static ThemeData dark() {
    return _base(Brightness.dark);
  }

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          brightness == Brightness.light ? AppColors.background : null,
    );
  }
}