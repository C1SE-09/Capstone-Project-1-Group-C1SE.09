/// frontend/lib/presentation/screens/recording_screen.dart
/// ==========================================================
/// Task #58: RecordingScreen
///
/// UI states:
///   [_UploadState.idle]        – ready, buttons enabled
///   [_UploadState.uploading]   – progress bar shown, buttons disabled
///   [_UploadState.transcribing]– spinner + "Transcribing…" message
///   [_UploadState.failed]      – "Upload failed" banner + Retry button
///
/// Usage (push from TeacherDashboard or via GoRouter):
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => RecordingScreen(
///       filePath: '/data/.../recording.m4a',
///       classId: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
///       teacherId: 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy',
///     ),
///   ));
library recording_screen;

import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Internal state enum
// ---------------------------------------------------------------------------

enum _UploadState { idle, uploading, transcribing, failed }

// ---------------------------------------------------------------------------
// Screen widget
// ---------------------------------------------------------------------------

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.filePath,
    required this.classId,
    required this.teacherId,
    TeacherRepositoryBase? repository,
  }) : _repository = repository;

  /// Absolute path to the audio file that was recorded.
  final String filePath;

  /// UUID of the class this recording belongs to.
  final String classId;

  /// UUID of the teacher (MVP: passed in directly).
  final String teacherId;

  /// Injected for testing; defaults to [TeacherRepository].
  final TeacherRepositoryBase? _repository;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with SingleTickerProviderStateMixin {
  // ------------------------------------------------------------------
  // State
  // ------------------------------------------------------------------

  _UploadState _state = _UploadState.idle;
  double _progress = 0.0; // 0.0 – 1.0; -1 = indeterminate
  String? _errorMessage;
  VoiceRecord? _result;

  late final TeacherRepositoryBase _repo;
  late final AnimationController _pulseController;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _repo = widget._repository ?? TeacherRepository();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  Future<void> _startUpload() async {
    setState(() {
      _state = _UploadState.uploading;
      _progress = 0.0;
      _errorMessage = null;
    });

    try {
      final record = await _repo.uploadAudio(
        filePath: widget.filePath,
        classId: widget.classId,
        teacherId: widget.teacherId,
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? sent / total : -1;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _result = record;
        _state = _UploadState.transcribing;
      });
    } on TeacherRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _UploadState.failed;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _UploadState.failed;
        _errorMessage = e.toString();
      });
    }
  }

  void _retry() => _startUpload();

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Ghi âm bài giảng'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: switch (_state) {
            _UploadState.idle => _buildIdleBody(colorScheme, textTheme),
            _UploadState.uploading =>
              _buildUploadingBody(colorScheme, textTheme),
            _UploadState.transcribing =>
              _buildTranscribingBody(colorScheme, textTheme),
            _UploadState.failed => _buildFailedBody(colorScheme, textTheme),
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // State widgets
  // ------------------------------------------------------------------

  /// Idle: show file info and Upload button.
  Widget _buildIdleBody(ColorScheme cs, TextTheme tt) {
    return Center(
      key: const ValueKey('idle'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Microphone icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                size: 64,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Tệp âm thanh đã sẵn sàng',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.filePath.split(RegExp(r'[\\/]')).last,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 48),
            // Upload button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _startUpload,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text(
                  'Tải lên & phiên âm',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Uploading: progress bar + percentage, buttons disabled.
  Widget _buildUploadingBody(ColorScheme cs, TextTheme tt) {
    final isIndeterminate = _progress < 0;
    final pct = isIndeterminate ? null : (_progress * 100).toStringAsFixed(0);

    return Center(
      key: const ValueKey('uploading'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated upload icon
            FadeTransition(
              opacity: _pulseController,
              child: Icon(
                Icons.cloud_upload_rounded,
                size: 80,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isIndeterminate
                  ? 'Đang tải lên…'
                  : 'Đang tải lên… $pct%',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: isIndeterminate ? null : _progress,
                minHeight: 10,
                backgroundColor: cs.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 40),
            // Disabled placeholder buttons
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: null, // disabled during upload
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Tải lên & phiên âm'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Vui lòng không đóng ứng dụng trong khi tải lên.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Transcribing: success + spinner.
  Widget _buildTranscribingBody(ColorScheme cs, TextTheme tt) {
    return Center(
      key: const ValueKey('transcribing'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success check
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 60,
                color: cs.secondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tải lên thành công!',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ID bản ghi: ${_result?.id ?? '—'}',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 40),
            // Done button (navigate back / to result)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(_result),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Quay lại trang chủ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Failed: error message + Retry button.
  Widget _buildFailedBody(ColorScheme cs, TextTheme tt) {
    return Center(
      key: const ValueKey('failed'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: cs.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 58,
                color: cs.onErrorContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tải lên thất bại',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.error,
              ),
            ),
            const SizedBox(height: 12),
            // Error detail banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage ?? 'Lỗi không xác định.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            // Retry button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Thử lại',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Cancel / go back
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Huỷ'),
            ),
          ],
        ),
      ),
    );
  }
}
