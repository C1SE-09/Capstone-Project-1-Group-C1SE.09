import 'package:flutter/material.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

enum MedicationTone { brand, ok, warn, neutral }
typedef GardenCardTone = MedicationTone;

class MedicationCard extends StatelessWidget {
  const MedicationCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.radius = 16,
  });
  final Widget child;
  final Color? color, borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: color ?? context.k.surface,
          borderRadius: BorderRadius.circular(radius),
          border: borderColor == null ? null : Border.all(color: borderColor!)),
      child: child);
}

typedef GardenVoiceCard = MedicationCard;

class MedicationBadge extends StatelessWidget {
  const MedicationBadge(this.label,
      {super.key, this.status, this.tone, this.showDot = false});
  final String label;
  final String? status;
  final MedicationTone? tone;
  final bool showDot;

  MedicationTone get _tone =>
      tone ??
      switch (status) {
        'given' || 'approved' => MedicationTone.ok,
        'pending' => MedicationTone.warn,
        _ => MedicationTone.neutral
      };

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (ink, tint) = switch (_tone) {
      MedicationTone.brand => (k.brand, k.brandTint),
      MedicationTone.ok => (k.ok, k.okTint),
      MedicationTone.warn => (k.warn, k.warnTint),
      MedicationTone.neutral => (k.inkSoft, k.surfaceSunken)
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: tint, borderRadius: BorderRadius.circular(999)),
        child: showDot
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    key: const ValueKey('badge-status-dot'),
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: ink, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: ink)),
              ])
            : Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: ink)));
  }
}

typedef GardenVoiceBadge = MedicationBadge;

class MedicationAction extends StatelessWidget {
  const MedicationAction(
      {super.key,
      required this.label,
      required this.onPressed,
      this.danger = false,
      this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool danger, busy;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: danger ? context.k.bad : context.k.brand,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              disabledBackgroundColor: context.k.surfaceSunken,
              disabledForegroundColor: context.k.inkSoft,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700)),
          child: busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: context.l10n?.bugReportStatusInProgress ?? 'Đang xử lý'))
              : Text(label, textAlign: TextAlign.center)));
}

typedef GardenVoiceAction = MedicationAction;

String medicationError(Object error) => error.toString();
