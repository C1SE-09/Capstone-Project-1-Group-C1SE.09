import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
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
    Teacher teacher;
    try {
      teacher = await repository.getCurrentTeacher();
    } catch (_) {
      teacher = const Teacher(teacherId: '', fullName: 'Cô Hà', email: '', classId: '');
    }
    final id = widget.classId ?? teacher.classId ?? '';
    ui.ClassInfo? classInfo;
    if (id.isNotEmpty) {
      try {
        classInfo = uiClassInfoFromDomain(await classRepository.getClassInfo(id), count: 0);
      } catch (_) {}
    }
    className = classInfo?.name ?? 'Mầm 1';
    schoolName = classInfo?.school ?? 'Trường Mầm non Hoa Sen';
    teacherName = teacher.fullName.isNotEmpty ? teacher.fullName : 'Cô Hà';

    if (widget.child.id.isNotEmpty) {
      try {
        final todayReport = await repository.getTodayReport(widget.child.id, DateTime.now());
        if (todayReport != null) {
          if (todayReport.summaryText != null && todayReport.summaryText!.trim().isNotEmpty) {
            note.text = todayReport.summaryText!.trim();
          }
          if (todayReport.eating != null && todayReport.eating!.trim().isNotEmpty) {
            eating.text = todayReport.eating!.trim();
          }
          if (todayReport.sleeping != null && todayReport.sleeping!.trim().isNotEmpty) {
            sleep.text = todayReport.sleeping!.trim();
          }
          if (todayReport.health != null && todayReport.health!.trim().isNotEmpty) {
            health.text = todayReport.health!.trim();
          }
          if (todayReport.mood != null && todayReport.mood!.trim().isNotEmpty) {
            mood.text = todayReport.mood!.trim();
          }
          if (todayReport.activitiesText != null && todayReport.activitiesText!.trim().isNotEmpty) {
            activity.text = todayReport.activitiesText!.trim();
          }
        }
      } catch (_) {}
    }
    return _ReportMeta(teacher, classInfo);
  }

  String eatingLevel = 'Tốt';
  String sleepQuality = 'Tốt';
  late final eating = TextEditingController(text: widget.readOnly ? 'Ăn hết suất cơm trưa, uống đủ nước.' : '');
  late final sleepDuration = TextEditingController(text: widget.readOnly ? '120' : '');
  late final sleep = TextEditingController(text: widget.readOnly ? 'Ngủ ngon, không quấy khóc.' : '');
  late final health = TextEditingController(text: widget.readOnly ? 'Sức khỏe bình thường, không có biểu hiện bất thường.' : '');
  late final mood = TextEditingController(text: widget.readOnly ? 'Vui vẻ, hòa đồng với các bạn.' : '');
  late final activity = TextEditingController(text: widget.readOnly ? 'Tham gia hoạt động vẽ và xếp hình nhóm.' : '');
  late final note = TextEditingController(text: widget.readOnly ? 'Bé chơi ngoan, hòa nhập tốt với các bạn trong giờ hoạt động nhóm.' : '');

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
                        Expanded(
                          child: TextField(
                            controller: sleepDuration,
                            readOnly: widget.readOnly,
                            textAlignVertical: TextAlignVertical.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(fontSize: 14, height: 1.2),
                            decoration: const InputDecoration(
                              hintText: 'Thời lượng (phút)',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
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
                    const SizedBox(height: 4),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: note,
                      builder: (context, value, _) => Text(
                        '${value.text.characters.length}/500',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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
                        label: submitting ? 'Đang gửi…' : 'Gửi báo cáo',
                        icon: Icons.send_outlined,
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
                              Text('$className · $teacherName · $todayLong', style: const TextStyle(fontSize: 11.5, color: KColors.inkFaint)),
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
      final teacherId = teacher.teacherId.isNotEmpty
          ? teacher.teacherId
          : repository.teacherId;
      if (teacherId.isEmpty) {
        throw StateError('Missing teacher id');
      }
      await TeacherRepository().createManualReport(
        teacherId: teacherId,
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
    } catch (e) {
      debugPrint('Save draft error: $e');
      if (mounted) setState(() => submitError = 'Không thể lưu bản nháp. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> _sendReport() async {
    if (submitting) return;
    setState(() {
      submitting = true;
      submitError = null;
    });
    try {
      final teacher = await metaFuture.then((meta) => meta.teacher);
      final teacherId = teacher.teacherId.isNotEmpty
          ? teacher.teacherId
          : repository.teacherId;
      if (teacherId.isEmpty) {
        throw StateError('Missing teacher id');
      }
      final reportRes = await TeacherRepository().createManualReport(
        teacherId: teacherId,
        childId: widget.child.id,
        eating: eating.text,
        sleeping: sleep.text,
        health: health.text,
        activities: activity.text,
        mood: mood.text,
        teacherNote: note.text,
      );
      final reportId = (reportRes['daily_report_id'] ?? reportRes['report_id'])?.toString();
      if (reportId != null && reportId.isNotEmpty) {
        await TeacherRepository().publishReport(
          reportId: reportId,
          teacherId: teacherId,
        );
      }
      if (!mounted) return;
      widget.onSent();
    } catch (e) {
      debugPrint('Send report error: $e');
      if (mounted) setState(() => submitError = 'Không thể gửi báo cáo. Vui lòng thử lại.');
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
          Text('Gửi báo cáo cho phụ huynh?', style: Theme.of(context).textTheme.titleMedium),
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
                    Text('Báo cáo ngày $todayLong', style: const TextStyle(fontSize: 12, color: KColors.inkFaint)),
                  ],
                ),
              ],
            ),
          ),
          if (severity != Severity.none)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Báo cáo có thông tin sức khỏe cần được kiểm tra trước khi gửi.', style: TextStyle(fontSize: 12.5, color: KColors.inkSoft)),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: KButton(label: 'Hủy', secondary: true, onPressed: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                child: KButton(
                  label: submitting ? 'Đang gửi…' : 'Gửi báo cáo',
                  icon: Icons.send_outlined,
                  onPressed: submitting ? null : () async {
                    Navigator.pop(context);
                    await _sendReport();
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
  final Teacher teacher;
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
        isDense: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14, height: 1.2),
        items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 14, height: 1.2)))).toList(),
        onChanged: enabled ? (value) { if (value != null) onChanged(value); } : null,
      );

}

class _TextArea extends StatelessWidget {
  const _TextArea({
    required this.controller,
    required this.readOnly,
    this.maxLines = 2,
    this.maxLength,
  });
  final TextEditingController controller;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        readOnly: readOnly,
        minLines: 1,
        maxLines: maxLines,
        maxLength: maxLength,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 14, height: 1.4),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
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
