import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:adark_frontend/data/repositories/http_report_response_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

/// StreamAudioSource từ bộ nhớ Uint8List cho just_audio.
// ignore: experimental_member_use
class MemoryAudioSource extends StreamAudioSource {
  MemoryAudioSource(this._bytes, {this.contentType = 'audio/m4a'});
  final Uint8List _bytes;
  final String contentType;

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
      contentType: contentType,
    );
  }
}

/// Bong bóng phát tin nhắn thoại kiểu Messenger trong luồng trao đổi.
class VoiceMessageBubbleWidget extends StatefulWidget {
  const VoiceMessageBubbleWidget({
    super.key,
    required this.audioUrl,
    this.durationSeconds,
    required this.repository,
    this.isMe = false,
  });

  final String audioUrl;
  final int? durationSeconds;
  final HttpReportResponseRepository repository;
  final bool isMe;

  @override
  State<VoiceMessageBubbleWidget> createState() =>
      _VoiceMessageBubbleWidgetState();
}

class _VoiceMessageBubbleWidgetState extends State<VoiceMessageBubbleWidget> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  // Mô phỏng 24 cột sóng âm với biên độ ngẫu nhiên nhưng ổn định theo hash của audioUrl
  late final List<double> _waveformHeights = _generateWaveform(widget.audioUrl);

  static List<double> _generateWaveform(String seed) {
    final rand = math.Random(seed.hashCode);
    return List.generate(24, (i) {
      final h = 6.0 + rand.nextDouble() * 18.0;
      return h;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.durationSeconds != null && widget.durationSeconds! > 0) {
      _duration = Duration(seconds: widget.durationSeconds!);
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _initAndTogglePlay() async {
    if (_player == null) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      try {
        final bytes = await widget.repository.getAudioBytes(widget.audioUrl);
        if (!mounted) return;

        final player = AudioPlayer();
        _player = player;

        _stateSub = player.playerStateStream.listen((state) {
          if (!mounted) return;
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _position = Duration.zero;
              unawaited(player.seek(Duration.zero));
              unawaited(player.pause());
            }
          });
        });

        _posSub = player.positionStream.listen((pos) {
          if (!mounted) return;
          setState(() => _position = pos);
        });

        _durSub = player.durationStream.listen((dur) {
          if (!mounted || dur == null) return;
          setState(() => _duration = dur);
        });

        final ext = widget.audioUrl.contains('.')
            ? widget.audioUrl.split('.').last.toLowerCase()
            : 'm4a';
        final ct = switch (ext) {
          'mp3' => 'audio/mpeg',
          'wav' => 'audio/wav',
          'ogg' => 'audio/ogg',
          _ => 'audio/m4a',
        };

        await player.setAudioSource(MemoryAudioSource(bytes, contentType: ct));
        if (!mounted) return;
        setState(() => _isLoading = false);
        await player.play();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } else {
      if (_isPlaying) {
        await _player?.pause();
      } else {
        if (_position >= _duration && _duration > Duration.zero) {
          await _player?.seek(Duration.zero);
        }
        await _player?.play();
      }
    }
  }

  void _onSeek(double fraction) {
    if (_player == null || _duration == Duration.zero) return;
    final target = _duration * fraction.clamp(0.0, 1.0);
    _player?.seek(target);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalSec = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : (widget.durationSeconds != null && widget.durationSeconds! > 0
            ? (widget.durationSeconds! * 1000).toDouble()
            : 1.0);
    final curSec = _position.inMilliseconds.toDouble();
    final progress = (curSec / totalSec).clamp(0.0, 1.0);

    final brandColor = context.k.brand;
    final activeWaveColor = brandColor;
    final inactiveWaveColor = context.k.lineStrong;

    return Container(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe ? context.k.brandTint.withValues(alpha: 0.35) : context.k.surfaceSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nút Play / Pause tròn
          GestureDetector(
            onTap: _initAndTogglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: brandColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(
                      _hasError
                          ? Icons.refresh_rounded
                          : (_isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                      size: 22,
                      color: Colors.white,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Sóng âm thanh tương tác
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final local = box.globalToLocal(details.globalPosition);
                      final fraction = (local.dx - 48) / (box.size.width - 48);
                      _onSeek(fraction);
                    }
                  },
                  onTapDown: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final local = box.globalToLocal(details.globalPosition);
                      final fraction = (local.dx - 48) / (box.size.width - 48);
                      _onSeek(fraction);
                    }
                  },
                  child: SizedBox(
                    height: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(_waveformHeights.length, (idx) {
                        final barFraction = (idx + 1) / _waveformHeights.length;
                        final isBarActive = barFraction <= progress;
                        return Container(
                          width: 3,
                          height: _waveformHeights[idx],
                          decoration: BoxDecoration(
                            color: isBarActive
                                ? activeWaveColor
                                : inactiveWaveColor,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying
                          ? _formatDuration(_position)
                          : (_duration > Duration.zero
                              ? _formatDuration(_duration)
                              : '${widget.durationSeconds ?? 0}s'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: context.k.inkSoft,
                      ),
                    ),
                    if (_hasError)
                      Text(
                        'Lỗi tải audio',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.k.bad,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
