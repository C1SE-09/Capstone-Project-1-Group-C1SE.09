import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_navigation.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:adark_frontend/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocaleController.instance.load();
  });

  tearDown(() async {
    await LocaleController.instance.setLocale(const Locale('vi'));
  });

  test('LocaleController toggles between vi and en correctly', () async {
    expect(LocaleController.instance.value.languageCode, equals('vi'));
    expect(LocaleController.instance.isVietnamese, isTrue);

    await LocaleController.instance.toggleLocale();
    expect(LocaleController.instance.value.languageCode, equals('en'));
    expect(LocaleController.instance.isEnglish, isTrue);

    await LocaleController.instance.toggleLocale();
    expect(LocaleController.instance.value.languageCode, equals('vi'));
    expect(LocaleController.instance.isVietnamese, isTrue);
  });

  test('LocaleController persists choice in SharedPreferences', () async {
    await LocaleController.instance.setLocale(const Locale('en'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kinderlog-app-locale'), equals('en'));

    // Test load
    await LocaleController.instance.load();
    expect(LocaleController.instance.value.languageCode, equals('en'));
  });

  testWidgets('GardenVoiceParentNavigation displays localized tab labels in English',
      (tester) async {
    await LocaleController.instance.setLocale(const Locale('en'));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          bottomNavigationBar: GardenVoiceParentNavigation(
            selected: GardenVoiceParentDestination.home,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Overview'), findsOneWidget);
    expect(find.bySemanticsLabel('Reports'), findsOneWidget);
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
    expect(find.bySemanticsLabel('Account'), findsOneWidget);
  });

  testWidgets('GardenVoiceTeacherNavigation displays localized tab labels in English',
      (tester) async {
    await LocaleController.instance.setLocale(const Locale('en'));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          bottomNavigationBar: GardenVoiceTeacherNavigation(
            selected: GardenVoiceTeacherDestination.home,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Overview'), findsOneWidget);
    expect(find.bySemanticsLabel('Class'), findsOneWidget);
    expect(find.bySemanticsLabel('Record'), findsOneWidget);
    expect(find.bySemanticsLabel('Reports'), findsOneWidget);
    expect(find.bySemanticsLabel('Account'), findsOneWidget);
  });

  testWidgets('GardenVoiceTeacherNavigation displays localized tab labels in Vietnamese',
      (tester) async {
    await LocaleController.instance.setLocale(const Locale('vi'));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          bottomNavigationBar: GardenVoiceTeacherNavigation(
            selected: GardenVoiceTeacherDestination.home,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Tổng quan'), findsOneWidget);
    expect(find.bySemanticsLabel('Lớp'), findsOneWidget);
    expect(find.bySemanticsLabel('Ghi âm'), findsOneWidget);
    expect(find.bySemanticsLabel('Báo cáo'), findsOneWidget);
    expect(find.bySemanticsLabel('Tài khoản'), findsOneWidget);
  });
}
