// frontend/lib/presentation/teacher/pages/class_report_list_screen.dart
// ================================================================
// Tab "Báo cáo lớp": liệt kê các lớp giáo viên đang phụ trách.
// Bấm một lớp → mở chi tiết báo cáo của lớp đó.

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/domain/entities/class/class_report_overview.dart';
import 'package:adark_frontend/presentation/teacher/controllers/class_report_list_controller.dart';
import 'package:adark_frontend/presentation/teacher/pages/class_detail_screen.dart';
import 'package:adark_frontend/presentation/shared/view_state.dart';
import 'package:adark_frontend/presentation/shared/widgets/app_error_widget.dart';
import 'package:adark_frontend/presentation/shared/widgets/loading_widget.dart';
import 'package:flutter/material.dart';

class ClassReportListScreen extends StatefulWidget {
  const ClassReportListScreen({super.key});

  @override
  State<ClassReportListScreen> createState() => _ClassReportListScreenState();
}

class _ClassReportListScreenState extends State<ClassReportListScreen> {
  late final ClassReportListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ClassReportListController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Báo cáo lớp'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return switch (_controller.state) {
            ViewState.loading => const LoadingWidget(message: 'Đang tải danh sách lớp…'),
            ViewState.error => AppErrorWidget(
                message: _controller.error ?? 'Không thể tải danh sách lớp.',
                onRetry: _controller.load,
              ),
            ViewState.success => _buildContent(),
          };
        },
      ),
    );
  }

  Widget _buildContent() {
    final classes = _controller.classes;
    if (classes.isEmpty) {
      return const Center(child: Text('Chưa có lớp nào được phân công.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: classes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _classCard(classes[index]),
    );
  }

  Widget _classCard(ClassReportOverview item) {
    final progress = item.progress.clamp(0.0, 1.0).toDouble();
    final classId = item.classInfo.classId.trim();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (classId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Không có mã lớp hợp lệ để mở chi tiết.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ClassDetailScreen(classId: classId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.classInfo.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.classInfo.gradeLabel ?? 'Lớp'} · '
                          '${item.classInfo.roomNumber ?? 'Chưa có phòng'}',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '${item.completedCount}/${item.totalChildren} báo cáo đã gửi',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _summaryChip(
                    '${item.totalChildren} trẻ',
                    AppColors.primaryLight,
                    AppColors.primary,
                  ),
                  _summaryChip(
                    '${item.draftCount} bản nháp',
                    AppColors.warningBg,
                    AppColors.warningFg,
                  ),
                  _summaryChip(
                    '${item.missingCount} chưa có',
                    AppColors.surfaceAlt,
                    AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
