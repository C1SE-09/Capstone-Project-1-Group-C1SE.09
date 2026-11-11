import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  String get _headerDate {
    final date = widget.initialReport?.reportDate ?? DateTime.now();
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day
        ? 'Hôm nay'
        : _todayLong(date);
  }

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
    return GardenVoiceScope(
      child: Builder(
        builder: (context) => FutureBuilder<_ReportMeta>(
          future: metaFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => setState(() => metaFuture = _loadMeta()),
                    child: const Text(
                        'Không tải được thông tin báo cáo · Thử lại'),
                  ),
                ),
              );
            }
            final k = context.k;
            final compact = MediaQuery.sizeOf(context).width < 360 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.2;
            Widget durationField() => SizedBox(
                  width: 96,
                  height: 40,
                  child: TextField(
                    controller: sleepDuration,
                    readOnly: widget.readOnly,
                    textAlignVertical: TextAlignVertical.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(color: k.ink, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '—',
                      filled: true,
                      fillColor: k.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: k.lineStrong),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: k.lineStrong),
                      ),
                    ),
                  ),
                );
            return Scaffold(
              backgroundColor: k.canvas,
              appBar: KAppBar(
                title: 'Chỉnh sửa báo cáo',
                subtitle: '${widget.child.name} · $_headerDate',
                onBack: () => Navigator.pop(context),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                children: [
                  if (widget.readOnly)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: k.surfaceSunken,
                        borderRadius: BorderRadius.circular(KRadii.control),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 18, color: k.ok),
                          const SizedBox(width: 10),
                          Text(
                            'Báo cáo đã gửi, không thể sửa.',
                            style: TextStyle(fontSize: 13, color: k.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  _FieldBlock(
                    icon: const _MealFieldIcon(),
                    label: 'Ăn uống',
                    child: _TextArea(
                        controller: eating, readOnly: widget.readOnly),
                  ),
                  const SizedBox(height: KSpace.x8 + KSpace.x1),
                  _FieldBlock(
                    icon: SvgPicture.asset(
                      'assets/garden_voice/review_moon.svg',
                      width: 22,
                      height: 22,
                    ),
                    label: 'Giấc ngủ',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TextArea(controller: sleep, readOnly: widget.readOnly),
                        const SizedBox(height: 8),
                        if (compact)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thời lượng (phút)',
                                style: TextStyle(
                                  color: k.inkSoft,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              durationField(),
                            ],
                          )
                        else
                          Row(
                            children: [
                            Text(
                              'Thời lượng (phút)',
                              style: TextStyle(
                                color: k.inkSoft,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            durationField(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KSpace.x8),
                  _FieldBlock(
                    icon: SvgPicture.asset(
                      'assets/garden_voice/parent_notification_health.svg',
                      width: 22,
                      height: 22,
                    ),
                    label: 'Sức khỏe',
                    child: _TextArea(
                        controller: health, readOnly: widget.readOnly),
                  ),
                  const SizedBox(height: KSpace.x4),
                  _FieldBlock(
                    label: 'Tâm trạng',
                    child: _TextArea(
                        controller: mood, readOnly: widget.readOnly),
                  ),
                  const SizedBox(height: KSpace.x5),
                  _FieldBlock(
                    icon: SvgPicture.asset(
                      'assets/garden_voice/review_artist_palette.svg',
                      width: 22,
                      height: 22,
                    ),
                    label: 'Hoạt động',
                    child: _TextArea(
                        controller: activity, readOnly: widget.readOnly),
                  ),
                  const SizedBox(height: 12),
                  _FieldBlock(
                    label: 'Ghi chú của cô',
                    child: _TextArea(
                      controller: note,
                      readOnly: widget.readOnly,
                      maxLines: 3,
                      maxLength: 500,
                    ),
                  ),
                  const SizedBox(height: KSpace.x6),
                  if (!widget.readOnly) ...[
                    if (submitError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: KSpace.x2),
                        child: Text(
                          submitError!,
                          style: TextStyle(color: k.bad),
                        ),
                      ),
                    if (compact) ...[
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: KButton(
                          label: 'Lưu nháp',
                          secondary: true,
                          onPressed: submitting ? null : _saveDraft,
                        ),
                      ),
                      const SizedBox(height: KSpace.x2),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: KButton(
                          label: submitting ? 'Đang gửi…' : 'Gửi báo cáo',
                          onPressed: submitting ? null : _confirmSend,
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: KButton(
                                label: 'Lưu nháp',
                                secondary: true,
                                onPressed: submitting ? null : _saveDraft,
                              ),
                            ),
                          ),
                          const SizedBox(width: KSpace.x2),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: KButton(
                                label: submitting ? 'Đang gửi…' : 'Gửi báo cáo',
                                onPressed: submitting ? null : _confirmSend,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
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
  const _FieldBlock({this.icon, required this.label, required this.child});
  final Widget? icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Row(
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: k.ink,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _MealFieldIcon extends StatelessWidget {
  const _MealFieldIcon();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 22,
        height: 22,
        child: Stack(
          children: [
            Positioned(
              left: 3,
              top: 1,
              child: SvgPicture.asset(
                'assets/garden_voice/review_spoon.svg',
                width: 7,
                height: 11,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 3,
              child: SvgPicture.asset(
                'assets/garden_voice/review_bowl.svg',
                width: 18,
                height: 9,
              ),
            ),
          ],
        ),
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
  Widget build(BuildContext context) {
    final k = context.k;
    return TextField(
        controller: controller,
        readOnly: readOnly,
        minLines: 1,
        maxLines: maxLines,
        maxLength: maxLength,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(color: k.ink, fontSize: 14, height: 1.4),
        decoration: InputDecoration(
          hintText: 'Chưa có ghi nhận',
          hintStyle: TextStyle(color: k.inkSoft, fontSize: 14, height: 1.4),
          filled: true,
          fillColor: k.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: k.lineStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: k.lineStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: k.brand),
          ),
        ),
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      );
  }
}

