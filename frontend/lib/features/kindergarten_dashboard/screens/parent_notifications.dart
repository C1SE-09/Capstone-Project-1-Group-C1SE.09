import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart'
    show FilterChipButton, kDateLabel, kWeekdayLabel;

enum _NotificationFilter {
  all('Tất cả', 'Chưa có thông báo.'),
  reports('Báo cáo', 'Chưa có báo cáo mới.'),
  health('Sức khỏe', 'Chưa có thông báo sức khỏe.'),
  leave('Đơn nghỉ', 'Chưa có đơn nghỉ mới.');

  const _NotificationFilter(this.label, this.emptyMessage);
  final String label;
  final String emptyMessage;
}

/// Nội dung inbox trong shell phụ huynh, giữ thanh điều hướng hiện có.
class ParentNotifications extends StatefulWidget {
  const ParentNotifications({
    super.key,
    required this.reports,
    required this.childName,
    required this.teacherName,
    required this.onOpenReport,
    required this.onMarkAllRead,
  });

  final List<DailyReport> reports;
  final String childName;
  final String teacherName;
  final ValueChanged<DailyReport> onOpenReport;
  final VoidCallback onMarkAllRead;

  @override
  State<ParentNotifications> createState() => _ParentNotificationsState();
}

class _ParentNotificationsState extends State<ParentNotifications> {
  final _filterScroll = ScrollController();
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  void dispose() {
    _filterScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    // shortcut: API chỉ có lịch sử báo cáo, nối hai nhóm còn lại khi có inbox backend.
    final reports = switch (_filter) {
      _NotificationFilter.all || _NotificationFilter.reports => widget.reports,
      _ => const <DailyReport>[],
    };
    final unread = reports.where((r) => r.status != ReportStatus.read).toList();
    final read = reports.where((r) => r.status == ReportStatus.read).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(KSpace.x5, KSpace.x4, KSpace.x5, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final title = Semantics(
                header: true,
                child: Text(
                  'Thông báo',
                  style: TextStyle(
                      fontSize: 24,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: k.ink),
                ),
              );
              final markRead = TextButton(
                onPressed: unread.isEmpty ? null : widget.onMarkAllRead,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Đánh dấu đã đọc',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: unread.isEmpty ? k.inkFaint : k.brand)),
              );
              final largeText = MediaQuery.textScalerOf(context).scale(14) > 16;
              if (constraints.maxWidth < 360 || largeText) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    Align(alignment: Alignment.centerRight, child: markRead),
                  ],
                );
              }
              return Row(
                children: [Expanded(child: title), markRead],
              );
            },
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(KSpace.x5, KSpace.x3, KSpace.x5, 0),
          child: SingleChildScrollView(
            controller: _filterScroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 7,
              children: [
                for (final filter in _NotificationFilter.values)
                  Semantics(
                    key: ValueKey('parent-notification-filter-${filter.name}'),
                    label: 'Bộ lọc ${filter.label.toLowerCase()}',
                    button: true,
                    selected: _filter == filter,
                    onTap: () => setState(() => _filter = filter),
                    child: ExcludeSemantics(
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: FilterChipButton(
                            label: filter.label,
                            selected: _filter == filter,
                            onTap: () => setState(() => _filter = filter),
                            unselectedTextColor: k.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KSpace.x2),
        Expanded(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(KSpace.x5, 0, KSpace.x5, KSpace.x6),
            children: [
              if (reports.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpace.x8),
                  child: Text(
                    _filter.emptyMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: k.inkSoft),
                  ),
                ),
              if (unread.isNotEmpty) ...[
                const _SectionTitle('Mới'),
                const SizedBox(height: KSpace.x2),
                for (final report in unread) ...[
                  _ReportNotification(
                    report: report,
                    childName: widget.childName,
                    teacherName: widget.teacherName,
                    onTap: () => widget.onOpenReport(report),
                  ),
                  const SizedBox(height: KSpace.x3),
                ],
              ],
              if (read.isNotEmpty) ...[
                const _SectionTitle('Trước đó'),
                const SizedBox(height: KSpace.x2),
                for (final report in read) ...[
                  _ReportNotification(
                    report: report,
                    childName: widget.childName,
                    teacherName: widget.teacherName,
                    onTap: () => widget.onOpenReport(report),
                  ),
                  const SizedBox(height: KSpace.x3),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: context.k.ink,
        ),
      );
}

class _ReportNotification extends StatelessWidget {
  const _ReportNotification({
    required this.report,
    required this.childName,
    required this.teacherName,
    required this.onTap,
  });

  final DailyReport report;
  final String childName;
  final String teacherName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final unread =
        report.status != ReportStatus.read || report.hasUnreadResponses;
    // published_at chỉ có ngày; không tự suy ra giờ gửi báo cáo.
    final dateLabel =
        DateFormat('dd/MM').format(report.publishedAt ?? report.reportDate);
    final today = DateUtils.isSameDay(report.reportDate, DateTime.now());
    final details = [
      if (report.eating?.trim().isNotEmpty == true) 'Ăn uống',
      if (report.sleeping?.trim().isNotEmpty == true) 'Giấc ngủ',
      if (report.activitiesText?.trim().isNotEmpty == true) 'Hoạt động',
    ].join(' · ');
    final weekday = kWeekdayLabel(report.reportDate, capitalize: false);
    final description = details.isNotEmpty
        ? '$details của $childName ${today ? 'hôm nay' : weekday}'
        : report.summaryText?.trim().isNotEmpty == true
            ? report.summaryText!.trim()
            : '$teacherName đã gửi báo cáo ngày ${kDateLabel(report.reportDate)}.';
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: unread ? k.lineStrong : k.line),
    );

    return Semantics(
      label: unread ? 'Chưa đọc' : 'Đã đọc',
      child: Material(
        color: k.reviewSurface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/garden_voice/parent_notification_artist_palette.svg',
                        width: 28,
                        height: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: KSpace.x3),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: KSpace.x2,
                          runSpacing: KSpace.x1,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: KSpace.x2, vertical: KSpace.x1),
                              decoration: BoxDecoration(
                                color: k.activityRowTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'BÁO CÁO',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w700,
                                  color: k.brand,
                                ),
                              ),
                            ),
                            Text(dateLabel,
                                style:
                                    TextStyle(fontSize: 12, color: k.inkSoft)),
                            if (unread)
                              SvgPicture.asset(
                                  'assets/notifications/unread_dot.svg'),
                          ],
                        ),
                        const SizedBox(height: KSpace.x1),
                        Text(
                          today
                              ? 'Báo cáo ngày đã sẵn sàng'
                              : 'Báo cáo ngày $weekday',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: k.ink),
                        ),
                        const SizedBox(height: KSpace.x1),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, height: 1.4, color: k.inkSoft),
                        ),
                      ],
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
