import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/child/child.dart'
    as domain_child;
import 'package:adark_frontend/domain/entities/class/class_info.dart'
    as domain_class;
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/child_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/severity_adapter.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

enum RecordMode { classroom, child }

class RecordHubScreen extends StatefulWidget {
  const RecordHubScreen(
      {super.key,
      required this.onClass,
      required this.onChild,
      this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
      this.repository,
      this.classRepository});
  final VoidCallback onClass;
  final ValueChanged<Child> onChild;
  final String classId;
  final HttpDashboardRepository? repository;
  final HttpClassDataRepository? classRepository;

  @override
  State<RecordHubScreen> createState() => _RecordHubScreenState();
}

class _RecordHubScreenState extends State<RecordHubScreen> {
  String query = '';
  late final HttpDashboardRepository repository =
      widget.repository ?? HttpDashboardRepository();
  late final HttpClassDataRepository classRepository =
      widget.classRepository ?? HttpClassDataRepository();
  late Future<_RecordHubData> future;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  // Loads class roster, dashboard statuses, and class display information.
  Future<_RecordHubData> _load() async {
    final values = await Future.wait([
      repository.getClassChildren(widget.classId),
      repository.getClassDashboard(widget.classId, DateTime.now()),
      classRepository.getClassInfo(widget.classId)
    ]);
    final rawChildren = values[0] as List<domain_child.Child>;
    final dashboard = values[1] as ClassDashboardSummary;
    final classInfo = values[2] as domain_class.ClassInfo;
    final statuses = {
      for (final item in dashboard.pendingChildren) item.child.childId: item
    };
    final converted = rawChildren.map((child) {
      final item = statuses[child.childId];
      final severity = severityFromDescription(null);
      return item == null
          ? uiChildFromDomain(
              child: child, reportStatus: ReportStatus.none, severity: severity)
          : uiChildFromDomainWithReport(
              child: child,
              reportStatus: item.status,
              severity: severity,
              updatedAt: item.updatedAt);
    }).toList();
    return _RecordHubData(converted, classInfo.name, dashboard.totalChildren,
        dashboard.notCompletedCount);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_RecordHubData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        if (snapshot.hasError || snapshot.data == null)
          return Scaffold(
              body: Center(
                  child: TextButton(
                      onPressed: () => setState(() => future = _load()),
                      child: const Text('Không tải được lớp · Thử lại'))));
        final data = snapshot.data;
        if (data == null)
          return const Scaffold(
              body: Center(child: Text('Không có dữ liệu lớp.')));
        final list = data.children
            .where((child) =>
                child.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return Scaffold(
          appBar: KAppBar(
              title: 'Ghi nhận hoạt động',
              subtitle: 'Chọn trẻ để bắt đầu ghi nhận',
              onBack: () => Navigator.pop(context)),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                KCard(
                  color: KColors.brandTint,
                  onTap: widget.onClass,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: KColors.brand,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.groups_outlined,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cả ${data.className}',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            Text('Ghi một lần, tạo báo cáo cho tất cả trẻ.',
                                style: TextStyle(
                                    fontSize: 12.5, color: KColors.inkSoft)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: KColors.brand),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('hoặc chọn từng trẻ',
                              style: TextStyle(
                                  fontSize: 12, color: KColors.inkFaint))),
                      Expanded(child: Divider()),
                    ],
                  ),
                ),
                SearchField(
                    hint: 'Tìm trẻ…',
                    onChanged: (value) => setState(() => query = value)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(
                              '${data.className} · ${data.totalChildren} trẻ',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: KColors.inkSoft))),
                      Text('${data.pendingCount} chưa xong',
                          style: const TextStyle(
                              fontSize: 12, color: KColors.inkFaint)),
                    ],
                  ),
                ),
                Expanded(
                  child: KCard(
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final child = list[index];
                        return InkWell(
                          onTap: () => widget.onChild(child),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Avatar(name: child.name),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(child.name,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500)),
                                      if (child.allergy != null)
                                        Text('Dị ứng: ${child.allergy}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: KColors.warn)),
                                    ],
                                  ),
                                ),
                                StatusBadge(child.status),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      });
}

class _RecordHubData {
  const _RecordHubData(
      this.children, this.className, this.totalChildren, this.pendingCount);
  final List<Child> children;
  final String className;
  final int totalChildren;
  final int pendingCount;
}

class RecordFlowScreen extends StatefulWidget {
  const RecordFlowScreen({
    super.key,
    required this.mode,
    this.child,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.className = 'Mầm 1',
    this.repository,
    this.teacherRepository,
  });
  final RecordMode mode;
  final Child? child;
  final String classId;
  final String className;
  final HttpDashboardRepository? repository;
  final TeacherRepository? teacherRepository;

  @override
  State<RecordFlowScreen> createState() => _RecordFlowScreenState();
}

class _RecordFlowScreenState extends State<RecordFlowScreen> {
  String step = 'record';
  PlatformFile? uploadedFile;
  VoiceRecord? voiceRecord;
  ExtractionData? extractionData;
  String? transcript;

  late final TeacherRepository teacherRepository =
      widget.teacherRepository ?? TeacherRepository();

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      'processing' => ProcessingScreen(
          mode: widget.mode,
          file: uploadedFile,
          classId: widget.classId,
          child: widget.child,
          teacherRepository: teacherRepository,
          onBack: () => setState(() => step = 'record'),
          onDone: (record, extraction) {
            voiceRecord = record;
            extractionData = extraction;
            transcript = record?.effectiveTranscript ?? extraction?.transcript;
            setState(() => step = 'review');
          },
        ),
      'review' || 'segment' => ReviewScreen(
          mode: widget.mode,
          classId: widget.classId,
          child: widget.child,
          className: widget.className,
          extraction: extractionData,
          transcript: transcript,
          voiceRecord: voiceRecord,
          repository: widget.repository,
          teacherRepository: teacherRepository,
          onBack: () => setState(() => step = 'record'),
          onCompleted: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã tạo và gửi báo cáo thành công!'),
                backgroundColor: Color(0xFF2E7D32),
              ),
            );
          },
        ),
      _ => RecordingScreen(
          mode: widget.mode,
          child: widget.child,
          className: widget.className,
          onSubmit: (file) {
            setState(() {
              uploadedFile = file;
              step = 'processing';
            });
          },
        ),
    };
  }
}

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.mode,
    required this.onSubmit,
    this.child,
    this.className = 'Mầm 1',
  });
  final RecordMode mode;
  final Child? child;
  final ValueChanged<PlatformFile?> onSubmit;
  final String className;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  int seconds = 0;
  String phase = 'ready';
  PlatformFile? selectedFile;
  Timer? timer;
  // Primary wave controller — drives the oscillation frequency.
  late final AnimationController wave = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  // Secondary controller with slightly different period for a richer, more organic look.
  late final AnimationController wave2 = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void dispose() {
    timer?.cancel();
    wave.dispose();
    wave2.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m4a', 'wav', 'mp3', 'webm', 'ogg', 'aac', 'flac'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        timer?.cancel();
        wave.stop();
        setState(() {
          selectedFile = result.files.single;
          phase = 'file_selected';
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Không thể chọn file. Vui lòng kiểm tra quyền truy cập hoặc thử lại.')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void toggle() {
    if (phase == 'done' || phase == 'file_selected') return;
    if (phase == 'recording') {
      timer?.cancel();
      wave.stop();
      wave2.stop();
      setState(() => phase = 'done');
      return;
    }
    wave.repeat(reverse: true);
    wave2.repeat(reverse: false);
    setState(() => phase = 'recording');
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds >= 179) {
        timer?.cancel();
        wave.stop();
        wave2.stop();
        setState(() {
          seconds = 180;
          phase = 'done';
        });
      } else {
        setState(() => seconds++);
      }
    });
  }

  String get time =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final classroom = widget.mode == RecordMode.classroom;
    final recording = phase == 'recording';
    final hasFile = phase == 'file_selected' && selectedFile != null;

    return Scaffold(
      appBar: KAppBar(
          title: classroom ? 'Ghi âm cả lớp' : 'Ghi âm',
          onBack: () => Navigator.pop(context)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          children: [
            KCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  classroom
                      ? Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                              color: KColors.brandTint, shape: BoxShape.circle),
                          child: const Icon(Icons.groups_outlined,
                              color: KColors.brand))
                      : Avatar(name: widget.child?.name ?? 'Trẻ', size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            classroom
                                ? 'Cả ${widget.className}'
                                : (widget.child?.name ?? 'Trẻ'),
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                            classroom
                                ? 'Cả lớp'
                                : '${widget.className}${widget.child?.nickname == null ? '' : ' · ${widget.child!.nickname}'}',
                            style: Theme.of(context).textTheme.bodySmall),
                        if (!classroom && widget.child?.allergy != null)
                          Text('Dị ứng: ${widget.child?.allergy}',
                              style: const TextStyle(
                                  fontSize: 11, color: KColors.warn)),
                      ],
                    ),
                  ),
                  if (classroom)
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        appRouter.go('/class-select');
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: KColors.brandTint,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: KColors.brand.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded,
                                size: 15, color: KColors.brand),
                            SizedBox(width: 4),
                            Text('Đổi lớp',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: KColors.brand)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasFile) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 26),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: KColors.surface,
                        borderRadius: BorderRadius.circular(KRadii.card),
                        border: Border.all(
                            color: KColors.brand.withValues(alpha: .35),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: KColors.brand.withValues(alpha: .08),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: KColors.brandTint,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.audio_file_rounded,
                                size: 40, color: KColors.brand),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            selectedFile!.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: KColors.ink),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kích thước: ${_formatBytes(selectedFile!.size)}',
                            style: const TextStyle(
                                fontSize: 13, color: KColors.inkSoft),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: KColors.okTint,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 15, color: KColors.ok),
                                SizedBox(width: 6),
                                Text(
                                  'Đã sẵn sàng tạo báo cáo',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: KColors.ok),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    AnimatedBuilder(
                      animation: Listenable.merge([wave, wave2]),
                      builder: (_, __) => SizedBox(
                        height: 56,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            28,
                            (index) {
                              // Each bar uses two overlapping sine waves with independent phase offsets
                              // to create an organic, speech-like ripple effect.
                              final double phaseOffset = index * 0.42;
                              final double amp1 = (math.sin(phaseOffset +
                                          wave.value * math.pi * 2) +
                                      1) /
                                  2;
                              final double amp2 = (math.sin(phaseOffset * 1.3 +
                                          wave2.value * math.pi * 2 +
                                          1.1) +
                                      1) /
                                  2;
                              final double combined = (amp1 * 0.6 + amp2 * 0.4);
                              final double barH =
                                  recording ? 5 + 38 * combined : 4;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 80),
                                width: 3,
                                height: barH,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: recording
                                      ? KColors.brand.withValues(
                                          alpha: 0.5 + 0.5 * combined)
                                      : KColors.brand.withValues(alpha: .28),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox.square(
                      dimension: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (phase != 'ready')
                            SizedBox.square(
                              dimension: 132,
                              child: CircularProgressIndicator(
                                value: seconds / 180,
                                strokeWidth: 4,
                                strokeCap: StrokeCap.round,
                                backgroundColor: KColors.surfaceSunken,
                                color: seconds >= 150
                                    ? KColors.warn
                                    : KColors.brand,
                              ),
                            ),
                          Material(
                            color: recording ? KColors.bad : KColors.brand,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: phase == 'done' ? null : toggle,
                              child: SizedBox.square(
                                dimension: 96,
                                child: Icon(
                                    recording
                                        ? Icons.stop_rounded
                                        : Icons.mic_none_rounded,
                                    size: 36,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(time,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color:
                                seconds >= 150 ? KColors.warn : KColors.ink)),
                    Text(
                      phase == 'ready'
                          ? 'Nhấn để bắt đầu ghi âm'
                          : recording
                              ? 'Đang ghi âm · Nói tự nhiên'
                              : 'Đã ghi âm $time',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (phase == 'ready') ...[
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.upload_file_rounded,
                            size: 20, color: KColors.brand),
                        label: const Text(
                          'Tải lên file ghi âm',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: KColors.brand),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: KColors.brand, width: 1.4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(KRadii.control)),
                          backgroundColor:
                              KColors.brandTint.withValues(alpha: .35),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (hasFile) ...[
              KButton(
                label: 'Gửi xử lý',
                icon: Icons.auto_awesome,
                large: true,
                onPressed: () => widget.onSubmit(selectedFile),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: KButton(
                      label: 'Chọn file khác',
                      icon: Icons.folder_open_rounded,
                      secondary: true,
                      onPressed: _pickFile,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KButton(
                      label: 'Hủy chọn',
                      ghost: true,
                      onPressed: () => setState(() {
                        selectedFile = null;
                        phase = 'ready';
                      }),
                    ),
                  ),
                ],
              ),
            ] else if (phase == 'done') ...[
              KButton(
                  label: 'Gửi xử lý',
                  icon: Icons.send_outlined,
                  large: true,
                  onPressed: () => widget.onSubmit(null)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: KButton(
                          label: 'Ghi âm lại',
                          icon: Icons.refresh,
                          secondary: true,
                          onPressed: () => setState(() {
                                seconds = 0;
                                phase = 'ready';
                              }))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: KButton(
                          label: 'Hủy',
                          ghost: true,
                          onPressed: () => Navigator.pop(context))),
                ],
              ),
            ] else
              Text(
                classroom
                    ? 'Kể lần lượt về các bé trong lớp. Nhắc tên bé trước khi nói — hệ thống sẽ tách phần của từng bé.'
                    : 'Kể lại hoạt động của bé trong ngày. Hệ thống sẽ tự sắp xếp thành báo cáo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({
    super.key,
    required this.mode,
    required this.onBack,
    required this.onDone,
    this.file,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.child,
    this.teacherRepository,
  });
  final RecordMode mode;
  final VoidCallback onBack;
  final void Function(VoiceRecord? record, ExtractionData? extraction) onDone;
  final PlatformFile? file;
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
  Timer? fallbackTimer;
  late final TeacherRepository repository =
      widget.teacherRepository ?? TeacherRepository();

  List<String> get steps => [
        widget.file != null
            ? 'Đã tải lên: ${widget.file!.name}'
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
    fallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (isProcessing) return;
    setState(() {
      isProcessing = true;
      errorMessage = null;
      active = 0;
    });

    final file = widget.file;
    if (file == null) {
      _runSimulated();
      return;
    }

    try {
      final teacherId = AuthRepository.currentUser?.teacherId ??
          'bbbbbbbb-0000-0000-0000-000000000001';
      final childId = widget.mode == RecordMode.child ? widget.child?.id : null;

      // 1. Upload audio file to backend / MinIO
      setState(() => active = 0);

      String safeFilePath = '';
      if (!kIsWeb) {
        try {
          safeFilePath = file.path ?? '';
        } catch (_) {
          safeFilePath = '';
        }
      }

      Uint8List? fileBytes;
      try {
        fileBytes = file.bytes;
      } catch (_) {}

      if (fileBytes == null && file.readStream != null) {
        try {
          final chunks = <int>[];
          await for (final chunk in file.readStream!) {
            chunks.addAll(chunk);
          }
          fileBytes = Uint8List.fromList(chunks);
        } catch (_) {}
      }

      final voiceRecord = await repository.uploadAudio(
        filePath: safeFilePath,
        fileBytes: fileBytes,
        fileName: file.name,
        classId: widget.classId,
        teacherId: teacherId,
        childId: childId,
      );

      if (!mounted) return;

      // 2. Poll for PhoWhisper speech-to-text
      setState(() => active = 1);
      VoiceRecord? currentRecord = voiceRecord;
      String? transcript;

      for (var attempt = 0; attempt < 60; attempt++) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        try {
          currentRecord = await repository.getVoiceRecord(
            voiceId: voiceRecord.id,
            teacherId: teacherId,
          );
          if (currentRecord.status == 'completed') {
            transcript = currentRecord.effectiveTranscript;
            break;
          } else if (currentRecord.status == 'failed') {
            throw Exception(currentRecord.errorMessage ??
                'Quá trình nhận dạng giọng nói thất bại.');
          }
        } catch (e) {
          if (attempt >= 58) rethrow;
        }
      }

      if (transcript == null &&
          currentRecord != null &&
          currentRecord.status != 'completed') {
        throw Exception(
          'Quá trình xử lý âm thanh quá thời gian chờ (hơn 2 phút). Vui lòng thử lại hoặc chọn file âm thanh ngắn hơn.',
        );
      }

      final effectiveTranscript = transcript?.trim() ?? '';
      if (effectiveTranscript.isEmpty) {
        throw Exception(
          'Không nhận diện được nội dung giọng nói từ bản ghi. Vui lòng nói to, rõ ràng hơn hoặc thử lại.',
        );
      }

      if (!mounted) return;

      // 3. Run NLP model extraction
      setState(() => active = 2);
      ExtractionData? extraction;
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
          final serverMessage = e.message.isNotEmpty
              ? e.message
              : 'Nội dung ghi âm không liên quan đến báo cáo học sinh.';
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFED6C02), size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nội dung không liên quan',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Text(
                '$serverMessage\n\nVui lòng ghi âm lại và mô tả về bé trong ngày (ăn uống, giấc ngủ, tâm trạng, hoạt động…).',
                style: const TextStyle(fontSize: 14, height: 1.55),
              ),
              actions: [
                FilledButton.icon(
                  icon: const Icon(Icons.mic_none_rounded, size: 18),
                  label: const Text('Ghi âm lại'),
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFED6C02)),
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
        // ─── Lỗi khác (network, server 5xx…) → dừng, không fallback ───
        extraction = ExtractionData(
          transcript: effectiveTranscript,
        );
      } catch (_) {
        // ─── Exception không phải TeacherRepositoryException → dừng ───
        extraction = ExtractionData(
          transcript: effectiveTranscript,
        );
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
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFED6C02)),
                SizedBox(width: 8),
                Text('Nội dung không liên quan',
                    style: TextStyle(fontSize: 17)),
              ],
            ),
            content: const Text(
              'Nội dung ghi âm không liên quan đến hoạt động học sinh.\n\nVui lòng ghi âm lại và mô tả về bé trong ngày (ăn uống, giấc ngủ, tâm trạng, hoạt động…).',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ghi âm lại'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDone(currentRecord, extraction);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFED6C02)),
                child: const Text('Vẫn tiếp tục'),
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
      final friendlyMsg = _getFriendlyErrorMessage(e);
      setState(() {
        isProcessing = false;
        errorMessage = friendlyMsg;
      });
      await _showAudioErrorDialog(friendlyMsg);
    }
  }

  Future<void> _showAudioErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: Color(0xFFD32F2F), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Không thể xử lý file âm thanh',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onBack();
            },
            child: const Text('Quay lại'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
            style: FilledButton.styleFrom(
              backgroundColor: KColors.brand,
            ),
            onPressed: () {
              Navigator.pop(context);
              _start();
            },
          ),
        ],
      ),
    );
  }

  String _getFriendlyErrorMessage(dynamic error) {
    if (error == null)
      return 'Đã có sự cố khi xử lý file âm thanh. Vui lòng thử lại.';

    String raw = '';
    int? statusCode;
    if (error is TeacherRepositoryException) {
      raw = error.message;
      statusCode = error.statusCode;
    } else {
      raw = error.toString();
    }

    raw = raw
        .replaceFirst('TeacherRepositoryException: ', '')
        .replaceFirst('Exception: ', '')
        .replaceFirst('Error: ', '')
        .trim();

    if (statusCode != null) {
      if (statusCode == 400) {
        if (raw.toLowerCase().contains('unsupported audio format') ||
            raw.toLowerCase().contains('format')) {
          return 'Định dạng file không được hỗ trợ. Vui lòng tải lên file âm thanh định dạng .mp3, .wav, .m4a, .webm.';
        }
        return 'Dữ liệu file âm thanh gửi lên không hợp lệ. Vui lòng kiểm tra lại.';
      }
      if (statusCode == 404) {
        return 'Không tìm thấy dữ liệu lớp học hoặc thông tin giáo viên trên hệ thống.';
      }
      if (statusCode == 413) {
        return 'File ghi âm quá lớn (vượt quá 25MB). Vui lòng chọn file dung lượng nhỏ hơn.';
      }
      if (statusCode >= 500) {
        return 'Hệ thống đang bận hoặc gặp sự cố khi xử lý âm thanh. Vui lòng thử lại sau ít phút.';
      }
    }

    final lower = raw.toLowerCase();

    if (lower.contains('on web') ||
        lower.contains('unimplementederror') ||
        lower.contains('bytes property') ||
        lower.contains('flutter_file_picker')) {
      return 'Không thể đọc file trên trình duyệt. Vui lòng chọn lại file âm thanh (.mp3, .wav, .m4a).';
    }

    if (lower.contains('unsupported audio format') ||
        lower.contains('định dạng âm thanh không hợp lệ')) {
      return 'Định dạng file không được hỗ trợ. Vui lòng chọn file âm thanh (.mp3, .wav, .m4a, .webm).';
    }

    if (lower.contains('quá lớn') ||
        lower.contains('413') ||
        lower.contains('too large') ||
        lower.contains('payload')) {
      return 'File ghi âm quá lớn (vượt quá 25MB). Vui lòng chọn file dung lượng nhỏ hơn.';
    }

    if (lower.contains('connection refused') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection error')) {
      return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng của bạn và thử lại.';
    }

    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Quá trình tải lên hoặc xử lý file quá thời gian chờ. Vui lòng kiểm tra tốc độ mạng và thử lại.';
    }

    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('internal server error') ||
        lower.contains('server error')) {
      return 'Máy chủ đang gặp sự cố khi xử lý file âm thanh. Vui lòng thử lại sau ít phút.';
    }

    if (lower.contains('nhận dạng giọng nói thất bại') ||
        lower.contains('speech-to-text') ||
        lower.contains('phowhisper')) {
      return 'Không thể nhận diện giọng nói từ file ghi âm. Vui lòng thử lại hoặc chọn file khác.';
    }

    if (lower.contains('nosuchmethod') ||
        lower.contains('typeerror') ||
        lower.contains('rangeerror') ||
        lower.contains('dioexception') ||
        lower.contains('httpexception') ||
        lower.contains('traceback') ||
        lower.contains('null check operator') ||
        lower.contains('null safety') ||
        lower.contains('assertion failed') ||
        lower.contains('stack trace')) {
      return 'Đã xảy ra sự cố kỹ thuật khi xử lý file. Vui lòng thử lại hoặc chọn file khác.';
    }

    final hasVietnamese = RegExp(
            r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]',
            caseSensitive: false)
        .hasMatch(raw);
    if (hasVietnamese &&
        !raw.contains('{') &&
        !raw.contains('(') &&
        !raw.contains('http') &&
        raw.length < 150) {
      return raw;
    }

    return 'Không thể xử lý file âm thanh vào lúc này. Vui lòng thử lại hoặc chọn file khác.';
  }

  String _generateUuid() {
    final rnd = math.Random();
    String hex(int len) =>
        List.generate(len, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-8${hex(3)}-${hex(12)}';
  }

  void _runSimulated() {
    fallbackTimer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (active >= steps.length - 1) {
        t.cancel();
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          final synthId = _generateUuid();
          final synthTranscript = '';
          final synthRecord = VoiceRecord(
            id: synthId,
            status: 'completed',
            transcription: synthTranscript,
          );
          final synthExtraction = ExtractionData(
            transcript: synthTranscript,
            classWideExtraction: widget.mode == RecordMode.classroom
                ? {
                    'meals': '',
                    'sleeping': '',
                    'health': '',
                    'activities': '',
                    'mood': '',
                  }
                : null,
          );
          widget.onDone(synthRecord, synthExtraction);
        });
      } else {
        setState(() => active++);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KAppBar(
        title: errorMessage != null ? 'Thông báo sự cố' : 'Đang xử lý',
        onBack: widget.onBack,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(steps[active],
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
            Text('Hệ thống đang xử lý file ghi âm của bạn.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            StepIndicator(steps: steps, active: active),
            const Spacer(),
            KCard(
              color: KColors.infoTint,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: KColors.info,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.file != null
                          ? 'Đang xử lý file "${widget.file!.name}". Vui lòng giữ màn hình này cho đến khi hoàn tất.'
                          : 'Vui lòng giữ màn hình này cho đến khi hoàn tất.',
                      style: Theme.of(context).textTheme.bodyMedium,
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

enum ObservationDecision { approved, discarded, pending }

enum ObservationKind { normal, unmatched, classwide }

class ObservationItem {
  ObservationItem({
    required this.id,
    required this.name,
    this.childId,
    this.nickname,
    this.matched = true,
    this.decision = ObservationDecision.approved,
    this.kind = ObservationKind.normal,
    this.eating = '',
    this.sleep = '',
    this.activities = '',
    this.mood = '',
    this.health = '',
    this.note = '',
    this.snippet = '',
    this.severity = Severity.none,
  });

  final String id;
  String name;
  String? childId;
  String? nickname;
  bool matched;
  ObservationDecision decision;
  ObservationKind kind;
  String eating;
  String sleep;
  String activities;
  String mood;
  String health;
  String note;
  String snippet;
  Severity severity;

  ObservationItem assign(Child child) {
    return ObservationItem(
      id: id,
      name: child.name,
      childId: child.id,
      nickname: child.nickname,
      matched: true,
      decision: ObservationDecision.approved,
      kind: ObservationKind.normal,
      eating: eating,
      sleep: sleep,
      activities: activities,
      mood: mood,
      health: health,
      note: note,
      snippet: snippet,
      severity: severity,
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.onBack,
    required this.onCompleted,
    this.mode = RecordMode.classroom,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.child,
    this.className = 'Mầm 1',
    this.repository,
    this.teacherRepository,
    this.extraction,
    this.transcript,
    this.voiceRecord,
  });

  final VoidCallback onBack;
  final VoidCallback onCompleted;
  final RecordMode mode;
  final String classId;
  final Child? child;
  final String className;
  final HttpDashboardRepository? repository;
  final TeacherRepository? teacherRepository;
  final ExtractionData? extraction;
  final String? transcript;
  final VoiceRecord? voiceRecord;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final HttpDashboardRepository repository =
      widget.repository ?? HttpDashboardRepository();
  late final TeacherRepository teacherRepository =
      widget.teacherRepository ?? TeacherRepository();
  late Future<List<Child>> childrenFuture;
  List<ObservationItem> items = [];
  List<Child> roster = [];
  bool isDone = false;
  bool isSubmitting = false;
  int savedReportsCount = 0;
  int savedHealthCount = 0;

  /// Map từ item.id → list draft_report_id đã được tạo (sau khi gọi approve-item).
  /// Dùng để gom lại và gửi 1 lần qua send-batch.
  final Map<String, List<String>> approvedDraftIds = {};

  /// Set các item.id đang trong quá trình approve (disable button tránh double-click).
  final Set<String> approvingIds = <String>{};

  /// True khi đang gọi send-batch.
  bool isSendingBatch = false;

  ExtractionData? currentExtraction;
  String? editedTranscript;

  String get effectiveTranscript =>
      (editedTranscript != null && editedTranscript!.trim().isNotEmpty)
          ? editedTranscript!.trim()
          : (widget.transcript != null && widget.transcript!.trim().isNotEmpty)
              ? widget.transcript!.trim()
              : (currentExtraction?.transcript != null &&
                      currentExtraction!.transcript!.trim().isNotEmpty)
                  ? currentExtraction!.transcript!.trim()
                  : '';

  @override
  void initState() {
    super.initState();
    currentExtraction = widget.extraction;
    childrenFuture = _loadChildren().then((children) {
      roster = children;
      items = _buildObservations(children);
      return children;
    }).catchError((e, st) {
      debugPrint('ReviewScreen childrenFuture error: $e\n$st');
      throw e;
    });
  }

  List<ObservationItem> _buildObservations(List<Child> children,
      [ExtractionData? customExtraction]) {
    try {
      final ext = customExtraction ?? currentExtraction ?? widget.extraction;

      // Legacy single-child mode (RecordMode.child không còn dùng trong flow mới,
      // nhưng giữ lại để không vỡ các entry-point cũ nếu còn gọi tới).
      if (widget.mode == RecordMode.child && widget.child != null) {
        final c = widget.child!;
        final meals =
            ext?.meals?.trim().isNotEmpty == true ? ext!.meals!.trim() : '';
        final sleep = ext?.sleeping?.trim().isNotEmpty == true
            ? ext!.sleeping!.trim()
            : '';
        final activities = ext?.activities?.trim().isNotEmpty == true
            ? ext!.activities!.trim()
            : '';
        final mood =
            ext?.mood?.trim().isNotEmpty == true ? ext!.mood!.trim() : '';
        final health =
            ext?.health?.trim().isNotEmpty == true ? ext!.health!.trim() : '';

        return [
          ObservationItem(
            id: c.id,
            name: c.name,
            childId: c.id,
            nickname: c.nickname,
            matched: true,
            eating: meals,
            sleep: sleep,
            activities: activities,
            mood: mood,
            health: health,
            note: widget.transcript ?? '',
            severity: c.severity,
          ),
        ];
      }

      // ====================================================================
      // Classroom mode - Auto-detect flow (mới)
      // ====================================================================
      // Cấu trúc items:
      //   1. Classwide item (1) - nếu backend có classWideExtraction có nội dung
      //   2. Child items (N) - chỉ các bé CÓ override trong childExtractions
      //   3. Unmatched items (M) - các segments không gắn được với bé nào
      // ====================================================================
      final result = <ObservationItem>[];

      final childMap = ext?.childExtractions;
      final hasChildOverrides = childMap != null && childMap.isNotEmpty;

      // -------- 1. Classwide item -----------------------------------------
      if (ext?.hasClassWideContent == true) {
        final cw = ext!.classWideExtraction!;
        result.add(_classwideItemFromExtraction(cw));
      } else if (widget.mode == RecordMode.classroom && !hasChildOverrides) {
        // Chỉ thêm fallback "Chung cả lớp" nếu không có bất kỳ override nào theo từng bé
        result.add(
          ObservationItem(
            id: 'classwide',
            name: 'Chung cả lớp',
            matched: true,
            kind: ObservationKind.classwide,
            decision: ObservationDecision.pending,
            eating:
                ext?.meals?.trim().isNotEmpty == true ? ext!.meals!.trim() : '',
            sleep: ext?.sleeping?.trim().isNotEmpty == true
                ? ext!.sleeping!.trim()
                : '',
            activities: ext?.activities?.trim().isNotEmpty == true
                ? ext!.activities!.trim()
                : '',
            mood: ext?.mood?.trim().isNotEmpty == true ? ext!.mood!.trim() : '',
            health: ext?.health?.trim().isNotEmpty == true
                ? ext!.health!.trim()
                : '',
            note: ext?.rawJson?['teacher_note']?.toString() ??
                ext?.rawJson?['notes']?.toString() ??
                ext?.rawJson?['note']?.toString() ??
                '',
          ),
        );
      }

      // -------- 2. Child items (chỉ các bé có override) -------------------
      if (childMap != null && childMap.isNotEmpty) {
        for (final child in children) {
          // Tìm override theo id hoặc theo name (backend có thể trả key là name)
          dynamic data;
          if (childMap.containsKey(child.id)) {
            data = childMap[child.id];
          } else if (childMap.containsKey(child.name)) {
            data = childMap[child.name];
          }
          if (data is! Map) {
            continue; // Bé này không có override → KHÔNG tạo item (dùng classwide default)
          }
          result.add(_childItemFromExtraction(child, data));
        }
      }

      // -------- 3. Unmatched items ----------------------------------------
      bool _hasExtractionContent(dynamic seg) {
        if (seg is! Map) return false;
        final extr = seg['extraction'];
        if (extr is! Map) return false;
        return extr.values.any((v) {
          if (v == null) return false;
          final s = v.toString().trim();
          return s.isNotEmpty;
        });
      }

      final rawUnmatched = ext?.rawJson?['unmatched_segments'];

      if (rawUnmatched is List && rawUnmatched.isNotEmpty) {
        for (var i = 0; i < rawUnmatched.length; i++) {
          final seg = rawUnmatched[i];

          if (!_hasExtractionContent(seg)) {
            continue;
          }

          final text =
              seg is Map ? (seg['text']?.toString() ?? '') : seg.toString();
          if (text.trim().isNotEmpty) {
            result.add(_unmatchedItem('unmatched_$i', text));
          }
        }
      } else if (ext?.segments != null) {
        var uIdx = 0;
        for (final seg in ext!.segments!) {
          if (seg is Map) {
            final isClassWide = seg['is_class_wide'] == true;
            final matches = seg['child_matches'];
            final hasMatches = matches is List && matches.isNotEmpty;
            if (!isClassWide && !hasMatches) {
              if (!_hasExtractionContent(seg)) {
                continue;
              }
              final text = seg['text']?.toString() ?? '';
              if (text.trim().isNotEmpty) {
                result.add(_unmatchedItem('unmatched_${uIdx++}', text));
              }
            }
          }
        }
      }

      return result;
    } catch (e, st) {
      debugPrint('Error in _buildObservations: $e\n$st');
      // Fallback an toàn: 1 classwide item duy nhất
      return [
        ObservationItem(
          id: 'classwide',
          name: 'Chung cả lớp',
          matched: true,
          kind: ObservationKind.classwide,
          eating: '',
          sleep: '',
          activities: '',
          mood: '',
          health: '',
        ),
      ];
    }
  }

  /// Tạo classwide ObservationItem từ classWideExtraction map.
  ObservationItem _classwideItemFromExtraction(Map<String, dynamic> cw) {
    String pick(String key, String fallback) {
      final v = cw[key];
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : fallback;
    }

    final noteVal = pick('notes', '') != ''
        ? pick('notes', '')
        : (pick('teacher_note', '') != ''
            ? pick('teacher_note', '')
            : (pick('note', '') != ''
                ? pick('note', '')
                : ''));

    return ObservationItem(
      id: 'classwide',
      name: 'Chung cả lớp',
      matched: true,
      kind: ObservationKind.classwide,
      decision: ObservationDecision.pending,
      eating: pick('meals', ''),
      sleep: pick('sleeping', ''),
      activities: pick('activities', ''),
      mood: pick('mood', ''),
      health: pick('health', ''),
      note: noteVal,
    );
  }

  /// Tạo child ObservationItem từ childExtractions[childId/name].
  ObservationItem _childItemFromExtraction(Child child, Map data) {
    String? pick(String key) {
      final v = data[key];
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : null;
    }

    return ObservationItem(
      id: child.id,
      name: child.name,
      childId: child.id,
      nickname: child.nickname,
      matched: true,
      kind: ObservationKind.normal,
      decision: ObservationDecision.pending,
      eating: pick('meals') ?? '',
      sleep: pick('sleeping') ?? '',
      activities: pick('activities') ?? '',
      mood: pick('mood') ?? '',
      health: pick('health') ?? '',
      note: pick('notes') ??
          pick('teacher_note') ??
          pick('note') ??
          '',
      severity: child.severity,
    );
  }

  /// Tạo unmatched ObservationItem cho 1 segment không gắn được với bé nào.
  ObservationItem _unmatchedItem(String id, String text) {
    return ObservationItem(
      id: id,
      name: 'Chưa rõ bé nào',
      matched: false,
      kind: ObservationKind.unmatched,
      decision: ObservationDecision.pending,
      snippet: text,
      eating: '',
      sleep: '',
      activities: '',
      mood: '',
    );
  }

  Future<List<Child>> _loadChildren() async {
    try {
      if (widget.mode == RecordMode.child && widget.child != null) {
        return [widget.child!];
      }
      final results = await Future.wait([
        repository.getClassChildren(widget.classId),
        repository
            .getClassDashboard(widget.classId, DateTime.now())
            .catchError((err) {
          debugPrint(
              'ReviewScreen getClassDashboard error (fallback to defaults): $err');
          return ClassDashboardSummary(
            classInfo: domain_class.ClassInfo(
              classId: widget.classId,
              schoolId: '',
              name: widget.className,
            ),
            teacherName: '',
            totalChildren: 0,
            completedCount: 0,
            draftCount: 0,
            missingCount: 0,
            pendingChildren: const [],
          );
        }),
      ]);
      final classRoster = results[0] as List<domain_child.Child>;
      final dashboard = results[1] as ClassDashboardSummary;
      final statuses = {
        for (final item in dashboard.pendingChildren) item.child.childId: item
      };
      return classRoster.map((child) {
        final item = statuses[child.childId];
        return item == null
            ? uiChildFromDomain(
                child: child,
                reportStatus: ReportStatus.none,
                severity: severityFromDescription(null))
            : uiChildFromDomainWithReport(
                child: child,
                reportStatus: item.status,
                severity: severityFromDescription(null),
                updatedAt: item.updatedAt);
      }).toList();
    } catch (e, st) {
      debugPrint('Error in _loadChildren: $e\n$st');
      rethrow;
    }
  }

  /// Approve 1 item (gọi POST /api/teacher/reports/approve-item).
  /// Item được approve sẽ được backend tạo draft NGAY và trả về list draft_report_ids.
  /// Lưu vào [approvedDraftIds] để gom lại gửi batch.
  Future<void> _approveItem(ObservationItem item) async {
    if (approvingIds.contains(item.id)) return; // tránh double-click

    String teacherId;
    try {
      final t = await repository.getCurrentTeacher();
      teacherId = t.teacherId.isNotEmpty ? t.teacherId : repository.teacherId;
    } catch (_) {
      teacherId = AuthRepository.currentUser?.teacherId ?? repository.teacherId;
    }

    // Phải có voiceRecordId để backend biết lấy extraction từ đâu.
    final voiceRecordId = widget.voiceRecord?.id;
    if (voiceRecordId == null || voiceRecordId.isEmpty) {
      await _approveItemManualFallback(item, teacherId);
      return;
    }

    setState(() => approvingIds.add(item.id));

    try {
      // Map item.kind → API kind
      String kind;
      String? childId;
      String? classId;
      Map<String, String?>? extraction;

      if (item.kind == ObservationKind.classwide) {
        kind = 'classwide';
        classId = widget.classId;
        extraction = {
          if (item.eating.isNotEmpty) 'meals': item.eating,
          if (item.sleep.isNotEmpty) 'sleeping': item.sleep,
          if (item.health.isNotEmpty) 'health': item.health,
          if (item.activities.isNotEmpty) 'activities': item.activities,
          if (item.mood.isNotEmpty) 'mood': item.mood,
          if (item.note.isNotEmpty) 'teacher_note': item.note,
        };
      } else if (item.kind == ObservationKind.unmatched) {
        // Unmatched: backend hiện tại KHÔNG tạo draft (theo doc),
        // chỉ echo lại để user biết segment này được chấp nhận.
        // Vẫn gọi API để đồng bộ trạng thái, nhưng draft_ids sẽ rỗng.
        kind = 'unmatched';
        classId = widget.classId;
        extraction = {
          'transcript': item.snippet,
          'teacher_note': item.snippet,
        };
      } else {
        // normal / child
        kind = 'child';
        childId = item.childId;
        extraction = {
          if (item.eating.isNotEmpty) 'meals': item.eating,
          if (item.sleep.isNotEmpty) 'sleeping': item.sleep,
          if (item.health.isNotEmpty) 'health': item.health,
          if (item.activities.isNotEmpty) 'activities': item.activities,
          if (item.mood.isNotEmpty) 'mood': item.mood,
          if (item.note.isNotEmpty) 'teacher_note': item.note,
        };
      }

      final res = await teacherRepository.approveItem(
        voiceRecordId: voiceRecordId,
        teacherId: teacherId,
        kind: kind,
        childId: childId,
        classId: classId,
        extraction: extraction,
      );

      // Parse draft_report_ids từ response (List<dynamic> các UUID string)
      final draftIdsRaw = res['draft_report_ids'];
      final newDraftIds = <String>[];
      if (draftIdsRaw is List) {
        for (final v in draftIdsRaw) {
          final s = v?.toString();
          if (s != null && s.isNotEmpty) newDraftIds.add(s);
        }
      }

      // Classwide có thể trả child_id_to_report_id (map) thay vì list
      if (newDraftIds.isEmpty && kind == 'classwide') {
        final map = res['child_id_to_report_id'];
        if (map is Map) {
          map.forEach((k, v) {
            final s = v?.toString();
            if (s != null && s.isNotEmpty) newDraftIds.add(s);
          });
        }
      }

      if (newDraftIds.isEmpty && kind == 'classwide') {
        // Nếu API trả rỗng cho classwide, fallback manual để lấy draft ids
        await _approveItemManualFallback(item, teacherId);
        return;
      }

      if (!mounted) return;
      setState(() {
        approvedDraftIds[item.id] = newDraftIds;
        item.decision = ObservationDecision.approved;
      });
    } catch (e) {
      debugPrint('Approve item error: $e, trying manual fallback...');
      await _approveItemManualFallback(item, teacherId);
    } finally {
      if (mounted) setState(() => approvingIds.remove(item.id));
    }
  }

  Future<void> _approveItemManualFallback(
      ObservationItem item, String teacherId) async {
    setState(() => approvingIds.add(item.id));
    final newDraftIds = <String>[];
    try {
      if (item.kind == ObservationKind.classwide) {
        for (final child in roster) {
          try {
            final res = await teacherRepository.createManualReport(
              teacherId: teacherId,
              childId: child.id,
              eating: item.eating,
              sleeping: item.sleep,
              health: item.health,
              activities: item.activities,
              mood: item.mood,
              teacherNote: item.note,
              overwrite: true,
            );
            final id = res['report_id']?.toString() ??
                res['daily_report_id']?.toString();
            if (id != null && id.isNotEmpty) newDraftIds.add(id);
          } catch (err) {
            debugPrint('Manual fallback error for child ${child.id}: $err');
          }
        }
      } else {
        final targetChildId = item.childId ?? item.id;
        final res = await teacherRepository.createManualReport(
          teacherId: teacherId,
          childId: targetChildId,
          eating: item.eating,
          sleeping: item.sleep,
          health: item.health,
          activities: item.activities,
          mood: item.mood,
          teacherNote: item.note,
          overwrite: true,
        );
        final id =
            res['report_id']?.toString() ?? res['daily_report_id']?.toString();
        if (id != null && id.isNotEmpty) newDraftIds.add(id);
      }
      if (mounted) {
        setState(() {
          approvedDraftIds[item.id] = newDraftIds;
          item.decision = ObservationDecision.approved;
        });
      }
    } catch (err) {
      debugPrint('Fallback manual report failed: $err');
      if (mounted)
        _showError('Không thể tạo bản nháp báo cáo. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => approvingIds.remove(item.id));
    }
  }

  /// Duyệt tất cả các mục chưa được duyệt.
  Future<void> _approveAll() async {
    for (final item in items) {
      if (item.decision != ObservationDecision.approved &&
          item.decision != ObservationDecision.discarded) {
        await _approveItem(item);
      }
    }
  }

  /// Bỏ duyệt 1 item đã được duyệt.
  void _unapproveItem(ObservationItem item) {
    if (approvingIds.contains(item.id)) return;
    setState(() {
      item.decision = ObservationDecision.pending;
      approvedDraftIds.remove(item.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã bỏ duyệt mục "${item.name}".'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Bỏ duyệt tất cả các mục đã duyệt.
  void _unapproveAll() {
    setState(() {
      for (final item in items) {
        if (item.decision == ObservationDecision.approved) {
          item.decision = ObservationDecision.pending;
        }
      }
      approvedDraftIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã bỏ duyệt tất cả các mục.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Hiển thị hộp thoại xem đầy đủ nội dung văn bản đã phân tích.
  void _showTranscriptDialog(BuildContext context, String text) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: KColors.brand, size: 22),
            SizedBox(width: 8),
            Text('Text đã phân tích',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Toàn bộ nội dung giọng nói từ file ghi âm đã được AI chuyển thành văn bản và phân tích:',
                style: TextStyle(fontSize: 12.5, color: KColors.inkSoft),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: KColors.line),
                ),
                child: SelectableText(
                  text,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.6, color: KColors.ink),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                    content: Text('Đã sao chép!'),
                    duration: Duration(seconds: 1)),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Sao chép'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _editAndReanalyzeTranscript();
            },
            icon: const Icon(Icons.edit_note_rounded, size: 16),
            label: const Text('Sửa & Phân tích lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  /// Gửi batch tất cả draft đã thu được.
  /// Gọi POST /api/teacher/reports/send-batch với list tất cả draft_report_ids.
  Future<void> _sendBatch() async {
    if (isSendingBatch) return;

    // Gom tất cả draft ids từ approved items
    final allDraftIds = <String>[];
    for (final ids in approvedDraftIds.values) {
      allDraftIds.addAll(ids);
    }
    // dedupe (giữ thứ tự)
    final uniqueDraftIds = <String>[];
    final seen = <String>{};
    for (final id in allDraftIds) {
      if (seen.add(id)) uniqueDraftIds.add(id);
    }

    if (uniqueDraftIds.isEmpty) {
      // Tự động duyệt các mục pending nếu chưa duyệt
      if (items.any((i) => i.decision != ObservationDecision.discarded)) {
        await _approveAll();
        for (final ids in approvedDraftIds.values) {
          allDraftIds.addAll(ids);
        }
        for (final id in allDraftIds) {
          if (seen.add(id)) uniqueDraftIds.add(id);
        }
      }
      if (uniqueDraftIds.isEmpty) {
        _showError('Chưa có báo cáo nào được duyệt để gửi.');
        return;
      }
    }

    String teacherId;
    try {
      final t = await repository.getCurrentTeacher();
      teacherId = t.teacherId.isNotEmpty ? t.teacherId : repository.teacherId;
    } catch (_) {
      teacherId = AuthRepository.currentUser?.teacherId ?? repository.teacherId;
    }

    setState(() {
      isSendingBatch = true;
      isSubmitting = true;
    });

    try {
      final res = await teacherRepository.sendBatch(
        teacherId: teacherId,
        reportIds: uniqueDraftIds,
      );

      final sent = (res['sent'] is num) ? (res['sent'] as num).toInt() : 0;
      final skipped =
          (res['skipped'] is num) ? (res['skipped'] as num).toInt() : 0;
      final failed =
          (res['failed'] is num) ? (res['failed'] as num).toInt() : 0;

      if (failed > 0 && sent == 0) {
        debugPrint(
            'sendBatch returned failed=$failed (${res['results']}), publishing individually...');
        for (final repId in uniqueDraftIds) {
          try {
            await teacherRepository.publishReport(
                reportId: repId, teacherId: teacherId);
          } catch (e) {
            debugPrint('Individual publish error for $repId: $e');
          }
        }
      }

      // Tính số phiếu liên lạc + sức khỏe từ các item đã approve
      final pCount = uniqueDraftIds.length;
      final hCount = items
          .where((i) =>
              i.decision == ObservationDecision.approved &&
              approvedDraftIds.containsKey(i.id) &&
              i.health.isNotEmpty)
          .length;

      if (!mounted) return;
      setState(() {
        savedReportsCount = pCount;
        savedHealthCount = hCount;
        isDone = true;
      });

      if (failed > 0) {
        debugPrint('send-batch: sent=$sent skipped=$skipped failed=$failed');
      }
    } catch (e) {
      debugPrint('send-batch error: $e, trying publishReport fallback...');
      bool fallbackOk = false;
      for (final repId in uniqueDraftIds) {
        try {
          await teacherRepository.publishReport(
              reportId: repId, teacherId: teacherId);
          fallbackOk = true;
        } catch (_) {}
      }
      if (fallbackOk) {
        if (!mounted) return;
        setState(() {
          savedReportsCount = uniqueDraftIds.length;
          savedHealthCount = 0;
          isDone = true;
        });
        return;
      }
      if (mounted) _showError('Không thể gửi báo cáo. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          isSendingBatch = false;
          isSubmitting = false;
        });
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _assignChild(ObservationItem item) {
    showModalBottomSheet<Child>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: KColors.canvas,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => _AssignSheet(card: item, roster: roster),
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() {
          final idx = items.indexWhere((i) => i.id == item.id);
          if (idx != -1) {
            items[idx] = item.assign(selected);
          }
        });
      }
    });
  }

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return _DoneScreenView(
        parentReportsCount: savedReportsCount,
        healthRecordsCount: savedHealthCount,
        recordingTime: _timeNow(),
        onBack: widget.onCompleted,
      );
    }

    // Counters cho header + bottom sheet
    final totalCount = items.length;
    final approvedCount = items
        .where((i) =>
            i.decision == ObservationDecision.approved &&
            approvedDraftIds.containsKey(i.id))
        .length;
    final pendingCount = items
        .where((i) =>
            i.decision != ObservationDecision.discarded &&
            i.decision != ObservationDecision.approved)
        .length;
    final discardedCount =
        items.where((i) => i.decision == ObservationDecision.discarded).length;
    final healthCount = approvedDraftIds.entries
        .where((e) => items.any((i) => i.id == e.key && i.health.isNotEmpty))
        .length;

    // Unmatched còn lại (chưa được gán/lọc) - phải = 0 mới cho confirm
    final unmatchedActiveCount = items
        .where((i) =>
            i.kind == ObservationKind.unmatched &&
            i.decision != ObservationDecision.discarded)
        .length;

    final subtitle = widget.mode == RecordMode.classroom
        ? 'Ghi âm cả lớp · ${widget.className}'
        : 'Ghi âm cho bé ${widget.child?.name ?? ''} · ${widget.className}';

    return Scaffold(
      appBar: KAppBar(
        title: 'Xem lại & tách theo bé',
        subtitle: subtitle,
        onBack: widget.onBack,
        trailing: effectiveTranscript.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.description_outlined,
                    color: KColors.brand),
                tooltip: 'Xem text đã phân tích',
                onPressed: () =>
                    _showTranscriptDialog(context, effectiveTranscript),
              )
            : null,
      ),
      body: FutureBuilder<List<Child>>(
        future: childrenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() {
                  childrenFuture = _loadChildren().then((children) {
                    roster = children;
                    items = _buildObservations(children);
                    return children;
                  });
                }),
                child: const Text('Không tải được danh sách trẻ · Thử lại'),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: counter X/Y
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Từ 1 lần nói · ${items.length} ghi nhận',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: KColors.ink),
                      ),
                    ),
                    if (pendingCount > 0) ...[
                      TextButton.icon(
                        onPressed: _approveAll,
                        icon: const Icon(Icons.done_all_rounded,
                            size: 14, color: KColors.brand),
                        label: const Text(
                          'Duyệt tất cả',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: KColors.brand,
                              fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (approvedCount > 0) ...[
                      TextButton.icon(
                        onPressed: _unapproveAll,
                        icon: const Icon(Icons.undo_rounded,
                            size: 14, color: KColors.warn),
                        label: const Text(
                          'Bỏ duyệt tất cả',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: KColors.warn,
                              fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _CounterPill(
                      approved: approvedCount,
                      total: totalCount - discardedCount,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Đọc lại theo đúng thứ tự cô đã kể.',
                  style: TextStyle(fontSize: 12.5, color: KColors.inkSoft),
                ),
                const SizedBox(height: 16),
                if (effectiveTranscript.isNotEmpty)
                  _AnalyzedTextCard(
                    text: effectiveTranscript,
                    onEdit: _editAndReanalyzeTranscript,
                  ),
                for (var i = 0; i < items.length; i++)
                  _AnimatedObservationWrapper(
                    key: ValueKey(items[i].id),
                    decision: items[i].decision,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ObservationTile(
                        card: items[i],
                        index: i,
                        isApproving: approvingIds.contains(items[i].id),
                        onToggleApprove: () {
                          if (items[i].decision ==
                              ObservationDecision.approved) {
                            _unapproveItem(items[i]);
                          } else {
                            _approveItem(items[i]);
                          }
                        },
                        onUnapprove: () => _unapproveItem(items[i]),
                        onDiscard: () => setState(() {
                          items[i].decision = ObservationDecision.discarded;
                          // Bỏ draft ids đã thu (nếu có) để không gửi nhầm
                          approvedDraftIds.remove(items[i].id);
                        }),
                        onRestore: () => setState(() {
                          items[i].decision = ObservationDecision.pending;
                          // Xóa draft ids để user phải approve lại
                          approvedDraftIds.remove(items[i].id);
                        }),
                        onAssign: () => _assignChild(items[i]),
                        onAssignClass: () => setState(() {
                          items[i].kind = ObservationKind.classwide;
                          items[i].name = 'Chung cả lớp';
                          items[i].matched = true;
                          items[i].decision = ObservationDecision.pending;
                          approvedDraftIds.remove(items[i].id);
                        }),
                        onEdit: () => _editObservation(items[i]),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomSheet: Container(
        decoration: const BoxDecoration(
          color: KColors.surface,
          border: Border(top: BorderSide(color: KColors.line)),
          boxShadow: [
            BoxShadow(
                color: Color(0x102a2926),
                blurRadius: 20,
                offset: Offset(0, -8)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sẽ gửi từ 1 lần nói này:',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: KColors.inkSoft),
            ),
            const SizedBox(height: 7),
            _SummaryRow('📄', approvedCount, 'phiếu liên lạc cho phụ huynh'),
            if (healthCount > 0)
              _SummaryRow('🏥', healthCount, 'ghi nhận vào sổ sức khỏe'),
            if (discardedCount > 0)
              _SummaryRow('🗑️', discardedCount, 'đã được loại bỏ'),
            if (unmatchedActiveCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _SurfaceBox(
                  padding: const EdgeInsets.all(8),
                  color: KColors.warnTint,
                  borderColor: KColors.warnTint,
                  child: Text(
                    'Còn $unmatchedActiveCount đoạn chưa xử lý. Gán cho một bé, cả lớp hoặc bỏ qua để xác nhận.',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: KColors.warn),
                  ),
                ),
              ),
            if (pendingCount > 0 && unmatchedActiveCount == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _SurfaceBox(
                  padding: const EdgeInsets.all(8),
                  color: KColors.brandTint,
                  borderColor: KColors.brandTint,
                  child: Text(
                    'Còn $pendingCount mục chưa duyệt. Bấm "Duyệt" từng mục hoặc loại bỏ để tiếp tục.',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: KColors.brand),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed:
                  !isSubmitting && (approvedCount > 0 || pendingCount > 0)
                      ? () async {
                          if (approvedCount == 0 && pendingCount > 0) {
                            await _approveAll();
                          }
                          await _sendBatch();
                        }
                      : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KRadii.control)),
              ),
              child: Text(
                isSubmitting
                    ? 'Đang gửi báo cáo…'
                    : approvedCount > 0
                        ? 'Gửi $approvedCount báo cáo'
                        : 'Duyệt & Gửi báo cáo cả lớp',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editObservation(ObservationItem item) async {
    final eatingCtrl = TextEditingController(text: item.eating);
    final sleepDigits = RegExp(r'\d+').firstMatch(item.sleep)?.group(0) ?? '';
    final sleepCtrl = TextEditingController(
      text: sleepDigits.isNotEmpty
          ? sleepDigits
          : (int.tryParse(item.sleep.trim()) != null ? item.sleep.trim() : ''),
    );
    final activitiesCtrl = TextEditingController(text: item.activities);
    final moodCtrl = TextEditingController(text: item.mood);
    final healthCtrl = TextEditingController(text: item.health);
    final noteCtrl = TextEditingController(text: item.note);
    final snippetCtrl = TextEditingController(text: item.snippet);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditObservationSheet(
        title: item.name,
        isClasswide: item.kind == ObservationKind.classwide,
        isUnmatched: item.kind == ObservationKind.unmatched,
        eatingCtrl: eatingCtrl,
        sleepCtrl: sleepCtrl,
        activitiesCtrl: activitiesCtrl,
        moodCtrl: moodCtrl,
        healthCtrl: healthCtrl,
        noteCtrl: noteCtrl,
        snippetCtrl: snippetCtrl,
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        item.eating = eatingCtrl.text.trim();
        final sVal = sleepCtrl.text.trim();
        item.sleep = sVal.isNotEmpty ? '$sVal phút' : '';
        item.activities = activitiesCtrl.text.trim();
        item.mood = moodCtrl.text.trim();
        item.health = healthCtrl.text.trim();
        item.note = noteCtrl.text.trim();
        if (item.kind == ObservationKind.unmatched) {
          item.snippet = snippetCtrl.text.trim();
        }
      });

      // Nếu item đã được approve trước đó, gọi lại approveItem để sync với backend
      if (item.decision == ObservationDecision.approved) {
        await _approveItem(item);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật nội dung cho "${item.name}".'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _editAndReanalyzeTranscript() async {
    final textCtrl = TextEditingController(text: effectiveTranscript);
    final shouldReanalyze = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: KColors.brand),
            SizedBox(width: 8),
            Text('Chỉnh sửa văn bản ghi âm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bạn có thể chỉnh sửa lại nội dung văn bản dưới đây rồi bấm "Phân tích lại" để AI trích xuất lại thông tin:',
                style: TextStyle(fontSize: 12.5, color: KColors.inkSoft),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 6,
                minLines: 3,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung văn bản...',
                  filled: true,
                  fillColor: KColors.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: KColors.line),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Phân tích lại'),
          ),
        ],
      ),
    );

    if (shouldReanalyze == true && mounted) {
      final newText = textCtrl.text.trim();
      if (newText.isEmpty) {
        _showError('Văn bản không được để trống.');
        return;
      }

      final voiceRecordId = widget.voiceRecord?.id;
      if (voiceRecordId == null || voiceRecordId.isEmpty) {
        setState(() {
          editedTranscript = newText;
        });
        return;
      }

      String teacherId;
      try {
        final t = await repository.getCurrentTeacher();
        teacherId = t.teacherId.isNotEmpty ? t.teacherId : repository.teacherId;
      } catch (_) {
        teacherId =
            AuthRepository.currentUser?.teacherId ?? repository.teacherId;
      }

      if (!mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang phân tích lại với văn bản mới...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final newExtraction = await teacherRepository.analyzeTranscript(
          voiceId: voiceRecordId,
          teacherId: teacherId,
          editedTranscript: newText,
        );

        if (!mounted) return;
        Navigator.pop(context); // close loading dialog

        setState(() {
          editedTranscript = newText;
          currentExtraction = newExtraction;
          approvedDraftIds.clear();
          items = _buildObservations(roster, newExtraction);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã phân tích lại thành công!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // close loading dialog
        _showError('Lỗi khi phân tích lại: $e');
      }
    }
  }
}

class _AnalyzedTextCard extends StatefulWidget {
  const _AnalyzedTextCard({
    required this.text,
    this.onEdit,
  });
  final String text;
  final VoidCallback? onEdit;

  @override
  State<_AnalyzedTextCard> createState() => _AnalyzedTextCardState();
}

class _AnalyzedTextCardState extends State<_AnalyzedTextCard> {
  bool isExpanded = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép nội dung văn bản đã phân tích.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KColors.brand.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: KColors.brand.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => isExpanded = !isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: KColors.brandTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.text_snippet_outlined,
                        color: KColors.brand, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Xem lại text đã phân tích',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: KColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isExpanded
                              ? 'Chạm để thu gọn'
                              : 'Chạm để xem lại toàn bộ text đã ghi âm',
                          style: const TextStyle(
                              fontSize: 11.5, color: KColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: KColors.inkSoft,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KColors.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: KColors.line),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.text,
                        style: const TextStyle(
                            fontSize: 13, height: 1.55, color: KColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.onEdit != null) ...[
                        OutlinedButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text('Sửa & Phân tích lại',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton.tonalIcon(
                        onPressed: _copy,
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text('Sao chép',
                            style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
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

typedef SegmentationScreen = ReviewScreen;

class _ObservationTile extends StatelessWidget {
  const _ObservationTile({
    required this.card,
    required this.index,
    required this.onToggleApprove,
    required this.onUnapprove,
    required this.onDiscard,
    required this.onRestore,
    required this.onAssign,
    required this.onAssignClass,
    this.onEdit,
    this.isApproving = false,
  });

  final ObservationItem card;
  final int index;
  final VoidCallback onToggleApprove;
  final VoidCallback onUnapprove;
  final VoidCallback onDiscard;
  final VoidCallback onRestore;
  final VoidCallback onAssign;
  final VoidCallback onAssignClass;
  final VoidCallback? onEdit;
  final bool isApproving;

  @override
  Widget build(BuildContext context) {
    if (card.decision == ObservationDecision.discarded) {
      return _SurfaceBox(
        color: KColors.canvas,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Đã loại bỏ · ${card.name}',
                style: const TextStyle(fontSize: 12, color: KColors.inkFaint),
              ),
            ),
            TextButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.undo_rounded, size: 15),
              label: const Text('Hoàn tác'),
            ),
          ],
        ),
      );
    }

    final isUnmatched = card.kind == ObservationKind.unmatched;

    return _SurfaceBox(
      color: isUnmatched
          ? KColors.warnTint.withValues(alpha: 0.45)
          : KColors.surface,
      borderColor: isUnmatched ? KColors.warn : KColors.line,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isUnmatched ? KColors.warn : KColors.brand,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (card.matched)
                Avatar(name: card.name, size: 32)
              else
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: KColors.warnTint,
                  child: Text(
                    '?',
                    style: TextStyle(
                        fontSize: 16,
                        color: KColors.warn,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: isUnmatched ? KColors.warn : KColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isUnmatched
                          ? 'Đoạn này có nhắc tên nhưng chưa khớp'
                          : 'Đoạn ${index + 1}',
                      style: const TextStyle(
                          fontSize: 11, color: KColors.inkFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isUnmatched) ...[
            const SizedBox(height: 10),
            _SurfaceBox(
              color: KColors.surface,
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lời cô nói, chỉ cô thấy',
                      style:
                          TextStyle(fontSize: 10.5, color: KColors.inkFaint)),
                  const SizedBox(height: 3),
                  Text(
                    card.snippet.isNotEmpty
                        ? card.snippet
                        : 'Chưa nhận diện chính xác được bé trong lớp.',
                    style:
                        const TextStyle(fontSize: 12, color: KColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _buildReportLine('🍽️', 'Bữa ăn', card.eating),
          _buildReportLine('😴', 'Giấc ngủ', card.sleep),
          _buildReportLine('🎨', 'Hoạt động', card.activities),
          _buildReportLine('🎭', 'Tâm trạng', card.mood),
          if (card.health.isNotEmpty)
            _buildReportLine('🏥', 'Sức khỏe', card.health),
          if (card.note.trim().isNotEmpty)
            _buildReportLine('📝', 'Ghi chú', card.note.trim()),
          if (card.eating.isEmpty &&
              card.sleep.isEmpty &&
              card.activities.isEmpty &&
              card.mood.isEmpty &&
              card.health.isEmpty &&
              card.note.trim().isEmpty &&
              !isUnmatched)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Không có thông tin chi tiết được ghi nhận',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: KColors.inkFaint),
              ),
            ),
          const Divider(height: 20),
          if (isUnmatched) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: KColors.warn,
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KRadii.control)),
                ),
                onPressed: onAssign,
                icon: const Icon(Icons.person_add_alt_rounded, size: 16),
                label: const Text('Gán cho một bé'),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KRadii.control)),
                ),
                onPressed: onAssignClass,
                child: const Text('Đoạn này nói về cả lớp'),
              ),
            ),
            if (onEdit != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KRadii.control)),
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Chỉnh sửa nội dung đoạn này'),
                ),
              ),
            ],
            Center(
              child: TextButton(
                onPressed: onDiscard,
                child: const Text('Bỏ đoạn này',
                    style: TextStyle(color: KColors.inkFaint)),
              ),
            ),
          ] else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onEdit != null) ...[
                  OutlinedButton.icon(
                    onPressed: isApproving ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Chỉnh sửa'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KRadii.control)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton.icon(
                  onPressed: isApproving ? null : onDiscard,
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text('Loại bỏ'),
                ),
                const SizedBox(width: 8),
                if (isApproving)
                  // Đang approve → hiện spinner (block cả Loại bỏ để tránh race)
                  const SizedBox(
                    height: 32,
                    width: 32,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (card.decision == ObservationDecision.approved) ...[
                  OutlinedButton.icon(
                    onPressed: onUnapprove,
                    icon: const Icon(Icons.undo_rounded,
                        size: 15, color: KColors.warn),
                    label: const Text(
                      'Bỏ duyệt',
                      style: TextStyle(
                          color: KColors.warn, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: KColors.warn, width: 1.2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KRadii.control)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onToggleApprove,
                    borderRadius: BorderRadius.circular(KRadii.control),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: KColors.okTint,
                        borderRadius: BorderRadius.circular(KRadii.control),
                        border: Border.all(
                            color: KColors.ok.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 15, color: KColors.ok),
                          SizedBox(width: 5),
                          Text(
                            'Đã duyệt',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: KColors.ok),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: onToggleApprove,
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: const Text('Duyệt'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReportLine(String emoji, String label, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$emoji $label: ',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: KColors.inkSoft),
            ),
            TextSpan(
              text: text,
              style: const TextStyle(fontSize: 13, color: KColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceBox extends StatelessWidget {
  const _SurfaceBox({
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? KColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? KColors.line),
      ),
      child: child,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.emoji, this.count, this.label);

  final String emoji;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
              width: 24,
              child: Text(emoji, style: const TextStyle(fontSize: 15))),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: KColors.ink),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: KColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.card, required this.roster});

  final ObservationItem card;
  final List<Child> roster;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.roster
        .where((c) =>
            query.isEmpty ||
            '${c.name} ${c.nickname ?? ''}'
                .toLowerCase()
                .contains(query.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Gán cho một bé',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: KColors.ink)),
            const SizedBox(height: 2),
            Text(
              widget.card.snippet.isNotEmpty
                  ? 'Đoạn nói: "${widget.card.snippet}". Chọn bé tương ứng.'
                  : 'Chọn bé tương ứng với đoạn ghi âm này.',
              style: const TextStyle(fontSize: 12, color: KColors.inkSoft),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Tìm tên bé hoặc biệt danh',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => ListTile(
                  leading: Avatar(name: list[i].name, size: 34),
                  title: Text(list[i].name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: list[i].nickname != null &&
                          list[i].nickname!.isNotEmpty
                      ? Text('Tên gọi ở lớp: ${list[i].nickname}',
                          style: const TextStyle(
                              fontSize: 11.5, color: KColors.inkSoft))
                      : null,
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => Navigator.pop(context, list[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneScreenView extends StatelessWidget {
  const _DoneScreenView({
    required this.parentReportsCount,
    required this.healthRecordsCount,
    required this.recordingTime,
    required this.onBack,
  });

  final int parentReportsCount;
  final int healthRecordsCount;
  final String recordingTime;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KAppBar(
        title: 'Đã tạo hồ sơ',
        subtitle: 'Xác nhận lúc $recordingTime',
        onBack: onBack,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          const Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: KColors.brand,
              child: Icon(Icons.check_rounded, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Cô nói một lần.\nBa nơi đã nhận.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: KColors.ink),
          ),
          const SizedBox(height: 8),
          const Text(
            'Không phải nhập lại ở đâu cả. Chạm từng nơi để xem hồ sơ đã tới đúng người.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: KColors.inkSoft),
          ),
          const SizedBox(height: 24),
          _SurfaceBox(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SummaryRow(
                    '📄', parentReportsCount, 'phiếu liên lạc cho phụ huynh'),
                const SizedBox(height: 6),
                _SummaryRow(
                    '🏥', healthRecordsCount, 'ghi nhận vào sổ sức khỏe'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SurfaceBox(
            child: Text(
              '$parentReportsCount phụ huynh nhận phiếu. Sổ sức khỏe có $healthRecordsCount dòng mới. Tất cả đến từ ghi âm lúc $recordingTime.',
              style: const TextStyle(fontSize: 12.5, color: KColors.inkSoft),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KRadii.control)),
            ),
            child: const Text('Về tổng quan lớp'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              onBack();
              appRouter.go('/class-select');
            },
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Quay lại để chọn lớp khác'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Counter pill "X / Y đã duyệt" ở header
// ===========================================================================

class _CounterPill extends StatelessWidget {
  const _CounterPill({required this.approved, required this.total});

  final int approved;
  final int total;

  @override
  Widget build(BuildContext context) {
    final done = approved >= total && total > 0;
    final color = done ? KColors.brand : KColors.inkSoft;
    final bg = done ? KColors.brandTint : KColors.canvas;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        'Đã duyệt $approved/$total',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ===========================================================================
// Animation wrapper cho mỗi ObservationTile
// Khi decision -> discarded: fade out + slide sang trái (~300ms)
// Khi restore: fade in + slide về 0 (~300ms)
// ===========================================================================

class _AnimatedObservationWrapper extends StatelessWidget {
  const _AnimatedObservationWrapper({
    super.key,
    required this.child,
    required this.decision,
  });

  final Widget child;
  final ObservationDecision decision;

  @override
  Widget build(BuildContext context) {
    final isDiscarded = decision == ObservationDecision.discarded;
    // Tween end: -1 nếu discarded (slide trái + fade), 0 nếu bình thường.
    // TweenAnimationBuilder sẽ tween từ giá trị hiện tại → end mỗi khi tween đổi.
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(
        begin: 0.0,
        end: isDiscarded ? -1.0 : 0.0,
      ),
      builder: (context, offset, c) {
        final clamped = offset.clamp(-1.0, 0.0);
        return Opacity(
          // offset = -1 → opacity = 0.45 (mờ đi); offset = 0 → opacity = 1.0
          opacity: 1.0 + clamped * 0.55,
          child: Transform.translate(
            // slide trái tối đa ~28px
            offset: Offset(clamped * 28, 0),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

// ===========================================================================
// Modal Bottom Sheet để chỉnh sửa nội dung chi tiết quan sát của bé / lớp
// ===========================================================================

class _EditObservationSheet extends StatelessWidget {
  const _EditObservationSheet({
    required this.title,
    required this.isClasswide,
    this.isUnmatched = false,
    required this.eatingCtrl,
    required this.sleepCtrl,
    required this.activitiesCtrl,
    required this.moodCtrl,
    required this.healthCtrl,
    required this.noteCtrl,
    required this.snippetCtrl,
  });

  final String title;
  final bool isClasswide;
  final bool isUnmatched;
  final TextEditingController eatingCtrl;
  final TextEditingController sleepCtrl;
  final TextEditingController activitiesCtrl;
  final TextEditingController moodCtrl;
  final TextEditingController healthCtrl;
  final TextEditingController noteCtrl;
  final TextEditingController snippetCtrl;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: KColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUnmatched ? KColors.warnTint : KColors.brandTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: isUnmatched ? KColors.warn : KColors.brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chỉnh sửa · $title',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: KColors.ink,
                      ),
                    ),
                    Text(
                      isClasswide
                          ? 'Áp dụng cho toàn thể các bé trong lớp'
                          : isUnmatched
                              ? 'Chỉnh sửa nội dung đoạn chưa phân loại'
                              : 'Chỉnh sửa chi tiết thông tin cho bé',
                      style:
                          const TextStyle(fontSize: 12, color: KColors.inkSoft),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (isUnmatched) ...[
                    _buildField(
                      emoji: '💬',
                      label: 'Nội dung đoạn nói',
                      controller: snippetCtrl,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildField(
                    emoji: '🍽️',
                    label: 'Bữa ăn',
                    controller: eatingCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    emoji: '😴',
                    label: 'Giấc ngủ',
                    controller: sleepCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    suffixText: 'phút',
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    emoji: '🎨',
                    label: 'Hoạt động',
                    controller: activitiesCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    emoji: '🎭',
                    label: 'Tâm trạng',
                    controller: moodCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    emoji: '🏥',
                    label: 'Sức khỏe',
                    controller: healthCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    emoji: '📝',
                    label: 'Ghi chú cho phụ huynh',
                    controller: noteCtrl,
                    maxLines: 4,
                    maxLength: 500,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KRadii.control)),
                  ),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Lưu thay đổi'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KRadii.control)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String emoji,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: KColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 2 : 1,
          maxLength: maxLength,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          buildCounter: maxLength != null
              ? (context,
                  {required currentLength, required isFocused, maxLength}) {
                  return Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$currentLength/$maxLength ký tự',
                      style: const TextStyle(
                          fontSize: 11.5, color: KColors.inkSoft),
                    ),
                  );
                }
              : null,
          style: const TextStyle(fontSize: 13.5, color: KColors.ink),
          decoration: InputDecoration(
            suffixText: suffixText,
            suffixStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: KColors.inkSoft),
            isDense: true,
            filled: true,
            fillColor: KColors.canvas,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: KColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: KColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: KColors.brand, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
