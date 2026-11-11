import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme_controller.dart';

class KCard extends StatelessWidget {
  const KCard(
      {super.key, required this.child, this.padding, this.onTap, this.color});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isGardenVoice = context.k.isGardenVoice;
    final content = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    return Card(
      color: color,
      shape: isGardenVoice
          ? RoundedRectangleBorder(
              side: color != null && color != context.k.surface
                  ? BorderSide.none
                  : BorderSide(color: context.k.line),
              borderRadius: const BorderRadius.all(Radius.circular(24)),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class KButton extends StatelessWidget {
  const KButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.secondary = false,
    this.ghost = false,
    this.danger = false,
    this.large = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool ghost;
  final bool danger;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: EdgeInsets.symmetric(vertical: large ? 4 : 0),
      child: icon == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label)
              ],
            ),
    );
    final style = ButtonStyle(
      minimumSize:
          WidgetStatePropertyAll(Size(double.infinity, context.k.buttonHeight)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(context.k.buttonRadius))),
      ),
    );
    if (danger) {
      return FilledButton(
        onPressed: onPressed,
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll(context.k.bad),
          foregroundColor: WidgetStatePropertyAll(context.k.canvas),
        ),
        child: child,
      );
    }
    if (ghost) {
      return TextButton(onPressed: onPressed, style: style, child: child);
    }
    if (secondary) {
      return OutlinedButton(onPressed: onPressed, style: style, child: child);
    }
    return FilledButton(onPressed: onPressed, style: style, child: child);
  }
}

class KAppBar extends StatelessWidget implements PreferredSizeWidget {
  const KAppBar(
      {super.key,
      required this.title,
      this.subtitle,
      this.onBack,
      this.trailing});
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 62 : 68);

  @override
  Widget build(BuildContext context) {
    final isGardenVoice = context.k.isGardenVoice;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: isGardenVoice
          ? context.k.canvas
          : context.k.canvas.withValues(alpha: .96),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: isGardenVoice
          ? const Border()
          : Border(bottom: BorderSide(color: context.k.line)),
      leading: onBack == null
          ? null
          : IconButton(
              onPressed: onBack,
              tooltip: 'Quay lại',
              padding: isGardenVoice ? EdgeInsets.zero : null,
              icon: isGardenVoice
                  ? SvgPicture.asset(
                      'assets/garden_voice/hub_back.svg',
                      width: 44,
                      height: 44,
                    )
                  : const Icon(Icons.chevron_left)),
      titleSpacing: onBack == null ? KSpace.x5 : (isGardenVoice ? 4 : 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isGardenVoice
                  ? TextStyle(
                      fontSize: onBack == null ? 20 : 16,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: context.k.ink,
                    )
                  : Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            if (isGardenVoice) SizedBox(height: onBack == null ? 2 : 1),
            Text(subtitle!,
                style: isGardenVoice
                    ? TextStyle(
                        fontSize: onBack == null ? 14 : 12,
                        height: 1.4,
                        fontWeight:
                            onBack == null ? FontWeight.w400 : FontWeight.w500,
                        color: context.k.inkSoft,
                      )
                    : Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      actions: trailing == null
          ? null
          : [
              trailing!,
              SizedBox(width: isGardenVoice ? KSpace.x5 : KSpace.x3),
            ],
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 40});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isGardenVoice = context.k.isGardenVoice;
    final colors = isGardenVoice
        ? [
            (context.k.okTint, context.k.ok),
            (context.k.badTint, context.k.badText),
            (context.k.sleepRowTint, context.k.sleepRowText),
            (context.k.activityRowTint, context.k.activityRowText),
            (context.k.accentTint, context.k.accentDeep),
          ]
        : [
            (context.k.brandTint, context.k.brand),
            (context.k.warnTint, context.k.warnDeep),
            (context.k.infoTint, context.k.info),
            (context.k.surfaceSunken, context.k.inkSoft),
            (context.k.badTint, context.k.bad),
          ];
    final words = name.trim().split(RegExp(r'\s+'));
    final last = words.last.characters.first;
    final first = words.length > 1
        ? words[words.length - 2].characters.first
        : words.first.characters.first;
    final pair = colors[name.length % colors.length];
    final double gvFontSize = size <= 32 ? 12 : (size <= 40 ? 14 : 16);
    final FontWeight gvWeight = size <= 32 ? FontWeight.w500 : FontWeight.w700;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: pair.$1),
      child: Text(
        '$first$last'.toUpperCase(),
        style: TextStyle(
            color: pair.$2,
            fontWeight: isGardenVoice ? gvWeight : FontWeight.w600,
            fontSize: isGardenVoice ? gvFontSize : size * .34,
            height: isGardenVoice ? 1.4 : null),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.labelOverride});
  final ReportStatus status;
  final String? labelOverride;

  @override
  Widget build(BuildContext context) {
    final isGardenVoice = context.k.isGardenVoice;
    final colors = switch (status) {
      ReportStatus.none => (
          context.k.surfaceSunken,
          context.k.inkFaint,
          context.k.inkSoft
        ),
      ReportStatus.draft || ReportStatus.processing => (
          context.k.infoTint,
          context.k.infoDot,
          context.k.brandStrong
        ),
      ReportStatus.submitted => (
          context.k.okTint,
          context.k.okDot,
          context.k.ok
        ),
      ReportStatus.read => (
          context.k.okDot,
          context.k.surface,
          context.k.surface
        ),
      ReportStatus.attention => (
          context.k.badTint,
          context.k.bad,
          context.k.badText
        ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isGardenVoice ? 8 : 10, vertical: isGardenVoice ? 4 : 5),
      decoration: BoxDecoration(
          color: colors.$1, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: colors.$2, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(labelOverride ?? status.label,
              style: TextStyle(
                  fontSize: isGardenVoice ? 12 : 11,
                  height: isGardenVoice ? 1.4 : null,
                  fontWeight: FontWeight.w500,
                  color: colors.$3)),
        ],
      ),
    );
  }
}

class SeverityChip extends StatelessWidget {
  const SeverityChip(this.severity, {super.key});
  final Severity severity;

  @override
  Widget build(BuildContext context) {
    final colors = switch (severity) {
      Severity.none => (context.k.okDot, context.k.ok),
      Severity.mild => (context.k.warnDot, context.k.warn),
      Severity.moderate => (context.k.bad, context.k.badText)
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: colors.$1, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(severity.label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: colors.$2)),
      ],
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onChanged, this.hint = 'Tìm...'});
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final isGardenVoice = context.k.isGardenVoice;
    final field = TextField(
      onChanged: onChanged,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(
        fontSize: 14,
        height: isGardenVoice ? 1.4 : 1.2,
        color: isGardenVoice ? context.k.ink : null,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: isGardenVoice ? context.k.inkSoft : context.k.inkFaint,
          height: isGardenVoice ? 1.4 : 1.2,
        ),
        prefixIcon: isGardenVoice
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: SvgPicture.asset(
                  'assets/garden_voice/record_search.svg',
                  width: 16.25,
                  height: 16.25,
                ),
              )
            : Icon(Icons.search, size: 20, color: context.k.inkFaint),
        prefixIconConstraints: isGardenVoice
            ? const BoxConstraints(minWidth: 40.25, minHeight: 16.25)
            : const BoxConstraints(minWidth: 40, minHeight: 40),
        isDense: true,
        filled: true,
        fillColor: context.k.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: isGardenVoice ? 14 : 12,
        ),
        border: isGardenVoice
            ? OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: context.k.lineStrong),
              )
            : null,
        enabledBorder: isGardenVoice
            ? OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: context.k.lineStrong),
              )
            : null,
        focusedBorder: isGardenVoice
            ? OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: context.k.brand),
              )
            : null,
      ),
    );
    if (!isGardenVoice) return field;
    return SizedBox(height: 48, child: field);
  }
}

class FilterChipButton extends StatelessWidget {
  const FilterChipButton(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.unselectedTextColor,
      this.warn = false});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? unselectedTextColor;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final isGardenVoice = context.k.isGardenVoice;
    final color = warn ? context.k.warn : context.k.brand;
    return Material(
      color: selected ? color : context.k.surface,
      shape: StadiumBorder(
          side: BorderSide(color: selected ? color : context.k.line)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: isGardenVoice ? 14 : 13,
              height: isGardenVoice ? 1.4 : null,
              fontWeight: isGardenVoice
                  ? (selected ? FontWeight.w700 : FontWeight.w400)
                  : FontWeight.w500,
              color: selected
                  ? (isGardenVoice ? context.k.surface : Colors.white)
                  : unselectedTextColor ?? context.k.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, required this.total});
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : value / total;
    return SizedBox.square(
      dimension: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 76,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              color: context.k.brand,
              backgroundColor: context.k.surfaceSunken,
            ),
          ),
          Text('${(progress * 100).round()}%',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard(
      {super.key,
      required this.value,
      required this.label,
      required this.icon,
      this.tone,
      this.onTap});
  final int value;
  final String label;
  final IconData icon;
  final Color? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? context.k.inkSoft;
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text('$value',
              style: const TextStyle(
                  fontSize: 24, height: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.k.inkSoft)),
        ],
      ),
    );
  }
}

Future<T?> showKSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.k.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: KSpace.x5,
          right: KSpace.x5,
          top: KSpace.x3,
          bottom: MediaQuery.viewInsetsOf(context).bottom + KSpace.x5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.k.lineStrong,
                    borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: KSpace.x4),
            child,
          ],
        ),
      ),
    ),
  );
}

class StepIndicator extends StatefulWidget {
  const StepIndicator({super.key, required this.steps, required this.active});
  final List<String> steps;
  final int active;

  @override
  State<StepIndicator> createState() => _StepIndicatorState();
}

class _StepIndicatorState extends State<StepIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: List.generate(widget.steps.length, (index) {
        final done = index < widget.active;
        final active = index == widget.active;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done || active
                          ? context.k.brand
                          : context.k.surfaceSunken,
                      boxShadow: active
                          ? [
                              BoxShadow(
                                  color: context.k.brand.withValues(alpha: .16),
                                  blurRadius: 0,
                                  spreadRadius: 5)
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('${index + 1}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? Colors.white
                                    : context.k.inkFaint)),
                  ),
                  if (index < widget.steps.length - 1)
                    Container(
                        width: 1,
                        height: active ? 58 : 44,
                        color: done ? context.k.brand : context.k.line),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.steps[index],
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: active
                            ? FontWeight.w600
                            : done
                                ? FontWeight.w500
                                : FontWeight.w400,
                        color:
                            done || active ? context.k.ink : context.k.inkFaint,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: SizedBox(
                          width: 180,
                          height: 4,
                          child: ColoredBox(
                            color: context.k.surfaceSunken,
                            child: reduceMotion
                                ? Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                        widthFactor: .4,
                                        child:
                                            ColoredBox(color: context.k.brand)))
                                : AnimatedBuilder(
                                    animation: _controller,
                                    builder: (context, _) {
                                      final t = _controller.value;
                                      final width =
                                          .4 + .15 * math.sin(t * math.pi);
                                      final left = -width + (1 + width) * t;
                                      return Align(
                                        alignment: Alignment(left * 2 - 1, 0),
                                        child: FractionallySizedBox(
                                            widthFactor: width,
                                            child: ColoredBox(
                                                color: context.k.brand)),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.k.surface,
        border: Border(top: BorderSide(color: context.k.line)),
      ),
      child:
          SafeArea(top: false, minimum: const EdgeInsets.all(14), child: child),
    );
  }
}

/// Định dạng ngày kiểu Việt Nam: 12/03/2026.
String kDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Một dòng nhãn — giá trị, dùng cho các card thông tin (liên hệ, thông tin bé).
class KInfoRow extends StatelessWidget {
  const KInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.danger = false,
    this.onTap,
    this.icon,
    this.showEditIcon = true,
  });

  final String label;
  final String value;
  final bool danger;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool showEditIcon;

  @override
  Widget build(BuildContext context) {
    final isGardenVoice = context.k.isGardenVoice;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isGardenVoice ? 16 : 14,
          vertical: isGardenVoice ? 13 : 10,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isGardenVoice ? 14 : 13,
                height: isGardenVoice ? 1.4 : null,
                color: isGardenVoice && danger && value.isEmpty
                    ? context.k.bad
                    : context.k.inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (danger && icon != null) ...[
                    Icon(icon, size: 15, color: context.k.bad),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        height: isGardenVoice ? 1.4 : null,
                        color: danger ? context.k.bad : context.k.ink,
                      ),
                    ),
                  ),
                  if (onTap != null && showEditIcon) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.edit_outlined, size: 16, color: context.k.brand),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Bộ chọn giao diện Sáng / Tối / Theo máy — dùng chung cho mọi vai trò.
/// (Trước đây nằm riêng trong teacher_tabs.dart.)
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key, this.onBack});

  final VoidCallback? onBack;

  static const _options = <(ThemeMode, String, IconData)>[
    (ThemeMode.light, 'Sáng', Icons.wb_sunny_outlined),
    (ThemeMode.dark, 'Tối', Icons.dark_mode_outlined),
    (ThemeMode.system, 'Theo máy', Icons.smartphone_outlined),
  ];

  static const _gardenVoiceOptions = <(ThemeMode, String, String)>[
    (ThemeMode.light, 'Sáng', 'Nền giấy ấm, rõ trong lớp học'),
    (ThemeMode.dark, 'Tối', 'Giảm chói khi xem buổi tối'),
    (ThemeMode.system, 'Theo máy', 'Tự đổi theo cài đặt điện thoại'),
  ];

  static String _labelForMode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Sáng',
        ThemeMode.dark => 'Tối',
        ThemeMode.system => 'Theo máy',
      };

  @override
  Widget build(BuildContext context) {
    final isGardenVoice = context.k.isGardenVoice;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) {
        if (isGardenVoice) {
          return Material(
            color: context.k.canvas,
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed:
                              onBack ?? () => Navigator.of(context).maybePop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          tooltip: 'Quay lại',
                          icon: SvgPicture.asset(
                            'assets/garden_voice/hub_back.svg',
                            width: 44,
                            height: 44,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Giao diện',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: context.k.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Chọn cách hiển thị KinderLog trên thiết bị.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                        color: context.k.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đang dùng',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                            color: context.k.inkSoft,
                          ),
                        ),
                        Text(
                          _labelForMode(mode),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: context.k.brandStrong,
                          ),
                        ),
                      ],
                    ),
                    for (final (value, labelText, description)
                        in _gardenVoiceOptions) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        button: true,
                        selected: mode == value,
                        label: labelText,
                        child: InkWell(
                          onTap: () => ThemeController.instance.set(value),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: context.k.surfaceSunken,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  labelText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    fontWeight: FontWeight.w700,
                                    color: context.k.brandStrong,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 17,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    color: context.k.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.brightness_6_outlined,
                      size: 19, color: context.k.inkSoft),
                  const SizedBox(width: 12),
                  const Text('Giao diện', style: TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final (value, labelText, icon) in _options) ...[
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: mode == value,
                        label: labelText,
                        child: InkWell(
                          onTap: () => ThemeController.instance.set(value),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: mode == value
                                  ? context.k.surface
                                  : Colors.transparent,
                              border: Border.all(
                                color: mode == value
                                    ? context.k.brand.withValues(alpha: .4)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  icon,
                                  size: 16,
                                  color: mode == value
                                      ? context.k.brand
                                      : context.k.inkFaint,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  labelText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: mode == value
                                        ? context.k.brand
                                        : context.k.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
