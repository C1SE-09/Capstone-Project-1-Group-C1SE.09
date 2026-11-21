import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/record_hub_screen.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:file_picker/file_picker.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/common/bug_report_sheet.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/record_models.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({
    super.key,
    required this.mode,
    required this.onBack,
    required this.onDone,
    this.file,
    this.session,
    this.editedMergedTranscript,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.child,
    this.teacherRepository,
  });
  final RecordMode mode;
  final VoidCallback onBack;
  final void Function(VoiceRecord? record, ExtractionData? extraction) onDone;
  final PlatformFile? file;
  final VoiceRecordingSession? session;
  final String? editedMergedTranscript;
  final String classId;
  final Child? child;
  final TeacherRepository? teacherRepository;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  int active = 0;
  String? errorMessage;
  bool isProcessing = false;
  VoiceRecord? uploadedRecord;
  String? completedTranscript;
  late final TeacherRepository repository =
      widget.teacherRepository ?? TeacherRepository();

  List<String> get steps => [
        widget.session != null
            ? 'Đã ghép ${widget.session!.completedCount} bản ghi'
            : 'Đã nhận bản ghi âm',
        'Đang chuyển giọng nói thành văn bản',
        'Đang phân tích & tổng hợp nội dung',
        widget.mode == RecordMode.classroom
            ? 'Đang tách thông tin từng bé'
            : 'Đang lưu nháp & gửi báo cáo',
      ];

  // Kiểm tra nội dung transcript có liên quan đến học sinh / hoạt động lớp học không.
  bool _isRelevantToStudent(String text) {
    if (text.trim().isEmpty) return true; // transcript rỗng → xử lý bình thường
    final lower = text.toLowerCase();
    // Từ khoá liên quan đến học sinh / môi trường mầm non.
    final keywords = [
      'bé',
      'em',
      'con',
      'trẻ',
      'học sinh',
      'cháu',
      'ăn',
      'ngủ',
      'chơi',
      'học',
      'hoạt động',
      'lớp',
      'sức khỏe',
      'tâm trạng',
      'cô',
      'giáo viên',
      'buổi sáng',
      'buổi chiều',
      'hôm nay',
      'ngày',
      'vui',
      'khóc',
      'ngoan',
      'nghịch',
      'tích cực',
      'kể',
      'nói',
      'nhắc',
      'báo cáo',
      'nhật ký',
      'ho',
      'sốt',
      'nhẹ',
      'ốm',
      'bệnh',
      'mệt',
      'khỏe',
      'đau',
      'quấy',
      'khóc',
      'buồn',
      'ngoan',
      'nói',
      'chuyện',
      'kể',
      'đùa',
      'hát',
      'vẽ',
      'chơi',
    ];
    return keywords.any((kw) => lower.contains(kw));
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _start() async {
    if (isProcessing) return;
    setState(() {
      isProcessing = true;
      errorMessage = null;
      active = completedTranscript != null
          ? 2
          : uploadedRecord != null
              ? 1
              : 0;
    });

    final file = widget.file;
    final session = widget.session;
    if (file == null && session == null) {
      setState(() {
        isProcessing = false;
        errorMessage =
            'Không tìm thấy bản ghi âm. Vui lòng quay lại và ghi âm lại.';
      });
      return;
    }

    try {
      final teacherId = AuthRepository.currentUser?.teacherId ??
          'bbbbbbbb-0000-0000-0000-000000000001';
      final childId = widget.mode == RecordMode.child ? widget.child?.id : null;

      VoiceRecord? currentRecord = uploadedRecord;
      String? transcript = completedTranscript;

      if (session != null && (currentRecord == null || transcript == null)) {
        setState(() => active = 1);
        final mergeRes = await repository.mergeVoiceSession(
          sessionId: session.sessionId,
          teacherId: teacherId,
          editedTranscript: widget.editedMergedTranscript,
        );
        final repId = mergeRes.representativeVoiceRecordId ??
            (session.clips.isNotEmpty
                ? session.clips.first.voiceRecordId
                : null);
        if (repId == null || repId.isEmpty) {
          throw Exception('Không tìm thấy bản ghi đại diện để phân tích.');
        }
        transcript = mergeRes.mergedTranscript;
        currentRecord = VoiceRecord(
          id: repId,
          status: 'completed',
          editedTranscript: transcript,
        );
        uploadedRecord = currentRecord;
      } else if (currentRecord == null) {
        // 1. Upload audio file to backend / MinIO
        setState(() => active = 0);

        String safeFilePath = '';
        if (!kIsWeb) {
          try {
            safeFilePath = file!.path ?? '';
          } catch (_) {
            safeFilePath = '';
          }
        }

        Uint8List? fileBytes;
        try {
          fileBytes = file!.bytes;
        } catch (_) {}

        if (fileBytes == null && file!.readStream != null) {
          try {
            final chunks = <int>[];
            await for (final chunk in file.readStream!) {
              chunks.addAll(chunk);
            }
            fileBytes = Uint8List.fromList(chunks);
          } catch (_) {}
        }

        currentRecord = await repository.uploadAudio(
          filePath: safeFilePath,
          fileBytes: fileBytes,
          fileName: file!.name,
          classId: widget.classId,
          teacherId: teacherId,
          childId: childId,
        );
        uploadedRecord = currentRecord;
      }

      if (!mounted) return;
      final voiceRecord = currentRecord;

      // 2. Poll for PhoWhisper speech-to-text unless a prior attempt finished it.
      if (transcript == null) {
        setState(() => active = 1);
        for (var attempt = 0; attempt < 60; attempt++) {
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;

          try {
            currentRecord = await repository.getVoiceRecord(
              voiceId: voiceRecord.id,
              teacherId: teacherId,
            );
            uploadedRecord = currentRecord;
          } catch (e) {
            if (attempt >= 58) rethrow;
            continue;
          }

          if (currentRecord.status == 'completed') {
            transcript = currentRecord.effectiveTranscript;
            break;
          } else if (currentRecord.status == 'failed') {
            uploadedRecord = null;
            final errMsg = currentRecord.errorMessage?.trim();
            throw Exception((errMsg != null && errMsg.isNotEmpty)
                ? errMsg
                : 'Quá trình nhận dạng giọng nói thất bại.');
          }
        }

        if (transcript == null && currentRecord?.status != 'completed') {
          throw Exception(
            'Quá trình xử lý âm thanh quá thời gian chờ (hơn 2 phút). Vui lòng thử lại hoặc chọn file âm thanh ngắn hơn.',
          );
        }
      }

      final effectiveTranscript = transcript?.trim() ?? '';
      if (effectiveTranscript.isEmpty) {
        throw Exception(
          'Không nhận diện được nội dung giọng nói từ bản ghi. Vui lòng nói to, rõ ràng hơn hoặc thử lại.',
        );
      }

      if (!mounted) return;
      completedTranscript = effectiveTranscript;

      // 3. Run NLP model extraction
      setState(() => active = 2);
      late final ExtractionData extraction;
      try {
        extraction = await repository.analyzeTranscript(
          voiceId: voiceRecord.id,
          teacherId: teacherId,
          editedTranscript: effectiveTranscript,
        );
      } on TeacherRepositoryException catch (e) {
        // ─── HTTP 400: Backend validation — nội dung không liên quan học sinh ───
        if (e.statusCode == 400) {
          if (!mounted) return;
          setState(() => isProcessing = false);
          final isEn = LocaleController.instance.isEnglish;
          final serverMessage = e.message.isNotEmpty
              ? e.message
              : (isEn
                  ? 'Audio recording is not relevant to student reports.'
                  : 'Nội dung ghi âm không liên quan đến báo cáo học sinh.');
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: context.k.warn, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEn ? 'Irrelevant Content' : 'Nội dung không liên quan',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Text(
                isEn
                    ? '$serverMessage\n\nPlease record again and describe the child during the day (eating, sleeping, mood, activities...).'
                    : '$serverMessage\n\nVui lòng ghi âm lại và mô tả về bé trong ngày (ăn uống, giấc ngủ, tâm trạng, hoạt động…).',
                style: const TextStyle(fontSize: 14, height: 1.55),
              ),
              actions: [
                FilledButton.icon(
                  icon: const Icon(Icons.mic_none_rounded, size: 18),
                  label: Text(isEn ? 'Record again' : 'Ghi âm lại'),
                  onPressed: () {
                    Navigator.pop(context); // đóng dialog
                    widget.onBack(); // về màn hình ghi âm
                  },
                ),
              ],
            ),
          );
          return; // dừng – onBack() đã xử lý navigation
        }
        rethrow;
      } catch (_) {
        rethrow;
      }

      if (!mounted) return;

      // 3b. Kiểm tra transcript có liên quan đến học sinh không.
      final effectiveText = extraction.transcript ?? effectiveTranscript;
      if (!_isRelevantToStudent(effectiveText)) {
        setState(() {
          isProcessing = false;
          errorMessage = null;
        });
        if (!mounted) return;
        final isEn = LocaleController.instance.isEnglish;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: context.k.warn),
                const SizedBox(width: 8),
                Text(isEn ? 'Irrelevant Content' : 'Nội dung không liên quan',
                    style: const TextStyle(fontSize: 18)),
              ],
            ),
            content: Text(
              isEn
                  ? 'Audio recording is not relevant to student activities.\n\nPlease record again and describe the child during the day (eating, sleeping, mood, activities...).'
                  : 'Nội dung ghi âm không liên quan đến hoạt động học sinh.\n\nVui lòng ghi âm lại và mô tả về bé trong ngày (ăn uống, giấc ngủ, tâm trạng, hoạt động…).',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isEn ? 'Record again' : 'Ghi âm lại'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDone(currentRecord, extraction);
                },
                child: Text(isEn ? 'Continue anyway' : 'Vẫn tiếp tục'),
              ),
            ],
          ),
        );
        return;
      }

      // 4. Final step
      setState(() => active = 3);
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      widget.onDone(currentRecord, extraction);
    } catch (e) {
      if (!mounted) return;
      final friendlyMsg = getFriendlyErrorMessage(e);
      setState(() {
        isProcessing = false;
        errorMessage = friendlyMsg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressStep = active == 0
        ? 0
        : active < 3
            ? 1
            : 2;
    return GardenVoiceScope(
      child: Builder(
        builder: (context) {
          final k = context.k;
          if (errorMessage != null) {
            return Scaffold(
              backgroundColor: k.canvas,
              body: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: GardenVoiceRecordHeader(
                        title: 'Thông báo sự cố',
                        subtitle: 'Phân tích bản ghi âm',
                        onBack: widget.onBack,
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
                        children: [
                          Center(
                            child: SvgPicture.asset(
                              'assets/garden_voice/process_error.svg',
                              width: 76,
                              height: 76,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Chưa xử lý được bản ghi âm',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: k.ink)),
                          const SizedBox(height: 12),
                          Text(errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, height: 1.4, color: k.inkSoft)),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FCFB),
                              border: Border.all(color: k.lineStrong),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    LocaleController.instance.isEnglish
                                        ? 'You can'
                                        : 'Thầy cô có thể',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: k.ink)),
                                const SizedBox(height: 4),
                                Text(
                                  LocaleController.instance.isEnglish
                                      ? 'Try again in a few moments, or go back to select another recording.'
                                      : 'Thử lại sau ít phút, hoặc quay lại để chọn bản ghi khác.',
                                  style:
                                      TextStyle(fontSize: 12, color: k.inkSoft),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: widget.file == null
                            ? SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: widget.onBack,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: k.brand,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 48),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text('Chọn bản ghi'),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: widget.onBack,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 48),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: const Text('Quay lại'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _start,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: k.brand,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 48),
                                        shape: const StadiumBorder(),
                                      ),
                                      child: const Text('Thử lại'),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final statusText = switch (active) {
            0 => 'Đang tải bản ghi âm lên',
            1 => 'Đang chuyển giọng nói thành văn bản',
            2 => 'Đang phân tích nội dung',
            _ => 'Đang hoàn tất báo cáo',
          };
          return Scaffold(
            backgroundColor: k.canvas,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: GardenVoiceRecordHeader(
                      title: 'Đang xử lý',
                      subtitle: 'Phân tích bản ghi âm',
                      onBack: widget.onBack,
                      showProgress: true,
                      progressStep: progressStep,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: k.brand,
                                backgroundColor: k.brandTint,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(statusText,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: k.ink)),
                                  const SizedBox(height: 2),
                                  Text(
                                      'Hệ thống đang xử lý file ghi âm của bạn.',
                                      style: TextStyle(
                                          fontSize: 14, color: k.inkSoft)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FCFB),
                            border: Border.all(color: k.lineStrong),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x0E212E2B),
                                  blurRadius: 16,
                                  offset: Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            children: [
                              for (var index = 0;
                                  index < steps.length;
                                  index++) ...[
                                Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: index < active
                                            ? k.ok
                                            : index == active
                                                ? k.brandTint
                                                : k.surfaceSunken,
                                        shape: BoxShape.circle,
                                      ),
                                      child: index < active
                                          ? const Icon(Icons.check,
                                              size: 14, color: Colors.white)
                                          : index == active
                                              ? Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                      color: k.brand,
                                                      shape: BoxShape.circle),
                                                )
                                              : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        steps[index],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: index == active
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: index <= active
                                              ? k.ink
                                              : k.inkSoft,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (index < steps.length - 1)
                                  const SizedBox(height: 14),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: k.brandTint,
                            border: Border.all(color: k.lineStrong),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  color: k.brand, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.file == null
                                      ? 'Vui lòng giữ màn hình này cho đến khi hoàn tất.'
                                      : 'Đang xử lý file "${widget.file!.name}". Vui lòng giữ màn hình này cho đến khi hoàn tất.',
                                  style: TextStyle(
                                      fontSize: 14, height: 1.4, color: k.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 13,
                            child: OutlinedButton(
                              onPressed: () =>
                                  showBugReportBottomSheet(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: k.brand,
                                side: BorderSide(color: k.line),
                                minimumSize: const Size(0, 48),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('Sự cố'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 21,
                            child: FilledButton(
                              onPressed: widget.onBack,
                              style: FilledButton.styleFrom(
                                backgroundColor: k.brand,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('Xem lại'),
                            ),
                          ),
                        ],
                      ),
                    ),
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

