// lib/core/services/locale_service.dart
// Service để quản lý ngôn ngữ (locale) trong ứng dụng

import 'package:flutter/material.dart';

class LocaleService extends ChangeNotifier {
  static LocaleService? _instance;

  LocaleService._();

  static LocaleService get instance {
    _instance ??= LocaleService._();
    return _instance!;
  }

  Locale _locale = const Locale('vi'); // Default: Tiếng Việt

  Locale get locale => _locale;

  /// List các ngôn ngữ được hỗ trợ
  static const List<Locale> supportedLocales = [
    Locale('vi'), // Tiếng Việt
    Locale('en'), // Tiếng Anh
  ];

  /// Tên hiển thị của từng ngôn ngữ
  static const Map<String, String> localeNames = {
    'vi': 'Tiếng Việt',
    'en': 'English',
  };

  /// Đổi ngôn ngữ
  void setLocale(Locale newLocale) {
    if (_locale == newLocale) return;
    if (!supportedLocales.contains(newLocale)) return;

    _locale = newLocale;
    notifyListeners();
  }

  /// Kiểm tra xem ngôn ngữ hiện tại có phải là tiếng Việt không
  bool get isVietnamese => _locale.languageCode == 'vi';

  /// Kiểm tra xem ngôn ngữ hiện tại có phải là tiếng Anh không
  bool get isEnglish => _locale.languageCode == 'en';
}
