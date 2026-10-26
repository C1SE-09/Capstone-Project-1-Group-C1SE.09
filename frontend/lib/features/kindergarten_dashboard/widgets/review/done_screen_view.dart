import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
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
  Duration _position = Duration.zero;
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
          _position = Duration.zero;
          player.seek(Duration.zero);
          player.pause();
        }
      });
    });
    player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
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
      appBar: KAppBar(
        title: 'Đã gửi thành công',
        subtitle: 'Xác nhận lúc ${widget.recordingTime}',
        onBack: widget.onBack,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: context.k.brand,
              child: const Icon(Icons.check_rounded,
                  size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Đã gửi thành công.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.k.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Không phải nhập lại ở đâu cả. Báo cáo đã được gửi tới phụ huynh.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.k.inkSoft),
          ),
          const SizedBox(height: 24),
          SurfaceBox(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SummaryRow(Icons.description_outlined, widget.parentReportsCount,
                    'phiếu liên lạc cho phụ huynh'),
                const SizedBox(height: 6),
                SummaryRow(Icons.health_and_safety_outlined, widget.healthRecordsCount,
                    'ghi nhận vào sổ sức khỏe'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceBox(
            child: Text(
              '${widget.parentReportsCount} phụ huynh nhận phiếu. Sổ sức khỏe có ${widget.healthRecordsCount} dòng mới. Tất cả đến từ ghi âm lúc ${widget.recordingTime}.',
              style: TextStyle(fontSize: 12, color: context.k.inkSoft),
            ),
          ),
          // ── Audio player ──────────────────────────────────────────────────
          if (hasAudio) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: context.k.surface,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: context.k.brand.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: context.k.brand.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: context.k.brandTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.headphones_rounded,
                            color: context.k.brand, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nghe lại bản ghi âm',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.k.ink),
                            ),
                            Text(
                              'Bản ghi âm đã được gửi đi',
                              style: TextStyle(
                                  fontSize: 11, color: context.k.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Slider tiến trình
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: context.k.brand,
                      inactiveTrackColor:
                          context.k.brand.withValues(alpha: 0.18),
                      thumbColor: context.k.brand,
                      overlayColor: context.k.brand.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: (_duration.inMilliseconds > 0)
                          ? (_position.inMilliseconds /
                                  _duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                          : 0.0,
                      onChanged: (v) {
                        if (_duration.inMilliseconds > 0) {
                          _player?.seek(Duration(
                              milliseconds:
                                  (v * _duration.inMilliseconds).round()));
                        }
                      },
                    ),
                  ),
                  // Thời gian + nút play
                  Row(
                    children: [
                      Text(
                        _formatDuration(_position),
                        style:
                            TextStyle(fontSize: 11, color: context.k.inkSoft),
                      ),
                      const Spacer(),
                      Text(
                        _formatDuration(_duration),
                        style:
                            TextStyle(fontSize: 11, color: context.k.inkSoft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : GestureDetector(
                            onTap: _togglePlay,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: context.k.brand,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        context.k.brand.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
          // ─────────────────────────────────────────────────────────────────
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: widget.onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KRadii.control)),
            ),
            child: const Text('Về tổng quan lớp'),
          ),
        ],
      ),
    );
  }
}
