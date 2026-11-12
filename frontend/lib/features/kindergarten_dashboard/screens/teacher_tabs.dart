import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/data/repositories/http_schedule_repository.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/report_status_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/severity_adapter.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_overview.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_class_header.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_account_screen.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_account_screen.dart' show TeacherAccountScreen;

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
    super.key,
    this.onOpenReport,
    this.onHistory,
    this.onHealth,
    this.onSelectClass,
    this.onOpenTimetable,
    this.onOpenAttendance,
    this.onOpenMedications,
    this.onEmergencyAlert,
    this.onOpenNotifications,
    this.onStartReport,
    this.notificationCount,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.repository,
    this.scheduleRepository,
    this.attendanceRepository,
    this.medicationRepository,
  });
  final ValueChanged<String>? onOpenReport;
  final VoidCallback? onHistory;
  final VoidCallback? onHealth;
  final VoidCallback? onSelectClass;
  final VoidCallback? onOpenTimetable;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenMedications;
  final VoidCallback? onEmergencyAlert;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onStartReport;
  final int? notificationCount;
  final String classId;
  final HttpDashboardRepository? repository;
  final ScheduleRepository? scheduleRepository;
  final HttpAttendanceRepository? attendanceRepository;
  final HttpMedicationRepository? medicationRepository;
  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late final HttpAttendanceRepository attendanceRepository =
      widget.attendanceRepository ?? HttpAttendanceRepository();
  late final HttpMedicationRepository medicationRepository =
      widget.medicationRepository ?? HttpMedicationRepository();
  late Future<_OverviewData> future;
  @override
  void initState() { super.initState(); future = _load(); }
  // Tải dữ liệu thật cho các khối Garden Voice; số không có nguồn không được suy diễn.
  Future<_OverviewData> _load() async {
    final today = DateTime.now();
    final values = await Future.wait<dynamic>([
      repository.getCurrentTeacher(),
      repository.getClassDashboard(widget.classId, today),
      attendanceRepository.getClassAttendanceDetails(widget.classId, today),
      _loadMedications(),
    ]);
    return _OverviewData(
      values[0] as Teacher,
      values[1] as ClassDashboardSummary,
      values[2] as Map<String, AttendanceChildRecord>,
      values[3] as MedicationsTodayData?,
    );
  }

  Future<MedicationsTodayData?> _loadMedications() async {
    try {
      return await medicationRepository.getTodayMedications();
    } catch (_) {
      return null;
    }
  }
  // Renders overview loading, error and data states.
  @override
  Widget build(BuildContext context) => GardenVoiceScope(
        child: FutureBuilder<_OverviewData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(() => future = _load()),
                  child: const Text('Không tải được tổng quan · Thử lại'),
                ),
              );
            }
            final data = snapshot.data!;
            return GardenVoiceTeacherOverview(
              teacher: data.teacher,
              dashboard: data.dashboard,
              attendance: data.attendance,
              medications: data.medications,
              notificationCount: widget.notificationCount,
              onStartReport: widget.onStartReport,
              onOpenNotifications: widget.onOpenNotifications,
              onOpenAttendance: widget.onOpenAttendance,
              onOpenMedications: widget.onOpenMedications,
              onEmergencyAlert: widget.onEmergencyAlert,
              onHealth: widget.onHealth,
              onRefresh: () async {
                final refreshed = await _load();
                if (mounted) setState(() => future = Future.value(refreshed));
              },
            );
          },
        ),
      );
}

class _OverviewData {
  const _OverviewData(
    this.teacher,
    this.dashboard,
    this.attendance,
    this.medications,
  );

  final Teacher teacher;
  final ClassDashboardSummary dashboard;
  final Map<String, AttendanceChildRecord> attendance;
  final MedicationsTodayData? medications;
}

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({
    super.key,
    required this.initialHealthOnly,
    required this.onRecord,
    required this.onEdit,
    required this.children,
    this.onSelectClass,
    this.onOpenTimetable,
    this.onOpenAttendance,
    this.onOpenLeaveRequests,
    this.onOpenNotifications,
    this.onRefresh,
    this.teacherName,
    this.notificationCount,
    this.pendingLeaveCount,
    this.className = 'Lớp',
    this.schoolName = 'Chưa có thông tin trường',
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
  });
  final bool initialHealthOnly;
  final ValueChanged<Child> onRecord;
  final ValueChanged<Child> onEdit;
  final List<Child> children;
  final VoidCallback? onSelectClass;
  final VoidCallback? onOpenTimetable;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenLeaveRequests;
  final VoidCallback? onOpenNotifications;
  final Future<void> Function()? onRefresh;
  final String? teacherName;
  final int? notificationCount;
  final int? pendingLeaveCount;
  final String classId;
  final String className;
  final String schoolName;

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  String query = '';
  late bool healthOnly = widget.initialHealthOnly;

  @override
  void didUpdateWidget(covariant ClassListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHealthOnly != oldWidget.initialHealthOnly) {
      healthOnly = widget.initialHealthOnly;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.children.where((child) {
      final matches = child.name.toLowerCase().contains(query.toLowerCase());
      return matches && (!healthOnly || child.severity != Severity.none);
    }).toList();
    final subtitleText = (widget.teacherName != null &&
            widget.teacherName!.trim().isNotEmpty)
        ? widget.teacherName!.trim()
        : widget.schoolName;
    final content = Builder(
      builder: (context) {
        final k = context.k;
        return ColoredBox(
          color: k.canvas,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GardenVoiceClassHeader(
                className: widget.className,
                subtitle: subtitleText,
                selectedTab: GardenVoiceClassTab.roster,
                notificationCount: widget.notificationCount,
                pendingLeaveCount: widget.pendingLeaveCount,
                onSelectClass: widget.onSelectClass,
                onOpenNotifications: widget.onOpenNotifications,
                onTabSelected: (tab) {
                  switch (tab) {
                    case GardenVoiceClassTab.roster:
                      if (healthOnly) setState(() => healthOnly = false);
                    case GardenVoiceClassTab.attendance:
                      widget.onOpenAttendance?.call();
                    case GardenVoiceClassTab.leaveRequests:
                      widget.onOpenLeaveRequests?.call();
                    case GardenVoiceClassTab.timetable:
                      widget.onOpenTimetable?.call();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 39),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: k.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: k.lineStrong),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/garden_voice/class_search.svg',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(() => query = value),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.24,
                            color: k.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tìm tên bé…',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.24,
                              color: k.inkSoft,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: widget.onRefresh ?? () async {},
                  child: list.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
                              child: Center(
                                child: Text(
                                  'Không tìm thấy trẻ phù hợp.',
                                  style: TextStyle(color: k.inkFaint),
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: k.reviewSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: k.lineStrong),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0D102737),
                                    blurRadius: 24,
                                    offset: Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Color(0x08102737),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  for (var index = 0;
                                      index < list.length;
                                      index++) ...[
                                    _ChildRow(
                                      child: list[index],
                                      onTap: () => _showActions(list[index]),
                                    ),
                                    if (index < list.length - 1)
                                      Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: k.line),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
    return context.k.isGardenVoice
        ? content
        : GardenVoiceScope(child: content);
  }

  void _showActions(Child child) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ChildActionsScreen(
        child: child,
        className: widget.className,
        onRecord: () => widget.onRecord(child),
        onEdit: () => widget.onEdit(child),
      ),
    ));
  }
}

class _ChildActionsScreen extends StatelessWidget {
  const _ChildActionsScreen({
    required this.child,
    required this.className,
    required this.onRecord,
    required this.onEdit,
  });

  final Child child;
  final String className;
  final VoidCallback onRecord;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => GardenVoiceScope(
        child: Builder(
          builder: (context) {
            final k = context.k;
            final allergy = (child.allergy ?? '').trim();
            final careNotes = (child.careNotes ?? '').trim();
            final note = allergy.isNotEmpty
                ? allergy.toLowerCase().startsWith('dị ứng')
                    ? allergy
                    : 'Dị ứng ${allergy[0].toLowerCase()}${allergy.substring(1)}'
                : careNotes.isNotEmpty
                    ? careNotes
                    : 'Chưa có lưu ý chăm sóc.';
            return Scaffold(
              backgroundColor: k.canvas,
              appBar: KAppBar(
                title: child.name,
                onBack: () => Navigator.of(context).pop(),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        className,
                        style: TextStyle(
                          color: k.inkSoft,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: k.surfaceSunken,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ghi nhận trong ngày',
                              style: TextStyle(
                                color: k.brandStrong,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              note,
                              style: TextStyle(
                                color: k.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      KButton(
                        label: 'Ghi âm cho bé',
                        onPressed: () {
                          Navigator.of(context).pop();
                          onRecord();
                        },
                      ),
                      const SizedBox(height: 14),
                      KButton(
                        label: 'Soạn báo cáo',
                        secondary: true,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onEdit();
                        },
                      ),
                      const SizedBox(height: 14),
                      KButton(
                        label: 'Xem trao đổi với phụ huynh',
                        secondary: true,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onEdit();
                        },
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

class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.child, required this.onTap});
  final Child child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final allergyText = (child.allergy ?? '').trim();
    final careNotesText = (child.careNotes ?? '').trim();
    String? subtitle;
    Color subtitleColor = k.inkSoft;
    if (allergyText.isNotEmpty) {
      subtitle = allergyText.toLowerCase().startsWith('dị ứng')
          ? allergyText
          : 'Dị ứng: $allergyText';
      subtitleColor = k.warn;
    } else if (careNotesText.isNotEmpty) {
      subtitle = careNotesText;
      subtitleColor = k.inkSoft;
    } else if (child.severity != Severity.none) {
      subtitle = 'Sức khỏe: ${child.severity.label}';
      subtitleColor = k.warn;
    }
    final statusLabel = switch (child.status) {
      ReportStatus.none => 'Chưa ghi',
      ReportStatus.submitted || ReportStatus.read => 'Đã ghi',
      _ => null,
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Avatar(name: child.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                      color: k.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusBadge(child.status, labelOverride: statusLabel),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.onOpenReport,
    required this.children,
    this.repository,
    this.referenceDate,
  });
  final void Function(Child child, DailyReport? report) onOpenReport;
  final List<Child> children;
  final HttpDashboardRepository? repository;
  final DateTime? referenceDate;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String query = '';
  String filter = 'Tất cả';
  late final HttpDashboardRepository repository =
      widget.repository ?? HttpDashboardRepository();
  late Future<List<_HistoryRow>> future;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  // Loads the latest report history for each roster child.
  Future<List<_HistoryRow>> _load() async {
    final validChildren =
        widget.children.where((c) => c.id.isNotEmpty).toList();
    final childLists = await Future.wait(
      validChildren.map((child) async {
        try {
          final reports = await repository.getRecentReports(child.id,
              includeDraft: true);
          return reports.map((report) => _HistoryRow(child, report)).toList();
        } catch (e) {
          debugPrint('Error loading reports for child ${child.id}: $e');
          return <_HistoryRow>[];
        }
      }),
    );
    final rows = <_HistoryRow>[];
    for (final list in childLists) {
      rows.addAll(list);
    }
    rows.sort((a, b) => b.report.reportDate.compareTo(a.report.reportDate));
    return rows;
  }

  ReportStatus _rowStatus(_HistoryRow row) {
    final healthText = (row.report.health ?? '').toLowerCase();
    final hasSeverity =
        severityFromDescription(row.report.health) != Severity.none ||
            healthText.contains('mild') ||
            healthText.contains('moderate') ||
            healthText.contains('cần chú ý') ||
            row.report.activities.any(
              (a) =>
                  severityFromDescription(a['description']?.toString()) !=
                  Severity.none,
            ) ||
            row.child.severity != Severity.none;
    return uiReportStatusFromDomain(
      row.report.status,
      hasSeverity: hasSeverity,
    );
  }

  String _rowTimeLabel(_HistoryRow row) {
    final published = row.report.publishedAt;
    if (published != null) {
      return '${published.hour.toString().padLeft(2, '0')}:${published.minute.toString().padLeft(2, '0')}';
    }
    final d = row.report.reportDate;
    if (d.hour != 0 || d.minute != 0) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    if (row.child.time.trim().isNotEmpty) {
      return row.child.time.trim();
    }
    return '08:00';
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<_HistoryRow>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => future = _load()),
              child: const Text('Không tải được lịch sử · Thử lại'),
            ),
          );
        }
        final k = context.k;
        final now = widget.referenceDate ?? DateTime.now();
        final historyRows = snapshot.data ?? const <_HistoryRow>[];
        final groupsMap = <String, List<_HistoryRow>>{};
        for (final row in historyRows) {
          groupsMap
              .putIfAbsent(
                  _historyGroupLabel(row.report.reportDate, now), () => [])
              .add(row);
        }
        bool allowed(ReportStatus status) => switch (filter) {
              'Bản nháp' => status == ReportStatus.draft ||
                  status == ReportStatus.attention,
              'Đã gửi' => status == ReportStatus.submitted ||
                  status == ReportStatus.attention,
              'Đã đọc' => status == ReportStatus.read,
              _ => true,
            };
        final groups = groupsMap.entries
            .map((entry) => MapEntry(
                entry.key,
                entry.value
                    .where((row) =>
                        row.child.name
                            .toLowerCase()
                            .contains(query.toLowerCase()) &&
                        allowed(_rowStatus(row)))
                    .toList()))
            .where((entry) => entry.value.isNotEmpty)
            .toList();
        return ColoredBox(
          color: k.canvas,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Báo cáo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: k.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SearchField(
                      hint: 'Tìm theo tên bé…',
                      onChanged: (value) => setState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Tất cả', 'Bản nháp', 'Đã gửi', 'Đã đọc']
                            .map(
                              (value) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChipButton(
                                  label: value,
                                  selected: filter == value,
                                  onTap: () => setState(() => filter = value),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final r = await _load();
                    if (mounted) setState(() => future = Future.value(r));
                  },
                  child: groups.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
                              child: Center(
                                child: Text(
                                  'Không có báo cáo nào khớp với bộ lọc này.',
                                  style: TextStyle(color: k.inkFaint),
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          children: [
                            for (var groupIndex = 0;
                                groupIndex < groups.length;
                                groupIndex++) ...[
                              Padding(
                                padding: EdgeInsets.only(
                                  top: groupIndex == 0 ? 0 : 12,
                                  bottom: 12,
                                ),
                                child: Text(
                                  groups[groupIndex].key,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    height: 1.28,
                                    color: k.ink,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: k.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: k.lineStrong),
                                ),
                                child: Column(
                                  children: [
                                    for (var index = 0;
                                        index < groups[groupIndex].value.length;
                                        index++) ...[
                                      InkWell(
                                        onTap: () => widget.onOpenReport(
                                          groups[groupIndex].value[index].child,
                                          groups[groupIndex]
                                              .value[index]
                                              .report,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight: 66),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            child: Row(
                                              children: [
                                                Avatar(
                                                  name: groups[groupIndex]
                                                      .value[index]
                                                      .child
                                                      .name,
                                                  size: 40,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        groups[groupIndex]
                                                            .value[index]
                                                            .child
                                                            .name,
                                                        style: TextStyle(
                                                          fontSize: 14.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          height: 1.28,
                                                          color: k.ink,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Báo cáo ngày · ${_rowTimeLabel(groups[groupIndex].value[index])}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          height: 1.28,
                                                          color: k.inkSoft,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    _HistoryStatusPill(
                                                      status: _rowStatus(
                                                        groups[groupIndex]
                                                            .value[index],
                                                      ),
                                                    ),
                                                    if (groups[groupIndex]
                                                        .value[index]
                                                        .report
                                                        .hasDiscussion) ...[
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: groups[groupIndex]
                                                                  .value[index]
                                                                  .report
                                                                  .hasUnreadResponses
                                                              ? k.badTint
                                                              : k.surfaceSunken,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .chat_bubble_rounded,
                                                              size: 10,
                                                              color: groups[groupIndex]
                                                                      .value[index]
                                                                      .report
                                                                      .hasUnreadResponses
                                                                  ? k.bad
                                                                  : k.inkSoft,
                                                            ),
                                                            const SizedBox(
                                                                width: 3),
                                                            Text(
                                                              groups[groupIndex]
                                                                      .value[index]
                                                                      .report
                                                                      .hasUnreadResponses
                                                                  ? (groups[groupIndex].value[index].report.unreadResponseCount > 1
                                                                      ? 'Tin mới (${groups[groupIndex].value[index].report.unreadResponseCount})'
                                                                      : 'Tin mới')
                                                                  : 'Trao đổi',
                                                              style: TextStyle(
                                                                fontSize: 10.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: groups[groupIndex]
                                                                        .value[index]
                                                                        .report
                                                                        .hasUnreadResponses
                                                                    ? k.bad
                                                                    : k.inkSoft,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (index <
                                          groups[groupIndex].value.length - 1)
                                        Divider(
                                          height: 0.6,
                                          thickness: 0.6,
                                          color: k.line,
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
    return context.k.isGardenVoice
        ? content
        : GardenVoiceScope(child: content);
  }
}

class _HistoryStatusPill extends StatelessWidget {
  const _HistoryStatusPill({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (bg, fg, label) = switch (status) {
      ReportStatus.submitted => (
          k.activityRowTint,
          k.activityRowText,
          'Đã gửi'
        ),
      ReportStatus.read => (k.okTint, k.ok, 'Đã đọc'),
      ReportStatus.attention => (k.accentTint, k.warn, 'Cần chú ý'),
      ReportStatus.draft ||
      ReportStatus.processing ||
      ReportStatus.none =>
        (k.surfaceSunken, k.inkSoft, 'Bản nháp'),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          height: 1.28,
          color: fg,
        ),
      ),
    );
  }
}

class _HistoryRow {
  const _HistoryRow(this.child, this.report);
  final Child child;
  final DailyReport report;
}

typedef AccountScreen = TeacherAccountScreen;

String _longDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _shortDate(DateTime d) => _longDate(d);

String _historyGroupLabel(DateTime d, DateTime now) {
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  return _shortDate(d);
}
