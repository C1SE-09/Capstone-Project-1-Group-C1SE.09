// frontend/lib/presentation/recording/pages/recording_screen.dart
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

import 'dart:typed_data';

import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/presentation/recording/pages/extraction_results_screen.dart';
import 'package:adark_frontend/presentation/recording/pages/report_processing_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _UploadState { idle, uploading, transcribing, ready, failed }

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.filePath,
    required this.classId,
    required this.teacherId,
    this.childId,
    this.childName,
    this.childInitials,
    this.classTeacherInfo,
    this.fileBytes,
    this.fileName,
    TeacherRepositoryBase? repository,
  }) : _repository = repository;

  /// Absolute path to the audio file that was recorded.
  final String filePath;

  /// Optional audio bytes when the recording is selected from browser/web.
  final Uint8List? fileBytes;

  /// Original file name used when sending bytes from a web upload.
  final String? fileName;

  /// UUID of the class this recording belongs to.
  final String classId;

  /// UUID of the teacher (MVP: passed in directly).
  final String teacherId;

  /// UUID of the child associated with this recording.
  final String? childId;
  final String? childName;
  final String? childInitials;
  final String? classTeacherInfo;

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
        fileBytes: widget.fileBytes,
        fileName: widget.fileName,
        classId: widget.classId,
        teacherId: widget.teacherId,
        childId: widget.childId,
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? sent / total : -1;
          });
        },
      );

      if (!mounted) return;
      _result = record;

      final childObj = Child(
        childId: widget.childId ?? '11111111-1111-1111-1111-111111111111',
        fullName: widget.childName ?? 'Bé Nguyễn Văn A',
        gender: 'male',
        dateOfBirth: DateTime(2021, 5, 10),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReportProcessingScreen(
            child: childObj,
            phase: ProcessingPhase.transcribe,
            voiceId: record.id,
            teacherId: widget.teacherId,
            classId: widget.classId,
            audioFilePath: widget.filePath,
            transcript: record.effectiveTranscript,
            repository: _repo,
          ),
        ),
      );
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



  void _navigateToExtractionResults(String voiceId) {
    if (!mounted) return;
    try {
      final childNameParam = widget.childName != null
          ? '&childName=${Uri.encodeComponent(widget.childName!)}'
          : '';
      final childInitialsParam = widget.childInitials != null
          ? '&childInitials=${Uri.encodeComponent(widget.childInitials!)}'
          : '';
      final classTeacherParam = widget.classTeacherInfo != null
          ? '&classTeacherInfo=${Uri.encodeComponent(widget.classTeacherInfo!)}'
          : '';

      context.pushReplacement(
        '/extraction-results?voiceId=$voiceId&teacherId=${widget.teacherId}&childId=${widget.childId ?? ''}$childNameParam$childInitialsParam$classTeacherParam',
      );
    } catch (_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ExtractionResultsScreen(
            voiceId: voiceId,
            teacherId: widget.teacherId,
            childId: widget.childId,
            childName: widget.childName,
            childInitials: widget.childInitials,
            classTeacherInfo: widget.classTeacherInfo,
          ),
        ),
      );
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

  /// Idle: show file info, Confirm button, and Back button.
  Widget _buildIdleBody(ColorScheme cs, TextTheme tt) {
    final fileName = widget.filePath.split(RegExp(r'[\\/]')).last;

    return Center(
      key: const ValueKey('idle'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Audio file icon
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.audio_file_rounded,
                size: 58,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Xác nhận tệp âm thanh',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Highlighted File Name box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    cs.surfaceContainerHighest.withAlpha((0.6 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file_outlined,
                      color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      fileName.isNotEmpty ? fileName : 'tệp_âm_thanh',
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Confirm button (Tải lên MinIO & khởi chạy Celery task)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _startUpload,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'Xác nhận & Tải lên',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Back button (Quay lại màn hình trước)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text(
                  'Trở lại',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
              isIndeterminate ? 'Đang tải lên…' : 'Đang tải lên… $pct%',
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

  /// Transcribing: Uses ReportProcessingScreen (phase 1) instead of single spinner.
  Widget _buildTranscribingBody(ColorScheme cs, TextTheme tt) {
    final childObj = Child(
      childId: widget.childId ?? '11111111-1111-1111-1111-111111111111',
      fullName: widget.childName ?? 'Bé Nguyễn Văn A',
      gender: 'male',
      dateOfBirth: DateTime(2021, 5, 10),
    );

    return ReportProcessingScreen(
      key: const ValueKey('transcribing_processing_screen'),
      child: childObj,
      phase: ProcessingPhase.transcribe,
      voiceId: _result?.id,
      teacherId: widget.teacherId,
      classId: widget.classId,
      audioFilePath: widget.filePath,
      transcript: _result?.effectiveTranscript ?? '',
      repository: _repo,
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
            buildCounter: (context,
                {required currentLength, required isFocused, maxLength}) {
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
              fillColor:
                  cs.surfaceContainerHighest.withAlpha((0.5 * 255).round()),
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
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                  _navigateToExtractionResults(voiceId);
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
