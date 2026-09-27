import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart' as legacy_teacher;
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/class_info_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;

import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class ReportEditorScreen extends StatefulWidget {
  const ReportEditorScreen({
    super.key,
    required this.child,
    required this.onSent,
    this.readOnly = false,
    this.classId,
    this.repository,
    this.classRepository,
  });
  final Child child;
  final bool readOnly;
  final VoidCallback onSent;
  final String? classId;
  final HttpDashboardRepository? repository;
  final HttpClassDataRepository? classRepository;

  @override
  State<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends State<ReportEditorScreen> {
  late Severity severity = widget.child.severity;
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late final HttpClassDataRepository classRepository = widget.classRepository ?? HttpClassDataRepository();
  late Future<_ReportMeta> metaFuture;
  bool submitting = false;
  String? submitError;
  String className = 'Chưa xác định';
  String schoolName = 'Chưa có thông tin trường';
  String teacherName = '';

  String get todayLong => _todayLong(DateTime.now());

  @override
  void initState() {
    super.initState();
    metaFuture = _loadMeta();
  }

  // Loads teacher and class metadata for report preview labels.
  Future<_ReportMeta> _loadMeta() async {
    final teacher = await repository.getCurrentTeacher();
    final id = widget.classId ?? teacher.classId ?? '';
    final classInfo = id.isEmpty
        ? null
        : uiClassInfoFromLegacy(await classRepository.getClassInfo(id), count: 0);
    className = classInfo?.name ?? 'Chưa xác định';
    schoolName = classInfo?.school ?? 'Chưa có thông tin trường';
    teacherName = teacher.fullName;
    return _ReportMeta(teacher, classInfo);
  }

  String eatingLevel = 'Tốt';
  String sleepQuality = 'Tốt';
  late final eating = TextEditingController();
  late final sleepDuration = TextEditingController();
  late final sleep = TextEditingController();
  late final health = TextEditingController();
  late final mood = TextEditingController();
  late final activity = TextEditingController();
  late final note = TextEditingController();

  @override
  void dispose() {
    for (final controller in [eating, sleepDuration, sleep, health, mood, activity, note]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReportMeta>(
      future: metaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => setState(() => metaFuture = _loadMeta()),
                child: const Text('Không tải được thông tin báo cáo · Thử lại'),
              ),
            ),
          );
        }
        final meta = snapshot.data;
        if (meta == null) return const Scaffold(body: Center(child: Text('Không có thông tin báo cáo.')));

        return Scaffold(
          appBar: KAppBar(
            title: widget.child.name,
            subtitle: todayLong,
            onBack: () => Navigator.pop(context),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (widget.readOnly)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: KColors.surfaceSunken, borderRadius: BorderRadius.circular(KRadii.control)),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: KColors.ok),
                      SizedBox(width: 10),
                      Text('Báo cáo đã gửi, không thể sửa.', style: TextStyle(fontSize: 13, color: KColors.inkSoft)),
                    ],
                  ),
                ),
              if (severity != Severity.none)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: KColors.warnTint, borderRadius: BorderRadius.circular(KRadii.control)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: KColors.warn),
                      const SizedBox(width: 10),
                      Text('Cần theo dõi sức khỏe · mức ${severity.label.toLowerCase()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: KColors.warnDeep)),
                    ],
                  ),
                ),
              _FieldBlock(
                emoji: '🍽️',
                label: 'Ăn uống',
                child: Column(
                  children: [
                    _Dropdown(
                      value: eatingLevel,
                      values: const ['Rất tốt', 'Tốt', 'Tạm được', 'Kém'],
                      enabled: !widget.readOnly,
                      onChanged: (value) => setState(() => eatingLevel = value),
                    ),
                    const SizedBox(height: 10),
                    _TextArea(controller: eating, readOnly: widget.readOnly),
                  ],
                ),
              ),
              _FieldBlock(
                emoji: '😴',
                label: 'Giấc ngủ',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: TextField(controller: sleepDuration, readOnly: widget.readOnly, decoration: const InputDecoration(hintText: 'Thời lượng'))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Dropdown(
                            value: sleepQuality,
                            values: const ['Rất tốt', 'Tốt', 'Tạm được', 'Kém'],
                            enabled: !widget.readOnly,
                            onChanged: (value) => setState(() => sleepQuality = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _TextArea(controller: sleep, readOnly: widget.readOnly),
                  ],
                ),
              ),
              _FieldBlock(
                emoji: '🏥',
                label: 'Sức khỏe',
                sensitive: true,
                child: Column(
                  children: [
                    SegmentedButton<Severity>(
                      segments: Severity.values.map((value) => ButtonSegment(value: value, label: Text(value.label))).toList(),
                      selected: {severity},
                      showSelectedIcon: false,
                      onSelectionChanged: widget.readOnly ? null : (values) => setState(() => severity = values.first),
                    ),
                    const SizedBox(height: 10),
                    _TextArea(controller: health, readOnly: widget.readOnly),
                  ],
                ),
              ),
              _FieldBlock(emoji: '🎭', label: 'Tâm trạng', child: _TextArea(controller: mood, readOnly: widget.readOnly)),
              _FieldBlock(emoji: '🎨', label: 'Hoạt động', child: _TextArea(controller: activity, readOnly: widget.readOnly)),
              _FieldBlock(
                emoji: '📝',
                label: 'Ghi chú của cô',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _TextArea(controller: note, readOnly: widget.readOnly, maxLines: 3, maxLength: 500),
                    Text('${note.text.length}/500', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomActionBar(
            child: widget.readOnly
                ? KButton(label: 'Xem trước', icon: Icons.visibility_outlined, secondary: true, large: true, onPressed: _preview)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (submitError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(submitError!, style: const TextStyle(color: KColors.bad)),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: KButton(
                              label: 'Lưu nháp',
                              secondary: true,
                              onPressed: submitting ? null : _saveDraft,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: KButton(
                              label: 'Xem trước',
                              icon: Icons.visibility_outlined,
                              ghost: true,
                              onPressed: submitting ? null : _preview,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      KButton(
                        label: submitting ? 'Đang lưu bản nháp…' : 'Lưu bản nháp',
                        icon: Icons.save_outlined,
                        large: true,
                        onPressed: submitting ? null : _confirmSend,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _preview() {
    showKSheet(
      context,
      SizedBox(
        height: MediaQuery.sizeOf(context).height * .68,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Phụ huynh sẽ thấy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: KColors.inkFaint)),
            const SizedBox(height: 10),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(color: KColors.canvas, borderRadius: BorderRadius.circular(KRadii.card)),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(schoolName, style: const TextStyle(fontSize: 12, color: KColors.inkFaint)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Avatar(name: widget.child.name, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.child.name, style: Theme.of(context).textTheme.titleMedium),
                              Text('Lớp $className · $teacherName · $todayLong', style: const TextStyle(fontSize: 11.5, color: KColors.inkFaint)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PreviewRow('🍽️ Ăn uống', '$eatingLevel — ${eating.text}'),
                    _PreviewRow('😴 Giấc ngủ', '${sleepDuration.text}, ${sleepQuality.toLowerCase()} — ${sleep.text}'),
                    _PreviewRow('🏥 Sức khỏe · ${severity.label}', health.text),
                    _PreviewRow('🎭 Tâm trạng', mood.text),
                    _PreviewRow('🎨 Hoạt động', activity.text),
                    _PreviewRow('📝 Lời nhắn của cô', note.text),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            KButton(label: 'Đóng', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  // Saves the manually edited report through the existing draft endpoint.
  Future<void> _saveDraft() async {
    if (submitting) return;
    setState(() {
      submitting = true;
      submitError = null;
    });
    try {
      final teacher = await metaFuture.then((meta) => meta.teacher);
      if (teacher.teacherId.isEmpty) {
        throw StateError('Missing teacher id');
      }
      await TeacherRepository().createManualReport(
        teacherId: teacher.teacherId,
        childId: widget.child.id,
        eating: eating.text,
        sleeping: sleep.text,
        health: health.text,
        activities: activity.text,
        mood: mood.text,
        teacherNote: note.text,
      );
      if (!mounted) return;
      widget.onSent();
    } catch (_) {
      if (mounted) setState(() => submitError = 'Không thể lưu bản nháp. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _confirmSend() {
    final todayLong = _todayLong(DateTime.now());
    showKSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lưu bản nháp báo cáo?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: KColors.surfaceSunken, borderRadius: BorderRadius.circular(KRadii.control)),
            child: Row(
              children: [
                Avatar(name: widget.child.name),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.child.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    Text('Bản nháp báo cáo $todayLong', style: const TextStyle(fontSize: 12, color: KColors.inkFaint)),
                  ],
                ),
              ],
            ),
          ),
          if (severity != Severity.none)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Báo cáo có thông tin sức khỏe cần được kiểm tra trước khi lưu.', style: TextStyle(fontSize: 12.5, color: KColors.inkSoft)),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: KButton(label: 'Hủy', secondary: true, onPressed: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                child: KButton(
                  label: submitting ? 'Đang lưu…' : 'Lưu bản nháp',
                  icon: Icons.save_outlined,
                  onPressed: submitting ? null : () async {
                    Navigator.pop(context);
                    await _saveDraft();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportMeta {
  const _ReportMeta(this.teacher, this.classInfo);
  final legacy_teacher.Teacher teacher;
  final ui.ClassInfo? classInfo;
}

// Formats current date for the report header.
String _todayLong(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({required this.emoji, required this.label, required this.child, this.sensitive = false});
  final String emoji;
  final String label;
  final Widget child;
  final bool sensitive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sensitive ? KColors.warnTint.withValues(alpha: .35) : KColors.surface,
        border: Border.all(color: sensitive ? KColors.warn.withValues(alpha: .3) : KColors.line),
        borderRadius: BorderRadius.circular(KRadii.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (sensitive) const Text('Thông tin nhạy cảm', style: TextStyle(fontSize: 10.5, color: KColors.warnDeep)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.value, required this.values, required this.enabled, required this.onChanged});
  final String value;
  final List<String> values;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: enabled ? (value) { if (value != null) onChanged(value); } : null,
      );

}

class _TextArea extends StatelessWidget {
  const _TextArea({required this.controller, required this.readOnly, this.maxLines = 2, this.maxLength});
  final TextEditingController controller;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        maxLength: maxLength,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
        ),
      );
}
