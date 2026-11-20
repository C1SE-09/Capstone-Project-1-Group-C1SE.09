import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adark_frontend/l10n/generated/app_localizations.dart';

/// Extension tiện ích giúp truy cập l10n nhanh gọn từ BuildContext: `context.l10n`
extension LocalizationExtension on BuildContext {
  AppLocalizations? get l10n => AppLocalizations.of(this);
  bool get isVietnamese => LocaleController.instance.isVietnamese;
}

/// Quản lý lựa chọn ngôn ngữ toàn ứng dụng (Tiếng Việt / English).
/// Kế thừa `ValueNotifier<Locale>` để UI tự động cập nhật khi đổi ngôn ngữ.
class LocaleController extends ValueNotifier<Locale> {
  LocaleController._() : super(const Locale('vi'));

  static final LocaleController instance = LocaleController._();

  static const _prefsKey = 'kinderlog-app-locale';

  static const supportedLocales = <Locale>[
    Locale('vi'),
    Locale('en'),
  ];

  /// Nạp ngôn ngữ đã lưu từ bộ nhớ (mặc định là 'vi').
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefsKey);
      if (savedCode == 'en') {
        value = const Locale('en');
      } else {
        value = const Locale('vi');
      }
    } catch (_) {
      value = const Locale('vi');
    }
  }

  /// Đặt ngôn ngữ cụ thể ('vi' hoặc 'en') và lưu vào SharedPreferences.
  Future<void> setLocale(Locale newLocale) async {
    if (newLocale.languageCode != 'vi' && newLocale.languageCode != 'en') return;
    if (value == newLocale) return;
    value = newLocale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, newLocale.languageCode);
    } catch (_) {}
  }

  /// Đổi nhanh giữa Tiếng Việt và Tiếng Anh.
  Future<void> toggleLocale() async {
    final next = value.languageCode == 'vi' ? const Locale('en') : const Locale('vi');
    await setLocale(next);
  }

  bool get isVietnamese => value.languageCode == 'vi';
  bool get isEnglish => value.languageCode == 'en';

  /// Truy cập AppLocalizations bất kỳ đâu mà không cần BuildContext (cho Repositories, Utils, v.v.)
  AppLocalizations get currentL10n => lookupAppLocalizations(value);

  /// Định dạng tên giáo viên song ngữ (tự động gắn danh xưng tĩnh 'Cô' / 'Teacher').
  static String formatTeacherName(String rawName, {bool? isEn}) {
    final effectiveIsEn = isEn ?? instance.isEnglish;
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return effectiveIsEn ? 'Teacher' : 'Giáo viên';
    final clean = trimmed.replaceFirst(RegExp(r'^(Cô|Thầy|cô|thầy|Teacher)\s+', caseSensitive: false), '');
    if (clean.isEmpty) return effectiveIsEn ? 'Teacher' : 'Giáo viên';
    return effectiveIsEn ? 'Teacher $clean' : 'Cô $clean';
  }

  /// Định dạng tên trường học song ngữ (tự động gắn danh xưng tĩnh 'Trường Mầm Non' / 'Kindergarten').
  static String formatSchoolName(String rawName, {bool? isEn}) {
    final effectiveIsEn = isEn ?? instance.isEnglish;
    final trimmed = rawName.trim();
    if (trimmed.isEmpty ||
        trimmed == 'Chưa có thông tin trường' ||
        trimmed == 'No school information') {
      return effectiveIsEn ? 'No school information' : 'Chưa có thông tin trường';
    }
    final clean = trimmed
        .replaceFirst(RegExp(r'^(Trường\s+Mầm\s+Non|Trường\s+Mẫu\s+Giáo|Trường|School)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+(Kindergarten|Preschool)$', caseSensitive: false), '');
    if (clean.isEmpty) return effectiveIsEn ? 'Kindergarten' : 'Trường Mầm Non';
    return effectiveIsEn ? '$clean Kindergarten' : 'Trường Mầm Non $clean';
  }

  /// Định dạng tên lớp học song ngữ (tự động gắn danh xưng tĩnh 'Lớp' / 'Class').
  static String formatClassName(String rawName, {bool? isEn}) {
    final effectiveIsEn = isEn ?? instance.isEnglish;
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return effectiveIsEn ? 'Class' : 'Lớp';
    final clean = trimmed.replaceFirst(RegExp(r'^(Lớp|Class)\s+', caseSensitive: false), '');
    if (clean.isEmpty) return effectiveIsEn ? 'Class' : 'Lớp';
    return effectiveIsEn ? 'Class $clean' : 'Lớp $clean';
  }
}

/// Hiển thị hộp thoại chọn ngôn ngữ (Tiếng Việt / English).
void showLanguageSelectionDialog(BuildContext context) {
  final l10n = context.l10n;
  showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        l10n?.languageSelectTitle ?? 'Ngôn ngữ / Language',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: ListenableBuilder(
        listenable: LocaleController.instance,
        builder: (context, _) {
          final isVi = LocaleController.instance.isVietnamese;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Tiếng Việt 🇻🇳', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: isVi ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32)) : const Icon(Icons.circle_outlined, color: Colors.grey),
                onTap: () {
                  LocaleController.instance.setLocale(const Locale('vi'));
                  Navigator.pop(dialogCtx);
                },
              ),
              ListTile(
                title: const Text('English 🇬🇧', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: !isVi ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32)) : const Icon(Icons.circle_outlined, color: Colors.grey),
                onTap: () {
                  LocaleController.instance.setLocale(const Locale('en'));
                  Navigator.pop(dialogCtx);
                },
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: Text(l10n?.commonClose ?? 'Đóng / Close'),
        ),
      ],
    ),
  );
}

