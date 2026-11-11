import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_audio/just_audio.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

typedef AudioPlayerFactory = AudioPlayer Function();

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
  const AudioPlayerCard({
    super.key,
    required this.recordedBytes,
    this.audioPlayerFactory,
  });

  final Uint8List recordedBytes;
  final AudioPlayerFactory? audioPlayerFactory;

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
    final player = widget.audioPlayerFactory?.call() ?? AudioPlayer();
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

  String _formatProgress(double ratio) =>
      '${_formatDuration(Duration(milliseconds: (ratio.clamp(0.0, 1.0) * _duration.inMilliseconds).round()))} / ${_formatDuration(_duration)}';

  void _seekToRatio(double ratio) {
    if (_duration.inMilliseconds == 0) return;
    _player?.seek(Duration(
      milliseconds: (ratio.clamp(0.0, 1.0) * _duration.inMilliseconds).round(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const List<double> heights = [
      8,
      16,
      24,
      12,
      20,
      28,
      14,
      22,
      10,
      18,
      26,
      12,
      20,
      8,
      16,
      22
    ];
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.k.reviewSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.k.lineStrong),
        boxShadow: [
          BoxShadow(
              color: context.k.ink.withValues(alpha: .055),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: _isLoading
                ? const SizedBox(
                    width: 44,
                    height: 44,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _isPlaying
                    ? Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: context.k.brand, shape: BoxShape.circle),
                        child: Icon(Icons.pause,
                            color: context.k.surface, size: 22),
                      )
                    : SvgPicture.asset('assets/garden_voice/review_play.svg'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                final key = event.logicalKey;
                final step = key == LogicalKeyboardKey.arrowRight ||
                        key == LogicalKeyboardKey.arrowUp
                    ? .05
                    : key == LogicalKeyboardKey.arrowLeft ||
                            key == LogicalKeyboardKey.arrowDown
                        ? -.05
                        : null;
                if (step == null) return KeyEventResult.ignored;
                _seekToRatio(progress + step);
                return KeyEventResult.handled;
              },
              child: Semantics(
                label: 'Tiến trình bản ghi âm',
                value: _formatProgress(progress),
                increasedValue: _formatProgress(progress + .05),
                decreasedValue: _formatProgress(progress - .05),
                slider: true,
                onIncrease: () => _seekToRatio(progress + .05),
                onDecrease: () => _seekToRatio(progress - .05),
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    key: const ValueKey('audio-waveform'),
                    excludeFromSemantics: true,
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _seekToRatio(
                        details.localPosition.dx / constraints.maxWidth),
                    onHorizontalDragUpdate: (details) => _seekToRatio(
                        details.localPosition.dx / constraints.maxWidth),
                    child: SizedBox(
                      height: 36,
                      child: Row(
                        spacing: 2,
                        children: [
                          for (var index = 0; index < heights.length; index++)
                            Container(
                              width: 3,
                              height: heights[index],
                              decoration: BoxDecoration(
                                color: index / heights.length < progress
                                    ? context.k.brand
                                    : context.k.line,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDuration(_duration),
                  style: TextStyle(fontSize: 12, color: context.k.ink)),
              Text('Bản ghi gốc',
                  style: TextStyle(fontSize: 12, color: context.k.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}
