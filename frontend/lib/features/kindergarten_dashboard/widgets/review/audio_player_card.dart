import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

/// AudioSource từ bytes trong bộ nhớ, dùng cho just_audio.
// ignore: experimental_member_use
class BytesAudioSource extends StreamAudioSource {
  BytesAudioSource(this._bytes);
  final Uint8List _bytes;

  @override
  // ignore: experimental_member_use
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    // ignore: experimental_member_use
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}

class AudioPlayerCard extends StatefulWidget {
  const AudioPlayerCard({super.key, required this.recordedBytes});

  final Uint8List recordedBytes;

  @override
  State<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<AudioPlayerCard> {
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
    if (widget.recordedBytes.isEmpty) return;
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
      await player.setAudioSource(BytesAudioSource(widget.recordedBytes));
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.k.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.k.brand.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: context.k.brand.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: 2),
                    Text(
                      'Chạm để nghe lại giọng nói cô vừa ghi âm',
                      style:
                          TextStyle(fontSize: 11, color: context.k.inkSoft),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.k.brand,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(9),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: context.k.brand,
              inactiveTrackColor: context.k.brand.withValues(alpha: 0.18),
              thumbColor: context.k.brand,
              overlayColor: context.k.brand.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: (_duration.inMilliseconds > 0)
                  ? (_position.inMilliseconds / _duration.inMilliseconds)
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
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
          ),
        ],
      ),
    );
  }
}
