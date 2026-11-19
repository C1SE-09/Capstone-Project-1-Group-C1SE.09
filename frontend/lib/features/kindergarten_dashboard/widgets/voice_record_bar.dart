import 'dart:async';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

typedef OnVoiceRecordedCallback = Future<void> Function({
  required Uint8List bytes,
  required int durationSeconds,
  required String fileName,
});

/// Thanh công cụ thu âm tin nhắn thoại kiểu Messenger
class VoiceRecordBar extends StatefulWidget {
  const VoiceRecordBar({
    super.key,
    required this.onVoiceRecorded,
    this.onRecordingStateChanged,
    this.audioRecorder,
    this.isSending = false,
  });

  final OnVoiceRecordedCallback onVoiceRecorded;
  final ValueChanged<bool>? onRecordingStateChanged;
  final AudioRecorder? audioRecorder;
  final bool isSending;

  @override
  State<VoiceRecordBar> createState() => VoiceRecordBarState();
}

class VoiceRecordBarState extends State<VoiceRecordBar>
    with SingleTickerProviderStateMixin {
  late final AudioRecorder _recorder = widget.audioRecorder ?? AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseController.dispose();
    if (widget.audioRecorder == null) {
      _recorder.dispose();
    }
    super.dispose();
  }

  bool get isRecording => _isRecording;

  Future<void> startRecording() async {
    if (_isRecording || widget.isSending) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n?.voiceChatPermissionError ??
                  'Ứng dụng cần quyền sử dụng micro để ghi âm tin nhắn thoại.',
            ),
            backgroundColor: context.k.bad,
          ),
        );
        return;
      }

      final ext = kIsWeb ? 'webm' : 'm4a';
      final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
      String safePath = '';
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        safePath =
            '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      }

      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: 128000,
          sampleRate: kIsWeb ? 48000 : 44100,
          numChannels: kIsWeb ? 2 : 1,
        ),
        path: safePath,
      );

      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      widget.onRecordingStateChanged?.call(true);

      _recordTimer?.cancel();
      _pulseController.repeat(reverse: true);
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n?.voiceChatStartError ??
                'Không thể bắt đầu ghi âm. Vui lòng thử lại.',
          ),
          backgroundColor: context.k.bad,
        ),
      );
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
    widget.onRecordingStateChanged?.call(false);
  }

  Future<void> stopAndSendRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    final duration = _recordSeconds;

    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
      widget.onRecordingStateChanged?.call(false);

      if (path == null || path.isEmpty) return;

      final xFile = XFile(path);
      final bytes = await xFile.readAsBytes();
      if (bytes.isEmpty) return;

      final ext = kIsWeb ? 'webm' : 'm4a';
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await widget.onVoiceRecorded(
        bytes: bytes,
        durationSeconds: duration > 0 ? duration : 1,
        fileName: fileName,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n?.voiceChatSendError ??
                'Lỗi khi gửi file ghi âm. Vui lòng thử lại.',
          ),
          backgroundColor: context.k.bad,
        ),
      );
    }
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) {
      // Khi không ghi âm: hiển thị nút icon Micro tròn gọn gàng
      return IconButton(
        tooltip: context.l10n?.voiceChatRecordTooltip ?? 'Gửi tin nhắn thoại',
        onPressed: widget.isSending ? null : startRecording,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: context.k.surfaceSunken,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.mic_rounded,
            size: 20,
            color: context.k.brand,
          ),
        ),
      );
    }

    // Khi đang thu âm: hiển thị thanh thu âm thời gian thực giống Messenger
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: context.k.badTint.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.k.bad.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Chấm đỏ nhấp nháy mô phỏng đang thu âm
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: context.k.bad,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.k.bad.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Đồng hồ đếm giây
            Text(
              _formatTimer(_recordSeconds),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: context.k.bad,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            // Sóng âm thanh động
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(12, (index) {
                  final active = (index + _recordSeconds) % 3 == 0;
                  final height = active ? 16.0 : 8.0;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 3,
                    height: height,
                    decoration: BoxDecoration(
                      color: context.k.bad.withValues(alpha: active ? 0.9 : 0.4),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 8),
            // Nút Huỷ (Thùng rác)
            IconButton(
              tooltip: context.l10n?.voiceChatCancelTooltip ?? 'Huỷ ghi âm',
              onPressed: cancelRecording,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: context.k.inkSoft,
              ),
            ),
            const SizedBox(width: 4),
            // Nút Gửi ngay
            GestureDetector(
              onTap: stopAndSendRecording,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.k.brand,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.send_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
  }
}
