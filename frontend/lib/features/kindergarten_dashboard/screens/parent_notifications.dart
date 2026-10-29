import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

enum _NotificationFilter {
  all('Tất cả', 'Chưa có thông báo.'),
  reports('Báo Cáo', 'Chưa có báo cáo mới.'),
  health('Sức khoẻ', 'Chưa có thông báo sức khoẻ.'),
  attendance('Điểm danh', 'Chưa có thông báo điểm danh.');

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
    required this.onBack,
    required this.onSettings,
  });

  final List<DailyReport> reports;
  final String childName;
  final String teacherName;
  final ValueChanged<DailyReport> onOpenReport;
  final VoidCallback onBack;
  final VoidCallback onSettings;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(KSpace.x3, KSpace.x2, KSpace.x3, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Quay lại',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 20),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Thông báo',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: 19,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: k.ink),
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onSettings,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Cài đặt', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(KSpace.x5, 0, KSpace.x5, KSpace.x3),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 3, color: k.line),
              ),
              Scrollbar(
                controller: _filterScroll,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 4,
                radius: const Radius.circular(KSpace.x1),
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _filterScroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: KSpace.x2),
                  child: Row(
                    spacing: 7,
                    children: [
                      for (final filter in _NotificationFilter.values)
                        ChoiceChip(
                          label: Text(filter.label),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                          showCheckmark: false,
                          selectedColor: k.ink,
                          backgroundColor: k.surfaceSunken,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 11),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: _filter == filter ? k.surface : k.ink,
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: CardTheme(
            data: Theme.of(context).cardTheme.copyWith(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KRadii.card)),
                ),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(KSpace.x5, 0, KSpace.x5, KSpace.x6),
              itemCount: reports.isEmpty ? 1 : reports.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: KSpace.x4),
              itemBuilder: (context, index) {
                if (reports.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpace.x8),
                    child: Text(
                      _filter.emptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: k.inkSoft),
                    ),
                  );
                }
                final report = reports[index];
                return _ReportNotification(
                  report: report,
                  childName: widget.childName,
                  teacherName: widget.teacherName,
                  onTap: () => widget.onOpenReport(report),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
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
    final unread = report.status != ReportStatus.read;
    // published_at của API là ngày, không có giờ gửi để hiển thị.
    final dateLabel =
        DateFormat('dd/MM').format(report.publishedAt ?? report.reportDate);
    final today = DateUtils.isSameDay(report.reportDate, DateTime.now());
    final words = teacherName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words.reversed
        .take(2)
        .toList()
        .reversed
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();

    return Semantics(
      label: unread ? 'Chưa đọc' : 'Đã đọc',
      child: KCard(
        color: unread ? k.brandTint : k.surface,
        padding: unread
            ? const EdgeInsets.all(KSpace.x3)
            : const EdgeInsets.symmetric(horizontal: 2, vertical: KSpace.x1),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unread ? k.surface : k.brandTint,
                  borderRadius: BorderRadius.circular(KRadii.card),
                ),
                child: Text(initials.isEmpty ? 'BC' : initials,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: k.brand)),
              ),
            ),
            const SizedBox(width: KSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: KSpace.x1,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: KSpace.x2,
                      runSpacing: KSpace.x1,
                      children: [
                        Text('BÁO CÁO NGÀY',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .6,
                              color: k.inkSoft,
                            )),
                        Text(dateLabel,
                            style: TextStyle(
                                fontSize: 11, height: 1.25, color: k.inkSoft)),
                      ],
                    ),
                  ),
                  Text(
                    today
                        ? 'Báo cáo hôm nay của bé $childName đã sẵn sàng'
                        : 'Báo cáo ngày ${kDateLabel(report.reportDate)} của bé $childName',
                    style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: k.ink),
                  ),
                  Text(
                    '${teacherName.trim().isEmpty ? 'Giáo viên' : teacherName} đã gửi báo cáo ngày ${kDateLabel(report.reportDate)}.',
                    style:
                        TextStyle(fontSize: 13, height: 1.3, color: k.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
