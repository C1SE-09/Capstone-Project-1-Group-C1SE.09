import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/record_hub_screen.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/record/session_clip_bar.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/audio_player_card.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/record_models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/recorder_panel_widgets.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.mode,
    required this.onSubmit,
    this.child,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.className = 'Mầm 1',
    this.enableMultiClipSession = false,
    this.teacherRepository,
    this.audioRecorder,
    this.pathProvider,
    this.audioPlayerFactory,
    this.onSubmitSession,
  });
  final RecordMode mode;
  final Child? child;
  final ValueChanged<PlatformFile?> onSubmit;
  final String classId;
  final String className;
  final bool enableMultiClipSession;
  final TeacherRepository? teacherRepository;
  final AudioRecorder? audioRecorder;
  final Future<String> Function(String extension)? pathProvider;
  final AudioPlayerFactory? audioPlayerFactory;
  final void Function({
    required VoiceRecordingSession session,
    String? editedMergedTranscript,
    Uint8List? previewAudioBytes,
  })? onSubmitSession;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  int seconds = 0;
  String phase = 'ready';
  PlatformFile? selectedFile;
  Timer? timer;
  bool isBusy = false;
  String _currentExtension = 'm4a';

  // Multi-clip session state (User Story #78)
  VoiceRecordingSession? _session;
  bool _isUploadingClip = false;
  bool _isDiscardingSession = false;
  Timer? _pollTimer;
  final Set<String> _expandedClipIds = <String>{};
  final Set<String> _deletingClipIds = <String>{};
  final Set<String> _savingTranscriptClipIds = <String>{};
  final Map<String, String> _editedClipTranscripts = <String, String>{};
  final Map<String, Uint8List> _clipLocalBytes = <String, Uint8List>{};

  // Single-active-clip audio player state
  AudioPlayer? _clipPlayer;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _playerPosSub;
  StreamSubscription<Duration?>? _playerDurSub;
  String? _playingClipId;
  String? _loadingAudioClipId;
  Duration _clipPosition = Duration.zero;
  Duration _clipDuration = Duration.zero;

  late final AudioRecorder _recorder = widget.audioRecorder ?? AudioRecorder();
  late final TeacherRepository _repo =
      widget.teacherRepository ?? TeacherRepository();

  String get _teacherId =>
      AuthRepository.currentUser?.teacherId ??
      'bbbbbbbb-0000-0000-0000-000000000001';

  String get _sessionScope =>
      widget.mode == RecordMode.child && widget.child != null
          ? 'single_child'
          : 'whole_class';

  String? get _targetChildId =>
      _sessionScope == 'single_child' ? widget.child?.id : null;

  // Primary wave controller — drives the oscillation frequency.
  late final AnimationController wave = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  // Secondary controller with slightly different period for a richer, more organic look.
  late final AnimationController wave2 = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.enableMultiClipSession) {
      unawaited(_restoreActiveSession());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _pollTimer?.cancel();
    _playerStateSub?.cancel();
    _playerPosSub?.cancel();
    _playerDurSub?.cancel();
    _clipPlayer?.dispose();
    wave.dispose();
    wave2.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _restoreActiveSession() async {
    try {
      final restored = await _repo.createOrResumeVoiceSession(
        teacherId: _teacherId,
        classId: widget.classId,
        childId: _targetChildId,
        scope: _sessionScope,
      );
      if (!mounted) return;
      setState(() {
        _session = restored;
      });
      _syncPollingTimer();
    } catch (_) {
      // Initial silent restore: if offline/unavailable, keep UI ready and
      // lazily create session when the first clip is saved.
    }
  }

  Future<VoiceRecordingSession> _ensureSession() async {
    if (_session != null) return _session!;
    final created = await _repo.createOrResumeVoiceSession(
      teacherId: _teacherId,
      classId: widget.classId,
      childId: _targetChildId,
      scope: _sessionScope,
    );
    if (mounted) {
      setState(() => _session = created);
    } else {
      _session = created;
    }
    return created;
  }

  void _syncPollingTimer() {
    final hasInFlight =
        _session?.clips.any((c) => c.isPendingOrProcessing) ?? false;
    if (!hasInFlight) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_pollTimer != null && _pollTimer!.isActive) return;
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshSessionSilently()),
    );
  }

  Future<void> _refreshSessionSilently() async {
    final sessionId = _session?.sessionId;
    if (sessionId == null || !mounted) {
      _pollTimer?.cancel();
      return;
    }
    try {
      final refreshed = await _repo.getVoiceSession(
        sessionId: sessionId,
        teacherId: _teacherId,
      );
      if (!mounted) return;
      setState(() => _session = refreshed);
      _syncPollingTimer();
    } catch (_) {
      // Transient polling errors are retried on the next tick.
    }
  }

  Future<Uint8List?> _extractFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }
    if (file.readStream != null) {
      final chunks = <int>[];
      await for (final chunk in file.readStream!) {
        chunks.addAll(chunk);
      }
      if (chunks.isNotEmpty) return Uint8List.fromList(chunks);
    }
    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      return await XFile(file.path!).readAsBytes();
    }
    return null;
  }

  Future<void> _uploadClipToSession(PlatformFile file) async {
    if (!mounted) return;
    setState(() {
      _isUploadingClip = true;
      isBusy = false;
      phase = 'ready';
      seconds = 0;
      selectedFile = null;
    });

    try {
      final bytes = await _extractFileBytes(file);
      final safePath = kIsWeb ? '' : (file.path ?? '');
      final session = await _ensureSession();
      final record = await _repo.uploadAudioToSession(
        sessionId: session.sessionId,
        filePath: safePath,
        fileBytes: bytes,
        fileName: file.name,
        classId: widget.classId,
        teacherId: _teacherId,
        childId: _targetChildId,
      );
      if (bytes != null && bytes.isNotEmpty) {
        _clipLocalBytes[record.id] = bytes;
      }

      VoiceRecordingSession updatedSession;
      try {
        updatedSession = await _repo.getVoiceSession(
          sessionId: session.sessionId,
          teacherId: _teacherId,
        );
      } catch (_) {
        updatedSession = VoiceRecordingSession(
          sessionId: session.sessionId,
          scope: session.scope,
          status: session.status,
          teacherId: session.teacherId,
          classId: session.classId,
          childId: session.childId,
          recordedAt: session.recordedAt,
          clips: [
            ...session.clips,
            VoiceClip(
              voiceRecordId: record.id,
              status: record.status,
              createdAt: DateTime.now(),
            ),
          ],
          pendingCount: session.pendingCount + 1,
          completedCount: session.completedCount,
        );
      }

      if (!mounted) return;
      setState(() {
        _session = updatedSession;
        _isUploadingClip = false;
      });
      _syncPollingTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingClip = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getFriendlyErrorMessage(e)),
          backgroundColor: context.k.bad,
        ),
      );
    }
  }

  Future<AudioPlayer> _ensureClipPlayer() async {
    if (_clipPlayer != null) return _clipPlayer!;
    final player = widget.audioPlayerFactory?.call() ?? AudioPlayer();
    _clipPlayer = player;
    _playerStateSub = player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        unawaited(player.seek(Duration.zero));
        unawaited(player.pause());
        setState(() {
          _playingClipId = null;
          _clipPosition = Duration.zero;
        });
      }
    });
    _playerPosSub = player.positionStream.listen((pos) {
      if (!mounted || _playingClipId == null) return;
      setState(() => _clipPosition = pos);
    });
    _playerDurSub = player.durationStream.listen((dur) {
      if (!mounted || _playingClipId == null) return;
      setState(() => _clipDuration = dur ?? Duration.zero);
    });
    return player;
  }

  Future<void> _toggleClipPlay(VoiceClip clip) async {
    final clipId = clip.voiceRecordId;
    try {
      final player = await _ensureClipPlayer();
      if (_playingClipId == clipId) {
        await player.pause();
        if (mounted) setState(() => _playingClipId = null);
        return;
      }

      final localBytes = _clipLocalBytes[clipId];
      final audioUrl = clip.audioUrl?.trim() ?? '';
      if ((localBytes == null || localBytes.isEmpty) && audioUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n?.sttNoAudioToPlay ??
                    'Chưa có file âm thanh để phát lại.',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _loadingAudioClipId = clipId;
        _clipPosition = Duration.zero;
        _clipDuration = Duration(
          milliseconds: ((clip.audioDuration ?? 0) * 1000).round(),
        );
      });

      await player.stop();
      if (localBytes != null && localBytes.isNotEmpty) {
        await player.setAudioSource(BytesAudioSource(localBytes));
      } else {
        await player.setUrl(audioUrl);
      }

      if (!mounted) return;
      setState(() {
        _loadingAudioClipId = null;
        _playingClipId = clipId;
      });
      await player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAudioClipId = null;
        if (_playingClipId == clipId) _playingClipId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n?.sttCannotPlayAudio ??
                'Không thể phát đoạn ghi âm này.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteClip(VoiceClip clip) async {
    final clipId = clip.voiceRecordId;
    if (_playingClipId == clipId) {
      try {
        await _clipPlayer?.stop();
      } catch (_) {}
      _playingClipId = null;
    }

    setState(() => _deletingClipIds.add(clipId));
    try {
      await _repo.deleteVoiceClip(voiceId: clipId, teacherId: _teacherId);
      _expandedClipIds.remove(clipId);
      _editedClipTranscripts.remove(clipId);
      _clipLocalBytes.remove(clipId);

      final sessionId = _session?.sessionId;
      if (sessionId != null) {
        final refreshed = await _repo.getVoiceSession(
          sessionId: sessionId,
          teacherId: _teacherId,
        );
        if (!mounted) return;
        setState(() {
          _deletingClipIds.remove(clipId);
          _session = refreshed;
        });
        _syncPollingTimer();
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e)),
            backgroundColor: context.k.bad,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _deletingClipIds.remove(clipId));
    }
  }

  Future<void> _saveClipTranscript(VoiceClip clip, String editedText) async {
    final clipId = clip.voiceRecordId;
    setState(() {
      _editedClipTranscripts[clipId] = editedText;
      _savingTranscriptClipIds.add(clipId);
    });
    try {
      await _repo.updateTranscript(
        voiceId: clipId,
        editedTranscript: editedText,
        teacherId: _teacherId,
      );
      if (!mounted) return;
      final current = _session;
      if (current != null) {
        final updatedClips = current.clips
            .map((c) => c.voiceRecordId == clipId
                ? c.copyWith(transcript: editedText)
                : c)
            .toList();
        setState(() {
          _savingTranscriptClipIds.remove(clipId);
          _session = VoiceRecordingSession(
            sessionId: current.sessionId,
            scope: current.scope,
            status: current.status,
            teacherId: current.teacherId,
            classId: current.classId,
            childId: current.childId,
            recordedAt: current.recordedAt,
            mergedTranscript: current.mergedTranscript,
            representativeVoiceRecordId: current.representativeVoiceRecordId,
            clips: updatedClips,
            pendingCount: current.pendingCount,
            completedCount: current.completedCount,
          );
        });
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e)),
            backgroundColor: context.k.bad,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _savingTranscriptClipIds.remove(clipId));
    }
  }

  Future<void> _confirmAndDiscardSession() async {
    final session = _session;
    if (session == null || session.clips.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => GardenVoiceScope(
        child: Builder(
          builder: (context) {
            final k = context.k;
            return AlertDialog(
              backgroundColor: k.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                context.l10n?.cancelSessionConfirmTitle ?? 'Huỷ phiên ghi âm?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: k.ink,
                ),
              ),
              content: Text(
                context.l10n?.cancelSessionConfirmDesc ??
                    'Tất cả ${session.clips.length} đoạn ghi âm trong phiên hiện tại sẽ bị huỷ bỏ.',
                style: TextStyle(fontSize: 14, color: k.inkSoft),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.l10n?.keepSessionAction ?? 'Giữ lại'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: k.bad),
                  child: Text(context.l10n?.cancelSessionAction ?? 'Huỷ phiên'),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDiscardingSession = true);
    try {
      await _repo.discardVoiceSession(
        sessionId: session.sessionId,
        teacherId: _teacherId,
      );
      _pollTimer?.cancel();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDiscardingSession = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getFriendlyErrorMessage(e)),
          backgroundColor: context.k.bad,
        ),
      );
    }
  }

  void _submitSessionForAnalysis() {
    final session = _session;
    if (session == null || widget.onSubmitSession == null) return;
    _pollTimer?.cancel();
    try {
      _clipPlayer?.stop();
    } catch (_) {}

    final mergedParts = <String>[];
    Uint8List? firstPreviewBytes;
    for (final clip in session.clips) {
      if (!clip.isCompleted) continue;
      firstPreviewBytes ??= _clipLocalBytes[clip.voiceRecordId];
      var text =
          (_editedClipTranscripts[clip.voiceRecordId] ?? clip.transcript ?? '')
              .trim();
      while (text.endsWith('.')) {
        text = text.substring(0, text.length - 1).trim();
      }
      if (text.isNotEmpty) {
        mergedParts.add(text);
      }
    }

    widget.onSubmitSession!(
      session: session,
      editedMergedTranscript:
          mergedParts.isNotEmpty ? mergedParts.join(' ') : null,
      previewAudioBytes: firstPreviewBytes,
    );
  }

  String _formatSessionDuration(List<VoiceClip> clips) {
    final totalSec = clips
        .fold<double>(0, (sum, c) => sum + (c.audioDuration ?? 0))
        .round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m4a', 'wav', 'mp3', 'webm', 'ogg', 'aac', 'flac'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        timer?.cancel();
        wave.stop();
        wave2.stop();
        var file = result.files.single;
        if (file.bytes == null &&
            !kIsWeb &&
            file.path != null &&
            file.path!.isNotEmpty) {
          try {
            final xFile = XFile(file.path!);
            final bytes = await xFile.readAsBytes();
            file = PlatformFile(
              name: file.name,
              size: bytes.length,
              bytes: bytes,
              path: file.path,
            );
          } catch (_) {}
        }
        if (widget.enableMultiClipSession) {
          await _uploadClipToSession(file);
          return;
        }
        setState(() {
          selectedFile = file;
          phase = 'file_selected';
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Không thể chọn file. Vui lòng kiểm tra quyền truy cập hoặc thử lại.')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> toggle() async {
    if (isBusy || phase == 'file_selected' || phase == 'done') return;
    if (phase == 'recording') {
      await _stopRecording();
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    setState(() => isBusy = true);
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() => isBusy = false);
          await _showRecordingRecoveryDialog(
            iconAsset: 'assets/garden_voice/record_permission.svg',
            title: context.l10n?.sttNoMicPermissionTitle ?? 'Chưa có quyền micro',
            message: context.l10n?.sttMicPermissionMessage ??
                (LocaleController.instance.isEnglish
                    ? 'Please grant microphone access to record audio. You can open Device Settings, select Privacy → Microphone and enable it for KinderLog.'
                    : 'Vui lòng cấp quyền truy cập micro để ghi âm. Thầy cô có thể mở Cài đặt của thiết bị, chọn Quyền riêng tư → Micro và bật cho KinderLog.'),
            primaryLabel: context.l10n?.openSettingsAction ?? 'Mở cài đặt',
            secondaryLabel: context.l10n?.laterAction ?? 'Để sau',
            onPrimary: _openMicrophoneSettings,
          );
        }
        return;
      }

      AudioEncoder encoder = AudioEncoder.aacLc;
      String extension = 'm4a';

      if (kIsWeb) {
        if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
          encoder = AudioEncoder.opus;
          extension = 'webm';
        } else if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
          encoder = AudioEncoder.aacLc;
          extension = 'm4a';
        } else {
          encoder = AudioEncoder.wav;
          extension = 'wav';
        }
      } else {
        if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
          encoder = AudioEncoder.aacLc;
          extension = 'm4a';
        } else if (await _recorder.isEncoderSupported(AudioEncoder.wav)) {
          encoder = AudioEncoder.wav;
          extension = 'wav';
        } else if (await _recorder.isEncoderSupported(AudioEncoder.pcm16bits)) {
          encoder = AudioEncoder.pcm16bits;
          extension = 'wav';
        }
      }

      String recordPath = '';
      if (!kIsWeb) {
        if (widget.pathProvider != null) {
          recordPath = await widget.pathProvider!(extension);
        } else {
          try {
            final dir = await getTemporaryDirectory();
            recordPath =
                '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.$extension';
          } catch (_) {
            recordPath =
                'rec_${DateTime.now().millisecondsSinceEpoch}.$extension';
          }
        }
      }

      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: 128000,
          sampleRate: kIsWeb ? 48000 : 44100,
          numChannels: kIsWeb ? 2 : 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: recordPath,
      );

      _currentExtension = extension;

      wave.repeat(reverse: true);
      wave2.repeat(reverse: false);
      if (mounted) {
        setState(() {
          seconds = 0;
          phase = 'recording';
          selectedFile = null;
          isBusy = false;
        });
      }

      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (seconds >= 179) {
          _stopRecording();
        } else {
          setState(() => seconds++);
        }
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        setState(() => isBusy = false);
        await _showRecordingRecoveryDialog(
          iconAsset: 'assets/garden_voice/record_error.svg',
          title: context.l10n?.sttCannotRecordTitle ?? 'Chưa thể ghi âm',
          message: context.l10n?.sttCannotRecordMessage ??
              (LocaleController.instance.isEnglish
                  ? 'The app cannot record yet. Please check microphone access in device settings and try again.'
                  : 'Ứng dụng chưa thể ghi âm. Thầy cô vui lòng kiểm tra quyền truy cập Micro trong cài đặt thiết bị và thử lại nhé.'),
          primaryLabel: context.l10n?.bugReportCommonRetry ?? 'Thử lại',
          secondaryLabel: context.l10n?.commonClose ?? 'Đóng',
          onPrimary: () => _startRecording(),
        );
      }
    }
  }

  Future<void> _openMicrophoneSettings() async {
    final hint = context.l10n?.sttOpenSettingsForMic ??
        'Mở Cài đặt để cấp quyền micro.';
    try {
      final opened = await launchUrl(
        Uri.parse('app-settings:'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hint)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hint)),
        );
      }
    }
  }

  Future<void> _showRecordingRecoveryDialog({
    required String iconAsset,
    required String title,
    required String message,
    required String primaryLabel,
    required String secondaryLabel,
    required VoidCallback onPrimary,
  }) {
    if (!mounted) return Future<void>.value();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => GardenVoiceScope(
        child: Builder(
          builder: (context) {
            final k = context.k;
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 35, vertical: 24),
              backgroundColor: k.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(iconAsset, width: 56, height: 56),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: k.ink,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: k.inkSoft,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    KButton(
                      label: primaryLabel,
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onPrimary();
                      },
                    ),
                    const SizedBox(height: 8),
                    KButton(
                      label: secondaryLabel,
                      ghost: true,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _stopRecording() async {
    if (phase != 'recording') return;
    timer?.cancel();
    wave.stop();
    wave2.stop();

    setState(() => isBusy = true);
    try {
      final path = await _recorder.stop();
      if (path != null && path.isNotEmpty) {
        final xFile = XFile(path);
        final bytes = await xFile.readAsBytes();

        if (bytes.isEmpty) {
          if (mounted) {
            setState(() {
              seconds = 0;
              phase = 'ready';
              selectedFile = null;
              isBusy = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n?.audioTooShortError ??
                      'Bản ghi âm quá ngắn hoặc không có âm thanh. Vui lòng thử lại.',
                ),
                backgroundColor: context.k.warn,
              ),
            );
          }
          return;
        }

        final fileName =
            'rec_${DateTime.now().millisecondsSinceEpoch}.$_currentExtension';
        final platformFile = PlatformFile(
          name: fileName,
          size: bytes.length,
          bytes: bytes,
          path: kIsWeb ? null : path,
        );

        if (widget.enableMultiClipSession) {
          await _uploadClipToSession(platformFile);
          return;
        }

        if (mounted) {
          setState(() {
            selectedFile = platformFile;
            phase = 'done';
            isBusy = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }

    if (mounted) {
      setState(() {
        seconds = 0;
        phase = 'ready';
        selectedFile = null;
        isBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n?.cannotSaveAudioError ??
                'Không thể hoàn tất lưu bản ghi âm. Vui lòng bấm ghi âm lại.',
          ),
          backgroundColor: context.k.bad,
        ),
      );
    }
  }

  String get time =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  Widget _buildContextCard(
    KPalette k, {
    required Child? child,
    required String classLabel,
    required String? allergy,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FCFB),
        border: Border.all(color: k.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF212E2B).withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (child != null)
            Avatar(name: child.name)
          else
            SvgPicture.asset('assets/garden_voice/class_group.svg'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  child == null
                      ? (LocaleController.instance.isEnglish
                          ? 'All Class $classLabel'
                          : 'Cả lớp $classLabel')
                      : child.fullNameWithNickname,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: k.ink,
                  ),
                ),
                Text(
                  child == null
                      ? (LocaleController.instance.isEnglish
                          ? 'Record once, generate reports for all children.'
                          : 'Ghi một lần, tạo báo cáo cho tất cả trẻ.')
                      : classLabel,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: k.inkSoft,
                  ),
                ),
                if (allergy != null && allergy.isNotEmpty)
                  Text('Dị ứng: $allergy',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: k.warn,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiClipScaffold(
    BuildContext context,
    KPalette k, {
    required String subtitle,
    required Child? child,
    required String classLabel,
    required String? allergy,
    required VoiceRecordingSession session,
  }) {
    final clips = session.clips;
    final recording = phase == 'recording';
    final inFlightCount = clips.where((c) => c.isPendingOrProcessing).length;
    final failedCount = clips.where((c) => c.isFailed).length;
    final completedCount = clips.where((c) => c.isCompleted).length;
    final canAnalyze = !recording &&
        !_isUploadingClip &&
        !_isDiscardingSession &&
        session.pendingCount == 0 &&
        completedCount > 0;

    final String analyzeLabel;
    if (inFlightCount > 0) {
      analyzeLabel = 'Đang nhận dạng ($inFlightCount)…';
    } else if (failedCount > 0) {
      analyzeLabel = 'Xoá đoạn lỗi để gửi';
    } else {
      analyzeLabel = 'Gửi phân tích ($completedCount)';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  GardenVoiceRecordHeader(
                    title: 'Ghi âm',
                    subtitle: '$subtitle · Phiên hôm nay',
                    onBack: () => Navigator.pop(context),
                    showProgress: true,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: k.brandTint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${clips.length} bản ghi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: k.brand,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildContextCard(
                    k,
                    child: child,
                    classLabel: classLabel,
                    allergy: allergy,
                  ),
                  const SizedBox(height: 12),
                  CompactSessionRecorderDock(
                    recording: recording,
                    isBusy: isBusy || _isUploadingClip,
                    isUploading: _isUploadingClip,
                    seconds: seconds,
                    time: time,
                    wave: wave,
                    wave2: wave2,
                    onToggleMic: toggle,
                    onPickFile: _pickFile,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'DANH SÁCH BẢN GHI TRONG NGÀY',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: k.ink,
                            letterSpacing: .3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tổng ${_formatSessionDuration(clips)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: k.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (failedCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: k.badTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: k.bad.withValues(alpha: .4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 18, color: k.badText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Có $failedCount đoạn nhận dạng lỗi — chạm X để xoá trước khi gửi phân tích.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: k.badText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (var i = 0; i < clips.length; i++)
                    Builder(
                      builder: (_) {
                        final clip = clips[i];
                        final clipId = clip.voiceRecordId;
                        final isPlaying = _playingClipId == clipId;
                        final progress = isPlaying &&
                                _clipDuration.inMilliseconds > 0
                            ? (_clipPosition.inMilliseconds /
                                    _clipDuration.inMilliseconds)
                                .clamp(0.0, 1.0)
                            : 0.0;
                        return SessionClipBar(
                          key: ValueKey('session-clip-$clipId'),
                          index: i,
                          clip: clip,
                          isPlaying: isPlaying,
                          isLoadingAudio: _loadingAudioClipId == clipId,
                          playProgress: progress,
                          isExpanded: _expandedClipIds.contains(clipId),
                          isDeleting: _deletingClipIds.contains(clipId),
                          isSavingTranscript:
                              _savingTranscriptClipIds.contains(clipId),
                          editedTranscript: _editedClipTranscripts[clipId],
                          onTogglePlay: () => _toggleClipPlay(clip),
                          onDelete: () => _deleteClip(clip),
                          onToggleExpand: () => setState(() {
                            if (_expandedClipIds.contains(clipId)) {
                              _expandedClipIds.remove(clipId);
                            } else {
                              _expandedClipIds.add(clipId);
                            }
                          }),
                          onTranscriptChanged: (val) =>
                              _editedClipTranscripts[clipId] = val,
                          onSaveTranscript: (val) =>
                              _saveClipTranscript(clip, val),
                        );
                      },
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: k.surfaceSunken,
                      border: Border.all(color: k.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Phiên tự lưu suốt cả ngày. Chạm X để bỏ đoạn nhầm hoặc chạm mũi tên bên dưới X để xem & sửa câu đã nói.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: k.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: BoxDecoration(
                color: k.surface,
                border: Border(top: BorderSide(color: k.line)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    height: 48,
                    child: TextButton(
                      onPressed:
                          _isDiscardingSession ? null : _confirmAndDiscardSession,
                      style: TextButton.styleFrom(
                        foregroundColor: k.inkSoft,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Huỷ phiên'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const ValueKey('btn-analyze-session'),
                        onPressed:
                            canAnalyze ? _submitSessionForAnalysis : null,
                        icon: const Icon(Icons.send_rounded, size: 17),
                        label: Text(analyzeLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: k.brand,
                          foregroundColor: k.surface,
                          disabledBackgroundColor: k.line,
                          disabledForegroundColor: k.inkFaint,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recording = phase == 'recording';
    final hasFile = phase == 'file_selected' && selectedFile != null;
    final child = widget.child;
    final allergy =
        child?.allergy == null ? null : recordAllergy(child!.allergy!);
    final isEn = LocaleController.instance.isEnglish;
    final cleanClass = widget.className.replaceFirst(RegExp(r'^(Lớp|Class)\s*', caseSensitive: false), '');
    final classLabel = isEn
        ? (cleanClass.isEmpty ? 'Class' : 'Class $cleanClass')
        : (widget.className.startsWith('Lớp ')
            ? widget.className
            : 'Lớp ${widget.className}');
    final title = child?.fullNameWithNickname ?? (isEn ? 'Entire class' : 'Cả lớp');
    final subtitle = child == null ? classLabel : '$title · $classLabel';
    final canSubmit = !isBusy && (hasFile || phase == 'done');

    return GardenVoiceScope(
      child: Builder(
        builder: (context) {
          final k = context.k;
          if (widget.enableMultiClipSession &&
              _session != null &&
              _session!.clips.isNotEmpty) {
            return _buildMultiClipScaffold(
              context,
              k,
              subtitle: subtitle,
              child: child,
              classLabel: classLabel,
              allergy: allergy,
              session: _session!,
            );
          }

          return Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  GardenVoiceRecordHeader(
                    title: 'Ghi âm',
                    subtitle: subtitle,
                    onBack: () => Navigator.pop(context),
                    showProgress: true,
                  ),
                  const SizedBox(height: 18),
                  _buildContextCard(
                    k,
                    child: child,
                    classLabel: classLabel,
                    allergy: allergy,
                  ),
                  const SizedBox(height: 12),
                  if (_isUploadingClip)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: k.brand),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n?.savingClipToSession ??
                                'Đang lưu đoạn ghi âm vào phiên…',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: k.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (hasFile)
                    SelectedAudioFileCard(
                      file: selectedFile!,
                      formatBytes: _formatBytes,
                    )
                  else
                    GardenVoiceRecorderPanel(
                      recording: recording,
                      isBusy: isBusy,
                      seconds: seconds,
                      time: time,
                      message: phase == 'ready'
                          ? (context.l10n?.pressToStartRecording ??
                              'Nhấn để bắt đầu ghi âm')
                          : recording
                              ? (context.l10n?.recordingLiveMessage ??
                                  'Đang ghi âm · Nói tự nhiên')
                              : 'Đã ghi âm $time · ${_formatBytes(selectedFile?.size ?? 0)}',
                      wave: wave,
                      wave2: wave2,
                      onToggle: toggle,
                    ),
                  const SizedBox(height: 14),
                  if (!hasFile)
                    Center(
                      child: OutlinedButton(
                        onPressed: recording || isBusy ? null : _pickFile,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: k.brand,
                          minimumSize: const Size(230, 48),
                          side: BorderSide(color: k.line),
                          shape: const StadiumBorder(),
                          backgroundColor: k.surface,
                        ),
                        child: Text(
                          context.l10n?.uploadAudioFile ?? 'Tải lên file ghi âm',
                        ),
                      ),
                    ),
                  if (hasFile)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _pickFile,
                          child: Text(
                            context.l10n?.chooseAnotherFile ?? 'Chọn file khác',
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            selectedFile = null;
                            phase = 'ready';
                          }),
                          child: Text(
                            context.l10n?.cancelFileSelection ?? 'Hủy chọn',
                          ),
                        ),
                      ],
                    ),
                  if (phase == 'done')
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          seconds = 0;
                          phase = 'ready';
                          selectedFile = null;
                        }),
                        child: Text(
                          context.l10n?.sttRerecord ?? 'Ghi âm lại',
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F9),
                      border: Border.all(color: k.lineStrong),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n?.recordingHintTitle ??
                              'Gợi ý: kể lại hoạt động của bé',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: k.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n?.recordingHintDesc ??
                              'Kể lần lượt: ăn uống, giấc ngủ, hoạt động, sức khỏe và tâm trạng của bé.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: k.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 104,
                        height: 48,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: k.brand,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(context.l10n?.commonCancel ?? 'Hủy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: canSubmit
                                ? () => widget.onSubmit(selectedFile)
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: k.brand,
                              foregroundColor: k.surface,
                              disabledBackgroundColor:
                                  k.brand.withValues(alpha: .35),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(
                              context.l10n?.sendForProcessing ?? 'Gửi xử lý',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

