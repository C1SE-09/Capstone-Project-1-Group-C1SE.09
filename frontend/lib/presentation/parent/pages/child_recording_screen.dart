// frontend/lib/presentation/parent/pages/child_recording_screen.dart
// ================================================================

import 'dart:async';

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/presentation/recording/pages/transcript_review_screen.dart';
import 'package:adark_frontend/presentation/teacher/pages/manual_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum ChildRecordingState { idle, recording, recorded }

class ChildRecordingScreen extends StatefulWidget {
  const ChildRecordingScreen({
    super.key,
    required this.child,
    this.teacherId,
    this.classId,
  });

  final Child child;
  final String? teacherId;
  final String? classId;

  @override
  State<ChildRecordingScreen> createState() => _ChildRecordingScreenState();
}

class _ChildRecordingScreenState extends State<ChildRecordingScreen> {
  ChildRecordingState _state = ChildRecordingState.idle;
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    _timer?.cancel();
    setState(() {
      _state = ChildRecordingState.recording;
      _duration = Duration.zero;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _duration += const Duration(seconds: 1));
    });
  }

  void _stopRecording() {
    _timer?.cancel();
    _timer = null;
    setState(() => _state = ChildRecordingState.recorded);
  }

  void _recordAgain() {
    _timer?.cancel();
    setState(() {
      _state = ChildRecordingState.idle;
      _duration = Duration.zero;
    });
  }

  void _saveRecording() {
    // Điều hướng sang màn hình xem lại nội dung ghi âm
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TranscriptReviewScreen(
          child: widget.child,
          // Transcript mẫu — trong thực tế lấy từ backend sau khi upload
          transcript:
              'Hôm nay bé ${widget.child.displayName} ăn hết suất, ngủ khoảng 2 '
              'tiếng, sức khỏe bình thường và chơi ngoan với các bạn trong giờ '
              'hoạt động nhóm.',
          audioDuration: _duration.inSeconds > 0 ? _duration.inSeconds : 18,
          voiceId: null, // sẽ có sau khi upload thật
          teacherId: widget.teacherId,
          classId: widget.classId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Ghi âm hoạt động'),
        leading: IconButton(
          tooltip: 'Quay lại danh sách trẻ',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            children: [
              _buildChildHeader(),
              const SizedBox(height: 28),
              _buildRecordingCard(),
              const SizedBox(height: 20),
              _buildInstruction(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primaryLight,
          child: Text(
            _initials(widget.child.fullName),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.child.fullName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Lớp Mầm 1 · Ghi nhận hôm nay',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingCard() {
    final isRecording = _state == ChildRecordingState.recording;
    final isRecorded = _state == ChildRecordingState.recorded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _buildStateIcon(isRecording: isRecording, isRecorded: isRecorded),
          const SizedBox(height: 20),
          Text(
            isRecording
                ? 'Đang ghi âm...'
                : isRecorded
                    ? 'Đã ghi âm xong'
                    : 'Chưa ghi âm',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRecording
                ? 'Hãy nói về hoạt động của bé hôm nay'
                : isRecorded
                    ? 'Bản ghi đã sẵn sàng để nghe lại'
                    : 'Nhấn nút bên dưới để bắt đầu ghi nhận',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          _buildWaveform(isRecording: isRecording, isRecorded: isRecorded),
          const SizedBox(height: 14),
          Text(
            _formatDuration(_duration),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildMainAction(isRecording: isRecording, isRecorded: isRecorded),
          if (!isRecording && !isRecorded) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ManualReportScreen(
                      child: widget.child,
                      teacherId: widget.teacherId,
                      classId: widget.classId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Tạo báo cáo thủ công'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          if (isRecorded) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _recordAgain,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Ghi lại'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStateIcon(
      {required bool isRecording, required bool isRecorded}) {
    final color = isRecording
        ? AppColors.warningFg
        : isRecorded
            ? AppColors.primary
            : AppColors.textSecondary;
    final icon = isRecording
        ? Icons.mic_rounded
        : isRecorded
            ? Icons.check_rounded
            : Icons.mic_none_rounded;

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: isRecording
            ? AppColors.warningBg
            : isRecorded
                ? AppColors.primaryLight
                : AppColors.surfaceAlt,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 36),
    );
  }

  Widget _buildWaveform({required bool isRecording, required bool isRecorded}) {
    final active = isRecording || isRecorded;
    const heights = <double>[
      18,
      28,
      42,
      24,
      52,
      34,
      20,
      44,
      30,
      18,
      38,
      25,
      48,
      22,
      32
    ];

    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final height in heights)
            Container(
              width: 4,
              height: active ? height : 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainAction(
      {required bool isRecording, required bool isRecorded}) {
    if (isRecording) {
      return FilledButton.icon(
        onPressed: _stopRecording,
        icon: const Icon(Icons.stop_rounded),
        label: const Text('Dừng ghi âm'),
        style: _primaryButtonStyle(AppColors.warningFg),
      );
    }

    if (isRecorded) {
      return FilledButton.icon(
        onPressed: _saveRecording,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Lưu bản ghi'),
        style: _primaryButtonStyle(AppColors.primary),
      );
    }

    return FilledButton.icon(
      onPressed: _startRecording,
      icon: const Icon(Icons.mic_rounded),
      label: const Text('Bắt đầu ghi âm'),
      style: _primaryButtonStyle(AppColors.primary),
    );
  }

  ButtonStyle _primaryButtonStyle(Color color) {
    return FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildInstruction() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: AppColors.textTertiary, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Bản ghi âm sẽ được dùng để tạo báo cáo hoạt động cho phụ huynh.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
