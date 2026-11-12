import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

/// Thanh hiển thị 1 bản ghi âm trong phiên nhiều đoạn (kiểu Messenger, phong cách Garden Voice).
///
/// Bên phải thanh có 2 nút xếp dọc:
/// - Trên: nút `X` để xoá đoạn ghi nhầm.
/// - Dưới: nút mũi tên để mở rộng / thu gọn toàn bộ nội dung đã nói (và sửa nhanh nếu cần).
class SessionClipBar extends StatefulWidget {
  const SessionClipBar({
    super.key,
    required this.index,
    required this.clip,
    required this.isPlaying,
    required this.isLoadingAudio,
    required this.playProgress,
    required this.isExpanded,
    required this.isDeleting,
    required this.isSavingTranscript,
    this.editedTranscript,
    required this.onTogglePlay,
    required this.onDelete,
    required this.onToggleExpand,
    required this.onSaveTranscript,
    this.onTranscriptChanged,
  });

  final int index;
  final VoiceClip clip;
  final bool isPlaying;
  final bool isLoadingAudio;
  final double playProgress;
  final bool isExpanded;
  final bool isDeleting;
  final bool isSavingTranscript;
  final String? editedTranscript;
  final VoidCallback onTogglePlay;
  final VoidCallback onDelete;
  final VoidCallback onToggleExpand;
  final ValueChanged<String> onSaveTranscript;
  final ValueChanged<String>? onTranscriptChanged;

  @override
  State<SessionClipBar> createState() => _SessionClipBarState();
}

class _SessionClipBarState extends State<SessionClipBar> {
  static const List<double> _waveHeights = [
    9,
    15,
    19,
    12,
    20,
    14,
    10,
    17,
    19,
    11,
    15,
    18,
    13,
    10,
    16,
    11,
    14,
    9,
  ];

  late final TextEditingController _controller;
  bool _dirty = false;

  String get _resolvedTranscript =>
      (widget.editedTranscript ?? widget.clip.transcript ?? '').trim();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _resolvedTranscript);
  }

  @override
  void didUpdateWidget(covariant SessionClipBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = _resolvedTranscript;
    if (!_dirty && _controller.text != incoming) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDuration(double? seconds) {
    final totalSec = (seconds ?? 0).round().clamp(0, 3600);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final clip = widget.clip;
    final isPending = clip.isPendingOrProcessing;
    final isFailed = clip.isFailed;
    final canExpand = !isPending;

    final Color cardBg;
    final Color borderColor;
    if (widget.isPlaying || widget.isExpanded) {
      cardBg = const Color(0xFFEEF9F3);
      borderColor = k.brand;
    } else if (isPending) {
      cardBg = const Color(0xFFFFFDF7);
      borderColor = const Color(0xFFE7C99E);
    } else if (isFailed) {
      cardBg = k.badTint.withValues(alpha: .45);
      borderColor = k.bad.withValues(alpha: .5);
    } else {
      cardBg = k.reviewSurface;
      borderColor = k.lineStrong;
    }

    final timeLabel = _formatTimeOfDay(clip.createdAt);
    final durationLabel = _formatDuration(clip.audioDuration);
    final activeBars =
        (widget.playProgress.clamp(0.0, 1.0) * _waveHeights.length).round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: (widget.isPlaying || widget.isExpanded) ? 1.6 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: k.ink.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Play / Pause circle button
              Material(
                color: widget.isPlaying ? k.brandStrong : k.brand,
                shape: const CircleBorder(),
                child: InkWell(
                  key: ValueKey('clip-play-${clip.voiceRecordId}'),
                  customBorder: const CircleBorder(),
                  onTap: widget.isLoadingAudio ? null : widget.onTogglePlay,
                  child: SizedBox.square(
                    dimension: 40,
                    child: widget.isLoadingAudio
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: k.surface,
                            ),
                          )
                        : Icon(
                            widget.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: k.surface,
                            size: 22,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Middle: label, status pill, waveform, duration, and 1-line preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Đoạn ${widget.index + 1}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: k.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '· $timeLabel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: k.inkFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ClipStatusBadge(clip: clip),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 22,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (var i = 0; i < _waveHeights.length; i++)
                                  Container(
                                    width: 3,
                                    height: _waveHeights[i],
                                    decoration: BoxDecoration(
                                      color: (widget.isPlaying && i < activeBars)
                                          ? k.brand
                                          : k.lineStrong,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          durationLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: k.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    if (!widget.isExpanded) ...[
                      const SizedBox(height: 5),
                      Text(
                        isPending
                            ? 'Đang chuyển giọng nói thành văn bản…'
                            : isFailed
                                ? (clip.errorMessage?.trim().isNotEmpty == true
                                    ? clip.errorMessage!.trim()
                                    : 'Nhận dạng giọng nói thất bại')
                                : (_resolvedTranscript.isNotEmpty
                                    ? '"$_resolvedTranscript"'
                                    : 'Chưa có nội dung văn bản'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle:
                              isPending ? FontStyle.italic : FontStyle.normal,
                          fontWeight: FontWeight.w600,
                          color: isPending
                              ? k.warn
                              : isFailed
                                  ? k.badText
                                  : k.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right stacked controls: X delete on top, Chevron expand/collapse right below
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Xoá bản ghi này',
                    child: Material(
                      color: k.surface,
                      shape: CircleBorder(
                        side: BorderSide(color: k.line),
                      ),
                      child: InkWell(
                        key: ValueKey('clip-delete-${clip.voiceRecordId}'),
                        customBorder: const CircleBorder(),
                        onTap: widget.isDeleting ? null : widget.onDelete,
                        child: SizedBox.square(
                          dimension: 28,
                          child: widget.isDeleting
                              ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: k.bad,
                                  ),
                                )
                              : Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: k.inkFaint,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Tooltip(
                    message: widget.isExpanded
                        ? 'Thu gọn nội dung'
                        : 'Mở rộng nội dung đã nói',
                    child: Material(
                      color: widget.isExpanded
                          ? k.brand
                          : (canExpand ? k.brandTint : k.surfaceSunken),
                      shape: CircleBorder(
                        side: BorderSide(
                          color: widget.isExpanded
                              ? k.brand
                              : (canExpand ? k.lineStrong : k.line),
                        ),
                      ),
                      child: InkWell(
                        key: ValueKey('clip-expand-${clip.voiceRecordId}'),
                        customBorder: const CircleBorder(),
                        onTap: canExpand ? widget.onToggleExpand : null,
                        child: SizedBox.square(
                          dimension: 28,
                          child: Icon(
                            widget.isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: widget.isExpanded
                                ? k.surface
                                : (canExpand ? k.brand : k.inkFaint),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Expanded spoken transcript content integrated inside the clip bar
          if (widget.isExpanded) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: k.inputBorder),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: k.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: k.inputBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: k.brandTint,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: k.brand,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nội dung đã nói',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: k.inkSoft,
                          ),
                        ),
                      ),
                      if (_dirty)
                        TextButton(
                          onPressed: widget.isSavingTranscript
                              ? null
                              : () {
                                  setState(() => _dirty = false);
                                  widget.onSaveTranscript(
                                      _controller.text.trim());
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: k.brand,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 2),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: widget.isSavingTranscript
                              ? SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: k.brand,
                                  ),
                                )
                              : const Text(
                                  'Lưu chữ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isFailed)
                    Text(
                      clip.errorMessage?.trim().isNotEmpty == true
                          ? clip.errorMessage!.trim()
                          : 'Không thể nhận dạng đoạn này. Bấm X ở trên để xoá rồi ghi lại.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: k.badText,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    TextField(
                      key: ValueKey('clip-transcript-input-${clip.voiceRecordId}'),
                      controller: _controller,
                      maxLines: null,
                      minLines: 2,
                      onChanged: (value) {
                        if (!_dirty) {
                          setState(() => _dirty = true);
                        }
                        widget.onTranscriptChanged?.call(value);
                      },
                      onSubmitted: (value) {
                        setState(() => _dirty = false);
                        widget.onSaveTranscript(value.trim());
                      },
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: k.ink,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Nhập hoặc chỉnh sửa nội dung đoạn ghi âm…',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: k.inkFaint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClipStatusBadge extends StatelessWidget {
  const _ClipStatusBadge({required this.clip});

  final VoiceClip clip;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final String label;
    final Color bg;
    final Color fg;

    if (clip.isPendingOrProcessing) {
      label = 'Đang nhận dạng…';
      bg = k.warnTint;
      fg = k.warn;
    } else if (clip.isFailed) {
      label = 'Lỗi STT';
      bg = k.badTint;
      fg = k.badText;
    } else {
      label = 'Đã xong';
      bg = k.okTint;
      fg = k.ok;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
