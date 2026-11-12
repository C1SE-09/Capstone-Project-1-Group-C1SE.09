import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_navigation_scroll.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GardenVoiceTeacherOverview extends StatelessWidget {
  const GardenVoiceTeacherOverview({
    super.key,
    required this.teacher,
    required this.dashboard,
    required this.attendance,
    required this.medications,
    this.notificationCount,
    this.onStartReport,
    this.onOpenNotifications,
    this.onOpenAttendance,
    this.onOpenMedications,
    this.onEmergencyAlert,
    this.onHealth,
    this.onRefresh,
  });

  final Teacher teacher;
  final ClassDashboardSummary dashboard;
  final Map<String, AttendanceChildRecord> attendance;
  final MedicationsTodayData? medications;
  final int? notificationCount;
  final VoidCallback? onStartReport;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenMedications;
  final VoidCallback? onEmergencyAlert;
  final VoidCallback? onHealth;
  final Future<void> Function()? onRefresh;

  int get _presentCount => attendance.values
      .where((record) =>
          record.status == AttendanceStatus.arrived ||
          record.status == AttendanceStatus.late)
      .length;

  int get _lateCount => attendance.values
      .where((record) => record.status == AttendanceStatus.late)
      .length;

  int get _absentCount => attendance.values
      .where((record) =>
          record.status == AttendanceStatus.absent ||
          record.status == AttendanceStatus.excusedAbsent)
      .length;

  List<_CareItem> get _careItems {
    final children = {
      for (final item in dashboard.pendingChildren)
        item.child.childId: item.child,
    };
    final items = <_CareItem>[
      for (final item in dashboard.pendingChildren)
        if (item.child.allergy case final allergy?)
          _CareItem(
            name: item.child.displayName,
            detail: 'Dị ứng $allergy',
            kind: _CareKind.health,
          ),
      for (final entry in attendance.entries)
        if (entry.value.status == AttendanceStatus.late &&
            children[entry.key] != null)
          _CareItem(
            name: children[entry.key]!.displayName,
            detail: _lateLabel(entry.value),
            kind: _CareKind.late,
          ),
    ];
    return items.take(2).toList(growable: false);
  }

  String _lateLabel(AttendanceChildRecord record) {
    final time = record.checkInTime ?? record.expectedArrivalTime;
    return time == null || time.isEmpty ? 'Đã đến trễ' : 'Đã đến trễ lúc $time';
  }

  String _dateLabel(DateTime date) {
    const weekdays = [
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'Chủ nhật'
    ];
    return '${dashboard.classInfo.name} · ${weekdays[date.weekday - 1]}, '
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.now();
    final medicationDetail = medications == null
        ? 'Mở danh sách thuốc'
        : '${medications!.pendingCount} việc cần xử lý';
    final careItems = _careItems;

    return GardenVoiceScope(
      child: Builder(
        builder: (context) {
          final k = context.k;
          return RefreshIndicator(
            onRefresh: onRefresh ?? () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(17, 24, 17,
                  24 + GardenVoiceNavigationFrame.bottomPaddingOf(context)),
              children: [
                SizedBox(
                  height: 222,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -20,
                        right: -20,
                        top: 52,
                        height: 166,
                        child: Image.asset(
                          'assets/garden_voice/teacher_garden.png',
                          key: const ValueKey('garden-voice-garden-art'),
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                      ),
                      Positioned(
                        left: 4,
                        top: 18,
                        width: 286,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chào buổi sáng,',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: k.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              teacher.fullName,
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: k.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _dateLabel(date),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: k.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 7,
                        child: _NotificationButton(
                          count: notificationCount,
                          onPressed: onOpenNotifications,
                        ),
                      ),
                    ],
                  ),
                ),
                _ReportInvitation(
                  key: const ValueKey('garden-voice-report-invitation'),
                  onTap: onStartReport,
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 356 ||
                        MediaQuery.textScalerOf(context).scale(14) > 18;
                    final emergency = _QuickAction(
                      icon: 'assets/garden_voice/triangle_alert.svg',
                      iconBackground: k.badTint,
                      title: 'Báo sự cố',
                      detail: 'Gửi phụ huynh',
                      onTap: onEmergencyAlert,
                    );
                    final medication = _QuickAction(
                      icon: 'assets/garden_voice/pill.svg',
                      iconBackground: k.accentTint,
                      title: 'Thuốc hôm nay',
                      detail: medicationDetail,
                      onTap: onOpenMedications,
                    );
                    if (stacked) {
                      return Column(
                        children: [
                          emergency,
                          const Divider(height: 16),
                          medication,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: emergency),
                        VerticalDivider(
                            color: k.line,
                            width: 18,
                            indent: 11,
                            endIndent: 11),
                        Expanded(child: medication),
                      ],
                    );
                  },
                ),
                const Divider(height: 16),
                _AttendanceSummary(
                  hasAttendance: attendance.isNotEmpty,
                  presentCount: _presentCount,
                  totalChildren: dashboard.totalChildren,
                  lateCount: _lateCount,
                  absentCount: _absentCount,
                  onTap: onOpenAttendance,
                ),
                const Divider(height: 21),
                Text(
                  'Cần chú ý hôm nay',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: k.ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (careItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Chưa có lưu ý đặc biệt hôm nay.',
                      style: TextStyle(color: k.inkSoft),
                    ),
                  )
                else
                  Material(
                    color: k.surface,
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        for (var index = 0;
                            index < careItems.length;
                            index++) ...[
                          _CareRow(
                            item: careItems[index],
                            onTap: careItems[index].kind == _CareKind.health
                                ? onHealth
                                : onOpenAttendance,
                          ),
                          if (index < careItems.length - 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 52),
                              child: Divider(height: 1, color: k.line),
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({this.count, this.onPressed});

  final int? count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: k.infoTint,
          borderRadius: BorderRadius.circular(19),
          child: IconButton(
            tooltip: 'Thông báo',
            onPressed: onPressed,
            icon: ExcludeSemantics(
              child: SvgPicture.asset(
                'assets/garden_voice/bell.svg',
                width: 28,
                height: 28,
              ),
            ),
          ),
        ),
        if (count case final value? when value > 0)
          Positioned(
            top: -3,
            right: -5,
            child: Semantics(
              label: '$value thông báo chưa đọc',
              child: Container(
                constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: k.accent,
                  border: Border.all(color: k.surface, width: 1.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: k.surface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReportInvitation extends StatelessWidget {
  const _ReportInvitation({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Material(
      color: k.brandTint.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 145,
          child: Stack(
            children: [
              Positioned(
                right: -1,
                top: 0,
                child: Image.asset(
                  'assets/garden_voice/report_clipboard.png',
                  width: 139,
                  height: 139,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned(
                left: 21,
                top: 15,
                width: 225,
                child: Text(
                  'Ghi lại một ngày\ncủa bé',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.24,
                    fontWeight: FontWeight.w800,
                    color: k.brand,
                  ),
                ),
              ),
              Positioned(
                left: 21,
                top: 82,
                width: 225,
                child: Text(
                  'Ăn, ngủ, học và những điều cần lưu ý.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.3, color: k.inkSoft),
                ),
              ),
              Positioned(
                left: 21,
                bottom: 15,
                width: 160,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bắt đầu báo cáo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: k.brand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExcludeSemantics(
                      child: SvgPicture.asset(
                        'assets/garden_voice/chevron_right.svg',
                        width: 19,
                        height: 19,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.detail,
    this.onTap,
  });

  final String icon;
  final Color iconBackground;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    return Semantics(
      button: true,
      label: '$title, $detail',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: largeText ? 96 : 52,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ExcludeSemantics(
                    child: SvgPicture.asset(icon, width: 24, height: 24),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: largeText ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: k.ink,
                        ),
                      ),
                      Text(
                        detail,
                        maxLines: largeText ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: k.inkSoft),
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: SvgPicture.asset(
                    'assets/garden_voice/chevron_right.svg',
                    width: 16,
                    height: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({
    required this.hasAttendance,
    required this.presentCount,
    required this.totalChildren,
    required this.lateCount,
    required this.absentCount,
    this.onTap,
  });

  final bool hasAttendance;
  final int presentCount;
  final int totalChildren;
  final int lateCount;
  final int absentCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final normalScale = MediaQuery.textScalerOf(context).scale(14) <= 18;
    final icon = ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/garden_voice/users_round.svg',
        width: 31,
        height: 31,
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Điểm danh hôm nay',
          style: TextStyle(
            fontSize: 14.2,
            height: 1.24,
            fontWeight: FontWeight.w800,
            color: k.ink,
          ),
        ),
        Text(
          hasAttendance
              ? '$presentCount/$totalChildren bé đã đến'
              : 'Chưa có dữ liệu điểm danh',
          style: TextStyle(fontSize: 14, height: 1.24, color: k.inkSoft),
        ),
      ],
    );
    final chevron = ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/garden_voice/chevron_right.svg',
        width: 15,
        height: 15,
      ),
    );
    final lateBadge = _AttendanceBadge(
      label: '$lateCount đến trễ',
      width: normalScale ? 75 : null,
      background: k.accentTint,
      foreground: k.warn,
    );
    final absentBadge = _AttendanceBadge(
      label: '$absentCount vắng',
      width: normalScale ? 59 : null,
      background: k.okTint,
      foreground: k.brand,
    );
    return Semantics(
      key: const ValueKey('garden-voice-attendance-summary'),
      button: true,
      label: 'Điểm danh hôm nay',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: normalScale ? 9.5 : 8),
            child: normalScale
                ? Row(
                    children: [
                      icon,
                      const SizedBox(width: 9),
                      Expanded(child: text),
                      if (hasAttendance) ...[
                        const SizedBox(width: 8),
                        lateBadge,
                        const SizedBox(width: 8),
                        absentBadge,
                      ],
                      const SizedBox(width: 8),
                      chevron,
                    ],
                  )
                : Wrap(
                    spacing: 9,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      icon,
                      SizedBox(width: 147, child: text),
                      if (hasAttendance) ...[lateBadge, absentBadge],
                      chevron,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceBadge extends StatelessWidget {
  const _AttendanceBadge({
    required this.label,
    this.width,
    required this.background,
    required this.foreground,
  });

  final String label;
  final double? width;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: width == null ? 8 : 6,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              height: 1.24,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      );
}

enum _CareKind { health, late }

class _CareItem {
  const _CareItem({
    required this.name,
    required this.detail,
    required this.kind,
  });

  final String name;
  final String detail;
  final _CareKind kind;
}

class _CareRow extends StatelessWidget {
  const _CareRow({required this.item, this.onTap});

  final _CareItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final isHealth = item.kind == _CareKind.health;
    final pair = isHealth ? (k.accentTint, k.accentDeep) : (k.badTint, k.bad);
    final words = item.name.trim().split(RegExp(r'\s+'));
    final initials = words.length > 1
        ? '${words[0].characters.first}${words.last.characters.first}'
        : words.first.characters.first;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pair.$1,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                initials.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: pair.$2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: k.ink,
                    ),
                  ),
                  Text(
                    item.detail,
                    style: TextStyle(fontSize: 13.5, color: k.inkSoft),
                  ),
                ],
              ),
            ),
            ExcludeSemantics(
              child: SvgPicture.asset(
                'assets/garden_voice/chevron_right.svg',
                width: 16,
                height: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
