import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme preference. Mirrors the Figma Make "Sáng / Tối / Theo máy"
/// switcher: the choice is remembered across restarts.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);

  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'kinderlog-theme-mode';

  static const _labels = <ThemeMode, String>{
    ThemeMode.light: 'Sáng',
    ThemeMode.dark: 'Tối',
    ThemeMode.system: 'Theo máy',
  };

  static String label(ThemeMode mode) => _labels[mode]!;

  /// Loads the saved preference. Falls back to following the system setting.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = switch (prefs.getString(_prefsKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Persists and applies the chosen mode.
  Future<void> set(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}
