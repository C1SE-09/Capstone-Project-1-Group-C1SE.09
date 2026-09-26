import 'dart:async';
import 'dart:io';
import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/presentation/recording/pages/recording_screen.dart';
import 'package:adark_frontend/presentation/teacher/pages/manual_report_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum ChildRecordingState { idle, recording, recorded }

class ChildRecordingScreen extends StatefulWidget {
  const ChildRecordingScreen({super.key, required this.child, this.teacherId, this.classId});
  final Child child;
  final String? teacherId;
  final String? classId;
  @override
  State<ChildRecordingScreen> createState() => _ChildRecordingScreenState();
}

class _ChildRecordingScreenState extends State<ChildRecordingScreen> {
  ChildRecordingState _state = ChildRecordingState.idle;
  late final AudioRecorder _audioRecorder;
  String? _recordingPath;
  Duration _duration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (kIsWeb) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.webNotSupported), backgroundColor: Colors.orange),
        );
        return;
      }

      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final audioDir = Directory('${tempDir.path}/audio_recordings');
        if (!await audioDir.exists()) {
          await audioDir.create(recursive: true);
        }

        final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _recordingPath = '${audioDir.path}/$fileName';

        await _audioRecorder.start(const RecordConfig(), path: _recordingPath!);

        setState(() {
          _state = ChildRecordingState.recording;
          _duration = Duration.zero;
        });
        _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          if (!mounted) return;
          setState(() => _duration += const Duration(milliseconds: 100));
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noPermission), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.recordingError(e.toString())), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _stopRecording() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      _timer?.cancel();
      final path = await _audioRecorder.stop();

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        for (var attempt = 0; attempt < 8; attempt++) {
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) {
              setState(() {
                _state = ChildRecordingState.recorded;
                _recordingPath = path;
              });
              return;
            }
          }
          await Future.delayed(const Duration(milliseconds: 250));
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fileReadError), backgroundColor: Colors.red),
        );
        return;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fileSaveError), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.stopRecordingError(e.toString())), backgroundColor: Colors.red),
      );
    }
  }

  void _recordAgain() {
    _timer?.cancel();
    setState(() {
      _state = ChildRecordingState.idle;
      _duration = Duration.zero;
      _recordingPath = null;
    });
  }

  void _saveRecording() {
    final l10n = AppLocalizations.of(context)!;
    if (_recordingPath != null) {
      _uploadSelectedFile(_recordingPath!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noRecordingFile), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickAudioFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        if (file.path != null && !kIsWeb) {
          _uploadSelectedFile(file.path!);
          return;
        }

        if (file.bytes != null) {
          if (!mounted) return;
          _uploadSelectedFile(
            '',
            fileBytes: file.bytes!,
            fileName: file.name,
          );
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pickFileError(e.toString())), backgroundColor: Colors.red),
      );
    }
  }

  void _uploadSelectedFile(
    String filePath, {
    Uint8List? fileBytes,
    String? fileName,
  }) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RecordingScreen(
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
        classId: widget.classId ?? 'aaaaaaaa-0000-0000-0000-000000000001',
        teacherId: widget.teacherId ?? 'bbbbbbbb-0000-0000-0000-000000000001',
        childId: widget.child.childId,
        childName: widget.child.fullName,
        childInitials: _initials(widget.child.fullName),
        classTeacherInfo: 'Lớp Mầm 1 · Cô Mai',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(l10n.childRecording),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop()
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            children: [
              _buildChildHeader(l10n),
              const SizedBox(height: 28),
              _buildRecordingCard(l10n),
              const SizedBox(height: 20),
              _buildInstruction(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildHeader(AppLocalizations l10n) => Row(
    children: [
      CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFF0D5C4D),
        child: Text(
          _initials(widget.child.fullName),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.child.fullName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            Text(
              l10n.recordActivityHint,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildRecordingCard(AppLocalizations l10n) {
    final isRec = _state == ChildRecordingState.recording;
    final isRec2 = _state == ChildRecordingState.recorded;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE1DE)),
      ),
      child: Column(
        children: [
          Icon(
            isRec ? Icons.mic_rounded : isRec2 ? Icons.check_circle_outline_rounded : Icons.mic_none_rounded,
            size: 56,
            color: isRec ? const Color(0xFF0D5C4D) : isRec2 ? Colors.green : AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            isRec ? l10n.recordingInProgress : isRec2 ? l10n.recordingComplete : l10n.readyToRecord,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDuration(_duration),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 24),
          _buildMainAction(isRecording: isRec, isRecorded: isRec2, l10n: l10n),
          if (!isRec && !isRec2) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickAudioFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(l10n.selectAudioFile),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ManualReportScreen(
                    child: widget.child,
                    teacherId: widget.teacherId,
                    classId: widget.classId,
                  ),
                ));
              },
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(l10n.createManualReport),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          if (isRec2) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _recordAgain,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.recordAgain),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainAction({required bool isRecording, required bool isRecorded, required AppLocalizations l10n}) {
    if (isRecorded) {
      return FilledButton.icon(
        onPressed: _saveRecording,
        icon: const Icon(Icons.upload_rounded),
        label: Text(l10n.uploadAnalyze),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0D5C4D),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    if (isRecording) {
      return FilledButton.icon(
        onPressed: _stopRecording,
        icon: const Icon(Icons.stop_rounded),
        label: Text(l10n.stopRecording),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: _startRecording,
      icon: const Icon(Icons.mic_rounded),
      label: Text(l10n.startRecording),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0D5C4D),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInstruction(AppLocalizations l10n) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textTertiary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          l10n.recordingInstruction,
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, height: 1.4),
        ),
      ),
    ],
  );

  String _formatDuration(Duration v) {
    final m = v.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = v.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _initials(String n) {
    final p = n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first[0].toUpperCase();
    return (p.first[0] + p.last[0]).toUpperCase();
  }
}
