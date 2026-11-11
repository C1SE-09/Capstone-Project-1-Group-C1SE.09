import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum GardenVoiceClassTab { roster, attendance, leaveRequests, timetable }

class GardenVoiceClassHeader extends StatelessWidget {
  const GardenVoiceClassHeader({
    super.key,
    required this.className,
    required this.subtitle,
    required this.selectedTab,
    required this.onTabSelected,
    this.notificationCount,
    this.pendingLeaveCount,
    this.onSelectClass,
    this.onOpenNotifications,
  });

  final String className;
  final String subtitle;
  final GardenVoiceClassTab selectedTab;
  final ValueChanged<GardenVoiceClassTab> onTabSelected;
  final int? notificationCount;
  final int? pendingLeaveCount;
  final VoidCallback? onSelectClass;
  final VoidCallback? onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final largeText = MediaQuery.textScalerOf(context).scale(14) >= 24;
    final tabRowHeight = largeText ? 50.0 : 37.0;
    return ColoredBox(
      color: k.canvas,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: double.infinity,
              minHeight: largeText ? 160 : 114,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: 7,
                  top: 20,
                  width: 250,
                  height: 86,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/garden_voice/school_v2.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(21, 32, 78, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: onSelectClass,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                className,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.24,
                                  color: k.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            SvgPicture.asset(
                              'assets/garden_voice/chevron_down.svg',
                              width: 20,
                              height: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (subtitle.trim().isNotEmpty)
                        Text(
                          subtitle.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.24,
                            color: k.inkSoft,
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: 26,
                  top: 29,
                  child: _ClassNotifications(
                    count: notificationCount,
                    onTap: onOpenNotifications,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: tabRowHeight + 17,
            child: Column(
              children: [
                SizedBox(
                  height: tabRowHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ClassTabItem(
                          label: 'Danh sách',
                          selected: selectedTab == GardenVoiceClassTab.roster,
                          onTap: () =>
                              onTabSelected(GardenVoiceClassTab.roster),
                        ),
                        _ClassTabItem(
                          label: 'Điểm danh',
                          selected:
                              selectedTab == GardenVoiceClassTab.attendance,
                          onTap: () =>
                              onTabSelected(GardenVoiceClassTab.attendance),
                        ),
                        _ClassTabItem(
                          label: 'Đơn nghỉ',
                          selected:
                              selectedTab == GardenVoiceClassTab.leaveRequests,
                          badgeCount: pendingLeaveCount,
                          onTap: () =>
                              onTabSelected(GardenVoiceClassTab.leaveRequests),
                        ),
                        _ClassTabItem(
                          label: 'Lịch học',
                          selected:
                              selectedTab == GardenVoiceClassTab.timetable,
                          onTap: () =>
                              onTabSelected(GardenVoiceClassTab.timetable),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 0.6, color: k.line),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassNotifications extends StatelessWidget {
  const _ClassNotifications({this.count, this.onTap});

  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final unread = count ?? 0;
    return Semantics(
      button: onTap != null,
      label: unread > 0 ? 'Thông báo, $unread chưa đọc' : 'Thông báo',
      child: Material(
        color: k.activityRowTint,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(
                  'assets/garden_voice/bell.svg',
                  width: 27.6,
                  height: 27.6,
                ),
                if (unread > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: k.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: k.ink,
                        ),
                      ),
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

class _ClassTabItem extends StatelessWidget {
  const _ClassTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final count = badgeCount ?? 0;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.2,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        height: 1.24,
                        color: selected ? k.brand : k.inkSoft,
                      ),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: k.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 99 ? '99' : '$count',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          height: 1.24,
                          color: k.ink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 5,
                width: selected ? 84 : double.infinity,
                decoration: BoxDecoration(
                  color: selected ? k.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
