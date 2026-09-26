// frontend/lib/presentation/teacher/pages/activity_recording_screen.dart

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/presentation/teacher/controllers/activity_recording_controller.dart';
import 'package:adark_frontend/presentation/parent/pages/child_recording_screen.dart';
import 'package:adark_frontend/presentation/shared/view_state.dart';
import 'package:adark_frontend/presentation/shared/widgets/app_error_widget.dart';
import 'package:adark_frontend/presentation/shared/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class ActivityRecordingScreen extends StatefulWidget {
  const ActivityRecordingScreen({super.key, this.classId = 'aaaaaaaa-0000-0000-0000-000000000001'});

  final String classId;

  @override
  State<ActivityRecordingScreen> createState() =>
      _ActivityRecordingScreenState();
}

class _ActivityRecordingScreenState extends State<ActivityRecordingScreen> {
  late final ActivityRecordingController _controller;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _controller = ActivityRecordingController()..load(widget.classId);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        titleSpacing: 20,
        title: Text(l10n.activityRecording),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/teacher'),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return switch (_controller.state) {
            ViewState.loading =>
              LoadingWidget(message: l10n.loadingList),
            ViewState.error => AppErrorWidget(
                message: _controller.error ?? l10n.errorList,
                onRetry: () => _controller.load(widget.classId),
              ),
            ViewState.success => _buildContent(l10n),
          };
        },
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    final children = _controller.filteredChildren;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            '${_controller.classInfo?.name ?? l10n.className} · '
            '${children.length} ${l10n.childrenCount}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Text(
            l10n.selectChild,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            onChanged: _controller.setQuery,
            decoration: InputDecoration(
              hintText: l10n.searchChild,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _controller.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _controller.setQuery('');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: children.isEmpty
              ? Center(child: Text(l10n.noChildFound))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _childCard(children[index], l10n),
                ),
        ),
      ],
    );
  }

  Widget _childCard(Child child, AppLocalizations l10n) {
    final hasRecording = _controller.hasReportToday(child.childId);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showRecordingMessage(child),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  _initials(child.fullName),
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
                      child.fullName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasRecording
                          ? l10n.childRecorded
                          : l10n.childNotRecorded,
                      style: TextStyle(
                        color: hasRecording
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hasRecording
                    ? Icons.check_circle_outline
                    : Icons.mic_none_rounded,
                color:
                    hasRecording ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordingMessage(Child child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChildRecordingScreen(
          child: child,
          teacherId: 'bbbbbbbb-0000-0000-0000-000000000001',
          classId: widget.classId,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
