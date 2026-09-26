// frontend/lib/presentation/teacher/pages/class_detail_screen.dart
// =========================================================
// Màn "Chi tiết lớp" (MÀN 2 trong Figma):
//   - Card lớp
//   - Danh sách "Cần xử lý" (đầy đủ)
//   - "Hoạt động gần đây" (TIMELINE)

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/core/utils/date_formatter.dart';
import 'package:adark_frontend/domain/entities/activity/activity_item.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/presentation/teacher/controllers/class_detail_controller.dart';
import 'package:adark_frontend/presentation/shared/view_state.dart';
import 'package:adark_frontend/presentation/shared/widgets/app_error_widget.dart';
import 'package:adark_frontend/presentation/shared/widgets/loading_widget.dart';
import 'package:adark_frontend/presentation/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({
    super.key,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.showBackButton = true,
  });

  final String classId;
  final bool showBackButton;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  late final ClassDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ClassDetailController();
    _controller.load(widget.classId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.classDetail),
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                tooltip: l10n.back,
                icon: const Icon(Icons.arrow_back_rounded),
                // Chỉ pop khi màn này được mở bằng route riêng.
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return switch (_controller.state) {
            ViewState.loading =>
              LoadingWidget(message: l10n.loading),
            ViewState.error => AppErrorWidget(
                message: _controller.error ?? l10n.error,
                onRetry: () => _controller.load(widget.classId),
              ),
            ViewState.success => _buildContent(l10n),
          };
        },
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    final summary = _controller.summary;
    if (summary == null) {
      return Center(child: Text(l10n.noData));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClassCard(summary, l10n),
          const SizedBox(height: 24),
          _buildPendingSection(summary, l10n),
          const SizedBox(height: 24),
          _buildTimeline(l10n),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TỪNG KHỐI UI
  // ══════════════════════════════════════════════════════════

  /// Card "Lớp của tôi".
  Widget _buildClassCard(ClassDashboardSummary s, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('👥', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.classInfo.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.totalChildren} ${l10n.children} · ${s.teacherName}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Cần xử lý" + danh sách đầy đủ các trẻ chưa hoàn thành.
  Widget _buildPendingSection(ClassDashboardSummary s, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.pending,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${s.pendingChildren.length} ${l10n.pendingCount}',
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < s.pendingChildren.length; i++) ...[
                _pendingTile(s.pendingChildren[i], l10n),
                if (i != s.pendingChildren.length - 1)
                  const Divider(height: 1, color: AppColors.divider),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _pendingTile(ChildReportItem item, AppLocalizations l10n) {
    final status = item.status;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              _initials(item.child.fullName),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.child.fullName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status == null
                      ? l10n.noReport
                      : item.updatedAt != null
                          ? '${status.label} · ${formatHHMM(item.updatedAt!)}'
                          : status.label,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: status?.label ?? l10n.noReport,
            type: _statusTypeFor(status),
          ),
        ],
      ),
    );
  }

  /// "Hoạt động gần đây" — TIMELINE (điểm mới trong bài này).
  Widget _buildTimeline(AppLocalizations l10n) {
    final activities = _controller.activities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recentActivity,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < activities.length; i++)
          _timelineItem(
            activity: activities[i],
            isLast: i == activities.length - 1,
          ),
      ],
    );
  }

  Widget _timelineItem({required ActivityItem activity, required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cột TRÁI: icon + đường nối dọc (nếu chưa phải item cuối)
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _activityIcon(activity.type),
                size: 17,
                color: AppColors.primary,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                color: AppColors.divider,
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Nội dung: tin nhắn + thời gian tương đối
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    activity.message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatTimeAgo(activity.occurredAt),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════

  /// Map loại hoạt động → icon.
  IconData _activityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.reportSent:
        return Icons.send_outlined;
      case ActivityType.reportReviewing:
        return Icons.schedule_outlined;
      case ActivityType.audioRecorded:
        return Icons.mic_outlined;
    }
  }

  StatusType _statusTypeFor(ReportStatus? status) {
    switch (status) {
      case ReportStatus.published:
        return StatusType.success;
      case ReportStatus.draft:
        return StatusType.warning;
      case ReportStatus.archived:
      case null:
        return StatusType.error;
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
