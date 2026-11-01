import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/class_info_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;

import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class ReportEditorScreen extends StatefulWidget {
  const ReportEditorScreen({
    super.key,
    required this.child,
    required this.onSent,
    this.initialReport,
    this.readOnly = false,
    this.classId,
    this.repository,
    this.classRepository,
    this.initialExtraction,
    this.transcript,
    this.voiceId,
  });
  final Child child;
  final DailyReport? initialReport;
  final bool readOnly;
  final VoidCallback onSent;
  final String? classId;
  final HttpDashboardRepository? repository;
  final HttpClassDataRepository? classRepository;
  final ExtractionData? initialExtraction;
  final String? transcript;
  final String? voiceId;

  @override
  State<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends State<ReportEditorScreen> {
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late final HttpClassDataRepository classRepository = widget.classRepository ?? HttpClassDataRepository();
  late Future<_ReportMeta> metaFuture;
  bool submitting = false;
  String? submitError;
  String className = 'Chưa xác định';
  String schoolName = 'Chưa có thông tin trường';
  String teacherName = '';

  String get todayLong => widget.initialReport != null
      ? _todayLong(widget.initialReport!.reportDate)
      : _todayLong(DateTime.now());

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

    if (widget.initialReport != null) {
      final rep = widget.initialReport!;
      if (rep.eating != null && rep.eating!.trim().isNotEmpty) {
        eating.text = rep.eating!.trim();
      }
      if (rep.sleeping != null && rep.sleeping!.trim().isNotEmpty) {
        sleep.text = rep.sleeping!.trim();
      }
      if (rep.health != null && rep.health!.trim().isNotEmpty) {
        health.text = rep.health!.trim();
      }
      if (rep.mood != null && rep.mood!.trim().isNotEmpty) {
        mood.text = rep.mood!.trim();
      }
      if (rep.activitiesText != null && rep.activitiesText!.trim().isNotEmpty) {
        activity.text = rep.activitiesText!.trim();
      }
      if (rep.summaryText != null && rep.summaryText!.trim().isNotEmpty) {
        note.text = rep.summaryText!.trim();
      }
    } else if (widget.initialExtraction != null) {
      final ext = widget.initialExtraction!;
      eating.text = (ext.meals != null && ext.meals!.trim().isNotEmpty)
          ? ext.meals!.trim()
          : '';
      sleep.text = (ext.sleeping != null && ext.sleeping!.trim().isNotEmpty)
          ? ext.sleeping!.trim()
          : '';
      health.text = (ext.health != null && ext.health!.trim().isNotEmpty)
          ? ext.health!.trim()
          : '';
      mood.text = (ext.mood != null && ext.mood!.trim().isNotEmpty)
          ? ext.mood!.trim()
          : '';
      activity.text = (ext.activities != null && ext.activities!.trim().isNotEmpty)
          ? ext.activities!.trim()
          : '';
      final extNote = ext.rawJson?['teacher_note']?.toString().trim().isNotEmpty == true
          ? ext.rawJson!['teacher_note']!.toString().trim()
          : (ext.rawJson?['notes']?.toString().trim().isNotEmpty == true
              ? ext.rawJson!['notes']!.toString().trim()
              : (ext.rawJson?['note']?.toString().trim().isNotEmpty == true
                  ? ext.rawJson!['note']!.toString().trim()
                  : ''));
      note.text = extNote;
    } else if (widget.child.id.isNotEmpty) {
      try {
        final todayReport = await repository.getTodayReport(widget.child.id, DateTime.now());
        if (todayReport != null) {
          note.text = todayReport.summaryText?.trim() ?? '';
          eating.text = todayReport.eating?.trim() ?? '';
          final rawSleep = todayReport.sleeping?.trim() ?? '';
          final digits = RegExp(r'\d+').firstMatch(rawSleep)?.group(0) ?? '';
          sleepDuration.text = digits;
          sleep.text = rawSleep;
          health.text = todayReport.health?.trim() ?? '';
          mood.text = todayReport.mood?.trim() ?? '';
          activity.text = todayReport.activitiesText?.trim() ?? '';
        }
      } catch (_) {}
    }
    return _ReportMeta(teacher, classInfo);
  }

  late final eating = TextEditingController(text: '');
  late final sleepDuration = TextEditingController(text: '');
  late final sleep = TextEditingController(text: '');
  late final health = TextEditingController(text: '');
  late final mood = TextEditingController(text: '');
  late final activity = TextEditingController(text: '');
  late final note = TextEditingController(text: '');

  @override
  void dispose() {
    for (final controller in [eating, sleepDuration, sleep, health, mood, activity, note]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

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
                  decoration: BoxDecoration(color: context.k.surfaceSunken, borderRadius: BorderRadius.circular(KRadii.control)),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: context.k.ok),
                      const SizedBox(width: 10),
                      Text('Báo cáo đã gửi, không thể sửa.', style: TextStyle(fontSize: 13, color: context.k.inkSoft)),
                    ],
                  ),
                ),
              _FieldBlock(
                icon: Icons.restaurant_outlined,
                label: 'Ăn uống',
                child: _TextArea(controller: eating, readOnly: widget.readOnly),
              ),
              _FieldBlock(
                icon: Icons.bedtime_outlined,
                label: 'Giấc ngủ',
                child: Column(
                  children: [
                    TextField(
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
                    const SizedBox(height: 10),
                    _TextArea(controller: sleep, readOnly: widget.readOnly),
                  ],
                ),
              ),
              _FieldBlock(
                icon: Icons.health_and_safety_outlined,
                label: 'Sức khỏe',
                child: _TextArea(controller: health, readOnly: widget.readOnly),
              ),
              _FieldBlock(icon: Icons.sentiment_satisfied_outlined, label: 'Tâm trạng', child: _TextArea(controller: mood, readOnly: widget.readOnly)),
              _FieldBlock(icon: Icons.palette_outlined, label: 'Hoạt động', child: _TextArea(controller: activity, readOnly: widget.readOnly)),
              _FieldBlock(
                icon: Icons.edit_note,
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
          bottomNavigationBar: widget.readOnly
              ? null
              : BottomActionBar(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (submitError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(submitError!, style: TextStyle(color: context.k.bad)),
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


  // Lưu bản nháp thủ công. Nếu bé đã có bản nháp trong ngày → ghi đè (overwrite=true).
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
        reportDate: widget.initialReport != null
            ? _isoDate(widget.initialReport!.reportDate)
            : null,
        overwrite: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu bản nháp thành công')),
      );
    } catch (e) {
      debugPrint('Save draft error: $e');
      if (mounted) setState(() => submitError = getFriendlyErrorMessage(e, fallback: 'Không thể lưu bản nháp. Vui lòng thử lại.'));
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
        reportDate: widget.initialReport != null
            ? _isoDate(widget.initialReport!.reportDate)
            : null,
        overwrite: true,
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
      if (mounted) setState(() => submitError = getFriendlyErrorMessage(e, fallback: 'Không thể gửi báo cáo. Vui lòng thử lại.'));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _confirmSend() {
    final reportDateText = todayLong;
    showKSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gửi báo cáo cho phụ huynh?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.k.surfaceSunken, borderRadius: BorderRadius.circular(KRadii.control)),
            child: Row(
              children: [
                Avatar(name: widget.child.name),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.child.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    Text('Báo cáo ngày $reportDateText', style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
                  ],
                ),
              ],
            ),
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
  const _FieldBlock({required this.icon, required this.label, required this.child});
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.k.surface,
        border: Border.all(color: context.k.line),
        borderRadius: BorderRadius.circular(KRadii.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.k.brand),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
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

