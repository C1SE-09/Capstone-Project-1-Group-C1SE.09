import 'package:flutter/material.dart';

abstract final class KColors {
  // Light theme colors
  static const canvas = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFF2F4F7);
  static const ink = Color(0xFF182230);
  static const inkSoft = Color(0xFF526070);
  static const inkFaint = Color(
      0xFF667085); // Darkened for WCAG AA contrast (Figma muted 0xFF98A2B3 is decoration-only)
  static const line = Color(0xFFE4E7EC);
  static const lineStrong = Color(0xFF98A2B3);
  static const brand = Color(0xFF3A6BC9);
  static const brandStrong = Color(0xFF33539F);
  static const brandTint = Color(0xFFEDF2FC);
  static const ok = Color(0xFF3F8B5C);
  static const okTint = Color(0xFFE7F6EE);
  static const warn = Color(0xFFB0791B);
  static const warnDeep = Color(0xFF8A5E12);
  static const warnTint = Color(0xFFF6EED9);
  static const bad = Color(0xFFBB4A34);
  static const badTint = Color(0xFFFDECE8);
  static const accent = Color(0xFFF2A93B);
  static const accentDeep = Color(0xFF8A5A00);
  static const accentTint = Color(0xFFFFF6E0);
  static const info = Color(0xFF4B6F8C);
  static const infoTint = Color(0xFFE7EEF3);

  // Dark theme colors
  static const canvasDark =
      Color(0xFF16191D); // A2 dark: proposed, no Figma dark yet
  static const surfaceDark = Color(0xFF212429); // proposed
  static const surfaceSunkenDark = Color(0xFF2A2E35); // proposed
  static const inkDark = Color(0xFFE8EAED); // proposed
  static const inkSoftDark = Color(0xFFC2C7CF); // proposed
  static const inkFaintDark = Color(0xFF9AA1AB); // proposed
  static const lineDark = Color(0xFF33373F); // proposed
  static const lineStrongDark = Color(0xFF474C55); // proposed
  static const brandDark = Color(0xFF7AA5E8); // proposed
  static const brandStrongDark = Color(0xFF9DB9EC); // proposed
  static const brandTintDark = Color(0xFF1E2A44); // proposed
  static const okDark = Color(0xFF6FCF8E);
  static const okTintDark = Color(0xFF1E3328);
  static const warnDark = Color(0xFFE5B05C);
  static const warnDeepDark = Color(0xFFF5C878);
  static const warnTintDark = Color(0xFF3A2F1A);
  static const badDark = Color(0xFFE87B63);
  static const badTintDark = Color(0xFF3A2621);
  static const infoDark = Color(0xFF7BA3C7);
  static const infoTintDark = Color(0xFF1F2D3A);
  static const accentDark = Color(0xFFF2B950); // proposed
  static const accentDeepDark = Color(0xFFF5C878); // proposed
  static const accentTintDark = Color(0xFF3A2F1A); // proposed
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
  static const control = 8.0;
}

/// Theme-aware design tokens. Widgets read these via `context.k` so light and
/// dark themes resolve automatically. Registered on each ThemeData below.
class KPalette extends ThemeExtension<KPalette> {
  const KPalette({
    required this.canvas,
    required this.surface,
    required this.reviewSurface,
    required this.surfaceSunken,
    required this.foodRowTint,
    required this.foodRowText,
    required this.sleepRowTint,
    required this.sleepRowText,
    required this.activityRowTint,
    required this.activityRowText,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.lineStrong,
    required this.inputBorder,
    required this.brand,
    required this.brandStrong,
    required this.brandTint,
    required this.accent,
    required this.accentDeep,
    required this.accentTint,
    required this.ok,
    required this.okDot,
    required this.okTint,
    required this.warn,
    required this.warnDot,
    required this.warnDeep,
    required this.warnTint,
    required this.bad,
    required this.badText,
    required this.badTint,
    required this.info,
    required this.infoDot,
    required this.infoTint,
    required this.buttonHeight,
    required this.buttonRadius,
    required this.isGardenVoice,
  });

  final Color canvas;
  final Color surface;
  final Color reviewSurface;
  final Color surfaceSunken;
  final Color foodRowTint;
  final Color foodRowText;
  final Color sleepRowTint;
  final Color sleepRowText;
  final Color activityRowTint;
  final Color activityRowText;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color line;
  final Color lineStrong;
  final Color inputBorder;
  final Color brand;
  final Color brandStrong;
  final Color brandTint;
  final Color accent;
  final Color accentDeep;
  final Color accentTint;
  final Color ok;
  final Color okDot;
  final Color okTint;
  final Color warn;
  final Color warnDot;
  final Color warnDeep;
  final Color warnTint;
  final Color bad;
  final Color badText;
  final Color badTint;
  final Color info;
  final Color infoDot;
  final Color infoTint;
  final double buttonHeight;
  final double buttonRadius;
  final bool isGardenVoice;

  static const light = KPalette(
    canvas: KColors.canvas,
    surface: KColors.surface,
    reviewSurface: KColors.surface,
    surfaceSunken: KColors.surfaceSunken,
    foodRowTint: KColors.accentTint,
    foodRowText: KColors.accentDeep,
    sleepRowTint: KColors.brandTint,
    sleepRowText: KColors.brandStrong,
    activityRowTint: KColors.infoTint,
    activityRowText: KColors.info,
    ink: KColors.ink,
    inkSoft: KColors.inkSoft,
    inkFaint: KColors.inkFaint,
    line: KColors.line,
    lineStrong: KColors.lineStrong,
    inputBorder: KColors.lineStrong,
    brand: KColors.brand,
    brandStrong: KColors.brandStrong,
    brandTint: KColors.brandTint,
    accent: KColors.accent,
    accentDeep: KColors.accentDeep,
    accentTint: KColors.accentTint,
    ok: KColors.ok,
    okDot: KColors.ok,
    okTint: KColors.okTint,
    warn: KColors.warn,
    warnDot: KColors.warn,
    warnDeep: KColors.warnDeep,
    warnTint: KColors.warnTint,
    bad: KColors.bad,
    badText: KColors.bad,
    badTint: KColors.badTint,
    info: KColors.info,
    infoDot: KColors.info,
    infoTint: KColors.infoTint,
    buttonHeight: 44,
    buttonRadius: KRadii.control,
    isGardenVoice: false,
  );

  static final loginWarmSage = light.copyWith(
    canvas: const Color(0xFFF5F4F0),
    reviewSurface: const Color(0xFFF7FBFA),
    surfaceSunken: const Color(0xFFF1F7F8),
    ink: const Color(0xFF24313D),
    inkSoft: const Color(0xFF566574),
    inkFaint: const Color(0xFF637281),
    line: const Color(0xFF9FC3CF),
    lineStrong: const Color(0xFF9FC3CF),
    inputBorder: const Color(0xFF9FC3CF),
    brand: const Color(0xFF176B60),
    brandStrong: const Color(0xFF176B60),
    buttonHeight: 52,
    buttonRadius: 26,
  );

  static const dark = KPalette(
    canvas: KColors.canvasDark,
    surface: KColors.surfaceDark,
    reviewSurface: KColors.surfaceDark,
    surfaceSunken: KColors.surfaceSunkenDark,
    foodRowTint: KColors.accentTintDark,
    foodRowText: KColors.accentDeepDark,
    sleepRowTint: KColors.brandTintDark,
    sleepRowText: KColors.brandStrongDark,
    activityRowTint: KColors.infoTintDark,
    activityRowText: KColors.infoDark,
    ink: KColors.inkDark,
    inkSoft: KColors.inkSoftDark,
    inkFaint: KColors.inkFaintDark,
    line: KColors.lineDark,
    lineStrong: KColors.lineStrongDark,
    inputBorder: KColors.lineStrongDark,
    brand: KColors.brandDark,
    brandStrong: KColors.brandStrongDark,
    brandTint: KColors.brandTintDark,
    accent: KColors.accentDark,
    accentDeep: KColors.accentDeepDark,
    accentTint: KColors.accentTintDark,
    ok: KColors.okDark,
    okDot: KColors.okDark,
    okTint: KColors.okTintDark,
    warn: KColors.warnDark,
    warnDot: KColors.warnDark,
    warnDeep: KColors.warnDeepDark,
    warnTint: KColors.warnTintDark,
    bad: KColors.badDark,
    badText: KColors.badDark,
    badTint: KColors.badTintDark,
    info: KColors.infoDark,
    infoDot: KColors.infoDark,
    infoTint: KColors.infoTintDark,
    buttonHeight: 44,
    buttonRadius: KRadii.control,
    isGardenVoice: false,
  );

  /// Token Garden Voice chỉ dùng cho các màn đã chuyển theo trang Figma 08.
  static const gardenVoice = KPalette(
    canvas: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    reviewSurface: Color(0xFFF9FCFB),
    surfaceSunken: Color(0xFFF6F7F8),
    foodRowTint: Color(0xFFFFF0DE),
    foodRowText: Color(0xFF754A20),
    sleepRowTint: Color(0xFFF0EBFA),
    sleepRowText: Color(0xFF614988),
    activityRowTint: Color(0xFFE6F2FC),
    activityRowText: Color(0xFF2F6488),
    ink: Color(0xFF102737),
    inkSoft: Color(0xFF65727D),
    inkFaint: Color(0xFF75838B),
    line: Color(0xFFE5E8EB),
    lineStrong: Color(0xFFB5D4CE),
    inputBorder: Color(0xFFC7DEDA),
    brand: Color(0xFF087F70),
    brandStrong: Color(0xFF06695E),
    brandTint: Color(0xFFE6F3EB),
    accent: Color(0xFFEFA83E),
    accentDeep: Color(0xFFA45B0C),
    accentTint: Color(0xFFFFF0D9),
    ok: Color(0xFF176747),
    okDot: Color(0xFF3C9771),
    okTint: Color(0xFFE5F5E7),
    warn: Color(0xFFA45B0C),
    warnDot: Color(0xFFC37A1B),
    warnDeep: Color(0xFFA45B0C),
    warnTint: Color(0xFFFFF0D9),
    bad: Color(0xFFCD5148),
    badText: Color(0xFFA93832),
    badTint: Color(0xFFFDEAE5),
    info: Color(0xFF1B74B8),
    infoDot: Color(0xFF328DD3),
    infoTint: Color(0xFFE6F3EB),
    buttonHeight: 48,
    buttonRadius: 24,
    isGardenVoice: true,
  );

  @override
  KPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? reviewSurface,
    Color? surfaceSunken,
    Color? foodRowTint,
    Color? foodRowText,
    Color? sleepRowTint,
    Color? sleepRowText,
    Color? activityRowTint,
    Color? activityRowText,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? line,
    Color? lineStrong,
    Color? inputBorder,
    Color? brand,
    Color? brandStrong,
    Color? brandTint,
    Color? accent,
    Color? accentDeep,
    Color? accentTint,
    Color? ok,
    Color? okDot,
    Color? okTint,
    Color? warn,
    Color? warnDot,
    Color? warnDeep,
    Color? warnTint,
    Color? bad,
    Color? badText,
    Color? badTint,
    Color? info,
    Color? infoDot,
    Color? infoTint,
    double? buttonHeight,
    double? buttonRadius,
    bool? isGardenVoice,
  }) {
    return KPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      reviewSurface: reviewSurface ?? this.reviewSurface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      foodRowTint: foodRowTint ?? this.foodRowTint,
      foodRowText: foodRowText ?? this.foodRowText,
      sleepRowTint: sleepRowTint ?? this.sleepRowTint,
      sleepRowText: sleepRowText ?? this.sleepRowText,
      activityRowTint: activityRowTint ?? this.activityRowTint,
      activityRowText: activityRowText ?? this.activityRowText,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      inputBorder: inputBorder ?? this.inputBorder,
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      brandTint: brandTint ?? this.brandTint,
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      accentTint: accentTint ?? this.accentTint,
      ok: ok ?? this.ok,
      okDot: okDot ?? this.okDot,
      okTint: okTint ?? this.okTint,
      warn: warn ?? this.warn,
      warnDot: warnDot ?? this.warnDot,
      warnDeep: warnDeep ?? this.warnDeep,
      warnTint: warnTint ?? this.warnTint,
      bad: bad ?? this.bad,
      badText: badText ?? this.badText,
      badTint: badTint ?? this.badTint,
      info: info ?? this.info,
      infoDot: infoDot ?? this.infoDot,
      infoTint: infoTint ?? this.infoTint,
      buttonHeight: buttonHeight ?? this.buttonHeight,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      isGardenVoice: isGardenVoice ?? this.isGardenVoice,
    );
  }

  @override
  KPalette lerp(ThemeExtension<KPalette>? other, double t) {
    if (other is! KPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return KPalette(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      reviewSurface: mix(reviewSurface, other.reviewSurface),
      surfaceSunken: mix(surfaceSunken, other.surfaceSunken),
      foodRowTint: mix(foodRowTint, other.foodRowTint),
      foodRowText: mix(foodRowText, other.foodRowText),
      sleepRowTint: mix(sleepRowTint, other.sleepRowTint),
      sleepRowText: mix(sleepRowText, other.sleepRowText),
      activityRowTint: mix(activityRowTint, other.activityRowTint),
      activityRowText: mix(activityRowText, other.activityRowText),
      ink: mix(ink, other.ink),
      inkSoft: mix(inkSoft, other.inkSoft),
      inkFaint: mix(inkFaint, other.inkFaint),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      inputBorder: mix(inputBorder, other.inputBorder),
      brand: mix(brand, other.brand),
      brandStrong: mix(brandStrong, other.brandStrong),
      brandTint: mix(brandTint, other.brandTint),
      accent: mix(accent, other.accent),
      accentDeep: mix(accentDeep, other.accentDeep),
      accentTint: mix(accentTint, other.accentTint),
      ok: mix(ok, other.ok),
      okDot: mix(okDot, other.okDot),
      okTint: mix(okTint, other.okTint),
      warn: mix(warn, other.warn),
      warnDot: mix(warnDot, other.warnDot),
      warnDeep: mix(warnDeep, other.warnDeep),
      warnTint: mix(warnTint, other.warnTint),
      bad: mix(bad, other.bad),
      badText: mix(badText, other.badText),
      badTint: mix(badTint, other.badTint),
      info: mix(info, other.info),
      infoDot: mix(infoDot, other.infoDot),
      infoTint: mix(infoTint, other.infoTint),
      buttonHeight: buttonHeight + (other.buttonHeight - buttonHeight) * t,
      buttonRadius: buttonRadius + (other.buttonRadius - buttonRadius) * t,
      isGardenVoice: t < 0.5 ? isGardenVoice : other.isGardenVoice,
    );
  }
}

/// Reads the active palette from the widget tree: `context.k.brand`.
extension KThemeContext on BuildContext {
  KPalette get k => Theme.of(this).extension<KPalette>() ?? KPalette.light;
}

/// Phạm vi Garden Voice để các màn chuyển dần không làm đổi giao diện cũ.
class GardenVoiceScope extends StatelessWidget {
  const GardenVoiceScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const palette = KPalette.gardenVoice;
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: palette.brand,
          onPrimary: palette.surface,
          surface: palette.surface,
          error: palette.bad,
          onError: palette.surface,
        ),
        scaffoldBackgroundColor: palette.canvas,
        textTheme: base.textTheme
            .apply(
              fontFamily: 'Nunito',
              bodyColor: palette.ink,
              displayColor: palette.ink,
            )
            .copyWith(
              labelLarge: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
        extensions: const [palette],
        cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: palette.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: palette.line),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
          ),
        ),
        dividerTheme:
            DividerThemeData(color: palette.line, thickness: 1, space: 1),
        filledButtonTheme:
            FilledButtonThemeData(style: _scopeButtonShape(palette)),
        outlinedButtonTheme:
            OutlinedButtonThemeData(style: _scopeButtonShape(palette)),
        textButtonTheme: TextButtonThemeData(style: _scopeButtonShape(palette)),
        elevatedButtonTheme:
            ElevatedButtonThemeData(style: _scopeButtonShape(palette)),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Nunito'),
        child: child,
      ),
    );
  }
}

ButtonStyle _buttonShape() => const ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(KRadii.control))),
      ),
    );

ButtonStyle _scopeButtonShape(KPalette palette) => ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, palette.buttonHeight)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(palette.buttonRadius)),
      ),
    );

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

ThemeData _buildTheme(
    {required ColorScheme scheme, required KPalette palette}) {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'BeVietnamPro',
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.canvas,
    extensions: [palette],
    textTheme: TextTheme(
      headlineLarge: TextStyle(
          height: 1.25, fontWeight: FontWeight.w700, color: palette.ink),
      headlineMedium: TextStyle(
          height: 1.3, fontWeight: FontWeight.w700, color: palette.ink),
      titleLarge: TextStyle(
          height: 1.35, fontWeight: FontWeight.w600, color: palette.ink),
      titleMedium: TextStyle(
          height: 1.4, fontWeight: FontWeight.w600, color: palette.ink),
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
    // House button language: rounded-rect at KRadii.control (chips stay stadium pills).
    filledButtonTheme: FilledButtonThemeData(style: _buttonShape()),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonShape()),
    textButtonTheme: TextButtonThemeData(style: _buttonShape()),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonShape()),
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
      contentTextStyle:
          TextStyle(color: palette.surface, fontFamily: 'BeVietnamPro'),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );
}
