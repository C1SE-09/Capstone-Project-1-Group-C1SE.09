import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

enum ParentRequestDestination { history, home }

String requestTypeLabel(LeaveRequestType type) =>
    type == LeaveRequestType.absence ? 'Nghỉ học' : 'Báo đi trễ';

String requestStatusLabel(LeaveStatus status) => switch (status) {
      LeaveStatus.pending => 'Chờ duyệt',
      LeaveStatus.approved => 'Đã duyệt',
      LeaveStatus.rejected => 'Từ chối',
      LeaveStatus.cancelled => 'Đã hủy',
    };

String requestDate(DateTime value) => DateFormat('dd/MM/yyyy').format(value);

String requestDayLabel(DateTime value) {
  final day = DateUtils.dateOnly(value);
  const weekdays = [
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật'
  ];
  final prefix = day.isAtSameMomentAs(DateUtils.dateOnly(DateTime.now()))
      ? 'Hôm nay — '
      : '';
  return '$prefix${weekdays[day.weekday - 1]}, ${requestDate(day)}';
}

String requestTimestamp(DateTime value) => DateFormat('dd/MM/yyyy, HH:mm')
    .format(value.toUtc().add(const Duration(hours: 7)));

String requestRange(LeaveRequestEntity request) => request.totalDays == 1
    ? '${requestDate(request.fromDate)} · 1 ngày'
    : '${requestDate(request.fromDate)} – ${requestDate(request.toDate)} · ${request.totalDays} ngày';

class ParentRequestLayout extends StatelessWidget {
  const ParentRequestLayout(
      {super.key, this.title, required this.child, this.actions});
  final String? title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.k.canvas,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Scaffold(
              backgroundColor: context.k.canvas,
              appBar: title == null
                  ? null
                  : AppBar(
                      title: Text(title!,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.k.ink)),
                      titleSpacing: 8,
                      leadingWidth: 32,
                      toolbarHeight: 56 +
                          (MediaQuery.textScalerOf(context).scale(16) - 16) * 2,
                      backgroundColor: context.k.canvas,
                      foregroundColor: context.k.ink,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      leading: IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.chevron_left, size: 28)),
                      actions: actions,
                    ),
              body: SafeArea(
                top: title == null,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                      fontSize: 13, height: 1.4, color: context.k.ink),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
}

class ParentRequestCard extends StatelessWidget {
  const ParentRequestCard({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: color ?? context.k.surface,
            borderRadius: BorderRadius.circular(14)),
        child: child,
      );
}

class ParentRequestStatus extends StatelessWidget {
  const ParentRequestStatus(this.status, {super.key});
  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (ink, tint) = switch (status) {
      LeaveStatus.pending => (k.warnDeep, k.warnTint),
      LeaveStatus.approved => (k.ok, k.okTint),
      LeaveStatus.rejected => (k.bad, k.badTint),
      LeaveStatus.cancelled => (k.inkSoft, k.surfaceSunken),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20)),
      child: Text(requestStatusLabel(status),
          style:
              TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class ParentRequestButton extends StatelessWidget {
  const ParentRequestButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: context.k.brand,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              textStyle: const TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                if (busy)
                  Semantics(
                      label: 'Đang gửi đơn',
                      child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                Text(label, textAlign: TextAlign.center),
              ]),
        ),
      );
}

Future<bool> showParentRequestDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
  IconData? icon,
  Color? accent,
  Color? tint,
  bool danger = false,
}) async {
  final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final k = dialogContext.k;
        final primary = Theme.of(dialogContext).colorScheme.onPrimary;
        return Dialog(
            backgroundColor: k.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (icon != null)
                        Row(children: [
                          Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: tint ?? k.warnTint,
                                  shape: BoxShape.circle),
                              child: Icon(icon,
                                  size: 20, color: accent ?? k.warn)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(title,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: k.ink))),
                        ])
                      else
                        Text(title,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: k.ink)),
                      const SizedBox(height: 10),
                      Text(message,
                          style: TextStyle(fontSize: 13, color: k.inkSoft)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                    foregroundColor: k.inkSoft,
                                    side: BorderSide(color: k.line, width: 1.5),
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700)),
                                child: Text(cancelLabel))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                style: FilledButton.styleFrom(
                                    backgroundColor: danger ? k.bad : k.brand,
                                    foregroundColor: primary,
                                    minimumSize: const Size(0, 48),
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700)),
                                child: Text(confirmLabel))),
                      ]),
                    ])));
      });
  return agreed ?? false;
}

class ParentRequestError extends StatelessWidget {
  const ParentRequestError(this.message, {super.key, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
            liveRegion: true,
            child: Text(message, style: TextStyle(color: context.k.bad))),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ]);
}

class ParentRequestInfo extends StatelessWidget {
  const ParentRequestInfo(this.label, this.value, {super.key});
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: context.k.inkSoft, fontSize: 12.5))),
          const SizedBox(width: 8),
          Expanded(
              flex: 3,
              child: Align(
                  alignment: Alignment.centerRight,
                  child: DefaultTextStyle.merge(
                      style: const TextStyle(fontSize: 12.5), child: value))),
        ]),
      );
}

class ParentRequestChild extends StatelessWidget {
  const ParentRequestChild(
      {super.key,
      required this.child,
      required this.className,
      required this.teacherName});
  final Child child;
  final String className;
  final String teacherName;

  @override
  Widget build(BuildContext context) => ParentRequestCard(
          child: Row(children: [
        CircleAvatar(
            radius: 18,
            backgroundColor: context.k.brandTint,
            child: Text(
                child.fullName.trim().isEmpty
                    ? '?'
                    : child.fullName.trim().characters.first,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: context.k.brand))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(child.fullName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
              [className, teacherName]
                  .where((e) => e.trim().isNotEmpty)
                  .join(' · '),
              style: TextStyle(color: context.k.inkSoft, fontSize: 11)),
        ])),
      ]));
}

class ParentRequestPill extends StatelessWidget {
  const ParentRequestPill(
      {super.key,
      required this.label,
      required this.selected,
      required this.onPressed,
      this.brandTone = false});
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final bool brandTone;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: selected
                      ? (brandTone ? context.k.brandTint : context.k.ink)
                      : context.k.surface,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? (brandTone ? context.k.brand : context.k.surface)
                          : context.k.ink))),
        ),
      );
}
