// ============================================================================
// TranscriptReviewScreen – "Xem lại nội dung"
//
// Hiển thị sau khi ghi âm hoàn thành:
//   • Audio player (play/pause, waveform, duration)
//   • Nội dung nhận diện (transcript text, có thể chỉnh sửa)
//   • Nút "Tiếp tục" → chuyển sang ReportProcessingScreen
// ============================================================================

import 'dart:async';

import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/presentation/recording/pages/report_processing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TranscriptReviewScreen extends StatefulWidget {
  const TranscriptReviewScreen({
    super.key,
    required this.child,
    required this.transcript,
    required this.audioDuration,
    this.audioFilePath,
    this.voiceId,
    this.teacherId,
    this.classId,
  });

  /// Thông tin trẻ
  final Child child;

  /// Nội dung văn bản đã nhận diện từ ghi âm
  final String transcript;

  /// Thời lượng audio (giây)
  final int audioDuration;

  /// Đường dẫn file audio (nếu có, để phát lại)
  final String? audioFilePath;

  /// voiceId từ backend (để truyền sang màn hình tiếp theo)
  final String? voiceId;

  /// teacherId
  final String? teacherId;

  /// classId
  final String? classId;

  @override
  State<TranscriptReviewScreen> createState() => _TranscriptReviewScreenState();
}

class _TranscriptReviewScreenState extends State<TranscriptReviewScreen> {
  // ─── Audio player state ─────────────────────────────────────────────────
  bool _isPlaying = false;
  Timer? _playTimer;
  int _playedSeconds = 0;

  // ─── Transcript editing ─────────────────────────────────────────────────
  bool _isEditing = false;
  late final TextEditingController _transcriptController;
  late final FocusNode _focusNode;

  // ─── Constants ──────────────────────────────────────────────────────────
  static const _kPrimary = Color(0xFF0D5C4D);
  static const _kBackground = Color(0xFFF9F8F3);
  static const _kSurface = Colors.white;
  static const _kTextPrimary = Color(0xFF1E2522);
  static const _kTextSecondary = Color(0xFF757B77);
  static const _kTextGreen = Color(0xFF1B6E60);
  static const _kBorder = Color(0xFFDCE1DE);
  static const _kWaveform = Color(0xFF0D5C4D);

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController(text: widget.transcript);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _transcriptController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── Audio actions ───────────────────────────────────────────────────────

  void _togglePlay() {
    if (_isPlaying) {
      _playTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      if (_playedSeconds >= widget.audioDuration) {
        _playedSeconds = 0;
      }
      setState(() => _isPlaying = true);
      _playTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _playedSeconds++;
          if (_playedSeconds >= widget.audioDuration) {
            _isPlaying = false;
            _playTimer?.cancel();
          }
        });
      });
    }
  }

  // ─── Navigation ──────────────────────────────────────────────────────────

  void _onContinue() {
    final finalTranscript = _transcriptController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportProcessingScreen(
          child: widget.child,
          phase: ProcessingPhase.extract,
          transcript: finalTranscript,
          voiceId: widget.voiceId,
          teacherId: widget.teacherId,
          classId: widget.classId,
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }


  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(l10n),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAudioPlayer(l10n),
                    const SizedBox(height: 24),
                    _buildTranscriptSection(l10n),
                    const SizedBox(height: 12),
                    _buildHint(l10n),
                  ],
                ),
              ),
            ),
            _buildBottomBar(l10n),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28, color: _kTextPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reviewContent,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _kTextPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.child.fullName,
                  style: const TextStyle(fontSize: 13, color: _kTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Audio Player ─────────────────────────────────────────────────────────

  Widget _buildAudioPlayer(AppLocalizations l10n) {
    final progress = widget.audioDuration > 0
        ? _playedSeconds / widget.audioDuration
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.audioRecording,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: _kTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              // Play / Pause button
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: _kPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Waveform + progress bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Static waveform visualization
                    _buildWaveformBar(progress),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Duration label
              Text(
                _formatDuration(widget.audioDuration),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaveformBar(double progress) {
    const bars = <double>[
      16, 28, 20, 36, 24, 40, 18, 32, 28, 14,
      38, 22, 30, 26, 20, 34, 18, 28, 24, 16,
    ];
    final totalBars = bars.length;

    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(totalBars, (i) {
          final ratio = i / totalBars;
          final isPlayed = ratio <= progress;
          return Container(
            width: 3,
            height: bars[i],
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: isPlayed
                  ? _kWaveform
                  : _kWaveform.withAlpha((0.25 * 255).round()),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // ─── Transcript Section ──────────────────────────────────────────────────

  Widget _buildTranscriptSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.identifiedContent,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _kTextSecondary,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _isEditing = !_isEditing);
                if (_isEditing) {
                  Future.delayed(const Duration(milliseconds: 50), () {
                    _focusNode.requestFocus();
                  });
                } else {
                  _focusNode.unfocus();
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, size: 15, color: _kTextGreen),
                  const SizedBox(width: 4),
                  Text(
                    _isEditing ? l10n.done : l10n.edit,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _kTextGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isEditing ? _kPrimary : _kBorder,
              width: _isEditing ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: _transcriptController,
            focusNode: _focusNode,
            enabled: _isEditing,
            maxLines: null,
            minLines: 4,
            style: TextStyle(
              fontSize: 15,
              color: _isEditing ? _kTextPrimary : const Color(0xFF2E6B5E),
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Hint ────────────────────────────────────────────────────────────────

  Widget _buildHint(AppLocalizations l10n) {
    return Text(
      l10n.checkInstruction,
      style: const TextStyle(
        fontSize: 12.5,
        color: _kTextSecondary,
        height: 1.4,
      ),
    );
  }

  // ─── Bottom Bar ──────────────────────────────────────────────────────────

  Widget _buildBottomBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: _kBackground,
        border: Border(top: BorderSide(color: Color(0xFFEFECE6))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            l10n.continueAction,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
