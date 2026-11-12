import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart'
    show kDateLabel;
import 'package:flutter/material.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_navigation_scroll.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GardenVoiceParentOverview extends StatelessWidget {
  const GardenVoiceParentOverview({
    super.key,
    required this.parent,
    required this.overview,
    required this.report,
    required this.unreadCount,
    required this.onOpenReport,
    required this.onOpenNotifications,
    required this.onOpenTimetable,
    required this.onOpenRequests,
    required this.onOpenMedication,
  });

  final Parent parent;
  final ChildOverview overview;
  final DailyReport? report;
  final int unreadCount;
  final ValueChanged<DailyReport> onOpenReport;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenTimetable;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenMedication;

  @override
  Widget build(BuildContext context) {
    final displayName = parent.fullName.isEmpty ? 'Phụ huynh' : parent.fullName;
    return GardenVoiceScope(
      child: Builder(
        builder: (context) {
          final k = context.k;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 20, 20,
                24 + GardenVoiceNavigationFrame.bottomPaddingOf(context)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chào buổi sáng,',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: k.inkSoft,
                          ),
                        ),
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 24,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: k.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ParentNotificationButton(
                    unreadCount: unreadCount,
                    onPressed: onOpenNotifications,
                  ),
                ],
              ),
              const SizedBox(height: 23),
              _ChildOverviewCard(overview: overview),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Báo cáo hôm nay',
                          style: TextStyle(
                            fontSize: 19,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: k.ink,
                          ),
                        ),
                        if (report != null && report!.hasDiscussion)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: report!.hasUnreadResponses
                                  ? k.badTint
                                  : k.accentTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_rounded,
                                  size: 13,
                                  color: report!.hasUnreadResponses
                                      ? k.bad
                                      : k.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  report!.hasUnreadResponses
                                      ? (report!.unreadResponseCount > 1
                                          ? '${report!.unreadResponseCount} tin mới'
                                          : 'Có tin mới')
                                      : 'Có trao đổi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: report!.hasUnreadResponses
                                        ? k.bad
                                        : k.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    report == null
                        ? kDateLabel(DateTime.now())
                        : kDateLabel(report!.reportDate),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: k.inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DailyReportSummary(
                report: report,
                onTap: report == null ? null : () => onOpenReport(report!),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(12) > 15;
                  final actions = [
                    _ParentShortcut(
                      icon: 'assets/garden_voice/calendar.svg',
                      background: k.infoTint,
                      label: 'Lịch học',
                      onTap: onOpenTimetable,
                    ),
                    _ParentShortcut(
                      icon: 'assets/garden_voice/calendar_leave.svg',
                      background: k.badTint.withValues(alpha: .7),
                      label: 'Xin nghỉ · Trễ',
                      onTap: onOpenRequests,
                    ),
                    _ParentShortcut(
                      icon: 'assets/garden_voice/parent_pill.svg',
                      background: k.accentTint,
                      label: 'Dặn thuốc',
                      onTap: onOpenMedication,
                    ),
                  ];
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0;
                            index < actions.length;
                            index++) ...[
                          actions[index],
                          if (index < actions.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var index = 0; index < actions.length; index++) ...[
                        Expanded(child: actions[index]),
                        if (index < actions.length - 1)
                          const SizedBox(width: 10),
                      ],
                    ],
                  );
                },
              ),
              if ((report?.summaryText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                _TeacherNote(
                  teacherName: overview.teacherName,
                  message: report!.summaryText!.trim(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ParentNotificationButton extends StatelessWidget {
  const _ParentNotificationButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: k.infoTint,
          borderRadius: BorderRadius.circular(21),
          child: IconButton(
            tooltip: 'Thông báo',
            onPressed: onPressed,
            icon: ExcludeSemantics(
              child: SvgPicture.asset(
                'assets/garden_voice/parent_bell.svg',
                width: 23,
                height: 23,
              ),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Semantics(
              label: '$unreadCount báo cáo chưa đọc',
              child: Container(
                key: const ValueKey('garden-voice-parent-unread-badge'),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: k.bad,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$unreadCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: k.surface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChildOverviewCard extends StatelessWidget {
  const _ChildOverviewCard({required this.overview});

  final ChildOverview overview;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final allergy = overview.child.allergy;
    final classLabel = overview.className.isEmpty
        ? 'LỚP HỌC'
        : 'LỚP ${overview.className.toUpperCase()}';
    return Container(
      key: const ValueKey('garden-voice-parent-child-card'),
      height: 160,
      decoration: BoxDecoration(
        color: k.brandTint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 16,
            top: 14,
            width: 185,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .66,
                    color: k.brandStrong,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  overview.child.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    height: 1.28,
                    fontWeight: FontWeight.w800,
                    color: k.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  overview.teacherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.28,
                    fontWeight: FontWeight.w600,
                    color: k.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 6,
            top: -12,
            width: 147,
            height: 135,
            child: Image.asset(
              'assets/garden_voice/parent_child_reading.png',
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 11,
            child: Container(
              height: 33,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: allergy == null ? k.surface : k.badTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                allergy == null
                    ? 'Chưa có cập nhật điểm danh hôm nay'
                    : 'Dị ứng: $allergy',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.28,
                  fontWeight: FontWeight.w600,
                  color: allergy == null ? k.inkSoft : k.bad,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyReportSummary extends StatelessWidget {
  const _DailyReportSummary({required this.report, this.onTap});

  final DailyReport? report;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    if (report == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: k.surfaceSunken,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Chưa có báo cáo hôm nay.',
          style: TextStyle(color: k.inkSoft),
        ),
      );
    }
    return Material(
      color: k.surfaceSunken,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              _ReportRow(
                icon: 'assets/garden_voice/utensils.svg',
                background: k.accentTint,
                label: 'Ăn uống',
                detail: report!.eating ?? 'Chưa cập nhật',
              ),
              Divider(height: 1, color: k.line),
              _ReportRow(
                icon: 'assets/garden_voice/moon.svg',
                background: k.infoTint.withValues(alpha: .7),
                label: 'Giấc ngủ',
                detail: report!.sleeping ?? 'Chưa cập nhật',
              ),
              Divider(height: 1, color: k.line),
              _ReportRow(
                icon: 'assets/garden_voice/sparkles.svg',
                background: k.infoTint,
                label: 'Hoạt động',
                detail: report!.activitiesText ?? 'Chưa cập nhật',
              ),
              if (report!.hasDiscussion) ...[
                Divider(height: 1, color: k.line),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 16,
                        color: report!.hasUnreadResponses ? k.bad : k.brand,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report!.hasUnreadResponses
                              ? 'Có phản hồi mới (${report!.unreadResponseCount})'
                              : 'Đã có trao đổi với giáo viên',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: report!.hasUnreadResponses
                                ? k.bad
                                : k.inkSoft,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: k.inkSoft,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.background,
    required this.label,
    required this.detail,
  });

  final String icon;
  final Color background;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final largeText = MediaQuery.textScalerOf(context).scale(12.5) > 15;
    return SizedBox(
      height: largeText ? 116 : 68,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ExcludeSemantics(
              child: SvgPicture.asset(icon, width: 20, height: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: largeText ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.28,
                    fontWeight: FontWeight.w800,
                    color: k.ink,
                  ),
                ),
                Text(
                  detail,
                  maxLines: largeText ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.28,
                    color: k.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentShortcut extends StatelessWidget {
  const _ParentShortcut({
    required this.icon,
    required this.background,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final Color background;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 15;
    final k = context.k;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: largeText ? 96 : 66,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: SvgPicture.asset(icon, width: 24, height: 24),
                  ),
                  const SizedBox(height: 5),
                  if (largeText)
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.28,
                        fontWeight: FontWeight.w700,
                        color: k.ink,
                      ),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.28,
                          fontWeight: FontWeight.w700,
                          color: k.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeacherNote extends StatelessWidget {
  const _TeacherNote({required this.teacherName, required this.message});

  final String teacherName;
  final String message;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: k.surfaceSunken,
        border: Border(bottom: BorderSide(color: k.lineStrong)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/garden_voice/parent_teacher.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Lời nhắn của $teacherName',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.28,
                    fontWeight: FontWeight.w800,
                    color: k.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 13, height: 1.28, color: k.inkSoft),
          ),
        ],
      ),
    );
  }
}
