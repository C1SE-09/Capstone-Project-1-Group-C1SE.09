// frontend/lib/presentation/teacher/pages/teacher_screen.dart
// =========================================================

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/core/utils/date_formatter.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/presentation/teacher/controllers/teacher_home_controller.dart';
import 'package:adark_frontend/presentation/teacher/pages/activity_recording_screen.dart';
import 'package:adark_frontend/presentation/shared/view_state.dart';
import 'package:adark_frontend/presentation/shared/widgets/app_error_widget.dart';
import 'package:adark_frontend/presentation/shared/widgets/loading_widget.dart';
import 'package:adark_frontend/presentation/shared/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  late final TeacherHomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TeacherHomeController()..load();
  }

  @override
  void dispose() {
    _controller.dispose(); // LUÔN dispose để tránh rò rỉ bộ nhớ
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      // ListenableBuilder: tự rebuild khi controller notifyListeners()
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          // Dựa vào state để hiển thị loading / error / content
          return switch (_controller.state) {
            ViewState.loading =>
              const LoadingWidget(message: 'Đang tải dữ liệu…'),
            ViewState.error => AppErrorWidget(
                message: _controller.error ?? 'Đã có lỗi xảy ra.',
                onRetry: _controller.load,
              ),
            ViewState.success => _buildContent(context),
          };
        },
      ),
    );
  }

  /// AppBar với nút ← goback về trang login.
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Tổng quan'),
      leading: IconButton(
        tooltip: 'Đăng xuất / về trang đăng nhập',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.go('/login'), // ← NÚT GOBACK
      ),
    );
  }

  /// Nội dung chính khi đã có dữ liệu.
  Widget _buildContent(BuildContext context) {
    final summary = _controller.summary;
    final teacher = _controller.teacher;

    if (summary == null || teacher == null) {
      return const Center(child: Text('Không có dữ liệu.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreeting(context, teacher, summary.classInfo.name),
          const SizedBox(height: 20),
          _buildProgressCard(context, summary),
          const SizedBox(height: 24),
          _buildStatsRow(context, summary),
          const SizedBox(height: 24),
          _buildMyClass(context, summary),
          const SizedBox(height: 24),
          _buildPendingList(context, summary),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TỪNG KHỐI UI
  // ══════════════════════════════════════════════════════════

  /// Header: "Chào buổi sáng, Cô Hà" + avatar.
  Widget _buildGreeting(
      BuildContext context, Teacher teacher, String className) {
    final timeGreeting = _timeGreeting(DateTime.now().hour);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeGreeting,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                teacher.fullName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatVNWeekdayDate(DateTime.now())} · $className',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Avatar = chữ cái đầu tên
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primaryLight,
          child: Text(
            _initials(teacher.fullName),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Card "Tiến độ hôm nay" + thanh tiến độ + nút ghi âm.
  Widget _buildProgressCard(BuildContext context, ClassDashboardSummary s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 12),
            blurRadius: 40,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tiến độ hôm nay',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${s.completedCount}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' / ${s.totalChildren} báo cáo hoàn thành',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '${s.percent}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Thanh tiến độ
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFEFEAE2),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${s.notCompletedCount} trẻ chưa có báo cáo hôm nay.',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Nút ghi âm
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => context.go(
                '/teacher/activity-recording?classId=${s.classInfo.classId}',
              ),
              icon: const Text('🎤', style: TextStyle(fontSize: 18)),
              label: const Text(
                'Bắt đầu ghi âm',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hàng 4 ô thống kê: Tổng / Đã hoàn thành / Bản nháp / Chưa ghi nhận.
  Widget _buildStatsRow(BuildContext context, ClassDashboardSummary s) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _statBox(context, '${s.totalChildren}', 'Trẻ trong\nlớp'),
          _statDivider(),
          _statBox(context, '${s.completedCount}', 'Đã hoàn\nthành'),
          _statDivider(),
          _statBox(context, '${s.draftCount}', 'Bản nháp'),
          _statDivider(),
          _statBox(context, '${s.missingCount}', 'Chưa\nghi nhận'),
        ],
      ),
    );
  }

  Widget _statBox(BuildContext context, String value, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 40, color: AppColors.divider);
  }

  /// "Lớp của tôi" — card thông tin lớp.
  Widget _buildMyClass(BuildContext context, ClassDashboardSummary s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lớp của tôi',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/class-detail', extra: s.classInfo.classId),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                        child: Text('👥', style: TextStyle(fontSize: 20))),
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
                          '${s.totalChildren} trẻ · ${s.teacherName}',
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
            ),
          ),
        ),
      ],
    );
  }

  /// "Cần xử lý" — danh sách trẻ chưa hoàn thành báo cáo.
  Widget _buildPendingList(BuildContext context, ClassDashboardSummary s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cần xử lý',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                _pendingTile(s.pendingChildren[i]),
                if (i != s.pendingChildren.length - 1)
                  const Divider(height: 1, color: AppColors.divider),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _pendingTile(ChildReportItem item) {
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
                if (item.updatedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${status?.label ?? 'Chưa có báo cáo'} · ${formatHHMM(item.updatedAt!)}',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Badge trạng thái (tái dùng StatusBadge có sẵn)
          StatusBadge(
            label: status?.label ?? 'Chưa có',
            type: _statusTypeFor(status),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════

  /// Map ReportStatus → StatusType (để đổ vào StatusBadge).
  StatusType _statusTypeFor(ReportStatus? status) {
    switch (status) {
      case ReportStatus.published:
        return StatusType.success;
      case ReportStatus.draft:
        return StatusType.warning;
      case ReportStatus.archived:
      case null:
        return StatusType.error; // "Chưa có"
    }
  }

  /// "Chào buổi sáng/chiều/tối" theo giờ.
  String _timeGreeting(int hour) {
    if (hour < 12) return 'Chào buổi sáng,';
    if (hour < 18) return 'Chào buổi chiều,';
    return 'Chào buổi tối,';
  }

  /// Lấy chữ cái đầu tên: "Cô Hà" → "CH", "Lê Thị Mèo" → "LM".
  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
