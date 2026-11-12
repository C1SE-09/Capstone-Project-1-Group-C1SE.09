import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import 'package:cross_file/cross_file.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/record/session_clip_bar.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/audio_player_card.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/analyzed_text_card.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/edit_observation_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/review_common_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/done_screen_view.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/bug_report_sheet.dart';

export 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/audio_player_card.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/analyzed_text_card.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/edit_observation_screen.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/review_common_widgets.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/done_screen_view.dart';

enum RecordMode { classroom, child }

String _recordAllergy(String value) => value
    .replaceFirst(RegExp(r'^Dị ứng\s*:?\s*', caseSensitive: false), '')
    .trim();

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
  Widget build(BuildContext context) => GardenVoiceScope(
        child: FutureBuilder<_RecordHubData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Scaffold(
                  body: Center(
                      child: TextButton(
                          onPressed: () => setState(() => future = _load()),
                          child: const Text('Không tải được lớp · Thử lại'))));
            }
            final data = snapshot.data!;
            final list = data.children
                .where((child) =>
                    child.name.toLowerCase().contains(query.toLowerCase()))
                .toList();
            final k = context.k;
            return Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    _GardenVoiceRecordHeader(
                      title: 'Ghi nhận hoạt động',
                      subtitle: 'Chọn trẻ để bắt đầu ghi nhận',
                      onBack: () => Navigator.pop(context),
                      backAsset: 'assets/garden_voice/hub_back.svg',
                    ),
                    const SizedBox(height: 14),
                    Material(
                      color: k.brandTint,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: widget.onClass,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 82),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: k.lineStrong),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                  'assets/garden_voice/class_group.svg'),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        'Cả Lớp ${data.className.replaceFirst(RegExp(r'^Lớp\s+'), '')}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.4,
                                          fontWeight: FontWeight.w700,
                                          color: k.ink,
                                        )),
                                    Text(
                                        'Ghi một lần, tạo báo cáo cho tất cả trẻ.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          fontWeight: FontWeight.w600,
                                          color: k.inkSoft,
                                        )),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SvgPicture.asset(
                                  'assets/garden_voice/caret_filled.svg'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: k.line)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('hoặc chọn từng trẻ',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                  color: k.inkFaint,
                                )),
                          ),
                          Expanded(child: Divider(color: k.line)),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: TextField(
                        onChanged: (value) => setState(() => query = value),
                        style: TextStyle(fontSize: 14, color: k.ink),
                        decoration: InputDecoration(
                          hintText: 'Tìm trẻ…',
                          hintStyle: TextStyle(color: k.inkSoft),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(11),
                            child: SvgPicture.asset(
                                'assets/garden_voice/record_search.svg'),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          filled: true,
                          fillColor: const Color(0xFFEDF4F7),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF9FC3CF)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: k.brand, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${data.className} · ${data.totalChildren} trẻ',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: k.inkSoft,
                              ),
                            ),
                          ),
                          Text('${data.pendingCount} chưa xong',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: k.inkFaint,
                              )),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 257,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FCFB),
                          border: Border.all(color: k.lineStrong),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF212E2B)
                                  .withValues(alpha: .05),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: list.isEmpty
                            ? Center(
                                child: Text(
                                  'Không tìm thấy trẻ phù hợp.',
                                  style: TextStyle(color: k.inkSoft),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: k.line),
                                itemBuilder: (context, index) {
                                  final child = list[index];
                                  final allergy = child.allergy == null
                                      ? null
                                      : _recordAllergy(child.allergy!);
                                  return InkWell(
                                    onTap: () => widget.onChild(child),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Row(
                                        children: [
                                          Avatar(name: child.name),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(child.name,
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      height: 1.4,
                                                      color: k.ink,
                                                    )),
                                                if (allergy != null &&
                                                    allergy.isNotEmpty)
                                                  Text('Dị ứng: $allergy',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        height: 1.4,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: k.warn,
                                                      )),
                                                if ((child.careNotes ?? '')
                                                    .trim()
                                                    .isNotEmpty)
                                                  Text(
                                                      'Lưu ý: ${child.careNotes!.trim()}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        height: 1.4,
                                                        color: k.inkSoft,
                                                      )),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _GardenVoiceRecordStatus(
                                              status: child.status),
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
          },
        ),
      );
}

class _RecordHubData {
  const _RecordHubData(
      this.children, this.className, this.totalChildren, this.pendingCount);
  final List<Child> children;
  final String className;
  final int totalChildren;
  final int pendingCount;
}

class _GardenVoiceRecordHeader extends StatelessWidget {
  const _GardenVoiceRecordHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.backAsset = 'assets/garden_voice/record_back.svg',
    this.showProgress = false,
    this.progressStep = 0,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final String backAsset;
  final bool showProgress;
  final int progressStep;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: 'Quay lại',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: SvgPicture.asset(backAsset),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: k.ink,
                      )),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: k.inkSoft,
                      )),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
        if (showProgress) ...[
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index <= progressStep ? k.brand : k.brandTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
              'Bước ${progressStep + 1}/3 · ${const [
                'Ghi âm',
                'Phân tích',
                'Xem lại'
              ][progressStep]}',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: k.inkSoft,
              )),
        ],
      ],
    );
  }
}

class _GardenVoiceRecordStatus extends StatelessWidget {
  const _GardenVoiceRecordStatus({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (label, background, foreground) = switch (status) {
      ReportStatus.none => ('Chưa ghi', k.surfaceSunken, k.inkSoft),
      ReportStatus.draft || ReportStatus.processing => (
          'Đang xử lý',
          k.infoTint,
          k.info
        ),
      ReportStatus.submitted || ReportStatus.read => ('Đã ghi', k.okTint, k.ok),
      ReportStatus.attention => ('Cần xử lý', k.badTint, k.bad),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: foreground, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: foreground,
              )),
        ],
      ),
    );
  }
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
    this.audioRecorder,
    this.pathProvider,
  });
  final RecordMode mode;
  final Child? child;
  final String classId;
  final String className;
  final HttpDashboardRepository? repository;
  final TeacherRepository? teacherRepository;
  final AudioRecorder? audioRecorder;
  final Future<String> Function(String extension)? pathProvider;

  @override
  State<RecordFlowScreen> createState() => _RecordFlowScreenState();
}

class _RecordFlowScreenState extends State<RecordFlowScreen> {
  String step = 'record';
  PlatformFile? uploadedFile;
  VoiceRecordingSession? activeSession;
  String? editedMergedTranscript;
  Uint8List? previewAudioBytes;
  VoiceRecord? voiceRecord;
  ExtractionData? extractionData;
  String? transcript;

  late final TeacherRepository teacherRepository =
      widget.teacherRepository ?? TeacherRepository();

  @override
  Widget build(BuildContext context) {
    return GardenVoiceScope(
      child: Builder(
        builder: (context) => switch (step) {
          'processing' => ProcessingScreen(
              mode: widget.mode,
              file: uploadedFile,
              session: activeSession,
              editedMergedTranscript: editedMergedTranscript,
              classId: widget.classId,
              child: widget.child,
              teacherRepository: teacherRepository,
              onBack: () => setState(() => step = 'record'),
              onDone: (record, extraction) {
                voiceRecord = record;
                extractionData = extraction;
                transcript =
                    record?.effectiveTranscript ?? extraction?.transcript;
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
              recordedBytes: previewAudioBytes ?? uploadedFile?.bytes,
              repository: widget.repository,
              teacherRepository: teacherRepository,
              onBack: () => setState(() => step = 'record'),
              onCompleted: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã tạo và gửi báo cáo thành công!'),
                    backgroundColor: context.k.brand,
                  ),
                );
              },
            ),
          _ => RecordingScreen(
              mode: widget.mode,
              child: widget.child,
              classId: widget.classId,
              className: widget.className,
              enableMultiClipSession: true,
              teacherRepository: teacherRepository,
              audioRecorder: widget.audioRecorder,
              pathProvider: widget.pathProvider,
              onSubmit: (file) {
                setState(() {
                  uploadedFile = file;
                  activeSession = null;
                  editedMergedTranscript = null;
                  previewAudioBytes = file?.bytes;
                  step = 'processing';
                });
              },
              onSubmitSession: ({
                required session,
                editedMergedTranscript,
                previewAudioBytes,
              }) {
                setState(() {
                  activeSession = session;
                  this.editedMergedTranscript = editedMergedTranscript;
                  this.previewAudioBytes = previewAudioBytes;
                  uploadedFile = null;
                  step = 'processing';
                });
              },
            ),
        },
      ),
    );
  }
}

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.mode,
    required this.onSubmit,
    this.child,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.className = 'Mầm 1',
    this.enableMultiClipSession = false,
    this.teacherRepository,
    this.audioRecorder,
    this.pathProvider,
    this.audioPlayerFactory,
    this.onSubmitSession,
  });
  final RecordMode mode;
  final Child? child;
  final ValueChanged<PlatformFile?> onSubmit;
  final String classId;
  final String className;
  final bool enableMultiClipSession;
  final TeacherRepository? teacherRepository;
  final AudioRecorder? audioRecorder;
  final Future<String> Function(String extension)? pathProvider;
  final AudioPlayerFactory? audioPlayerFactory;
  final void Function({
    required VoiceRecordingSession session,
    String? editedMergedTranscript,
    Uint8List? previewAudioBytes,
  })? onSubmitSession;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  int seconds = 0;
  String phase = 'ready';
  PlatformFile? selectedFile;
  Timer? timer;
  bool isBusy = false;
  String _currentExtension = 'm4a';

  // Multi-clip session state (User Story #78)
  VoiceRecordingSession? _session;
  bool _isUploadingClip = false;
  bool _isDiscardingSession = false;
  Timer? _pollTimer;
  final Set<String> _expandedClipIds = <String>{};
  final Set<String> _deletingClipIds = <String>{};
  final Set<String> _savingTranscriptClipIds = <String>{};
  final Map<String, String> _editedClipTranscripts = <String, String>{};
  final Map<String, Uint8List> _clipLocalBytes = <String, Uint8List>{};

  // Single-active-clip audio player state
  AudioPlayer? _clipPlayer;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _playerPosSub;
  StreamSubscription<Duration?>? _playerDurSub;
  String? _playingClipId;
  String? _loadingAudioClipId;
  Duration _clipPosition = Duration.zero;
  Duration _clipDuration = Duration.zero;

  late final AudioRecorder _recorder = widget.audioRecorder ?? AudioRecorder();
  late final TeacherRepository _repo =
      widget.teacherRepository ?? TeacherRepository();

  String get _teacherId =>
      AuthRepository.currentUser?.teacherId ??
      'bbbbbbbb-0000-0000-0000-000000000001';

  String get _sessionScope =>
      widget.mode == RecordMode.child && widget.child != null
          ? 'single_child'
          : 'whole_class';

  String? get _targetChildId =>
      _sessionScope == 'single_child' ? widget.child?.id : null;

  // Primary wave controller — drives the oscillation frequency.
  late final AnimationController wave = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  // Secondary controller with slightly different period for a richer, more organic look.
  late final AnimationController wave2 = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.enableMultiClipSession) {
      unawaited(_restoreActiveSession());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _pollTimer?.cancel();
    _playerStateSub?.cancel();
    _playerPosSub?.cancel();
    _playerDurSub?.cancel();
    _clipPlayer?.dispose();
    wave.dispose();
    wave2.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _restoreActiveSession() async {
    try {
      final restored = await _repo.createOrResumeVoiceSession(
        teacherId: _teacherId,
        classId: widget.classId,
        childId: _targetChildId,
        scope: _sessionScope,
      );
      if (!mounted) return;
      setState(() {
        _session = restored;
      });
      _syncPollingTimer();
    } catch (_) {
      // Initial silent restore: if offline/unavailable, keep UI ready and
      // lazily create session when the first clip is saved.
    }
  }

  Future<VoiceRecordingSession> _ensureSession() async {
    if (_session != null) return _session!;
    final created = await _repo.createOrResumeVoiceSession(
      teacherId: _teacherId,
      classId: widget.classId,
      childId: _targetChildId,
      scope: _sessionScope,
    );
    if (mounted) {
      setState(() => _session = created);
    } else {
      _session = created;
    }
    return created;
  }

  void _syncPollingTimer() {
    final hasInFlight =
        _session?.clips.any((c) => c.isPendingOrProcessing) ?? false;
    if (!hasInFlight) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_pollTimer != null && _pollTimer!.isActive) return;
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshSessionSilently()),
    );
  }

  Future<void> _refreshSessionSilently() async {
    final sessionId = _session?.sessionId;
    if (sessionId == null || !mounted) {
      _pollTimer?.cancel();
      return;
    }
    try {
      final refreshed = await _repo.getVoiceSession(
        sessionId: sessionId,
        teacherId: _teacherId,
      );
      if (!mounted) return;
      setState(() => _session = refreshed);
      _syncPollingTimer();
    } catch (_) {
      // Transient polling errors are retried on the next tick.
    }
  }

  Future<Uint8List?> _extractFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }
    if (file.readStream != null) {
      final chunks = <int>[];
      await for (final chunk in file.readStream!) {
        chunks.addAll(chunk);
      }
      if (chunks.isNotEmpty) return Uint8List.fromList(chunks);
    }
    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      return await XFile(file.path!).readAsBytes();
    }
    return null;
  }

  Future<void> _uploadClipToSession(PlatformFile file) async {
    if (!mounted) return;
    setState(() {
      _isUploadingClip = true;
      isBusy = false;
      phase = 'ready';
      seconds = 0;
      selectedFile = null;
    });

    try {
      final bytes = await _extractFileBytes(file);
      final safePath = kIsWeb ? '' : (file.path ?? '');
      final session = await _ensureSession();
      final record = await _repo.uploadAudioToSession(
        sessionId: session.sessionId,
        filePath: safePath,
        fileBytes: bytes,
        fileName: file.name,
        classId: widget.classId,
        teacherId: _teacherId,
        childId: _targetChildId,
      );
      if (bytes != null && bytes.isNotEmpty) {
        _clipLocalBytes[record.id] = bytes;
      }

      VoiceRecordingSession updatedSession;
      try {
        updatedSession = await _repo.getVoiceSession(
          sessionId: session.sessionId,
          teacherId: _teacherId,
        );
      } catch (_) {
        updatedSession = VoiceRecordingSession(
          sessionId: session.sessionId,
          scope: session.scope,
          status: session.status,
          teacherId: session.teacherId,
          classId: session.classId,
          childId: session.childId,
          recordedAt: session.recordedAt,
          clips: [
            ...session.clips,
            VoiceClip(
              voiceRecordId: record.id,
              status: record.status,
              createdAt: DateTime.now(),
            ),
          ],
          pendingCount: session.pendingCount + 1,
          completedCount: session.completedCount,
        );
      }

      if (!mounted) return;
      setState(() {
        _session = updatedSession;
        _isUploadingClip = false;
      });
      _syncPollingTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingClip = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getFriendlyErrorMessage(e)),
          backgroundColor: context.k.bad,
        ),
      );
    }
  }

  Future<AudioPlayer> _ensureClipPlayer() async {
    if (_clipPlayer != null) return _clipPlayer!;
    final player = widget.audioPlayerFactory?.call() ?? AudioPlayer();
    _clipPlayer = player;
    _playerStateSub = player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        unawaited(player.seek(Duration.zero));
        unawaited(player.pause());
        setState(() {
          _playingClipId = null;
          _clipPosition = Duration.zero;
        });
      }
    });
    _playerPosSub = player.positionStream.listen((pos) {
      if (!mounted || _playingClipId == null) return;
      setState(() => _clipPosition = pos);
    });
    _playerDurSub = player.durationStream.listen((dur) {
      if (!mounted || _playingClipId == null) return;
      setState(() => _clipDuration = dur ?? Duration.zero);
    });
    return player;
  }

  Future<void> _toggleClipPlay(VoiceClip clip) async {
    final clipId = clip.voiceRecordId;
    try {
      final player = await _ensureClipPlayer();
      if (_playingClipId == clipId) {
        await player.pause();
        if (mounted) setState(() => _playingClipId = null);
        return;
      }

      final localBytes = _clipLocalBytes[clipId];
      final audioUrl = clip.audioUrl?.trim() ?? '';
      if ((localBytes == null || localBytes.isEmpty) && audioUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa có file âm thanh để phát lại.')),
          );
        }
        return;
      }

      setState(() {
        _loadingAudioClipId = clipId;
        _clipPosition = Duration.zero;
        _clipDuration = Duration(
          milliseconds: ((clip.audioDuration ?? 0) * 1000).round(),
        );
      });

      await player.stop();
      if (localBytes != null && localBytes.isNotEmpty) {
        await player.setAudioSource(BytesAudioSource(localBytes));
      } else {
        await player.setUrl(audioUrl);
      }

      if (!mounted) return;
      setState(() {
        _loadingAudioClipId = null;
        _playingClipId = clipId;
      });
      await player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAudioClipId = null;
        if (_playingClipId == clipId) _playingClipId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể phát đoạn ghi âm này.')),
      );
    }
  }

  Future<void> _deleteClip(VoiceClip clip) async {
    final clipId = clip.voiceRecordId;
    if (_playingClipId == clipId) {
      try {
        await _clipPlayer?.stop();
      } catch (_) {}
      _playingClipId = null;
    }

    setState(() => _deletingClipIds.add(clipId));
    try {
      await _repo.deleteVoiceClip(voiceId: clipId, teacherId: _teacherId);
      _expandedClipIds.remove(clipId);
      _editedClipTranscripts.remove(clipId);
      _clipLocalBytes.remove(clipId);

      final sessionId = _session?.sessionId;
      if (sessionId != null) {
        final refreshed = await _repo.getVoiceSession(
          sessionId: sessionId,
          teacherId: _teacherId,
        );
        if (!mounted) return;
        setState(() {
          _deletingClipIds.remove(clipId);
          _session = refreshed;
        });
        _syncPollingTimer();
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e)),
            backgroundColor: context.k.bad,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _deletingClipIds.remove(clipId));
    }
  }

  Future<void> _saveClipTranscript(VoiceClip clip, String editedText) async {
    final clipId = clip.voiceRecordId;
    setState(() {
      _editedClipTranscripts[clipId] = editedText;
      _savingTranscriptClipIds.add(clipId);
    });
    try {
      await _repo.updateTranscript(
        voiceId: clipId,
        editedTranscript: editedText,
        teacherId: _teacherId,
      );
      if (!mounted) return;
      final current = _session;
      if (current != null) {
        final updatedClips = current.clips
            .map((c) => c.voiceRecordId == clipId
                ? c.copyWith(transcript: editedText)
                : c)
            .toList();
        setState(() {
          _savingTranscriptClipIds.remove(clipId);
          _session = VoiceRecordingSession(
            sessionId: current.sessionId,
            scope: current.scope,
            status: current.status,
            teacherId: current.teacherId,
            classId: current.classId,
            childId: current.childId,
            recordedAt: current.recordedAt,
            mergedTranscript: current.mergedTranscript,
            representativeVoiceRecordId: current.representativeVoiceRecordId,
            clips: updatedClips,
            pendingCount: current.pendingCount,
            completedCount: current.completedCount,
          );
        });
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e)),
            backgroundColor: context.k.bad,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _savingTranscriptClipIds.remove(clipId));
    }
  }

  Future<void> _confirmAndDiscardSession() async {
    final session = _session;
    if (session == null || session.clips.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => GardenVoiceScope(
        child: Builder(
          builder: (context) {
            final k = context.k;
            return AlertDialog(
              backgroundColor: k.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Huỷ phiên ghi âm?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: k.ink,
                ),
              ),
              content: Text(
                'Tất cả ${session.clips.length} đoạn ghi âm trong phiên hiện tại sẽ bị huỷ bỏ.',
                style: TextStyle(fontSize: 14, color: k.inkSoft),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Giữ lại'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: k.bad),
                  child: const Text('Huỷ phiên'),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDiscardingSession = true);
    try {
      await _repo.discardVoiceSession(
        sessionId: session.sessionId,
        teacherId: _teacherId,
      );
      _pollTimer?.cancel();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDiscardingSession = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getFriendlyErrorMessage(e)),
          backgroundColor: context.k.bad,
        ),
      );
    }
  }

  void _submitSessionForAnalysis() {
    final session = _session;
    if (session == null || widget.onSubmitSession == null) return;
    _pollTimer?.cancel();
    try {
      _clipPlayer?.stop();
    } catch (_) {}

    final mergedParts = <String>[];
    Uint8List? firstPreviewBytes;
    for (final clip in session.clips) {
      if (!clip.isCompleted) continue;
      firstPreviewBytes ??= _clipLocalBytes[clip.voiceRecordId];
      var text =
          (_editedClipTranscripts[clip.voiceRecordId] ?? clip.transcript ?? '')
              .trim();
      while (text.endsWith('.')) {
        text = text.substring(0, text.length - 1).trim();
      }
      if (text.isNotEmpty) {
        mergedParts.add(text);
      }
    }

    widget.onSubmitSession!(
      session: session,
      editedMergedTranscript:
          mergedParts.isNotEmpty ? mergedParts.join(' ') : null,
      previewAudioBytes: firstPreviewBytes,
    );
  }

  String _formatSessionDuration(List<VoiceClip> clips) {
    final totalSec = clips
        .fold<double>(0, (sum, c) => sum + (c.audioDuration ?? 0))
        .round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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
        wave2.stop();
        var file = result.files.single;
        if (file.bytes == null &&
            !kIsWeb &&
            file.path != null &&
            file.path!.isNotEmpty) {
          try {
            final xFile = XFile(file.path!);
            final bytes = await xFile.readAsBytes();
            file = PlatformFile(
              name: file.name,
              size: bytes.length,
              bytes: bytes,
              path: file.path,
            );
          } catch (_) {}
        }
        if (widget.enableMultiClipSession) {
          await _uploadClipToSession(file);
          return;
        }
        setState(() {
          selectedFile = file;
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

  Future<void> toggle() async {
    if (isBusy || phase == 'file_selected' || phase == 'done') return;
    if (phase == 'recording') {
      await _stopRecording();
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    setState(() => isBusy = true);
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() => isBusy = false);
          await _showRecordingRecoveryDialog(
            iconAsset: 'assets/garden_voice/record_permission.svg',
            title: 'Chưa có quyền micro',
            message:
                'Vui lòng cấp quyền truy cập micro để ghi âm. Thầy cô có thể mở Cài đặt của thiết bị, chọn Quyền riêng tư → Micro và bật cho KinderLog.',
            primaryLabel: 'Mở cài đặt',
            secondaryLabel: 'Để sau',
            onPrimary: _openMicrophoneSettings,
          );
        }
        return;
      }

      AudioEncoder encoder = AudioEncoder.aacLc;
      String extension = 'm4a';

      if (kIsWeb) {
        if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
          encoder = AudioEncoder.opus;
          extension = 'webm';
        } else if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
          encoder = AudioEncoder.aacLc;
          extension = 'm4a';
        } else {
          encoder = AudioEncoder.wav;
          extension = 'wav';
        }
      } else {
        if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
          encoder = AudioEncoder.aacLc;
          extension = 'm4a';
        } else if (await _recorder.isEncoderSupported(AudioEncoder.wav)) {
          encoder = AudioEncoder.wav;
          extension = 'wav';
        } else if (await _recorder.isEncoderSupported(AudioEncoder.pcm16bits)) {
          encoder = AudioEncoder.pcm16bits;
          extension = 'wav';
        }
      }

      String recordPath = '';
      if (!kIsWeb) {
        if (widget.pathProvider != null) {
          recordPath = await widget.pathProvider!(extension);
        } else {
          try {
            final dir = await getTemporaryDirectory();
            recordPath =
                '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.$extension';
          } catch (_) {
            recordPath =
                'rec_${DateTime.now().millisecondsSinceEpoch}.$extension';
          }
        }
      }

      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: 128000,
          sampleRate: kIsWeb ? 48000 : 44100,
          numChannels: kIsWeb ? 2 : 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: recordPath,
      );

      _currentExtension = extension;

      wave.repeat(reverse: true);
      wave2.repeat(reverse: false);
      if (mounted) {
        setState(() {
          seconds = 0;
          phase = 'recording';
          selectedFile = null;
          isBusy = false;
        });
      }

      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (seconds >= 179) {
          _stopRecording();
        } else {
          setState(() => seconds++);
        }
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        setState(() => isBusy = false);
        await _showRecordingRecoveryDialog(
          iconAsset: 'assets/garden_voice/record_error.svg',
          title: 'Chưa thể ghi âm',
          message:
              'Ứng dụng chưa thể ghi âm. Thầy cô vui lòng kiểm tra quyền truy cập Micro trong cài đặt thiết bị và thử lại nhé.',
          primaryLabel: 'Thử lại',
          secondaryLabel: 'Đóng',
          onPrimary: () => _startRecording(),
        );
      }
    }
  }

  Future<void> _openMicrophoneSettings() async {
    try {
      final opened = await launchUrl(
        Uri.parse('app-settings:'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mở Cài đặt để cấp quyền micro.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mở Cài đặt để cấp quyền micro.')),
        );
      }
    }
  }

  Future<void> _showRecordingRecoveryDialog({
    required String iconAsset,
    required String title,
    required String message,
    required String primaryLabel,
    required String secondaryLabel,
    required VoidCallback onPrimary,
  }) {
    if (!mounted) return Future<void>.value();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => GardenVoiceScope(
        child: Builder(
          builder: (context) {
            final k = context.k;
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 35, vertical: 24),
              backgroundColor: k.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(iconAsset, width: 56, height: 56),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: k.ink,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: k.inkSoft,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    KButton(
                      label: primaryLabel,
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onPrimary();
                      },
                    ),
                    const SizedBox(height: 8),
                    KButton(
                      label: secondaryLabel,
                      ghost: true,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _stopRecording() async {
    if (phase != 'recording') return;
    timer?.cancel();
    wave.stop();
    wave2.stop();

    setState(() => isBusy = true);
    try {
      final path = await _recorder.stop();
      if (path != null && path.isNotEmpty) {
        final xFile = XFile(path);
        final bytes = await xFile.readAsBytes();

        if (bytes.isEmpty) {
          if (mounted) {
            setState(() {
              seconds = 0;
              phase = 'ready';
              selectedFile = null;
              isBusy = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Bản ghi âm quá ngắn hoặc không có âm thanh. Vui lòng thử lại.'),
                backgroundColor: context.k.warn,
              ),
            );
          }
          return;
        }

        final fileName =
            'rec_${DateTime.now().millisecondsSinceEpoch}.$_currentExtension';
        final platformFile = PlatformFile(
          name: fileName,
          size: bytes.length,
          bytes: bytes,
          path: kIsWeb ? null : path,
        );

        if (widget.enableMultiClipSession) {
          await _uploadClipToSession(platformFile);
          return;
        }

        if (mounted) {
          setState(() {
            selectedFile = platformFile;
            phase = 'done';
            isBusy = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }

    if (mounted) {
      setState(() {
        seconds = 0;
        phase = 'ready';
        selectedFile = null;
        isBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Không thể hoàn tất lưu bản ghi âm. Vui lòng bấm ghi âm lại.'),
          backgroundColor: context.k.bad,
        ),
      );
    }
  }

  String get time =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  Widget _buildContextCard(
    KPalette k, {
    required Child? child,
    required String classLabel,
    required String? allergy,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FCFB),
        border: Border.all(color: k.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF212E2B).withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (child != null)
            Avatar(name: child.name)
          else
            SvgPicture.asset('assets/garden_voice/class_group.svg'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  child == null ? 'Cả lớp $classLabel' : child.name,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: k.ink,
                  ),
                ),
                Text(
                  child == null
                      ? 'Ghi một lần, tạo báo cáo cho tất cả trẻ.'
                      : '$classLabel${child.nickname == null ? '' : ' · ${child.nickname}'}',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: k.inkSoft,
                  ),
                ),
                if (allergy != null && allergy.isNotEmpty)
                  Text('Dị ứng: $allergy',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: k.warn,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiClipScaffold(
    BuildContext context,
    KPalette k, {
    required String subtitle,
    required Child? child,
    required String classLabel,
    required String? allergy,
    required VoiceRecordingSession session,
  }) {
    final clips = session.clips;
    final recording = phase == 'recording';
    final inFlightCount = clips.where((c) => c.isPendingOrProcessing).length;
    final failedCount = clips.where((c) => c.isFailed).length;
    final completedCount = clips.where((c) => c.isCompleted).length;
    final canAnalyze = !recording &&
        !_isUploadingClip &&
        !_isDiscardingSession &&
        session.pendingCount == 0 &&
        completedCount > 0;

    final String analyzeLabel;
    if (inFlightCount > 0) {
      analyzeLabel = 'Đang nhận dạng ($inFlightCount)…';
    } else if (failedCount > 0) {
      analyzeLabel = 'Xoá đoạn lỗi để gửi';
    } else {
      analyzeLabel = 'Gửi phân tích ($completedCount)';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  _GardenVoiceRecordHeader(
                    title: 'Ghi âm',
                    subtitle: '$subtitle · Phiên hôm nay',
                    onBack: () => Navigator.pop(context),
                    showProgress: true,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: k.brandTint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${clips.length} bản ghi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: k.brand,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildContextCard(
                    k,
                    child: child,
                    classLabel: classLabel,
                    allergy: allergy,
                  ),
                  const SizedBox(height: 12),
                  _CompactSessionRecorderDock(
                    recording: recording,
                    isBusy: isBusy || _isUploadingClip,
                    isUploading: _isUploadingClip,
                    seconds: seconds,
                    time: time,
                    wave: wave,
                    wave2: wave2,
                    onToggleMic: toggle,
                    onPickFile: _pickFile,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'DANH SÁCH BẢN GHI TRONG NGÀY',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: k.ink,
                            letterSpacing: .3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tổng ${_formatSessionDuration(clips)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: k.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (failedCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: k.badTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: k.bad.withValues(alpha: .4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 18, color: k.badText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Có $failedCount đoạn nhận dạng lỗi — chạm X để xoá trước khi gửi phân tích.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: k.badText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (var i = 0; i < clips.length; i++)
                    Builder(
                      builder: (_) {
                        final clip = clips[i];
                        final clipId = clip.voiceRecordId;
                        final isPlaying = _playingClipId == clipId;
                        final progress = isPlaying &&
                                _clipDuration.inMilliseconds > 0
                            ? (_clipPosition.inMilliseconds /
                                    _clipDuration.inMilliseconds)
                                .clamp(0.0, 1.0)
                            : 0.0;
                        return SessionClipBar(
                          key: ValueKey('session-clip-$clipId'),
                          index: i,
                          clip: clip,
                          isPlaying: isPlaying,
                          isLoadingAudio: _loadingAudioClipId == clipId,
                          playProgress: progress,
                          isExpanded: _expandedClipIds.contains(clipId),
                          isDeleting: _deletingClipIds.contains(clipId),
                          isSavingTranscript:
                              _savingTranscriptClipIds.contains(clipId),
                          editedTranscript: _editedClipTranscripts[clipId],
                          onTogglePlay: () => _toggleClipPlay(clip),
                          onDelete: () => _deleteClip(clip),
                          onToggleExpand: () => setState(() {
                            if (_expandedClipIds.contains(clipId)) {
                              _expandedClipIds.remove(clipId);
                            } else {
                              _expandedClipIds.add(clipId);
                            }
                          }),
                          onTranscriptChanged: (val) =>
                              _editedClipTranscripts[clipId] = val,
                          onSaveTranscript: (val) =>
                              _saveClipTranscript(clip, val),
                        );
                      },
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: k.surfaceSunken,
                      border: Border.all(color: k.line),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Phiên tự lưu suốt cả ngày. Chạm X để bỏ đoạn nhầm hoặc chạm mũi tên bên dưới X để xem & sửa câu đã nói.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: k.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: BoxDecoration(
                color: k.surface,
                border: Border(top: BorderSide(color: k.line)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    height: 48,
                    child: TextButton(
                      onPressed:
                          _isDiscardingSession ? null : _confirmAndDiscardSession,
                      style: TextButton.styleFrom(
                        foregroundColor: k.inkSoft,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Huỷ phiên'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const ValueKey('btn-analyze-session'),
                        onPressed:
                            canAnalyze ? _submitSessionForAnalysis : null,
                        icon: const Icon(Icons.send_rounded, size: 17),
                        label: Text(analyzeLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: k.brand,
                          foregroundColor: k.surface,
                          disabledBackgroundColor: k.line,
                          disabledForegroundColor: k.inkFaint,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final recording = phase == 'recording';
    final hasFile = phase == 'file_selected' && selectedFile != null;
    final child = widget.child;
    final allergy =
        child?.allergy == null ? null : _recordAllergy(child!.allergy!);
    final classLabel = widget.className.startsWith('Lớp ')
        ? widget.className
        : 'Lớp ${widget.className}';
    final title = child?.name ?? 'Cả lớp';
    final subtitle = child == null ? classLabel : '$title · $classLabel';
    final canSubmit = !isBusy && (hasFile || phase == 'done');

    return GardenVoiceScope(
      child: Builder(
        builder: (context) {
          final k = context.k;
          if (widget.enableMultiClipSession &&
              _session != null &&
              _session!.clips.isNotEmpty) {
            return _buildMultiClipScaffold(
              context,
              k,
              subtitle: subtitle,
              child: child,
              classLabel: classLabel,
              allergy: allergy,
              session: _session!,
            );
          }

          return Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  _GardenVoiceRecordHeader(
                    title: 'Ghi âm',
                    subtitle: subtitle,
                    onBack: () => Navigator.pop(context),
                    showProgress: true,
                  ),
                  const SizedBox(height: 18),
                  _buildContextCard(
                    k,
                    child: child,
                    classLabel: classLabel,
                    allergy: allergy,
                  ),
                  const SizedBox(height: 12),
                  if (_isUploadingClip)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: k.brand),
                          const SizedBox(height: 12),
                          Text(
                            'Đang lưu đoạn ghi âm vào phiên…',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: k.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (hasFile)
                    _SelectedAudioFileCard(
                      file: selectedFile!,
                      formatBytes: _formatBytes,
                    )
                  else
                    _GardenVoiceRecorderPanel(
                      recording: recording,
                      isBusy: isBusy,
                      seconds: seconds,
                      time: time,
                      message: phase == 'ready'
                          ? 'Nhấn để bắt đầu ghi âm'
                          : recording
                              ? 'Đang ghi âm · Nói tự nhiên'
                              : 'Đã ghi âm $time · ${_formatBytes(selectedFile?.size ?? 0)}',
                      wave: wave,
                      wave2: wave2,
                      onToggle: toggle,
                    ),
                  const SizedBox(height: 14),
                  if (!hasFile)
                    Center(
                      child: OutlinedButton(
                        onPressed: recording || isBusy ? null : _pickFile,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: k.brand,
                          minimumSize: const Size(230, 48),
                          side: BorderSide(color: k.line),
                          shape: const StadiumBorder(),
                          backgroundColor: k.surface,
                        ),
                        child: const Text('Tải lên file ghi âm'),
                      ),
                    ),
                  if (hasFile)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _pickFile,
                          child: const Text('Chọn file khác'),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            selectedFile = null;
                            phase = 'ready';
                          }),
                          child: const Text('Hủy chọn'),
                        ),
                      ],
                    ),
                  if (phase == 'done')
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          seconds = 0;
                          phase = 'ready';
                          selectedFile = null;
                        }),
                        child: const Text('Ghi âm lại'),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F9),
                      border: Border.all(color: k.lineStrong),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gợi ý: kể lại hoạt động của bé',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: k.ink,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          'Kể lần lượt: ăn uống, giấc ngủ, hoạt động, sức khỏe và tâm trạng của bé.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: k.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 104,
                        height: 48,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: k.brand,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: canSubmit
                                ? () => widget.onSubmit(selectedFile)
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: k.brand,
                              foregroundColor: k.surface,
                              disabledBackgroundColor:
                                  k.brand.withValues(alpha: .35),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Gửi xử lý'),
                          ),
                        ),
                      ),
                    ],
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

class _GardenVoiceRecorderPanel extends StatelessWidget {
  const _GardenVoiceRecorderPanel({
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

class _CompactSessionRecorderDock extends StatelessWidget {
  const _CompactSessionRecorderDock({
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
                        message: 'Dừng ghi âm',
                        child: FilledButton.icon(
                          onPressed: isBusy ? null : onToggleMic,
                          icon: const Icon(Icons.stop_rounded, size: 16),
                          label: const Text('Lưu đoạn'),
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
                  message: 'Bắt đầu ghi âm',
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
                  label: const Text('Tải file'),
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

class _SelectedAudioFileCard extends StatelessWidget {
  const _SelectedAudioFileCard({required this.file, required this.formatBytes});

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
          Text('Đã sẵn sàng tạo báo cáo',
              style: TextStyle(fontSize: 12, color: k.ok)),
        ],
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
          final serverMessage = e.message.isNotEmpty
              ? e.message
              : 'Nội dung ghi âm không liên quan đến báo cáo học sinh.';
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
                  const Expanded(
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
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: context.k.warn),
                const SizedBox(width: 8),
                const Text('Nội dung không liên quan',
                    style: TextStyle(fontSize: 18)),
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
                      child: _GardenVoiceRecordHeader(
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
                                Text('Thầy cô có thể',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: k.ink)),
                                const SizedBox(height: 4),
                                Text(
                                  'Thử lại sau ít phút, hoặc quay lại để chọn bản ghi khác.',
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
                    child: _GardenVoiceRecordHeader(
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
      decision: ObservationDecision.pending,
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
    this.recordedBytes,
    this.audioPlayerFactory,
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

  /// Bytes của file ghi âm gốc, dùng để phát lại ở màn hình done.
  final Uint8List? recordedBytes;
  final AudioPlayerFactory? audioPlayerFactory;

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
  final Set<String> sentDraftIds = {};

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
      if (mounted) {
        setState(() {
          roster = children;
          items = _buildObservations(children);
        });
      }
      return children;
    }).catchError((Object e, StackTrace st) {
      debugPrint('ReviewScreen childrenFuture error: $e\n$st');
      throw e;
    });
  }

  bool _hasAnyLegacyContent(ExtractionData ext) {
    return (ext.meals?.trim().isNotEmpty ?? false) ||
        (ext.sleeping?.trim().isNotEmpty ?? false) ||
        (ext.activities?.trim().isNotEmpty ?? false) ||
        (ext.mood?.trim().isNotEmpty ?? false) ||
        (ext.health?.trim().isNotEmpty ?? false) ||
        (ext.rawJson?['teacher_note']?.toString().trim().isNotEmpty ?? false) ||
        (ext.rawJson?['notes']?.toString().trim().isNotEmpty ?? false) ||
        (ext.rawJson?['note']?.toString().trim().isNotEmpty ?? false);
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
        final note =
            ext?.rawJson?['teacher_note']?.toString().trim().isNotEmpty == true
                ? ext!.rawJson!['teacher_note']!.toString().trim()
                : (ext?.rawJson?['notes']?.toString().trim().isNotEmpty == true
                    ? ext!.rawJson!['notes']!.toString().trim()
                    : (ext?.rawJson?['note']?.toString().trim().isNotEmpty ==
                            true
                        ? ext!.rawJson!['note']!.toString().trim()
                        : ''));

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
            note: note,
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
      } else if (widget.mode == RecordMode.classroom &&
          !hasChildOverrides &&
          ext != null &&
          ext.classWideExtraction != null &&
          _hasAnyLegacyContent(ext)) {
        // Fallback: BE trả class_wide_extraction là dict hợp lệ (không null)
        // nhưng rỗng content (hasClassWideContent = false). Khi đó thử dùng
        // top-level legacy fields (ext.meals, ext.sleeping, ...). Nếu cũng
        // rỗng hết thì KHÔNG tạo item — để Unmatched items từ segments là
        // đầu mục duy nhất giáo viên cần review.
        // Chỉ thêm fallback "Chung cả lớp" nếu không có bất kỳ override nào theo từng bé

        result.add(
          ObservationItem(
            id: 'classwide',
            name: 'Chung cả lớp',
            matched: true,
            kind: ObservationKind.classwide,
            decision: ObservationDecision.pending,
            eating:
                ext.meals?.trim().isNotEmpty == true ? ext.meals!.trim() : '',
            sleep: ext.sleeping?.trim().isNotEmpty == true
                ? ext.sleeping!.trim()
                : '',
            activities: ext.activities?.trim().isNotEmpty == true
                ? ext.activities!.trim()
                : '',
            mood: ext.mood?.trim().isNotEmpty == true ? ext.mood!.trim() : '',
            health:
                ext.health?.trim().isNotEmpty == true ? ext.health!.trim() : '',
            note: ext.rawJson?['teacher_note']?.toString().trim().isNotEmpty ==
                    true
                ? ext.rawJson!['teacher_note']!.toString().trim()
                : (ext.rawJson?['notes']?.toString().trim().isNotEmpty == true
                    ? ext.rawJson!['notes']!.toString().trim()
                    : (ext.rawJson?['note']?.toString().trim().isNotEmpty ==
                            true
                        ? ext.rawJson!['note']!.toString().trim()
                        : '')),
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
      bool hasExtractionContent(dynamic seg) {
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

          if (!hasExtractionContent(seg)) {
            continue;
          }

          final text =
              seg is Map ? (seg['text']?.toString() ?? '') : seg.toString();
          if (text.trim().isNotEmpty) {
            result.add(_unmatchedItem(
              'unmatched_$i',
              text,
              seg is Map && seg['extraction'] is Map
                  ? (seg['extraction'] as Map<dynamic, dynamic>)
                  : null,
            ));
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
              if (!hasExtractionContent(seg)) {
                continue;
              }
              final text = seg['text']?.toString() ?? '';
              if (text.trim().isNotEmpty) {
                result.add(_unmatchedItem(
                  'unmatched_${uIdx++}',
                  text,
                  seg['extraction'] is Map
                      ? (seg['extraction'] as Map<dynamic, dynamic>)
                      : null,
                ));
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
    String pick(String key, [String fallback = '']) {
      final v = cw[key];
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : fallback;
    }

    final noteVal = pick('notes') != ''
        ? pick('notes')
        : (pick('teacher_note') != ''
            ? pick('teacher_note')
            : (pick('note') != '' ? pick('note') : ''));

    return ObservationItem(
      id: 'classwide',
      name: 'Chung cả lớp',
      matched: true,
      kind: ObservationKind.classwide,
      decision: ObservationDecision.pending,
      eating: pick('meals'),
      sleep: pick('sleeping'),
      activities: pick('activities'),
      mood: pick('mood'),
      health: pick('health'),
      note: noteVal,
    );
  }

  /// Tạo child ObservationItem từ childExtractions[childId/name].
  ObservationItem _childItemFromExtraction(Child child, Map data) {
    String pick(String key) {
      final v = data[key];
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : '';
    }

    return ObservationItem(
      id: child.id,
      name: child.name,
      childId: child.id,
      nickname: child.nickname,
      matched: true,
      kind: ObservationKind.normal,
      decision: ObservationDecision.pending,
      eating: pick('meals'),
      sleep: pick('sleeping'),
      activities: pick('activities'),
      mood: pick('mood'),
      health: pick('health'),
      note: pick('notes').isNotEmpty
          ? pick('notes')
          : (pick('teacher_note').isNotEmpty
              ? pick('teacher_note')
              : pick('note')),
      severity: child.severity,
    );
  }

  /// Tạo unmatched ObservationItem cho 1 segment không gắn được với bé nào.
  ObservationItem _unmatchedItem(String id, String text, [Map? extraction]) {
    String pick(String key) {
      if (extraction == null) return '';
      final v = extraction[key];
      final s = v?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : '';
    }

    return ObservationItem(
      id: id,
      name: 'Chưa rõ bé nào',
      matched: false,
      kind: ObservationKind.unmatched,
      decision: ObservationDecision.pending,
      snippet: text,
      eating: pick('meals'),
      sleep: pick('sleeping'),
      activities: pick('activities'),
      mood: pick('mood'),
      health: pick('health'),
      note: pick('notes').isNotEmpty
          ? pick('notes')
          : (pick('teacher_note').isNotEmpty
              ? pick('teacher_note')
              : pick('note')),
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

      if (kind == 'classwide') {
        for (final childItem in items) {
          if (childItem.kind != ObservationKind.classwide &&
              childItem.decision == ObservationDecision.approved &&
              childItem.id != item.id) {
            _approveItem(childItem);
          }
        }
      }
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
      if (mounted) {
        _showError('Không thể tạo bản nháp báo cáo. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => approvingIds.remove(item.id));
    }
  }

  void _discardItem(ObservationItem item) {
    final draftIds = List<String>.from(
      approvedDraftIds[item.id] ?? <String>[],
    );
    if (draftIds.any(sentDraftIds.contains)) {
      _showError('Báo cáo đã gửi một phần nên không thể loại bỏ mục này.');
      return;
    }
    setState(() {
      item.decision = ObservationDecision.discarded;
      approvedDraftIds.remove(item.id);
    });
    if (draftIds.isNotEmpty) teacherRepository.deleteDraftReports(draftIds);
  }

  void _restoreItem(ObservationItem item) {
    final draftIds = List<String>.from(
      approvedDraftIds[item.id] ?? <String>[],
    );
    setState(() {
      item.decision = ObservationDecision.pending;
      approvedDraftIds.remove(item.id);
    });
    if (draftIds.isNotEmpty) teacherRepository.deleteDraftReports(draftIds);
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
  /// Nếu cả lớp đang được duyệt, bé này sẽ được gán lại nội dung cả lớp thay vì xóa bỏ hoàn toàn khỏi báo cáo.
  Future<void> _unapproveItem(ObservationItem item) async {
    if (approvingIds.contains(item.id)) return;
    final draftIdsToDelete =
        List<String>.from(approvedDraftIds[item.id] ?? <String>[]);
    if (draftIdsToDelete.any(sentDraftIds.contains)) {
      _showError('Báo cáo đã gửi một phần nên không thể bỏ duyệt mục này.');
      return;
    }
    setState(() {
      item.decision = ObservationDecision.pending;
      approvedDraftIds.remove(item.id);
    });

    // Kiểm tra xem mục "Chung cả lớp" có đang được duyệt hay không
    ObservationItem? classwideItem;
    for (final it in items) {
      if (it.kind == ObservationKind.classwide &&
          it.decision == ObservationDecision.approved) {
        classwideItem = it;
        break;
      }
    }

    if (item.kind != ObservationKind.classwide && classwideItem != null) {
      // Bé này có thẻ riêng nhưng vừa bị hủy duyệt, trong khi cả lớp vẫn duyệt:
      // Gán lại nội dung cả lớp cho bé này thay vì xóa báo cáo!
      try {
        String teacherId;
        try {
          final t = await repository.getCurrentTeacher();
          teacherId =
              t.teacherId.isNotEmpty ? t.teacherId : repository.teacherId;
        } catch (_) {
          teacherId =
              AuthRepository.currentUser?.teacherId ?? repository.teacherId;
        }
        final voiceRecordId =
            widget.voiceRecord?.id ?? '00000000-0000-0000-0000-000000000000';
        await teacherRepository.approveItem(
          voiceRecordId: voiceRecordId,
          teacherId: teacherId,
          kind: 'child',
          childId: item.childId,
          extraction: {
            if (classwideItem.eating.isNotEmpty) 'meals': classwideItem.eating,
            if (classwideItem.sleep.isNotEmpty) 'sleeping': classwideItem.sleep,
            if (classwideItem.health.isNotEmpty) 'health': classwideItem.health,
            if (classwideItem.activities.isNotEmpty)
              'activities': classwideItem.activities,
            if (classwideItem.mood.isNotEmpty) 'mood': classwideItem.mood,
            if (classwideItem.note.isNotEmpty)
              'teacher_note': classwideItem.note,
          },
        );
      } catch (e) {
        debugPrint('Lỗi gán lại classwide cho bé khi bỏ duyệt: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Đã bỏ duyệt mục riêng của "${item.name}". Bé sẽ nhận báo cáo chung của cả lớp.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (draftIdsToDelete.isNotEmpty) {
      try {
        await teacherRepository.deleteDraftReports(draftIdsToDelete);
      } catch (e) {
        debugPrint('Lỗi xóa bản nháp khi bỏ duyệt: $e');
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Đã bỏ duyệt mục "${item.name}". Đã xóa khỏi bản nháp.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Bỏ duyệt tất cả các mục đã duyệt. Xóa tất cả draft reports khỏi backend DB.
  Future<void> _unapproveAll() async {
    if (approvedDraftIds.values
        .expand((ids) => ids)
        .any(sentDraftIds.contains)) {
      _showError('Đã có báo cáo được gửi nên không thể bỏ duyệt tất cả.');
      return;
    }
    final allDraftIdsToDelete = <String>[];
    for (final ids in approvedDraftIds.values) {
      allDraftIdsToDelete.addAll(ids);
    }
    setState(() {
      for (final item in items) {
        if (item.decision == ObservationDecision.approved) {
          item.decision = ObservationDecision.pending;
        }
      }
      approvedDraftIds.clear();
    });
    if (allDraftIdsToDelete.isNotEmpty) {
      try {
        await teacherRepository.deleteDraftReports(allDraftIdsToDelete);
      } catch (e) {
        debugPrint('Lỗi xóa tất cả bản nháp khi bỏ duyệt: $e');
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã bỏ duyệt tất cả các mục và xóa khỏi bản nháp.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Gửi batch tất cả draft đã thu được từ các mục ĐÃ ĐƯỢC DUYỆT.
  /// Gọi POST /api/teacher/reports/send-batch với list tất cả draft_report_ids.
  Future<void> _sendBatch() async {
    if (isSendingBatch) return;

    // CHỈ gom draft ids từ các mục có decision == approved
    final allDraftIds = <String>[];
    for (final item in items) {
      if (item.decision == ObservationDecision.approved) {
        final ids = approvedDraftIds[item.id];
        if (ids != null) allDraftIds.addAll(ids);
      }
    }
    // dedupe (giữ thứ tự)
    final allUniqueDraftIds = <String>[];
    final seen = <String>{};
    for (final id in allDraftIds) {
      if (seen.add(id)) allUniqueDraftIds.add(id);
    }

    final pendingCount = items
        .where((i) =>
            i.decision != ObservationDecision.discarded &&
            i.decision != ObservationDecision.approved)
        .length;
    if (pendingCount > 0) {
      _showError(
          'Còn $pendingCount mục chưa duyệt hoặc loại bỏ. Vui lòng xử lý tất cả các mục trước khi gửi.');
      return;
    }

    // Tuyệt đối không tự ý duyệt ngầm - chỉ mục nào được duyệt mới gửi.
    final uniqueDraftIds = allUniqueDraftIds
        .where((id) => !sentDraftIds.contains(id))
        .toList();
    if (uniqueDraftIds.isEmpty) {
      if (allUniqueDraftIds.isNotEmpty &&
          allUniqueDraftIds.every(sentDraftIds.contains)) {
        _finishBatchSend();
      } else {
        _showError(
            'Chưa có mục nào được duyệt. Hãy bấm "Duyệt" ít nhất 1 mục để gửi.');
      }
      return;
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
      final results = res['results'];
      final failedIds = <String>{};
      if (results is List) {
        for (final result in results) {
          if (result is! Map) continue;
          final id = result['daily_report_id']?.toString();
          if (id == null || !uniqueDraftIds.contains(id)) continue;
          if (result['result'] == 'sent' || result['result'] == 'skipped') {
            sentDraftIds.add(id);
          } else if (result['result'] == 'failed') {
            failedIds.add(id);
          }
        }
      }
      if (failed == 0 && sent + skipped == uniqueDraftIds.length) {
        sentDraftIds.addAll(uniqueDraftIds);
      }

      if (failed > 0 && sent == 0) {
        debugPrint(
            'sendBatch returned failed=$failed (${res['results']}), publishing individually...');
        final fallbackIds = failedIds.isEmpty
            ? uniqueDraftIds.where((id) => !sentDraftIds.contains(id))
            : failedIds;
        for (final repId in fallbackIds) {
          try {
            await teacherRepository.publishReport(
                reportId: repId, teacherId: teacherId);
            sentDraftIds.add(repId);
          } catch (e) {
            debugPrint('Individual publish error for $repId: $e');
          }
        }
      }

      final remaining =
          allUniqueDraftIds.where((id) => !sentDraftIds.contains(id)).length;
      if (remaining > 0) {
        _showError(
            'Đã gửi ${sentDraftIds.length} báo cáo; còn $remaining báo cáo chưa gửi. Vui lòng thử lại.');
        return;
      }
      _finishBatchSend();
    } catch (e) {
      // ponytail: timeout có thể che lần commit; cần idempotency/status lookup trước khi retry tự động.
      debugPrint('send-batch error: $e, trying publishReport fallback...');
      for (final repId in uniqueDraftIds.where((id) => !sentDraftIds.contains(id))) {
        try {
          await teacherRepository.publishReport(
              reportId: repId, teacherId: teacherId);
          sentDraftIds.add(repId);
        } catch (_) {}
      }
      final remaining =
          allUniqueDraftIds.where((id) => !sentDraftIds.contains(id)).length;
      if (remaining == 0 && allUniqueDraftIds.isNotEmpty) {
        _finishBatchSend();
        return;
      }
      _showError(
          'Đã gửi ${sentDraftIds.length} báo cáo; còn $remaining báo cáo chưa gửi. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          isSendingBatch = false;
          isSubmitting = false;
        });
      }
    }
  }

  void _finishBatchSend() {
    if (!mounted) return;
    final healthCount = items
        .where((item) =>
            item.health.isNotEmpty &&
            (approvedDraftIds[item.id] ?? const <String>[])
                .any(sentDraftIds.contains))
        .length;
    setState(() {
      savedReportsCount = sentDraftIds.length;
      savedHealthCount = healthCount;
      isDone = true;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _assignChild(ObservationItem item,
      {required VoidCallback onAssignClass}) {
    Navigator.of(context)
        .push<Child>(MaterialPageRoute(
            builder: (_) => _AssignScreen(
                  card: item,
                  roster: roster,
                  className: widget.className,
                  onAssignClass: onAssignClass,
                )))
        .then((selected) {
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
    final classLabel = widget.className.startsWith('Lớp ')
        ? widget.className
        : 'Lớp ${widget.className}';
    if (isDone) {
      final classwideItems =
          items.where((item) => item.kind == ObservationKind.classwide).toList();
      final classwideDraftIds = classwideItems.length == 1
          ? approvedDraftIds[classwideItems.single.id] ?? const <String>[]
          : const <String>[];
      if (classwideItems.length == 1 &&
          classwideItems.single.decision == ObservationDecision.approved &&
          classwideDraftIds.isNotEmpty &&
          classwideDraftIds.every(sentDraftIds.contains)) {
        return _ClasswideDoneScreen(
          classLabel: classLabel,
          onBack: widget.onCompleted,
        );
      }
      return _DoneScreenView(
        parentReportsCount: savedReportsCount,
        healthRecordsCount: savedHealthCount,
        recordingTime: _timeNow(),
        recordedBytes: widget.recordedBytes,
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

    // Unmatched còn lại (chưa được gán/lọc) - phải = 0 mới cho confirm
    final unmatchedActiveCount = items
        .where((i) =>
            i.kind == ObservationKind.unmatched &&
            i.decision != ObservationDecision.discarded)
        .length;
    final hasUnmatchedActive = unmatchedActiveCount > 0;
    final classwideItems = items
        .where((item) => item.kind == ObservationKind.classwide)
        .toList();
    final classwideChildItems = items
        .where((item) =>
            item.kind != ObservationKind.classwide &&
            item.kind != ObservationKind.unmatched)
        .toList();
    final isClasswideReview = classwideItems.length == 1 &&
        classwideChildItems.length == 1 &&
        items.length == 2 &&
        !hasUnmatchedActive &&
        discardedCount == 0 &&
        items.every(
          (item) => item.decision == ObservationDecision.approved,
        );
    final skippedItems = items
        .where((item) =>
            item.kind == ObservationKind.unmatched &&
            item.decision == ObservationDecision.discarded)
        .toList();
    final isSkippedReview = skippedItems.isNotEmpty &&
        !hasUnmatchedActive &&
        skippedItems.length == 1 &&
        items.length == 2 &&
        !items.any((item) => item.kind == ObservationKind.classwide) &&
        classwideChildItems.length == 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed: widget.onBack,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    icon: SvgPicture.asset('assets/garden_voice/edit_back.svg'),
                  ),
                  const SizedBox(width: 0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isClasswideReview
                              ? 'Duyệt báo cáo cả lớp'
                              : isSkippedReview
                                  ? 'Duyệt báo cáo'
                                  : hasUnmatchedActive
                                      ? 'Xem lại bản ghi'
                                      : 'Xem lại báo cáo',
                          style: TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: context.k.ink),
                        ),
                        if (!isClasswideReview && !isSkippedReview)
                          Text(
                            hasUnmatchedActive
                                ? '$classLabel · $unmatchedActiveCount đoạn cần cô xác nhận'
                                : 'Đã tách thông tin theo từng bé',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: context.k.inkSoft),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Child>>(
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
                        child: const Text(
                            'Không tải được danh sách trẻ · Thử lại'),
                      ),
                    );
                  }

                  Widget reviewTile(
                    ObservationItem item, {
                    bool summaryStyle = false,
                    bool showApproveAction = false,
                    String? summaryLabel,
                  }) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ObservationTile(
                          card: item,
                          className: widget.className,
                          showSegmentPreview: false,
                          summaryStyle: summaryStyle,
                          showApproveAction: showApproveAction,
                          summaryLabel: summaryLabel,
                          isApproving: approvingIds.contains(item.id),
                          onToggleApprove: () {
                            if (item.decision == ObservationDecision.approved) {
                              _unapproveItem(item);
                            } else {
                              _approveItem(item);
                            }
                          },
                          onUnapprove: () => _unapproveItem(item),
                          onDiscard: () => _discardItem(item),
                          onRestore: () => _restoreItem(item),
                          onAssign: () => _assignChild(
                            item,
                            onAssignClass: () {},
                          ),
                          onEdit: () => _editObservation(item),
                        ),
                      );

                  if (isClasswideReview) {
                    final childItem = classwideChildItems.single;
                    final classwideItem = classwideItems.single;
                    final actionLabel = pendingCount > 0
                        ? 'Duyệt tất cả'
                        : approvedCount > 0
                            ? 'Xác nhận gửi cho cả lớp'
                            : 'Chưa duyệt mục nào để gửi';
                    final VoidCallback? action = isSubmitting
                        ? null
                        : pendingCount > 0
                            ? _approveAll
                            : approvedCount > 0
                                ? _sendBatch
                                : null;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '$classLabel · Đã xử lý tất cả đoạn ghi',
                            style: TextStyle(
                              color: context.k.inkSoft,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          reviewTile(
                            childItem,
                            summaryStyle: true,
                            summaryLabel: 'Riêng ${childItem.name}',
                          ),
                          reviewTile(
                            classwideItem,
                            summaryStyle: true,
                            summaryLabel: 'Áp dụng cho cả lớp',
                          ),
                          SizedBox(
                            height: 48,
                            child: KButton(
                              label: actionLabel,
                              onPressed: action,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (isSkippedReview) {
                    final skipped = skippedItems.single;
                    final skippedDetail = skipped.snippet.trim();
                    final skippedMessage = skippedDetail.isEmpty
                        ? 'Đoạn chưa rõ đã được bỏ qua.'
                        : 'Đoạn chưa rõ “$skippedDetail” đã được bỏ qua.';
                    final activeItems = items
                        .where((item) => item.id != skipped.id)
                        .toList();
                    final canSend = !isSubmitting &&
                        approvedCount > 0 &&
                        pendingCount == 0 &&
                        unmatchedActiveCount == 0;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            skippedMessage,
                            style: TextStyle(
                              color: context.k.inkSoft,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          for (final item in activeItems)
                            reviewTile(
                              item,
                              summaryStyle: true,
                              showApproveAction: true,
                              summaryLabel: item.name,
                            ),
                          SizedBox(
                            height: 48,
                            child: KButton(
                              label: 'Gửi báo cáo cho phụ huynh',
                              onPressed: canSend ? _sendBatch : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 48,
                            child: KButton(
                              label: 'Xử lý lại đoạn ghi',
                              secondary: true,
                              onPressed: () => _restoreItem(skipped),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  Widget contentWidth(Widget child) => Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350),
                          child: child,
                        ),
                      );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hasUnmatchedActive) ...[
                          contentWidth(
                            Row(
                              children: List.generate(
                                3,
                                (index) => Expanded(
                                  child: Container(
                                    height: 4,
                                    margin: EdgeInsets.only(
                                        right: index == 2 ? 0 : 6),
                                    decoration: BoxDecoration(
                                      color: context.k.brand,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Bước 3/3 · Xem lại',
                                style: TextStyle(
                                    fontSize: 12, color: context.k.inkSoft)),
                          ),
                          const SizedBox(height: 0),
                        ] else
                          const SizedBox(height: 14),
                        if (items.length > 1 && !hasUnmatchedActive) ...[
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Từ 1 lần nói · ${items.length} ghi nhận',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                    color: context.k.ink),
                              ),
                              if (pendingCount > 0) ...[
                                TextButton.icon(
                                  onPressed: _approveAll,
                                  icon: Icon(Icons.done_all_rounded,
                                      size: 14, color: context.k.brand),
                                  label: Text(
                                    'Duyệt tất cả',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.k.brand,
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
                                  icon: Icon(Icons.undo_rounded,
                                      size: 14, color: context.k.warn),
                                  label: Text(
                                    'Bỏ duyệt tất cả',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.k.warn,
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
                          Text(
                            'Đọc lại theo đúng thứ tự cô đã kể.',
                            style: TextStyle(
                                fontSize: 12, color: context.k.inkSoft),
                          ),
                          const SizedBox(height: 16),
                        ] else
                          const SizedBox(height: 17),
                        if (!hasUnmatchedActive) ...[
                          if (widget.recordedBytes != null &&
                              widget.recordedBytes!.isNotEmpty)
                            contentWidth(
                              _AudioPlayerCard(
                                recordedBytes: widget.recordedBytes!,
                                audioPlayerFactory: widget.audioPlayerFactory,
                              ),
                            ),
                          if (effectiveTranscript.isNotEmpty)
                            contentWidth(
                              _AnalyzedTextCard(
                                text: effectiveTranscript,
                                matchedChildCount: items
                                    .where((item) =>
                                        item.childId != null &&
                                        item.matched &&
                                        item.kind == ObservationKind.normal)
                                    .length,
                                onEdit: _editAndReanalyzeTranscript,
                              ),
                            ),
                        ],
                        for (var i = 0; i < items.length; i++)
                          _AnimatedObservationWrapper(
                            key: ValueKey(items[i].id),
                            decision: items[i].decision,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ObservationTile(
                                card: items[i],
                                className: widget.className,
                                showSegmentPreview: hasUnmatchedActive,
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
                                onDiscard: () => _discardItem(items[i]),
                                onRestore: () => _restoreItem(items[i]),
                                onAssign: () =>
                                    _assignChild(items[i], onAssignClass: () {
                                  final draftIds = List<String>.from(
                                      approvedDraftIds[items[i].id] ??
                                          <String>[]);
                                  setState(() {
                                    items[i].kind = ObservationKind.classwide;
                                    items[i].name = 'Chung cả lớp';
                                    items[i].matched = true;
                                    items[i].decision =
                                        ObservationDecision.pending;
                                    approvedDraftIds.remove(items[i].id);
                                  });
                                  if (draftIds.isNotEmpty) {
                                    teacherRepository
                                        .deleteDraftReports(draftIds);
                                  }
                                }),
                                onEdit: () => _editObservation(items[i]),
                              ),
                            ),
                          ),
                        if (!hasUnmatchedActive) ...[
                          const SizedBox(height: 0),
                          if (pendingCount > 0 || approvedCount == 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                approvedCount == 0
                                    ? 'Chưa có mục nào được duyệt. Duyệt hoặc loại bỏ từng mục để tiếp tục.'
                                    : 'Còn $pendingCount mục chưa xử lý. Vui lòng duyệt hoặc loại bỏ tất cả các mục để có thể gửi.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: approvedCount == 0
                                      ? context.k.brand
                                      : context.k.warn,
                                ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          contentWidth(
                            FilledButton(
                              onPressed: !isSubmitting &&
                                      approvedCount > 0 &&
                                      pendingCount == 0 &&
                                      unmatchedActiveCount == 0
                                  ? _sendBatch
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: context.k.brand,
                                foregroundColor: context.k.surface,
                                disabledBackgroundColor:
                                    context.k.surfaceSunken,
                                disabledForegroundColor: context.k.inkSoft,
                                minimumSize: const Size(double.infinity, 48),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(isSubmitting
                                  ? 'Đang gửi báo cáo…'
                                  : approvedCount > 0 &&
                                          pendingCount == 0 &&
                                          unmatchedActiveCount == 0
                                      ? 'Hoàn thành'
                                      : approvedCount == 0
                                          ? 'Chưa duyệt mục nào để gửi'
                                          : pendingCount > 0
                                              ? 'Còn $pendingCount mục chưa duyệt hoặc loại bỏ'
                                              : 'Hoàn thành'),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sleepDurationMinutes(String value) {
    final duration = RegExp(r'(\d+)\s*phút', caseSensitive: false)
        .firstMatch(value)
        ?.group(1);
    if (duration != null) return duration;
    final numeric = int.tryParse(value.trim());
    if (numeric != null) return '$numeric';
    final times = RegExp(
      r'(\d{1,2}):(\d{2})\s*(?:đến|[-–])\s*(\d{1,2}):(\d{2})',
      caseSensitive: false,
    ).firstMatch(value);
    if (times == null) return '';
    final startHour = int.parse(times.group(1)!);
    final startMinute = int.parse(times.group(2)!);
    final endHour = int.parse(times.group(3)!);
    final endMinute = int.parse(times.group(4)!);
    if (startHour > 23 || endHour > 23 || startMinute > 59 || endMinute > 59) {
      return '';
    }
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    final minutes = (end - start + 1440) % 1440;
    return minutes == 0 ? '' : '$minutes';
  }

  String _sleepNarrative(String value) => value
      .replaceAll(
          RegExp(r'\s*(?:[·,]\s*)?\d+\s*phút', caseSensitive: false), '')
      .trim();

  String _editedSleep(String narrative, String duration) {
    final description = _sleepNarrative(narrative);
    final minutes = duration.trim().isNotEmpty
        ? duration.trim()
        : _sleepDurationMinutes(narrative);
    return [description, if (minutes.isNotEmpty) '$minutes phút']
        .where((value) => value.isNotEmpty)
        .join(' · ');
  }

  Future<void> _editObservation(ObservationItem item) async {
    if ((approvedDraftIds[item.id] ?? const <String>[])
        .any(sentDraftIds.contains)) {
      _showError('Báo cáo đã gửi một phần nên không thể sửa mục này.');
      return;
    }
    final eatingCtrl = TextEditingController(text: item.eating);
    final sleepCtrl =
        TextEditingController(text: _sleepDurationMinutes(item.sleep));
    final sleepDescriptionCtrl =
        TextEditingController(text: _sleepNarrative(item.sleep));
    final activitiesCtrl = TextEditingController(text: item.activities);
    final moodCtrl = TextEditingController(text: item.mood);
    final healthCtrl = TextEditingController(text: item.health);
    final noteCtrl = TextEditingController(text: item.note);
    final snippetCtrl = TextEditingController(text: item.snippet);

    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => GardenVoiceScope(
        child: EditObservationScreen(
          title: item.name,
          isUnmatched: item.kind == ObservationKind.unmatched,
          eatingCtrl: eatingCtrl,
          sleepCtrl: sleepCtrl,
          sleepDescriptionCtrl: sleepDescriptionCtrl,
          activitiesCtrl: activitiesCtrl,
          moodCtrl: moodCtrl,
          healthCtrl: healthCtrl,
          noteCtrl: noteCtrl,
          snippetCtrl: snippetCtrl,
        ),
      ),
    ));

    if (saved == true && mounted) {
      setState(() {
        item.eating = eatingCtrl.text.trim();
        item.sleep = _editedSleep(sleepDescriptionCtrl.text, sleepCtrl.text);
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
    eatingCtrl.dispose();
    sleepCtrl.dispose();
    sleepDescriptionCtrl.dispose();
    activitiesCtrl.dispose();
    moodCtrl.dispose();
    healthCtrl.dispose();
    noteCtrl.dispose();
    snippetCtrl.dispose();
  }

  Future<void> _editAndReanalyzeTranscript() async {
    final textCtrl = TextEditingController(text: effectiveTranscript);
    final shouldReanalyze = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: context.k.brand),
            const SizedBox(width: 8),
            const Text('Chỉnh sửa văn bản ghi âm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn có thể chỉnh sửa lại nội dung văn bản dưới đây rồi bấm "Phân tích lại" để AI trích xuất lại thông tin:',
                style: TextStyle(fontSize: 12, color: context.k.inkSoft),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 6,
                minLines: 3,
                style: const TextStyle(fontSize: 13, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung văn bản...',
                  filled: true,
                  fillColor: context.k.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.k.line),
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

        final oldDraftIds = <String>[];
        for (final ids in approvedDraftIds.values) {
          oldDraftIds.addAll(ids);
        }
        if (oldDraftIds.isNotEmpty) {
          try {
            await teacherRepository.deleteDraftReports(oldDraftIds);
          } catch (e) {
            debugPrint('Lỗi xóa bản nháp cũ khi phân tích lại: $e');
          }
        }

        if (!mounted) return;

        setState(() {
          editedTranscript = newText;
          currentExtraction = newExtraction;
          approvedDraftIds.clear();
          items = _buildObservations(roster, newExtraction);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã phân tích lại thành công!'),
            backgroundColor: context.k.brand,
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

// ===========================================================================
// Audio Player Card & Analyzed Text Card (delegated to extracted widgets)
// ===========================================================================

typedef _AudioPlayerCard = AudioPlayerCard;
typedef _AnalyzedTextCard = AnalyzedTextCard;

typedef SegmentationScreen = ReviewScreen;

class _ClasswideDoneScreen extends StatelessWidget {
  const _ClasswideDoneScreen({
    required this.classLabel,
    required this.onBack,
  });

  final String classLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => GardenVoiceScope(
        child: Builder(
          builder: (context) {
            final k = context.k;
            final name = classLabel.startsWith('Lớp ')
                ? classLabel.substring(4)
                : classLabel;
            return Scaffold(
              backgroundColor: k.canvas,
              appBar: KAppBar(
                title: 'Đã gửi báo cáo',
                onBack: onBack,
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Báo cáo ngày đã được gửi đến phụ huynh của từng bé trong lớp $name.',
                        style: TextStyle(
                          color: k.inkSoft,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      KButton(
                        label: 'Về tổng quan lớp',
                        onPressed: onBack,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _ObservationTile extends StatelessWidget {
  const _ObservationTile({
    required this.card,
    required this.className,
    required this.showSegmentPreview,
    required this.onToggleApprove,
    required this.onUnapprove,
    required this.onDiscard,
    required this.onRestore,
    required this.onAssign,
    this.onEdit,
    this.isApproving = false,
    this.summaryStyle = false,
    this.showApproveAction = false,
    this.summaryLabel,
  });

  final ObservationItem card;
  final String className;
  final bool showSegmentPreview;
  final VoidCallback onToggleApprove;
  final VoidCallback onUnapprove;
  final VoidCallback onDiscard;
  final VoidCallback onRestore;
  final VoidCallback onAssign;
  final VoidCallback? onEdit;
  final bool isApproving;
  final bool summaryStyle;
  final bool showApproveAction;
  final String? summaryLabel;

  @override
  Widget build(BuildContext context) {
    if (summaryStyle) {
      final k = context.k;
      final summary = [
        card.eating,
        card.sleep,
        card.activities,
        card.mood,
        card.health,
        card.note,
      ].where((value) => value.trim().isNotEmpty).join('. ');
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: k.surfaceSunken,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summaryLabel ??
                  (card.kind == ObservationKind.classwide
                      ? 'Áp dụng cho cả lớp'
                      : card.name),
              style: TextStyle(
                color: k.brandStrong,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              summary.isEmpty
                  ? 'Không có thông tin chi tiết được ghi nhận'
                  : summary,
              style: TextStyle(
                color: k.ink,
                fontSize: 17,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showApproveAction &&
                card.decision != ObservationDecision.approved)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isApproving ? null : onToggleApprove,
                  child: const Text('Duyệt'),
                ),
              ),
          ],
        ),
      );
    }

    if (card.decision == ObservationDecision.discarded) {
      return _SurfaceBox(
        color: context.k.canvas,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Đã loại bỏ · ${card.name}',
                style: TextStyle(fontSize: 12, color: context.k.inkFaint),
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
    final isSegmentPreview = showSegmentPreview && !isUnmatched;
    final segmentSummary = [
      card.eating,
      card.sleep,
      card.activities,
      card.mood,
      card.health,
      card.note,
    ].where((value) => value.trim().isNotEmpty).join('. ');
    final nameParts = card.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final avatarText = nameParts.length > 1
        ? '${nameParts[nameParts.length - 2][0]}${nameParts.last[0]}'
        : (nameParts.firstOrNull ?? '?')[0].toUpperCase();

    return _SurfaceBox(
      color: isUnmatched
          ? context.k.surface
          : isSegmentPreview
              ? context.k.surfaceSunken
              : context.k.reviewSurface,
      borderColor: isUnmatched
          ? context.k.bad.withValues(alpha: .52)
          : isSegmentPreview
              ? Colors.transparent
              : context.k.lineStrong,
      padding: isUnmatched
          ? const EdgeInsets.all(15)
          : const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUnmatched)
            Text('Chưa xác định bé',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.k.brandStrong))
          else if (isSegmentPreview)
            Text('Đã nhận ra · ${card.name}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.k.brandStrong))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: context.k.accentTint,
                  child: Text(avatarText.toUpperCase(),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.k.accentDeep)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name,
                          style: TextStyle(
                              fontSize: 14,
                              color: context.k.ink,
                              fontWeight: FontWeight.w700)),
                      Text(
                          className.startsWith('Lớp ')
                              ? className
                              : 'Lớp $className',
                          style: TextStyle(
                              fontSize: 11, color: context.k.inkFaint)),
                    ],
                  ),
                ),
                if (card.decision == ObservationDecision.approved)
                  Container(
                    key: const ValueKey('review-approved-pill'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.k.okTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Container(
                          key: const ValueKey('review-approved-dot'),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: context.k.okDot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text('Đã duyệt',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: context.k.ok)),
                      ],
                    ),
                  ),
              ],
            ),
          if (isUnmatched) ...[
            const SizedBox(height: 4),
            Text(
              '“${card.snippet.isNotEmpty ? card.snippet : 'Chưa nhận diện chính xác được bé trong lớp.'}”',
              style: TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: context.k.ink),
            ),
          ] else if (isSegmentPreview) ...[
            const SizedBox(height: 4),
            Text(segmentSummary,
                style: TextStyle(
                    fontSize: 17,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: context.k.ink)),
          ] else ...[
            const SizedBox(height: 10),
            if (card.eating.isNotEmpty)
              _buildReportLine(context, 'Ăn uống', card.eating),
            if (card.sleep.isNotEmpty)
              _buildReportLine(context, 'Giấc ngủ', card.sleep),
            if (card.activities.isNotEmpty)
              _buildReportLine(context, 'Hoạt động', card.activities),
            if (card.mood.isNotEmpty)
              _buildReportLine(context, 'Tâm trạng', card.mood),
            if (card.health.isNotEmpty)
              _buildReportLine(context, 'Sức khỏe', card.health),
            if (card.note.trim().isNotEmpty)
              _buildReportLine(context, 'Ghi chú', card.note.trim()),
            if (card.eating.isEmpty &&
                card.sleep.isEmpty &&
                card.activities.isEmpty &&
                card.mood.isEmpty &&
                card.health.isEmpty &&
                card.note.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Không có thông tin chi tiết được ghi nhận',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: context.k.inkFaint),
                ),
              ),
          ],
          if (!isSegmentPreview &&
              card.decision != ObservationDecision.approved)
            isUnmatched
                ? const SizedBox(height: 14)
                : const Divider(height: 20),
          if (isUnmatched) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAssign,
                style: FilledButton.styleFrom(
                  backgroundColor: context.k.brand,
                  foregroundColor: context.k.surface,
                  minimumSize: const Size(double.infinity, 48),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Gán đoạn này'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDiscard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.k.brand,
                  side: BorderSide(color: context.k.line),
                  minimumSize: const Size(double.infinity, 48),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Bỏ qua đoạn này'),
              ),
            ),
          ] else if (!isSegmentPreview &&
              card.decision == ObservationDecision.approved)
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 22,
              runSpacing: 0,
              children: [
                if (onEdit != null)
                  TextButton(
                    onPressed: isApproving ? null : onEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: context.k.brand,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Chỉnh sửa',
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w700)),
                  ),
                TextButton(
                  onPressed: isApproving ? null : onDiscard,
                  style: TextButton.styleFrom(
                    foregroundColor: context.k.badText,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Loại bỏ',
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: isApproving ? null : onUnapprove,
                  style: TextButton.styleFrom(
                    foregroundColor: context.k.warn,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Bỏ duyệt',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            )
          else if (!isSegmentPreview)
            Wrap(
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 0,
              children: [
                if (onEdit != null) ...[
                  TextButton(
                    onPressed: isApproving ? null : onEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: context.k.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text('Chỉnh sửa'),
                  ),
                ],
                TextButton(
                  onPressed: isApproving ? null : onDiscard,
                  style: TextButton.styleFrom(
                    foregroundColor: context.k.badText,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('Loại bỏ'),
                ),
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
                    icon: Icon(Icons.undo_rounded,
                        size: 15, color: context.k.warn),
                    label: Text(
                      'Bỏ duyệt',
                      style: TextStyle(
                          color: context.k.warn, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.k.warn, width: 1.2),
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
                        color: context.k.okTint,
                        borderRadius: BorderRadius.circular(KRadii.control),
                        border: Border.all(
                            color: context.k.ok.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 15, color: context.k.ok),
                          const SizedBox(width: 5),
                          Text(
                            'Đã duyệt',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.k.ok),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  TextButton(
                    onPressed: onToggleApprove,
                    style: TextButton.styleFrom(
                      foregroundColor: context.k.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text('Duyệt'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReportLine(BuildContext context, String label, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    final (background, foreground, asset) = switch (label) {
      'Ăn uống' => (
          context.k.foodRowTint,
          context.k.foodRowText,
          'food',
        ),
      'Giấc ngủ' => (
          context.k.sleepRowTint,
          context.k.sleepRowText,
          'sleep',
        ),
      'Hoạt động' => (
          context.k.activityRowTint,
          context.k.activityRowText,
          'activity',
        ),
      _ => (context.k.brandTint, context.k.brand, ''),
    };
    final icon = switch (asset) {
      'food' => Stack(
          children: [
            Positioned(
              left: 15,
              top: 4,
              child: SvgPicture.asset('assets/garden_voice/review_spoon.svg'),
            ),
            Positioned(
              left: 4,
              top: 12,
              child: SvgPicture.asset('assets/garden_voice/review_bowl.svg'),
            ),
          ],
        ),
      'sleep' => Padding(
          padding: const EdgeInsets.all(4),
          child: SvgPicture.asset('assets/garden_voice/review_moon.svg'),
        ),
      'activity' => Padding(
          padding: const EdgeInsets.all(4),
          child:
              SvgPicture.asset('assets/garden_voice/review_artist_palette.svg'),
        ),
      _ => Icon(Icons.favorite_outline, size: 18, color: foreground),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            SizedBox(width: 26, height: 26, child: icon),
            const SizedBox(width: 6),
            SizedBox(
              width: 65,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: foreground)),
            ),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.k.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _SurfaceBox = SurfaceBox;

class _AssignScreen extends StatefulWidget {
  const _AssignScreen({
    required this.card,
    required this.roster,
    required this.className,
    required this.onAssignClass,
  });

  final ObservationItem card;
  final List<Child> roster;
  final String className;
  final VoidCallback onAssignClass;

  @override
  State<_AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends State<_AssignScreen> {
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    icon: SvgPicture.asset('assets/notifications/back_44.svg'),
                  ),
                  const SizedBox(width: 4),
                  const Text('Gán đoạn ghi',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF24313D))),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    '“${widget.card.snippet}”',
                    style: const TextStyle(
                        fontSize: 14, height: 1.4, color: Color(0xFF65727D)),
                  ),
                  if (widget.roster.length > 4) ...[
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (value) => setState(() => query = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Tìm tên bé hoặc biệt danh',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  for (final child in list) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, child),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF087F70),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(child.name),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton(
                    onPressed: () {
                      widget.onAssignClass();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF087F70),
                      side: const BorderSide(color: Color(0xFFE5E8EB)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                        'Cả lớp ${widget.className.replaceFirst(RegExp(r'^Lớp\s+'), '')}'),
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

typedef _DoneScreenView = DoneScreenView;

// ===========================================================================
// Counter pill "X / Y đã duyệt" ở header
// ===========================================================================

typedef _CounterPill = CounterPill;
typedef _AnimatedObservationWrapper = AnimatedObservationWrapper;
