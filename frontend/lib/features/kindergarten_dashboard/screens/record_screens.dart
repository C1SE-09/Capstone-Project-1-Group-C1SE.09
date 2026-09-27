import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart' as legacy_dashboard;
import 'package:adark_frontend/domain/entities/child/child.dart' as legacy_child;
import 'package:adark_frontend/domain/entities/class/class_info.dart' as legacy_class;
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/child_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/severity_adapter.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/report_editor.dart';

enum RecordMode { classroom, child }

class RecordHubScreen extends StatefulWidget {
  const RecordHubScreen({super.key, required this.onClass, required this.onChild, this.classId = 'aaaaaaaa-0000-0000-0000-000000000001', this.repository, this.classRepository});
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
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late final HttpClassDataRepository classRepository = widget.classRepository ?? HttpClassDataRepository();
  late Future<_RecordHubData> future;
  @override
  void initState() { super.initState(); future = _load(); }
  // Loads class roster, dashboard statuses, and class display information.
  Future<_RecordHubData> _load() async {
    final values = await Future.wait([repository.getClassChildren(widget.classId), repository.getClassDashboard(widget.classId, DateTime.now()), classRepository.getClassInfo(widget.classId)]);
    final rawChildren = values[0] as List<legacy_child.Child>;
    final dashboard = values[1] as legacy_dashboard.ClassDashboardSummary;
    final classInfo = values[2] as legacy_class.ClassInfo;
    final statuses = {for (final item in dashboard.pendingChildren) item.child.childId: item};
    final converted = rawChildren.map((child) {
      final item = statuses[child.childId];
      final severity = severityFromDescription(null);
      return item == null ? uiChildFromLegacy(legacy: child, reportStatus: ReportStatus.none, severity: severity) : uiChildFromLegacyWithReport(legacy: child, legacyStatus: item.status, severity: severity, updatedAt: item.updatedAt);
    }).toList();
    return _RecordHubData(converted, classInfo.name, dashboard.totalChildren, dashboard.notCompletedCount);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_RecordHubData>(future: future, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (snapshot.hasError || snapshot.data == null) return Scaffold(body: Center(child: TextButton(onPressed: () => setState(() => future = _load()), child: const Text('Không tải được lớp · Thử lại'))));
    final data = snapshot.data;
    if (data == null) return const Scaffold(body: Center(child: Text('Không có dữ liệu lớp.')));
    final list = data.children.where((child) => child.name.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(
      appBar: KAppBar(title: 'Ghi nhận hoạt động', subtitle: 'Chọn trẻ để bắt đầu ghi nhận', onBack: () => Navigator.pop(context)),
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
                    decoration: BoxDecoration(color: KColors.brand, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.groups_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cả lớp ${data.className}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('Ghi một lần, tạo báo cáo cho tất cả trẻ.', style: TextStyle(fontSize: 12.5, color: KColors.inkSoft)),
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
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('hoặc chọn từng trẻ', style: TextStyle(fontSize: 12, color: KColors.inkFaint))),
                  Expanded(child: Divider()),
                ],
              ),
            ),
            SearchField(hint: 'Tìm trẻ…', onChanged: (value) => setState(() => query = value)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text('Lớp ${data.className} · ${data.totalChildren} trẻ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: KColors.inkSoft))),
                  Text('${data.pendingCount} chưa xong', style: const TextStyle(fontSize: 12, color: KColors.inkFaint)),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(child.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  if (child.allergy != null) Text('Dị ứng: ${child.allergy}', style: const TextStyle(fontSize: 12, color: KColors.warn)),
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
  const _RecordHubData(this.children, this.className, this.totalChildren, this.pendingCount);
  final List<Child> children; final String className; final int totalChildren; final int pendingCount;
}

class RecordFlowScreen extends StatefulWidget {
  const RecordFlowScreen({super.key, required this.mode, this.child, this.classId = 'aaaaaaaa-0000-0000-0000-000000000001', this.className = 'Mầm 1'});
  final RecordMode mode;
  final Child? child;
  final String classId;
  final String className;


  @override
  State<RecordFlowScreen> createState() => _RecordFlowScreenState();
}

class _RecordFlowScreenState extends State<RecordFlowScreen> {
  String step = 'record';

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      'processing' => ProcessingScreen(
          mode: widget.mode,
          onBack: () => setState(() => step = 'record'),
          onDone: () {
            if (widget.mode == RecordMode.classroom) {
              setState(() => step = 'segment');
            } else {
              final child = widget.child;
              if (child == null) return;
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => ReportEditorScreen(
                  child: child,
                  classId: widget.classId,
                  onSent: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu bản nháp báo cáo')));
                  },
                ),
              ));
            }
          },
        ),
      'segment' => SegmentationScreen(
          classId: widget.classId,
          onBack: () => setState(() => step = 'processing'),
          onCreated: (count) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã tạo $count báo cáo nháp')));
          },
        ),
      _ => RecordingScreen(mode: widget.mode, child: widget.child, className: widget.className, onSubmit: () => setState(() => step = 'processing')),
    };
  }
}

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key, required this.mode, required this.onSubmit, this.child, this.className = 'Mầm 1'});
  final RecordMode mode;
  final Child? child;
  final VoidCallback onSubmit;
  final String className;


  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> with SingleTickerProviderStateMixin {
  int seconds = 0;
  String phase = 'ready';
  Timer? timer;
  late final AnimationController wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void dispose() {
    timer?.cancel();
    wave.dispose();
    super.dispose();
  }

  void toggle() {
    if (phase == 'done') return;
    if (phase == 'recording') {
      timer?.cancel();
      wave.stop();
      setState(() => phase = 'done');
      return;
    }
    wave.repeat(reverse: true);
    setState(() => phase = 'recording');
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds >= 179) {
        timer?.cancel();
        wave.stop();
        setState(() {
          seconds = 180;
          phase = 'done';
        });
      } else {
        setState(() => seconds++);
      }
    });
  }

  String get time => '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final classroom = widget.mode == RecordMode.classroom;
    final recording = phase == 'recording';
    return Scaffold(
      appBar: KAppBar(title: classroom ? 'Ghi âm cả lớp' : 'Ghi âm', onBack: () => Navigator.pop(context)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          children: [
            KCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  classroom
                      ? Container(width: 44, height: 44, decoration: const BoxDecoration(color: KColors.brandTint, shape: BoxShape.circle), child: const Icon(Icons.groups_outlined, color: KColors.brand))
                      : Avatar(name: widget.child?.name ?? 'Trẻ', size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(classroom ? 'Cả lớp ${widget.className}' : (widget.child?.name ?? 'Trẻ'), style: Theme.of(context).textTheme.titleMedium),
                        Text(classroom ? 'Cả lớp' : 'Lớp ${widget.className}${widget.child?.nickname == null ? '' : ' · ${widget.child!.nickname}'}', style: Theme.of(context).textTheme.bodySmall),
                        if (!classroom && widget.child?.allergy != null)
                          Text('Dị ứng: ${widget.child?.allergy}', style: const TextStyle(fontSize: 11, color: KColors.warn)),

                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: wave,
                    builder: (_, __) => SizedBox(
                      height: 56,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          24,
                          (index) => Container(
                            width: 3,
                            height: recording ? 6 + 34 * ((math.sin(index * .9 + wave.value * math.pi * 2) + 1) / 2) : 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(color: KColors.brand.withValues(alpha: recording ? .85 : .3), borderRadius: BorderRadius.circular(99)),
                          ),
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
                              color: seconds >= 150 ? KColors.warn : KColors.brand,
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
                              child: Icon(recording ? Icons.stop_rounded : Icons.mic_none_rounded, size: 36, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(time, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: seconds >= 150 ? KColors.warn : KColors.ink)),
                  Text(
                    phase == 'ready' ? 'Nhấn để bắt đầu ghi âm' : recording ? 'Đang ghi âm · Nói tự nhiên' : 'Đã ghi âm $time',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (phase == 'done') ...[
              KButton(label: 'Gửi xử lý', icon: Icons.send_outlined, large: true, onPressed: widget.onSubmit),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: KButton(label: 'Ghi âm lại', icon: Icons.refresh, secondary: true, onPressed: () => setState(() {
                        seconds = 0;
                        phase = 'ready';
                      }))),
                  const SizedBox(width: 10),
                  Expanded(child: KButton(label: 'Hủy', ghost: true, onPressed: () => Navigator.pop(context))),
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
  const ProcessingScreen({super.key, required this.mode, required this.onBack, required this.onDone});
  final RecordMode mode;
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  int active = 1;
  Timer? timer;

  List<String> get steps => [
        'Đã nhận bản ghi âm',
        'Đang chuyển giọng nói thành văn bản',
        'Đang phân tích nội dung',
        widget.mode == RecordMode.classroom ? 'Đang tách phần của từng bé' : 'Đang tạo báo cáo',
      ];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (active >= steps.length - 1) {
        timer?.cancel();
        Future<void>.delayed(const Duration(milliseconds: 700), widget.onDone);
      } else {
        setState(() => active++);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KAppBar(title: 'Đang xử lý', onBack: widget.onBack),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(steps[active], style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
            Text('Quá trình mất khoảng 30 giây.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            StepIndicator(steps: steps, active: active),
            const Spacer(),
            KCard(
              color: KColors.infoTint,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: KColors.info),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Vui lòng giữ màn hình này cho đến khi hoàn tất.', style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SegmentationScreen extends StatefulWidget {
  const SegmentationScreen({super.key, required this.onBack, required this.onCreated, this.classId = 'aaaaaaaa-0000-0000-0000-000000000001', this.repository});
  final VoidCallback onBack;
  final ValueChanged<int> onCreated;
  final String classId;
  final HttpDashboardRepository? repository;

  @override
  State<SegmentationScreen> createState() => _SegmentationScreenState();
}

class _SegmentationScreenState extends State<SegmentationScreen> {
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late Future<List<Child>> childrenFuture;
  List<Segment> items = [];
  List<Child> roster = [];
  final Set<String> approved = {};
  @override
  void initState() { super.initState(); childrenFuture = _loadChildren().then((children) { items = children.map((child) => Segment(id: child.id, childId: child.id, name: child.name, matched: true, eating: '', sleep: '', health: '', severity: child.severity, mood: '')).toList(); roster = children; return children; }); }
  // Derives segmentation rows from the class roster and dashboard report states.
  Future<List<Child>> _loadChildren() async {
    final results = await Future.wait([repository.getClassChildren(widget.classId), repository.getClassDashboard(widget.classId, DateTime.now())]);
    final roster = results[0] as List<legacy_child.Child>;
    final dashboard = results[1] as legacy_dashboard.ClassDashboardSummary;
    final statuses = {for (final item in dashboard.pendingChildren) item.child.childId: item};
    return roster.map((child) {
      final item = statuses[child.childId];
      return item == null ? uiChildFromLegacy(legacy: child, reportStatus: ReportStatus.none, severity: severityFromDescription(null)) : uiChildFromLegacyWithReport(legacy: child, legacyStatus: item.status, severity: severityFromDescription(null), updatedAt: item.updatedAt);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unmatched = items.where((item) => !item.matched).length;
    return Scaffold(
      appBar: KAppBar(title: 'Tách theo từng bé', onBack: widget.onBack),
      body: FutureBuilder<List<Child>>(future: childrenFuture, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() => childrenFuture = _loadChildren().then((children) { items = children.map((child) => Segment(id: child.id, childId: child.id, name: child.name, matched: true, eating: '', sleep: '', health: '', severity: child.severity, mood: '')).toList(); roster = children; return children; })), child: const Text('Không tải được trẻ · Thử lại')));
        return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: KColors.infoTint, borderRadius: BorderRadius.circular(KRadii.control)),
            child: const Text('Hệ thống tách bản ghi theo tên bé được nhắc. Kiểm tra lại trước khi tạo báo cáo.', style: TextStyle(fontSize: 12.5, color: KColors.inkSoft)),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: KCard(
                color: item.matched ? KColors.surface : KColors.warnTint.withValues(alpha: .55),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        item.matched
                            ? Avatar(name: item.name)
                            : const CircleAvatar(backgroundColor: KColors.surfaceSunken, foregroundColor: KColors.inkSoft, child: Icon(Icons.groups_outlined)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                              Text(item.matched ? 'Gắn theo tên được nhắc' : 'Không gắn được với bé nào', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (!item.matched) const Icon(Icons.warning_amber_rounded, color: KColors.warn),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Ăn uống: ${item.eating}', style: const TextStyle(fontSize: 13.5)),
                    Text('Giấc ngủ: ${item.sleep}', style: const TextStyle(fontSize: 13.5)),
                    Row(children: [const Text('Sức khỏe: ', style: TextStyle(fontSize: 13.5)), SeverityChip(item.severity)]),
                    Text('Tâm trạng: ${item.mood}', style: const TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 14),
                    if (!item.matched)
                      KButton(label: 'Gán cho một bé', icon: Icons.person_add_alt, secondary: true, onPressed: () => _assign(item))
                    else if (approved.contains(item.id))
                      Row(
                        children: [
                          const Expanded(child: Text('Đã duyệt · sẽ tạo nháp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: KColors.ok))),
                          TextButton(onPressed: () => setState(() {
                                items.remove(item);
                                approved.remove(item.id);
                              }), child: const Text('Loại bỏ')),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(child: KButton(label: 'Loại bỏ', secondary: true, onPressed: () => setState(() => items.remove(item)))),
                          const SizedBox(width: 10),
                          Expanded(child: KButton(label: 'Duyệt', icon: Icons.check, onPressed: () => setState(() => approved.add(item.id)))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (unmatched > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: KColors.warnTint, border: Border.all(color: KColors.warn.withValues(alpha: .4)), borderRadius: BorderRadius.circular(KRadii.control)),
              child: Text('Còn $unmatched đoạn chưa gắn với bé nào. Gán trước khi gửi để tránh lộ thông tin riêng của bé khác.', style: const TextStyle(fontSize: 12.5, color: KColors.warnDeep)),
            ),
        ],
      );
      }),
      bottomNavigationBar: BottomActionBar(
        child: KButton(
          label: 'Tạo báo cáo nháp cho ${approved.length} bé',
          large: true,
          onPressed: unmatched == 0 && approved.isNotEmpty ? () => widget.onCreated(approved.length) : null,
        ),
      ),
    );
  }

  void _assign(Segment segment) {
    showKSheet(
      context,
      SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gán đoạn này cho bé', style: Theme.of(context).textTheme.titleMedium),
            Text('Chọn bé mà đoạn ghi âm này nói đến.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: roster
                    .map((child) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Avatar(name: child.name, size: 36),
                          title: Text(child.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          onTap: () {
                            setState(() {
                              final index = items.indexWhere((item) => item.id == segment.id);
                              items[index] = segment.assign(child);
                            });
                            Navigator.pop(context);
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
