// frontend/lib/presentation/parent/pages/parent_screen.dart
// =========================================================
// Màn "Tổng quan" của phụ huynh (MÀN 3 trong Figma).
//
// Cũng theo pattern giống TeacherScreen:
//   - Đọc data từ [ParentHomeController], không tự hardcode.
//   - Có nút ← (goback) đưa về trang login.

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/core/utils/date_formatter.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/presentation/parent/controllers/parent_home_controller.dart';
import 'package:adark_frontend/presentation/shared/view_state.dart';
import 'package:adark_frontend/presentation/shared/widgets/app_error_widget.dart';
import 'package:adark_frontend/presentation/shared/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  late final ParentHomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ParentHomeController()..load();
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
        title: Text(l10n.parentTitle),
        leading: IconButton(
          tooltip: l10n.backToLogin,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'), // ← NÚT GOBACK
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return switch (_controller.state) {
            ViewState.loading =>
              LoadingWidget(message: l10n.loading),
            ViewState.error => AppErrorWidget(
                message: _controller.error ?? l10n.error,
                onRetry: _controller.load,
              ),
            ViewState.success => _buildContent(context, l10n),
          };
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    final parent = _controller.parent;
    final childOverview = _controller.childOverview;

    if (parent == null || childOverview == null) {
      return Center(child: Text(l10n.noData));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreeting(parent.fullName, l10n),
          const SizedBox(height: 20),
          _buildReadyBanner(childOverview, l10n),
          const SizedBox(height: 20),
          _buildChildCard(childOverview, l10n),
          const SizedBox(height: 24),
          _buildTodayReport(l10n),
          const SizedBox(height: 24),
          _buildRecentReports(l10n),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TỪNG KHỐI UI
  // ══════════════════════════════════════════════════════════

  /// "Xin chào, Phụ huynh bé Nhím".
  Widget _buildGreeting(String name, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.helloParent,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Banner xanh "Báo cáo hôm nay... đã sẵn sàng".
  Widget _buildReadyBanner(ChildOverview overview, AppLocalizations l10n) {
    final todayReport = _controller.todayReport;

    // Chỉ hiện banner nếu báo cáo hôm nay đã Published.
    if (todayReport == null || todayReport.status != ReportStatus.published) {
      return _emptyBanner(overview, l10n);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.childTodayReport(overview.child.fullName),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.teacherSentReport(
                    overview.teacherName,
                    formatDDMMYYYY(todayReport.reportDate),
                  ),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBanner(ChildOverview overview, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.noReportToday(overview.child.fullName),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Card con: avatar + tên + "Lớp Mầm 1 · Cô Hà".
  Widget _buildChildCard(ChildOverview overview, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              _initials(overview.child.fullName),
              style: const TextStyle(
                color: AppColors.primary,
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
                  overview.child.fullName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.childCard(overview.className, overview.teacherName),
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

  /// "Báo cáo hôm nay".
  Widget _buildTodayReport(AppLocalizations l10n) {
    final todayReport = _controller.todayReport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.todayReport),
        const SizedBox(height: 12),
        _reportTile(
          icon: Icons.description_outlined,
          title: todayReport == null ? l10n.noReport : l10n.reportReady,
          subtitle: todayReport == null
              ? l10n.noTodayReport
              : formatDDMMYYYY(todayReport.reportDate),
          highlighted: todayReport != null,
        ),
      ],
    );
  }

  /// "Báo cáo gần đây" — danh sách.
  Widget _buildRecentReports(AppLocalizations l10n) {
    final reports = _controller.recentReports;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.recentReports),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < reports.length; i++) ...[
                _reportTile(
                  icon: Icons.description_outlined,
                  title: formatDDMMYYYY(reports[i].reportDate),
                  subtitle: reports[i].status.label,
                  showChevron: true,
                  isFlat: true,
                ),
                if (i != reports.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(height: 1, color: AppColors.divider),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 1 dòng báo cáo (dùng chung cho "hôm nay" và "gần đây").
  Widget _reportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool highlighted = false,
    bool showChevron = false,
    bool isFlat = false,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: highlighted ? AppColors.primaryLight : AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: highlighted ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (showChevron)
            const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
        ],
      ),
    );

    if (isFlat) return content;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }

  /// Chữ cái đầu tên: "Nguyễn Thị Nhím" → "NN".
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

/// Tiêu đề section nhỏ (tái sử dụng).
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
