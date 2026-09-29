import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

class KCard extends StatelessWidget {
  const KCard({super.key, required this.child, this.padding, this.onTap, this.color});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    return Card(
      color: color,
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
    this.large = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool ghost;
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
              children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
            ),
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 44)),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(KRadii.control))),
      ),
    );
    if (ghost) return TextButton(onPressed: onPressed, style: style, child: child);
    if (secondary) return OutlinedButton(onPressed: onPressed, style: style, child: child);
    return FilledButton(onPressed: onPressed, style: style, child: child);
  }
}

class KAppBar extends StatelessWidget implements PreferredSizeWidget {
  const KAppBar({super.key, required this.title, this.subtitle, this.onBack, this.trailing});
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 62 : 68);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: KColors.canvas.withValues(alpha: .96),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(bottom: BorderSide(color: KColors.line)),
      leading: onBack == null
          ? null
          : IconButton(onPressed: onBack, tooltip: 'Quay lại', icon: const Icon(Icons.chevron_left)),
      titleSpacing: onBack == null ? KSpace.x5 : 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: trailing == null ? null : [trailing!, const SizedBox(width: KSpace.x3)],
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 40});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    const colors = [
      (KColors.brandTint, KColors.brand),
      (KColors.warnTint, KColors.warnDeep),
      (KColors.infoTint, KColors.info),
      (KColors.surfaceSunken, KColors.inkSoft),
      (KColors.badTint, KColors.bad),
    ];
    final words = name.trim().split(RegExp(r'\s+'));
    final last = words.last.characters.first;
    final first = words.length > 1 ? words[words.length - 2].characters.first : words.first.characters.first;
    final pair = colors[name.length % colors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: pair.$1),
      child: Text(
        '$first$last'.toUpperCase(),
        style: TextStyle(color: pair.$2, fontWeight: FontWeight.w600, fontSize: size * .34),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      ReportStatus.none => (KColors.surfaceSunken, KColors.inkSoft),
      ReportStatus.draft || ReportStatus.processing => (KColors.infoTint, KColors.info),
      ReportStatus.submitted => (KColors.okTint, KColors.ok),
      ReportStatus.read => (KColors.ok, Colors.white),
      ReportStatus.attention => (KColors.badTint, KColors.bad),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: colors.$2, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.$2)),
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
    final color = switch (severity) { Severity.none => KColors.ok, Severity.mild => KColors.warn, Severity.moderate => KColors.bad };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(severity.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
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
    return TextField(
      onChanged: onChanged,
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(fontSize: 14, height: 1.2),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: KColors.inkFaint, height: 1.2),
        prefixIcon: const Icon(Icons.search, size: 20, color: KColors.inkFaint),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class FilterChipButton extends StatelessWidget {
  const FilterChipButton({super.key, required this.label, required this.selected, required this.onTap, this.warn = false});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? KColors.warn : KColors.brand;
    return Material(
      color: selected ? color : KColors.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? color : KColors.line)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : KColors.inkSoft),
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
              color: KColors.brand,
              backgroundColor: KColors.surfaceSunken,
            ),
          ),
          Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.value, required this.label, required this.icon, this.tone, this.onTap});
  final int value;
  final String label;
  final IconData icon;
  final Color? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? KColors.inkSoft;
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text('$value', style: const TextStyle(fontSize: 24, height: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KColors.inkSoft)),
        ],
      ),
    );
  }
}

Future<T?> showKSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: KColors.lineStrong, borderRadius: BorderRadius.circular(99))),
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

class _StepIndicatorState extends State<StepIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

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
                      color: done || active ? KColors.brand : KColors.surfaceSunken,
                      boxShadow: active ? [BoxShadow(color: KColors.brand.withValues(alpha: .16), blurRadius: 0, spreadRadius: 5)] : null,
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : KColors.inkFaint)),
                  ),
                  if (index < widget.steps.length - 1)
                    Container(width: 1, height: active ? 58 : 44, color: done ? KColors.brand : KColors.line),
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
                        fontWeight: active ? FontWeight.w600 : done ? FontWeight.w500 : FontWeight.w400,
                        color: done || active ? KColors.ink : KColors.inkFaint,
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
                            color: KColors.surfaceSunken,
                            child: reduceMotion
                                ? const Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: .4, child: ColoredBox(color: KColors.brand)))
                                : AnimatedBuilder(
                                    animation: _controller,
                                    builder: (context, _) {
                                      final t = _controller.value;
                                      final width = .4 + .15 * math.sin(t * math.pi);
                                      final left = -width + (1 + width) * t;
                                      return Align(
                                        alignment: Alignment(left * 2 - 1, 0),
                                        child: FractionallySizedBox(widthFactor: width, child: const ColoredBox(color: KColors.brand)),
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
      decoration: const BoxDecoration(
        color: KColors.surface,
        border: Border(top: BorderSide(color: KColors.line)),
      ),
      child: SafeArea(top: false, minimum: const EdgeInsets.all(14), child: child),
    );
  }
}
