import 'package:flutter/material.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

enum ObservationDecision { approved, discarded, pending }

class SurfaceBox extends StatelessWidget {
  const SurfaceBox({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? context.k.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? context.k.line),
      ),
      child: child,
    );
  }
}

class SummaryRow extends StatelessWidget {
  const SummaryRow(this.icon, this.count, this.label, {super.key});

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
              width: 24,
              child: Icon(icon, size: 16, color: context.k.brand)),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.k.ink),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: context.k.ink)),
          ),
        ],
      ),
    );
  }
}

class CounterPill extends StatelessWidget {
  const CounterPill({super.key, required this.approved, required this.total});

  final int approved;
  final int total;

  @override
  Widget build(BuildContext context) {
    final done = approved >= total && total > 0;
    final color = done ? context.k.brand : context.k.inkSoft;
    final bg = done ? context.k.brandTint : context.k.canvas;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        'Đã duyệt $approved/$total',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class AnimatedObservationWrapper extends StatelessWidget {
  const AnimatedObservationWrapper({
    super.key,
    required this.child,
    required this.decision,
  });

  final Widget child;
  final ObservationDecision decision;

  @override
  Widget build(BuildContext context) {
    final isDiscarded = decision == ObservationDecision.discarded;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(
        begin: 0.0,
        end: isDiscarded ? -1.0 : 0.0,
      ),
      builder: (context, offset, c) {
        final clamped = offset.clamp(-1.0, 0.0);
        return Opacity(
          opacity: 1.0 + clamped * 0.55,
          child: Transform.translate(
            offset: Offset(clamped * 28, 0),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}
