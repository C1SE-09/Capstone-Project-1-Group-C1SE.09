import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart'
    show
        Avatar,
        FilterChipButton,
        KAppBar,
        KButton,
        KCard,
        KInfoRow,
        SearchField,
        SeverityChip,
        StatusBadge;
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart'
    show ReportStatus, Severity;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GardenVoiceScope chỉ áp dụng font và token đã duyệt trong màn',
      (tester) async {
    KPalette? outerPalette;
    KPalette? gardenPalette;
    TextStyle? gardenLabel;
    String? gardenDefaultFont;

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(palette: KPalette.light),
        home: Builder(
          builder: (context) {
            outerPalette = context.k;
            return GardenVoiceScope(
              child: Builder(
                builder: (context) {
                  gardenPalette = context.k;
                  gardenLabel = Theme.of(context).textTheme.labelLarge;
                  gardenDefaultFont =
                      DefaultTextStyle.of(context).style.fontFamily;
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(outerPalette!.brand, const Color(0xFF3A6BC9));
    expect(gardenPalette!.brand, const Color(0xFF087F70));
    expect(gardenPalette!.brandStrong, const Color(0xFF06695E));
    expect(gardenPalette!.brandTint, const Color(0xFFE6F3EB));
    expect(gardenPalette!.reviewSurface, const Color(0xFFF9FCFB));
    expect(gardenPalette!.foodRowTint, const Color(0xFFFFF0DE));
    expect(gardenPalette!.foodRowText, const Color(0xFF754A20));
    expect(gardenPalette!.sleepRowTint, const Color(0xFFF0EBFA));
    expect(gardenPalette!.sleepRowText, const Color(0xFF614988));
    expect(gardenPalette!.activityRowTint, const Color(0xFFE6F2FC));
    expect(gardenPalette!.activityRowText, const Color(0xFF2F6488));
    expect(outerPalette!.reviewSurface, outerPalette!.surface);
    expect(KPalette.dark.reviewSurface, KPalette.dark.surface);
    expect(KPalette.light.foodRowTint, KPalette.light.accentTint);
    expect(KPalette.dark.activityRowText, KPalette.dark.info);
    final copied = gardenPalette!.copyWith(sleepRowText: Colors.black);
    expect(copied.sleepRowText, Colors.black);
    expect(
      gardenPalette!.lerp(KPalette.light, 0).activityRowTint,
      gardenPalette!.activityRowTint,
    );
    expect(gardenLabel!.fontFamily, 'Nunito');
    expect(gardenLabel!.fontSize, 14);
    expect(gardenLabel!.fontWeight, FontWeight.w700);
    expect(gardenLabel!.height, 1.4);
    expect(gardenDefaultFont, 'Nunito');
  });

  testWidgets('GV buttons use Figma 48dp/24dp while baseline KButton stays A2',
      (tester) async {
    late ThemeData gardenTheme;
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(palette: KPalette.light),
      home: Column(
        children: [
          const KButton(label: 'Baseline'),
          GardenVoiceScope(
            child: Builder(
              builder: (context) {
                gardenTheme = Theme.of(context);
                return const KButton(label: 'Garden Voice');
              },
            ),
          ),
        ],
      ),
    ));

    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
    final baselineSize = buttons.first.style!.minimumSize!.resolve({})!;
    final gardenSize = buttons.last.style!.minimumSize!.resolve({})!;
    final baselineShape =
        buttons.first.style!.shape!.resolve({}) as RoundedRectangleBorder;
    final gardenShape =
        buttons.last.style!.shape!.resolve({}) as RoundedRectangleBorder;

    expect(baselineSize.height, 44);
    expect(baselineShape.borderRadius, BorderRadius.circular(8));
    for (final style in [
      gardenTheme.filledButtonTheme.style,
      gardenTheme.outlinedButtonTheme.style,
      gardenTheme.textButtonTheme.style,
      gardenTheme.elevatedButtonTheme.style,
    ]) {
      expect(style?.minimumSize?.resolve({})?.height, 48);
      expect(
        style?.shape?.resolve({}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      );
    }
    expect(gardenSize.height, 48);
    expect(gardenShape.borderRadius, BorderRadius.circular(24));
    expect(tester.getSize(find.byType(FilledButton).last).height, 48);
  });

  testWidgets(
      'GV status badge tones use Figma background, dot, and text colors',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(palette: KPalette.light),
      home: const Column(
        children: [
          StatusBadge(ReportStatus.submitted),
          GardenVoiceScope(
            child: Column(
              children: [
                StatusBadge(ReportStatus.submitted),
                StatusBadge(ReportStatus.attention),
                StatusBadge(ReportStatus.draft),
                StatusBadge(ReportStatus.none),
                SeverityChip(Severity.mild),
              ],
            ),
          ),
        ],
      ),
    ));

    final baselineBadge = tester.widget<Container>(find
        .descendant(
            of: find.byType(StatusBadge).first,
            matching: find.byType(Container))
        .first);
    expect(baselineBadge.padding,
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5));
    expect(tester.widget<Text>(find.text('Đã gửi').first).style?.fontSize, 11);

    final badges = find.byType(StatusBadge);
    final success = _badgeContainers(tester, badges.at(1));
    final successBadge = tester.widget<Container>(find
        .descendant(of: badges.at(1), matching: find.byType(Container))
        .first);
    expect(successBadge.padding,
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4));
    expect((successBadge.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(99));
    expect(
      tester.getSize(find
          .descendant(of: badges.at(1), matching: find.byType(Container))
          .last),
      const Size(6, 6),
    );
    expect(
        tester
            .widget<SizedBox>(find.descendant(
                of: badges.at(1), matching: find.byType(SizedBox)))
            .width,
        6);
    expect(tester.widget<Text>(find.text('Đã gửi').last).style?.fontSize, 12);
    expect(tester.widget<Text>(find.text('Đã gửi').last).style?.height, 1.4);
    expect(_containerColor(success.first), const Color(0xFFE5F5E7));
    expect(_containerColor(success.last), const Color(0xFF3C9771));
    expect(tester.widget<Text>(find.text('Đã gửi').last).style?.color,
        const Color(0xFF176747));

    final error = _badgeContainers(tester, badges.at(2));
    expect(_containerColor(error.first), const Color(0xFFFDEAE5));
    expect(_containerColor(error.last), const Color(0xFFCD5148));
    expect(tester.widget<Text>(find.text('Cần xử lý').last).style?.color,
        const Color(0xFFA93832));

    final info = _badgeContainers(tester, badges.at(3));
    expect(_containerColor(info.first), const Color(0xFFE6F3EB));
    expect(_containerColor(info.last), const Color(0xFF328DD3));
    expect(tester.widget<Text>(find.text('Bản nháp').last).style?.color,
        const Color(0xFF06695E));

    final neutral = _badgeContainers(tester, badges.at(4));
    expect(_containerColor(neutral.first), const Color(0xFFF6F7F8));
    expect(tester.widget<Text>(find.text('Chưa có').last).style?.color,
        const Color(0xFF65727D));
    final warning = _badgeContainers(tester, find.byType(SeverityChip));
    expect(_containerColor(warning.last), const Color(0xFFC37A1B));
    expect(tester.widget<Text>(find.text('Nhẹ')).style?.color,
        const Color(0xFFA45B0C));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Batch 0 shared components adopt Garden Voice specs only inside GardenVoiceScope',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(palette: KPalette.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const KCard(child: Text('A2 Card')),
              FilterChipButton(
                  label: 'A2 Chip', selected: true, onTap: () {}),
              SearchField(hint: 'A2 Search', onChanged: (_) {}),
              const KAppBar(title: 'A2 Header', subtitle: 'A2 Sub'),
              const KInfoRow(label: 'A2 Label', value: 'A2 Value'),
              const Avatar(name: 'Nguyễn Minh An', size: 40),
              GardenVoiceScope(
                child: Column(
                  children: [
                    const KCard(child: Text('GV Card')),
                    KCard(
                      color: KPalette.gardenVoice.brandTint,
                      child: const Text('GV Highlighted Card'),
                    ),
                    FilterChipButton(
                        label: 'GV Chip Active',
                        selected: true,
                        onTap: () {}),
                    FilterChipButton(
                        label: 'GV Chip Inactive',
                        selected: false,
                        onTap: () {}),
                    SearchField(hint: 'Tìm kiếm…', onChanged: (_) {}),
                    const KAppBar(title: 'GV Main', subtitle: 'GV Sub'),
                    KAppBar(
                      title: 'GV Back',
                      subtitle: 'GV Back Sub',
                      onBack: () {},
                    ),
                    const KInfoRow(label: 'GV Label', value: 'GV Value'),
                    const Avatar(name: 'Nguyễn Minh An', size: 32),
                    const Avatar(name: 'Trần Bảo Ngọc', size: 40),
                    const Avatar(name: 'Lê Hoàng Nam', size: 56),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));

    // 1. KCard: A2 uses default cardTheme (radius 12), GV uses radius 24 + #E5E8EB border
    final cards = tester.widgetList<Card>(find.byType(Card)).toList();
    expect(cards[0].shape, isNull);
    final gvDefaultShape = cards[1].shape! as RoundedRectangleBorder;
    expect(gvDefaultShape.borderRadius,
        const BorderRadius.all(Radius.circular(24)));
    expect(gvDefaultShape.side.color, KPalette.gardenVoice.line);
    final gvHighlightShape = cards[2].shape! as RoundedRectangleBorder;
    expect(gvHighlightShape.borderRadius,
        const BorderRadius.all(Radius.circular(24)));
    expect(gvHighlightShape.side, BorderSide.none);

    // 2. FilterChipButton: A2 13px w500 vs GV 14px/1.4 w700 (selected) / w400 (unselected)
    expect(tester.widget<Text>(find.text('A2 Chip')).style?.fontSize, 13);
    final gvActiveChipText = tester.widget<Text>(find.text('GV Chip Active'));
    expect(gvActiveChipText.style?.fontSize, 14);
    expect(gvActiveChipText.style?.height, 1.4);
    expect(gvActiveChipText.style?.fontWeight, FontWeight.w700);
    final gvInactiveChipText =
        tester.widget<Text>(find.text('GV Chip Inactive'));
    expect(gvInactiveChipText.style?.fontSize, 14);
    expect(gvInactiveChipText.style?.fontWeight, FontWeight.w600);
    expect(gvInactiveChipText.style?.color, KPalette.gardenVoice.inkSoft);

    // 3. SearchField: GV height 48px, radius 12px, border #B5D4CE
    final searchFields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(searchFields[0].decoration?.enabledBorder, isNull);
    final gvSearchBorder =
        searchFields[1].decoration?.enabledBorder as OutlineInputBorder?;
    expect(gvSearchBorder?.borderRadius,
        const BorderRadius.all(Radius.circular(12)));
    expect(
        gvSearchBorder?.borderSide.color, KPalette.gardenVoice.lineStrong);
    expect(tester.getSize(find.byType(SearchField).last).height, 48);

    // 4. KAppBar: GV Main (20px w700) & GV Back (16px w700), no bottom border
    final appBars = tester.widgetList<AppBar>(find.byType(AppBar)).toList();
    expect((appBars[0].shape! as Border).bottom.color, KColors.line);
    expect((appBars[1].shape! as Border).bottom, BorderSide.none);
    expect(tester.widget<Text>(find.text('GV Main')).style?.fontSize, 20);
    expect(tester.widget<Text>(find.text('GV Main')).style?.fontWeight,
        FontWeight.w700);
    expect(tester.widget<Text>(find.text('GV Back')).style?.fontSize, 16);
    expect(tester.widget<Text>(find.text('GV Back Sub')).style?.fontSize, 12);

    // 5. KInfoRow: A2 label 13px vs GV label 14px/1.4 & padding 16x13
    expect(tester.widget<Text>(find.text('A2 Label')).style?.fontSize, 13);
    expect(tester.widget<Text>(find.text('GV Label')).style?.fontSize, 14);
    expect(tester.widget<Text>(find.text('GV Label')).style?.height, 1.4);

    // 6. Avatar: GV S(32→12px w500), M(40→14px w700), L(56→16px w700)
    final avatars = find.byType(Avatar);
    final gvAvatarS = tester.widget<Text>(
        find.descendant(of: avatars.at(1), matching: find.byType(Text)));
    final gvAvatarM = tester.widget<Text>(
        find.descendant(of: avatars.at(2), matching: find.byType(Text)));
    final gvAvatarL = tester.widget<Text>(
        find.descendant(of: avatars.at(3), matching: find.byType(Text)));
    expect(gvAvatarS.style?.fontSize, 12);
    expect(gvAvatarS.style?.fontWeight, FontWeight.w600);
    expect(gvAvatarM.style?.fontSize, 14);
    expect(gvAvatarM.style?.fontWeight, FontWeight.w700);
    expect(gvAvatarL.style?.fontSize, 16);
    expect(gvAvatarL.style?.fontWeight, FontWeight.w700);
    expect(tester.takeException(), isNull);
  });
}

List<Container> _badgeContainers(WidgetTester tester, Finder badge) => tester
    .widgetList<Container>(
        find.descendant(of: badge, matching: find.byType(Container)))
    .toList();

Color? _containerColor(Container container) =>
    (container.decoration! as BoxDecoration).color;
