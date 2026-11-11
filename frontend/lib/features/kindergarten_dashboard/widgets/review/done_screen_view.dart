import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/audio_player_card.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/review_common_widgets.dart';

class DoneScreenView extends StatefulWidget {
  const DoneScreenView({
    super.key,
    required this.parentReportsCount,
    required this.healthRecordsCount,
    required this.recordingTime,
    required this.onBack,
    this.recordedBytes,
  });

  final int parentReportsCount;
  final int healthRecordsCount;
  final String recordingTime;
  final VoidCallback onBack;

  /// Bytes ghi âm local (ưu tiên nếu có)
  final Uint8List? recordedBytes;

  @override
  State<DoneScreenView> createState() => _DoneScreenViewState();
}

class _DoneScreenViewState extends State<DoneScreenView> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final hasAudio =
        (widget.recordedBytes != null && widget.recordedBytes!.isNotEmpty);
    if (!hasAudio) return;

    final player = AudioPlayer();
    _player = player;

    player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          player.seek(Duration.zero);
          player.pause();
        }
      });
    });
    player.durationStream.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur ?? Duration.zero);
    });

    try {
      setState(() => _isLoading = true);
      await player.setAudioSource(BytesAudioSource(widget.recordedBytes!));
    } catch (e) {
      debugPrint('Audio player init error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;
    if (_isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _player != null;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 58, 20, 24),
        children: [
          SizedBox(
            height: 90,
            child: Center(
              child: SvgPicture.asset('assets/garden_voice/report_mascot.svg'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Đã gửi thành công.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: context.k.ink),
          ),
          const SizedBox(height: 16),
          Text(
            'Không phải nhập lại ở đâu cả. Báo cáo đã được gửi tới phụ huynh.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 12, height: 1.4, color: context.k.inkSoft),
          ),
          const SizedBox(height: 16),
          SurfaceBox(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summaryRow(context, widget.parentReportsCount,
                    'phiếu liên lạc cho phụ huynh'),
                if (widget.healthRecordsCount > 0) ...[
                  const SizedBox(height: 12),
                  _summaryRow(context, widget.healthRecordsCount,
                      'ghi nhận vào sổ sức khỏe'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SurfaceBox(
            borderColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              '${widget.parentReportsCount} phụ huynh nhận phiếu. Sổ sức khỏe có ${widget.healthRecordsCount} dòng mới. Tất cả đến từ ghi âm lúc ${widget.recordingTime}.',
              style: TextStyle(
                  fontSize: 12, height: 1.4, color: context.k.inkSoft),
            ),
          ),
          // ── Audio player ──────────────────────────────────────────────────
          if (hasAudio) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: _togglePlay,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FCFB),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border(bottom: BorderSide(color: context.k.lineStrong)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0E212E2B),
                        blurRadius: 16,
                        offset: Offset(0, 4)),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: context.k.brand, shape: BoxShape.circle),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : _isPlaying
                              ? const Icon(Icons.pause_rounded,
                                  color: Colors.white, size: 20)
                              : SvgPicture.asset(
                                  'assets/garden_voice/done_replay.svg'),
                    ),
                    const SizedBox(width: 12),
                    Text('Nghe lại bản ghi',
                        style: TextStyle(fontSize: 14, color: context.k.ink)),
                    const Spacer(),
                    Text(_formatDuration(_duration),
                        style:
                            TextStyle(fontSize: 12, color: context.k.inkSoft)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.onBack,
            style: FilledButton.styleFrom(
              backgroundColor: context.k.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Về tổng quan lớp'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(BuildContext context, int count, String label) {
    return Row(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 20,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: context.k.brand)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Text(label, style: TextStyle(fontSize: 14, color: context.k.ink)),
        ),
      ],
    );
  }
}
