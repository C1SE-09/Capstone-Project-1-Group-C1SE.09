import 'package:flutter/material.dart';

abstract final class KColors {
  // Light theme colors
  static const canvas = Color(0xFFF6F4EF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFEFECE5);
  static const ink = Color(0xFF2A2926);
  static const inkSoft = Color(0xFF605D57);
  static const inkFaint = Color(0xFF757169); // Darkened for WCAG AA contrast
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

  // Dark theme colors
  static const canvasDark = Color(0xFF1C1B1A);
  static const surfaceDark = Color(0xFF252422);
  static const surfaceSunkenDark = Color(0xFF2D2C29);
  static const inkDark = Color(0xFFE8E6E1);
  static const inkSoftDark = Color(0xFFC4C2BC);
  static const inkFaintDark = Color(0xFF9A9891);
  static const lineDark = Color(0xFF3E3D3A);
  static const lineStrongDark = Color(0xFF4E4D49);
  static const brandDark = Color(0xFF52BBA8);
  static const brandStrongDark = Color(0xFF6DD4C0);
  static const brandTintDark = Color(0xFF1E3833);
  static const okDark = Color(0xFF6FCF8E);
  static const okTintDark = Color(0xFF1E3328);
  static const warnDark = Color(0xFFE5B05C);
  static const warnDeepDark = Color(0xFFF5C878);
  static const warnTintDark = Color(0xFF3A2F1A);
  static const badDark = Color(0xFFE87B63);
  static const badTintDark = Color(0xFF3A2621);
  static const infoDark = Color(0xFF7BA3C7);
  static const infoTintDark = Color(0xFF1F2D3A);
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

/// Theme-aware design tokens. Widgets read these via `context.k` so light and
/// dark themes resolve automatically. Registered on each ThemeData below.
class KPalette extends ThemeExtension<KPalette> {
  const KPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceSunken,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.lineStrong,
    required this.brand,
    required this.brandStrong,
    required this.brandTint,
    required this.ok,
    required this.okTint,
    required this.warn,
    required this.warnDeep,
    required this.warnTint,
    required this.bad,
    required this.badTint,
    required this.info,
    required this.infoTint,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceSunken;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color line;
  final Color lineStrong;
  final Color brand;
  final Color brandStrong;
  final Color brandTint;
  final Color ok;
  final Color okTint;
  final Color warn;
  final Color warnDeep;
  final Color warnTint;
  final Color bad;
  final Color badTint;
  final Color info;
  final Color infoTint;

  static const light = KPalette(
    canvas: KColors.canvas,
    surface: KColors.surface,
    surfaceSunken: KColors.surfaceSunken,
    ink: KColors.ink,
    inkSoft: KColors.inkSoft,
    inkFaint: KColors.inkFaint,
    line: KColors.line,
    lineStrong: KColors.lineStrong,
    brand: KColors.brand,
    brandStrong: KColors.brandStrong,
    brandTint: KColors.brandTint,
    ok: KColors.ok,
    okTint: KColors.okTint,
    warn: KColors.warn,
    warnDeep: KColors.warnDeep,
    warnTint: KColors.warnTint,
    bad: KColors.bad,
    badTint: KColors.badTint,
    info: KColors.info,
    infoTint: KColors.infoTint,
  );

  static const dark = KPalette(
    canvas: KColors.canvasDark,
    surface: KColors.surfaceDark,
    surfaceSunken: KColors.surfaceSunkenDark,
    ink: KColors.inkDark,
    inkSoft: KColors.inkSoftDark,
    inkFaint: KColors.inkFaintDark,
    line: KColors.lineDark,
    lineStrong: KColors.lineStrongDark,
    brand: KColors.brandDark,
    brandStrong: KColors.brandStrongDark,
    brandTint: KColors.brandTintDark,
    ok: KColors.okDark,
    okTint: KColors.okTintDark,
    warn: KColors.warnDark,
    warnDeep: KColors.warnDeepDark,
    warnTint: KColors.warnTintDark,
    bad: KColors.badDark,
    badTint: KColors.badTintDark,
    info: KColors.infoDark,
    infoTint: KColors.infoTintDark,
  );

  @override
  KPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceSunken,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? line,
    Color? lineStrong,
    Color? brand,
    Color? brandStrong,
    Color? brandTint,
    Color? ok,
    Color? okTint,
    Color? warn,
    Color? warnDeep,
    Color? warnTint,
    Color? bad,
    Color? badTint,
    Color? info,
    Color? infoTint,
  }) {
    return KPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      brandTint: brandTint ?? this.brandTint,
      ok: ok ?? this.ok,
      okTint: okTint ?? this.okTint,
      warn: warn ?? this.warn,
      warnDeep: warnDeep ?? this.warnDeep,
      warnTint: warnTint ?? this.warnTint,
      bad: bad ?? this.bad,
      badTint: badTint ?? this.badTint,
      info: info ?? this.info,
      infoTint: infoTint ?? this.infoTint,
    );
  }

  @override
  KPalette lerp(ThemeExtension<KPalette>? other, double t) {
    if (other is! KPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return KPalette(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceSunken: mix(surfaceSunken, other.surfaceSunken),
      ink: mix(ink, other.ink),
      inkSoft: mix(inkSoft, other.inkSoft),
      inkFaint: mix(inkFaint, other.inkFaint),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      brand: mix(brand, other.brand),
      brandStrong: mix(brandStrong, other.brandStrong),
      brandTint: mix(brandTint, other.brandTint),
      ok: mix(ok, other.ok),
      okTint: mix(okTint, other.okTint),
      warn: mix(warn, other.warn),
      warnDeep: mix(warnDeep, other.warnDeep),
      warnTint: mix(warnTint, other.warnTint),
      bad: mix(bad, other.bad),
      badTint: mix(badTint, other.badTint),
      info: mix(info, other.info),
      infoTint: mix(infoTint, other.infoTint),
    );
  }
}

/// Reads the active palette from the widget tree: `context.k.brand`.
extension KThemeContext on BuildContext {
  KPalette get k => Theme.of(this).extension<KPalette>() ?? KPalette.light;
}

ThemeData kinderTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KColors.brand,
    primary: KColors.brand,
    surface: KColors.surface,
    error: KColors.bad,
  );
  return _buildTheme(scheme: scheme, palette: KPalette.light);
}

ThemeData kinderThemeDark() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KColors.brandDark,
    brightness: Brightness.dark,
    primary: KColors.brandDark,
    surface: KColors.surfaceDark,
    error: KColors.badDark,
  );
  return _buildTheme(scheme: scheme, palette: KPalette.dark);
}

ThemeData _buildTheme({required ColorScheme scheme, required KPalette palette}) {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'BeVietnamPro',
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.canvas,
    extensions: [palette],
    textTheme: TextTheme(
      headlineLarge: TextStyle(height: 1.25, fontWeight: FontWeight.w700, color: palette.ink),
      headlineMedium: TextStyle(height: 1.3, fontWeight: FontWeight.w700, color: palette.ink),
      titleLarge: TextStyle(height: 1.35, fontWeight: FontWeight.w600, color: palette.ink),
      titleMedium: TextStyle(height: 1.4, fontWeight: FontWeight.w600, color: palette.ink),
      bodyLarge: TextStyle(height: 1.5, color: palette.ink),
      bodyMedium: TextStyle(height: 1.5, color: palette.inkSoft),
      bodySmall: TextStyle(height: 1.45, color: palette.inkFaint),
      labelLarge: const TextStyle(fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: palette.line),
        borderRadius: const BorderRadius.all(Radius.circular(KRadii.card)),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: palette.inkFaint, height: 1.2),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(KRadii.control)),
        borderSide: BorderSide(color: palette.lineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(KRadii.control)),
        borderSide: BorderSide(color: palette.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(KRadii.control)),
        borderSide: BorderSide(color: palette.brand, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.ink,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(color: palette.surface, fontFamily: 'BeVietnamPro'),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );
}
