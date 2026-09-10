// frontend/lib/presentation/screens/recording_screen.dart
// ==========================================================
// Task #58: RecordingScreen
//
// UI states:
//   [_UploadState.idle]        – ready, buttons enabled
//   [_UploadState.uploading]   – progress bar shown, buttons disabled
//   [_UploadState.transcribing]– spinner + "Transcribing…" message
//   [_UploadState.failed]      – "Upload failed" banner + Retry button
//
// Usage (push from TeacherDashboard or via GoRouter):
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => RecordingScreen(
//       filePath: '/data/.../recording.m4a',
//       classId: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
//       teacherId: 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy',
//     ),
//   ));


import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/presentation/screens/extraction_results_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Internal state enum
// ---------------------------------------------------------------------------

enum _UploadState { idle, uploading, transcribing, ready, failed }

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

  bool _isSaving = false;
  late final TextEditingController _transcriptController;
  late final FocusNode _focusNode;

  late final TeacherRepositoryBase _repo;
  late final AnimationController _pulseController;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _repo = widget._repository ?? TeacherRepository();
    _transcriptController = TextEditingController();
    _focusNode = FocusNode();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _focusNode.dispose();
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
      _result = record;

      if (record.status == 'completed') {
        _transcriptController.text = record.effectiveTranscript;
        setState(() {
          _state = _UploadState.ready;
        });
      } else {
        setState(() {
          _state = _UploadState.transcribing;
        });
        _pollStatus(record.id);
      }
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

  Future<void> _pollStatus(String voiceId) async {
    while (mounted && _state == _UploadState.transcribing) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || _state != _UploadState.transcribing) break;

      try {
        final updated = await _repo.getVoiceRecord(
          voiceId: voiceId,
          teacherId: widget.teacherId,
        );

        if (!mounted) break;
        if (updated.status == 'completed') {
          _transcriptController.text = updated.effectiveTranscript;
          setState(() {
            _result = updated;
            _state = _UploadState.ready;
          });
          break;
        } else if (updated.status == 'failed') {
          setState(() {
            _state = _UploadState.failed;
            _errorMessage = 'Phiên âm âm thanh thất bại.';
          });
          break;
        }
      } catch (_) {
        // Polling retry
      }
    }
  }

  Future<void> _saveTranscript() async {
    final result = _result;
    if (result == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedRecord = await _repo.updateTranscript(
        voiceId: result.id,
        editedTranscript: _transcriptController.text,
        teacherId: widget.teacherId,
      );

      if (!mounted) return;
      setState(() {
        _result = updatedRecord;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu bản chỉnh sửa phiên âm!')),
      );
    } on TeacherRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lưu thất bại: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
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
            _UploadState.ready => _buildReadyBody(colorScheme, textTheme),
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
                color: cs.onSurface.withAlpha((0.6 * 255).round()),
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
                backgroundColor: cs.surfaceContainerHighest,
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
                color: cs.onSurface.withAlpha((0.5 * 255).round()),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Transcribing: AI model processing spinner while waiting for Celery worker.
  Widget _buildTranscribingBody(ColorScheme cs, TextTheme tt) {
    return Center(
      key: const ValueKey('transcribing'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulse animation for AI transcription
            FadeTransition(
              opacity: _pulseController,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 54,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'AI đang phân tích & phiên âm bài giảng…',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Mô hình PhoWhisper đang chuyển đổi âm thanh thành văn bản.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withAlpha((0.6 * 255).round()),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ready: Transcript is loaded! Display editable text field + Save button + Proceed to Extract.
  Widget _buildReadyBody(ColorScheme cs, TextTheme tt) {
    return SingleChildScrollView(
      key: const ValueKey('ready'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 28,
                  color: cs.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tải lên & Phiên âm hoàn tất',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'ID: ${_result?.id ?? '—'}',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withAlpha((0.5 * 255).round()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Văn bản phiên âm',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              if (_result?.editedTranscript != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Đã chỉnh sửa',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Multi-line TextFormField (Directly editable, no state rebuilds while typing)
          TextFormField(
            controller: _transcriptController,
            focusNode: _focusNode,
            minLines: 4,
            maxLines: 8,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: tt.bodyLarge?.copyWith(height: 1.4),
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
              return Text(
                '$currentLength ký tự',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withAlpha((0.6 * 255).round()),
                  fontWeight: FontWeight.w500,
                ),
              );
            },
            decoration: InputDecoration(
              hintText: 'Chưa có dữ liệu phiên âm...',
              filled: true,
              fillColor: cs.surfaceContainerHighest.withAlpha((0.5 * 255).round()),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),

          // Action: Save Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveTranscript,
              icon: _isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isSaving ? 'Đang lưu…' : 'Lưu bản chỉnh sửa',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: cs.secondary,
                foregroundColor: cs.onSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action: Proceed to Extract Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                final voiceId = _result?.id;
                if (voiceId != null && voiceId.isNotEmpty) {
                  try {
                    context.push(
                      '/extraction-results?voiceId=$voiceId&teacherId=${widget.teacherId}',
                    );
                  } catch (_) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExtractionResultsScreen(
                          voiceId: voiceId,
                          teacherId: widget.teacherId,
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text(
                'Tiến hành trích xuất',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary Action: Go back
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Quay lại trang chủ'),
            ),
          ),
        ],
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
                color: cs.errorContainer.withAlpha((0.5 * 255).round()),
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
