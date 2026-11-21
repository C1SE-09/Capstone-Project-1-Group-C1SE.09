import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart'
    as domain_status;

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/report_discussion_section.dart';


/// Sheet báo cáo hằng ngày — mở từ card báo cáo, danh sách gần đây,
/// hoặc push notification.
Future<void> showParentReportSheet(
  BuildContext context, {
  required DailyReport? report,
  required String childName,
  required String teacherName,
  HttpDashboardRepository? repository,
  ValueChanged<DailyReport>? onReportRead,
}) {
  return showKSheet(
    context,
    GardenVoiceScope(
      child: _ParentReportBody(
        report: report,
        childName: childName,
        teacherName: teacherName,
        repository: repository,
        onReportRead: onReportRead,
      ),
    ),
  );
}

class _ParentReportBody extends StatefulWidget {
  const _ParentReportBody({
    required this.report,
    required this.childName,
    required this.teacherName,
    this.repository,
    this.onReportRead,
  });

  final DailyReport? report;
  final String childName;
  final String teacherName;
  final HttpDashboardRepository? repository;
  final ValueChanged<DailyReport>? onReportRead;

  @override
  State<_ParentReportBody> createState() => _ParentReportBodyState();
}

class _ParentReportBodyState extends State<_ParentReportBody> {
  late DailyReport? _currentReport = widget.report;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void didUpdateWidget(_ParentReportBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.report?.dailyReportId != oldWidget.report?.dailyReportId) {
      _currentReport = widget.report;
      _markRead();
    }
  }

  void _markRead() {
    final rep = _currentReport;
    if (rep != null &&
        rep.status != domain_status.ReportStatus.read &&
        rep.status != domain_status.ReportStatus.draft) {
      widget.repository?.markReportAsRead(rep.dailyReportId).then((updated) {
        if (mounted) setState(() => _currentReport = updated);
        widget.onReportRead?.call(updated);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _currentReport;
    final reportDate = report?.reportDate;
    final dayName =
        reportDate == null ? null : kWeekdayLabel(reportDate);
    final date = reportDate == null
        ? null
        : '$dayName · ${DateFormat('dd/MM').format(reportDate)}';

    // Chỉ hiển thị các mục có dữ liệu thực tế được giáo viên nhập/ghi âm
    final eating = _nonEmpty(report?.eating);
    final sleeping = _stripSleepMinutes(report?.sleeping);
    final activities = _nonEmpty(report?.activitiesText);
    final mood = _nonEmpty(report?.mood);
    final health = _nonEmpty(report?.health);
    final note = _nonEmpty(report?.summaryText);

    final hasAnyData = eating != null ||
        sleeping != null ||
        activities != null ||
        mood != null ||
        health != null ||
        note != null;

    final hasReportId = report != null && report.dailyReportId.isNotEmpty;

    final reportContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/garden_voice/teacher_garden.png',
            width: double.infinity,
            height: 106,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: KSpace.x3),
        if (eating != null)
          _ReportField(
              iconAsset: 'assets/garden_voice/review_bowl.svg',
              label: context.l10n?.categoryMeal ?? 'Ăn uống',
              value: eating),
        if (sleeping != null)
          _ReportField(
              iconAsset: 'assets/garden_voice/review_moon.svg',
              label: context.l10n?.categorySleep ?? 'Giấc ngủ',
              value: sleeping),
        if (activities != null)
          _ReportField(
              iconAsset: 'assets/garden_voice/review_artist_palette.svg',
              label: context.l10n?.categoryActivity ?? 'Hoạt động',
              value: activities),
        if (mood != null)
          _ReportField(
              icon: Icons.sentiment_satisfied_outlined,
              label: context.l10n?.categoryMood ?? 'Tâm trạng',
              value: mood),
        if (health != null)
          _ReportField(
              icon: Icons.health_and_safety_outlined,
              label: context.l10n?.categoryHealth ?? 'Sức khỏe',
              value: health),
        if (note != null)
          _ReportField(
              icon: Icons.edit_note,
              label: context.l10n?.parentTeacherNoteTitle(widget.teacherName) ?? 'Lời nhắn của ${widget.teacherName}',
              value: note,
              highlighted: true),
        if (!hasAnyData)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                context.l10n?.parentReportNoDetails ?? 'Chưa có thông tin ghi nhận cho ngày này.',
                style: TextStyle(
                    color: context.k.inkFaint, fontSize: 13),
              ),
            ),
          ),
        const SizedBox(height: KSpace.x3),
        KButton(
          label: context.l10n?.reportReadConfirmed ?? 'Đã đọc báo cáo ✓',
          secondary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );

    if (hasReportId) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            _buildHeaderRow(context, date),
            Expanded(
              child: ReportDiscussionBubble(
                reportId: report.dailyReportId,
                childName: widget.childName,
                teacherName: widget.teacherName,
                unreadCount: _currentReport?.unreadResponseCount ?? 0,
                onDiscussionUpdated: () {
                  if (!mounted) return;
                  if (_currentReport != null &&
                      _currentReport!.hasUnreadResponses) {
                    final updated =
                        _currentReport!.copyWith(unreadResponseCount: 0);
                    setState(() => _currentReport = updated);
                    widget.onReportRead?.call(updated);
                  }
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: KSpace.x3, bottom: 84),
                  child: reportContent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeaderRow(context, date),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: KSpace.x3),
              child: reportContent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, String? date) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n?.parentReportDatePrefix ?? 'Báo cáo ngày',
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: context.k.ink,
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n?.commonClose ?? 'Đóng báo cáo',
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          icon: SvgPicture.asset(
            'assets/garden_voice/parent_report_close.svg',
            width: 44,
            height: 44,
          ),
        ),
        if (date != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: context.k.brandTint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              date,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: context.k.brand,
              ),
            ),
          ),
      ],
    );
  }
}

/// A single labelled field card in the parent report view.
class _ReportField extends StatelessWidget {
  const _ReportField({
    required this.label,
    required this.value,
    this.icon,
    this.iconAsset,
    this.highlighted = false,
  });
  final IconData? icon;
  final String? iconAsset;
  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: KSpace.x2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? context.k.accentTint : context.k.reviewSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (iconAsset != null)
            SvgPicture.asset(iconAsset!)
          else if (icon != null)
            Icon(icon, size: 24, color: context.k.brand),
          if (icon != null || iconAsset != null)
            const SizedBox(width: KSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: highlighted
                            ? context.k.accentDeep
                            : context.k.ink)),
                const SizedBox(height: KSpace.x1),
                Text(value,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color:
                            highlighted ? context.k.ink : context.k.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Returns null if value is null or blank — used to skip empty report fields.
String? _nonEmpty(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _stripSleepMinutes(String? value) {
  final clean = _nonEmpty(value);
  if (clean == null) return null;
  final stripped = clean
      .replaceAll(
          RegExp(r'\s*(?:[·,–-]\s*)?\d+\s*phút\b', caseSensitive: false), '')
      .trim();
  return stripped.isEmpty ? clean : stripped;
}
