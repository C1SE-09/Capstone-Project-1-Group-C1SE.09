import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tạm khóa Sáng; chỉ mở lại Dark/Theo máy sau khi người dùng duyệt UI.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.light);

  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'kinderlog-theme-mode';

  static const _labels = <ThemeMode, String>{
    ThemeMode.light: 'Sáng',
    ThemeMode.dark: 'Tối',
    ThemeMode.system: 'Theo máy',
  };

  static String label(ThemeMode mode) => _labels[mode]!;

  /// Tạm chỉ dùng Sáng cho tới khi giao diện tối được duyệt lại.
  Future<void> load() async {
    value = ThemeMode.light;
  }

  /// Persists and applies the chosen mode.
  Future<void> set(ThemeMode mode) async {
    if (mode != ThemeMode.light) return;
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        });
  }
}
