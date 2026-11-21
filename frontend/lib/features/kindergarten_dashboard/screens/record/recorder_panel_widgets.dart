import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:file_picker/file_picker.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';



class GardenVoiceRecorderPanel extends StatelessWidget {
  const GardenVoiceRecorderPanel({super.key, 
    required this.recording,
    required this.isBusy,
    required this.seconds,
    required this.time,
    required this.message,
    required this.wave,
    required this.wave2,
    required this.onToggle,
  });

  final bool recording;
  final bool isBusy;
  final int seconds;
  final String time;
  final String message;
  final AnimationController wave;
  final AnimationController wave2;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (recording) ...[
                  SvgPicture.asset('assets/garden_voice/record_status_dot.svg'),
                  const SizedBox(width: 8),
                ],
                Text(
                  recording ? 'Đang ghi âm · Nói tự nhiên' : message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: recording ? 14 : 13,
                    height: 1.4,
                    fontWeight: recording ? FontWeight.w800 : FontWeight.w700,
                    color: recording ? k.bad : k.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(time,
                style: TextStyle(
                  fontSize: 28,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                  color: seconds >= 150 ? k.warn : k.ink,
                )),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: Listenable.merge([wave, wave2]),
              builder: (_, __) => SizedBox(
                width: 165,
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(28, (index) {
                    final phaseOffset = index * .42;
                    final amp1 =
                        (math.sin(phaseOffset + wave.value * math.pi * 2) + 1) /
                            2;
                    final amp2 = (math.sin(phaseOffset * 1.3 +
                                wave2.value * math.pi * 2 +
                                1.1) +
                            1) /
                        2;
                    final combined = amp1 * .6 + amp2 * .4;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: 3,
                      height: recording ? 5 + 38 * combined : 4,
                      decoration: BoxDecoration(
                        color: recording
                            ? k.brand.withValues(alpha: .5 + .5 * combined)
                            : k.brand.withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox.square(
              dimension: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                      'assets/garden_voice/record_progress_outer.svg'),
                  if (recording)
                    SizedBox.square(
                      dimension: 132,
                      child: CircularProgressIndicator(
                        value: seconds / 180,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.transparent,
                        color: seconds >= 150 ? k.warn : k.brand,
                      ),
                    ),
                  Material(
                    color: recording ? k.bad : k.brand,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isBusy ? null : onToggle,
                      child: SizedBox.square(
                        dimension: 96,
                        child: isBusy
                            ? const Center(
                                child: SizedBox.square(
                                  dimension: 32,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : Tooltip(
                                message: recording
                                    ? 'Dừng ghi âm'
                                    : 'Bắt đầu ghi âm',
                                child: Icon(
                                  recording
                                      ? Icons.pause_rounded
                                      : Icons.mic_none_rounded,
                                  size: 36,
                                  color: Colors.white,
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
}

class CompactSessionRecorderDock extends StatelessWidget {
  const CompactSessionRecorderDock({super.key, 
    required this.recording,
    required this.isBusy,
    required this.isUploading,
    required this.seconds,
    required this.time,
    required this.wave,
    required this.wave2,
    required this.onToggleMic,
    required this.onPickFile,
  });

  final bool recording;
  final bool isBusy;
  final bool isUploading;
  final int seconds;
  final String time;
  final AnimationController wave;
  final AnimationController wave2;
  final VoidCallback onToggleMic;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: recording ? const Color(0xFFFFF8F7) : k.reviewSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: recording ? k.bad.withValues(alpha: .5) : k.lineStrong,
          width: 1.4,
        ),
      ),
      child: recording
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SvgPicture.asset('assets/garden_voice/record_status_dot.svg'),
                    const SizedBox(width: 8),
                    Text(
                      'Đang ghi đoạn mới…',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: k.badText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: seconds >= 150 ? k.warn : k.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: k.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: k.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([wave, wave2]),
                          builder: (_, __) => SizedBox(
                            height: 28,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(22, (index) {
                                final phaseOffset = index * .42;
                                final amp = (math.sin(phaseOffset +
                                            wave.value * math.pi * 2) +
                                        1) /
                                    2;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 80),
                                  width: 3,
                                  height: 6 + 20 * amp,
                                  decoration: BoxDecoration(
                                    color: k.brand.withValues(alpha: .45 + .55 * amp),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Tooltip(
                        message: context.l10n?.sttStopRecording ?? 'Dừng ghi âm',
                        child: FilledButton.icon(
                          onPressed: isBusy ? null : onToggleMic,
                          icon: const Icon(Icons.stop_rounded, size: 16),
                          label: Text(context.l10n?.sttSaveClip ?? 'Lưu đoạn'),
                          style: FilledButton.styleFrom(
                            backgroundColor: k.brand,
                            foregroundColor: k.surface,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Tooltip(
                  message: context.l10n?.sttStartRecording ?? 'Bắt đầu ghi âm',
                  child: Material(
                    color: k.brand,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      key: const ValueKey('session-mic-btn'),
                      customBorder: const CircleBorder(),
                      onTap: isBusy ? null : onToggleMic,
                      child: SizedBox.square(
                        dimension: 46,
                        child: isUploading
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: k.surface,
                                ),
                              )
                            : Icon(
                                Icons.mic_none_rounded,
                                color: k.surface,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUploading
                            ? 'Đang tải bản ghi vào phiên…'
                            : 'Ghi thêm bản mới',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: k.ink,
                        ),
                      ),
                      Text(
                        isUploading
                            ? 'Vui lòng chờ trong giây lát'
                            : 'Chạm mic để thêm vào phiên hôm nay',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: k.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onPickFile,
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: Text(context.l10n?.sttUploadFile ?? 'Tải file'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: k.brand,
                    backgroundColor: k.surface,
                    side: BorderSide(color: k.lineStrong),
                    shape: const StadiumBorder(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 38),
                    textStyle: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class SelectedAudioFileCard extends StatelessWidget {
  const SelectedAudioFileCard({super.key, required this.file, required this.formatBytes});

  final PlatformFile file;
  final String Function(int bytes) formatBytes;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      constraints: const BoxConstraints(minHeight: 289),
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: k.lineStrong),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.audio_file_rounded, size: 48, color: k.brand),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(file.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, color: k.ink)),
          ),
          const SizedBox(height: 6),
          Text('Kích thước: ${formatBytes(file.size)}',
              style: TextStyle(color: k.inkSoft)),
          const SizedBox(height: 14),
          Text(
            context.l10n?.readyToGenerateReports ?? 'Đã sẵn sàng tạo báo cáo',
            style: TextStyle(fontSize: 12, color: k.ok),
          ),
        ],
      ),
    );
  }
}

