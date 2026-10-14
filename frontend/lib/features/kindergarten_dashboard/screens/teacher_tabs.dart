import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_schedule_repository.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart' as domain_class;
import 'package:adark_frontend/domain/entities/timetable/class_schedule.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/report_status_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/change_password_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/bug_report_sheet.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
    super.key,
    this.onOpenReport,
    this.onHistory,
    this.onHealth,
    this.onSelectClass,
    this.onOpenTimetable,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.repository,
    this.scheduleRepository,
  });
  final ValueChanged<String>? onOpenReport;
  final VoidCallback? onHistory;
  final VoidCallback? onHealth;
  final VoidCallback? onSelectClass;
  final VoidCallback? onOpenTimetable;
  final String classId;
  final HttpDashboardRepository? repository;
  final ScheduleRepository? scheduleRepository;
  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late final ScheduleRepository scheduleRepository = widget.scheduleRepository ?? HttpScheduleRepository();
  late Future<_OverviewData> future;
  @override
  void initState() { super.initState(); future = _load(); }
  // Loads live teacher, class summary, and today's timetable.
  Future<_OverviewData> _load() async {
    final values = await Future.wait([
      repository.getCurrentTeacher(),
      repository.getClassDashboard(widget.classId, DateTime.now()),
      scheduleRepository.getClassSchedule(widget.classId).catchError((_) => <ClassSchedule>[]),
    ]);
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    final nowMinutes = now.hour * 60 + now.minute;
    final todayAll = (values[2] as List<ClassSchedule>)
        .where((item) => item.isActive && item.dayIndex == todayIndex)
        .toList()
      ..sort((a, b) => (_timeToMinutes(a.startTime) ?? 0).compareTo(_timeToMinutes(b.startTime) ?? 0));
    final upcoming = todayAll.where((item) => (_timeToMinutes(item.endTime) ?? 0) > nowMinutes).toList();
    final todayItems = upcoming.isNotEmpty ? upcoming : todayAll;
    return _OverviewData(
      values[0] as Teacher,
      values[1] as ClassDashboardSummary,
      todayItems.take(3).toList(growable: false),
    );
  }

  void _handleOpenTimetable() {
    widget.onOpenTimetable?.call();
    if (mounted) setState(() => future = _load());
  }
  // Renders overview loading, error and data states.
  @override
  Widget build(BuildContext context) => FutureBuilder<_OverviewData>(future: future, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError || snapshot.data == null) return Center(child: TextButton(onPressed: () => setState(() => future = _load()), child: const Text('Không tải được tổng quan · Thử lại')));
    final data = snapshot.data;
    if (data == null) return const Center(child: Text('Không có dữ liệu tổng quan.'));
    final total = data.dashboard.totalChildren;
    final healthCount = data.dashboard.pendingChildren.where((item) => item.child.medicalAllergies?.trim().isNotEmpty == true).length;
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_longDate(DateTime.now()), style: Theme.of(context).textTheme.bodyMedium),
                  Text('Chào ${data.teacher.fullName}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
                ],
              ),
            ),
            if (widget.onSelectClass != null)
              InkWell(
                onTap: widget.onSelectClass,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.k.brandTint,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: context.k.brand.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_outlined, size: 15, color: context.k.brand),
                      const SizedBox(width: 5),
                      Text(
                        data.dashboard.classInfo.name.isNotEmpty ? data.dashboard.classInfo.name : 'Đổi lớp',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.k.brand),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.swap_horiz_rounded, size: 15, color: context.k.brand),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        KCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ProgressRing(value: data.dashboard.completedCount, total: total),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tiến độ hôm nay', style: Theme.of(context).textTheme.bodyMedium),
                    Text('${data.dashboard.completedCount}/$total báo cáo đã gửi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Còn '),
                        TextSpan(text: '${data.dashboard.notCompletedCount} trẻ', style: TextStyle(fontWeight: FontWeight.w600, color: context.k.ink)),
                        const TextSpan(text: ' chưa có báo cáo.'),
                      ]),
                      style: TextStyle(fontSize: 13, color: context.k.inkSoft),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Hôm nay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.k.ink)),
        const SizedBox(height: 10),
        KCard(
          child: Column(
            children: [
              if (data.todayItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Hôm nay chưa có hoạt động', style: TextStyle(fontSize: 13, color: context.k.inkFaint)),
                  ),
                )
              else
                for (final item in data.todayItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Text(item.startTime, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.k.ink)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item.displayName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                        if (_timeToMinutes(item.startTime) != null &&
                            _timeToMinutes(item.startTime)! <= nowMinutes &&
                            nowMinutes < (_timeToMinutes(item.endTime) ?? 0))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: context.k.okTint, borderRadius: BorderRadius.circular(99)),
                            child: Text('Đang diễn ra', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.k.ok)),
                          )
                        else if (item.teacherLabel.isNotEmpty)
                          Text(item.teacherLabel, style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
                      ],
                    ),
                  ),
              const Divider(),
              InkWell(
                onTap: _handleOpenTimetable,
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Xem thời khóa biểu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.k.brand)),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: context.k.brand),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            StatCard(value: total, label: 'Tổng số trẻ', icon: Icons.groups_outlined),
            StatCard(value: data.dashboard.completedCount, label: 'Đã gửi', icon: Icons.check_circle_outline, tone: context.k.ok),
            StatCard(value: data.dashboard.draftCount, label: 'Bản nháp', icon: Icons.edit_outlined, tone: context.k.info),
            StatCard(value: healthCount, label: 'Cảnh báo sức khỏe', icon: Icons.monitor_heart_outlined, tone: context.k.warn),
          ],
        ),
      ],
    );
  });
}

class _OverviewData { const _OverviewData(this.teacher, this.dashboard, this.todayItems); final Teacher teacher; final ClassDashboardSummary dashboard; final List<ClassSchedule> todayItems; }

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key, required this.initialHealthOnly, required this.onRecord, required this.onEdit, required this.children, this.onSelectClass, this.onOpenTimetable, this.className = 'Lớp', this.schoolName = 'Chưa có thông tin trường', this.classId = 'aaaaaaaa-0000-0000-0000-000000000001'});
  final bool initialHealthOnly;
  final ValueChanged<Child> onRecord;
  final ValueChanged<Child> onEdit;
  final List<Child> children;
  final VoidCallback? onSelectClass;
  final VoidCallback? onOpenTimetable;
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
    if (widget.initialHealthOnly != oldWidget.initialHealthOnly) healthOnly = widget.initialHealthOnly;
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.children.where((child) {
      final matches = child.name.toLowerCase().contains(query.toLowerCase());
      return matches && (!healthOnly || child.severity != Severity.none);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.className, style: Theme.of(context).textTheme.headlineMedium),
                        Text(widget.schoolName, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  if (widget.onSelectClass != null)
                    OutlinedButton.icon(
                      onPressed: widget.onSelectClass,
                      icon: Icon(Icons.swap_horiz_rounded, size: 16, color: context.k.brand),
                      label: Text('Đổi lớp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.k.brand)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.k.brand, width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              KCard(
                onTap: widget.onOpenTimetable,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: context.k.brandTint, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.calendar_month_outlined, size: 18, color: context.k.brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Thời khóa biểu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          Text('Xem lịch học cả tuần của lớp', style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: context.k.inkFaint),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SearchField(hint: 'Tìm theo tên bé…', onChanged: (value) => setState(() => query = value)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilterChipButton(label: 'Tất cả', selected: !healthOnly, onTap: () => setState(() => healthOnly = false)),
                  FilterChipButton(label: 'Cảnh báo sức khỏe', warn: true, selected: healthOnly, onTap: () => setState(() => healthOnly = true)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Text('${widget.children.length} trẻ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.k.inkSoft))),
                  Text('${widget.children.where((c) => {ReportStatus.none, ReportStatus.draft, ReportStatus.attention}.contains(c.status)).length} chưa xong', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Không tìm thấy trẻ phù hợp.', style: TextStyle(color: context.k.inkFaint)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    KCard(
                      child: Column(
                        children: [
                          for (var index = 0; index < list.length; index++) ...[
                            _ChildRow(child: list[index], onTap: () => _showActions(list[index])),
                            if (index < list.length - 1) const Divider(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _showActions(Child child) {
    showKSheet(
      context,
      Column(
        children: [
          Row(
            children: [
              Avatar(name: child.name, size: 44),
              const SizedBox(width: 12),
              Expanded(child: Text(child.name, style: Theme.of(context).textTheme.titleMedium)),
              StatusBadge(child.status),
            ],
          ),
          const SizedBox(height: 20),
          KButton(label: 'Ghi âm', icon: Icons.mic_none, large: true, onPressed: () {
            Navigator.pop(context);
            widget.onRecord(child);
          }),
          const SizedBox(height: 10),
          KButton(label: 'Soạn báo cáo', icon: Icons.edit_outlined, secondary: true, onPressed: () {
            Navigator.pop(context);
            widget.onEdit(child);
          }),
        ],
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.child, required this.onTap});
  final Child child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Avatar(name: child.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(child.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      if (child.allergy != null) Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.warning_amber_rounded, size: 15, color: context.k.warn)),
                    ],
                  ),
                  if (child.severity != Severity.none)
                    Text('Sức khỏe: ${child.severity.label}', style: Theme.of(context).textTheme.bodySmall)
                  else if (child.allergy != null)
                    Text('Dị ứng: ${child.allergy}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.k.warn)),
                ],
              ),
            ),
            StatusBadge(child.status),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onOpenReport, required this.children, this.repository});
  final void Function(Child child, DailyReport? report) onOpenReport;
  final List<Child> children;
  final HttpDashboardRepository? repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String query = '';
  String filter = 'Tất cả';
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late Future<List<_HistoryRow>> future;
  @override
  void initState() { super.initState(); future = _load(); }
  // Loads the latest report history for each roster child.
  Future<List<_HistoryRow>> _load() async {
    final validChildren = widget.children.where((c) => c.id.isNotEmpty).toList();
    final childLists = await Future.wait(
      validChildren.map((child) async {
        try {
          final reports = await repository.getRecentReports(child.id, includeDraft: true);
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
  @override
  Widget build(BuildContext context) => FutureBuilder<List<_HistoryRow>>(future: future, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() => future = _load()), child: const Text('Không tải được lịch sử · Thử lại')));
    final historyRows = snapshot.data ?? const <_HistoryRow>[];
    final groupsMap = <String, List<_HistoryRow>>{};
    for (final row in historyRows) { groupsMap.putIfAbsent(_shortDate(row.report.reportDate), () => []).add(row); }
    bool allowed(ReportStatus status) => switch (filter) {
          'Bản nháp' => status == ReportStatus.draft,
          'Đã gửi' => status == ReportStatus.submitted || status == ReportStatus.attention,
          'Đã đọc' => status == ReportStatus.read,
          _ => true,
        };
    final groups = groupsMap.entries.map((entry) => MapEntry(entry.key, entry.value.where((row) => row.child.name.toLowerCase().contains(query.toLowerCase()) && allowed(uiReportStatusFromBackend(row.report.status.name))).toList())).where((entry) => entry.value.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lịch sử báo cáo', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 14),
              SearchField(hint: 'Tìm theo tên bé…', onChanged: (value) => setState(() => query = value)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Tất cả', 'Bản nháp', 'Đã gửi', 'Đã đọc']
                      .map((value) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChipButton(label: value, selected: filter == value, onTap: () => setState(() => filter = value)),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? Center(child: Text('Không có báo cáo nào khớp với bộ lọc này.', style: TextStyle(color: context.k.inkFaint)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                        child: Text(group.key, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.k.inkFaint, letterSpacing: .4)),
                      ),
                      KCard(
                        child: Column(
                          children: [
                            for (var index = 0; index < group.value.length; index++) ...[
                              InkWell(
                                onTap: () => widget.onOpenReport(group.value[index].child, group.value[index].report),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Avatar(name: group.value[index].child.name),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(group.value[index].child.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                      ),
                                      StatusBadge(uiReportStatusFromBackend(group.value[index].report.status.name)),
                                    ],
                                  ),
                                ),
                              ),
                              if (index < group.value.length - 1) const Divider(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  });
}

class _HistoryRow { const _HistoryRow(this.child, this.report); final Child child; final DailyReport report; }

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.onLogout, this.onSelectClass, this.classId = 'aaaaaaaa-0000-0000-0000-000000000001', this.repository, this.classRepository});
  final VoidCallback onLogout;
  final VoidCallback? onSelectClass;
  final String classId;
  final HttpDashboardRepository? repository;
  final HttpClassDataRepository? classRepository;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late final HttpClassDataRepository classRepository = widget.classRepository ?? HttpClassDataRepository();
  late Future<_AccountData> future;
  @override
  void initState() { super.initState(); future = _load(); }
  // Loads teacher profile, class metadata and roster count.
  Future<_AccountData> _load() async { final values = await Future.wait([repository.getCurrentTeacher(), classRepository.getClassInfo(widget.classId), repository.getClassChildren(widget.classId)]); final info = values[1] as domain_class.ClassInfo; return _AccountData(values[0] as Teacher, info.name, (values[2] as List).length); }
  @override
  Widget build(BuildContext context) => FutureBuilder<_AccountData>(future: future, builder: (context, snapshot) { if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator()); if (snapshot.hasError || snapshot.data == null) return Center(child: TextButton(onPressed: () => setState(() => future = _load()), child: const Text('Không tải được tài khoản · Thử lại'))); final data = snapshot.data; if (data == null) return const Center(child: Text('Không có thông tin tài khoản.')); final teacher = data.teacher; final className = data.className; return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        Text('Tài khoản', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        KCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Avatar(name: teacher.fullName, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teacher.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text('Giáo viên · $className', style: TextStyle(fontSize: 13, color: context.k.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const _GroupTitle('Thông tin'),
        KCard(
          child: Column(
            children: [
              _AccountRow(icon: Icons.phone_outlined, label: 'Số điện thoại', value: teacher.phone ?? 'Chưa cập nhật'),
              const Divider(),
              _AccountRow(
                icon: Icons.school_outlined,
                label: 'Lớp phụ trách',
                value: className,
                chevron: widget.onSelectClass != null,
                onTap: widget.onSelectClass,
              ),
              const Divider(),
              _AccountRow(icon: Icons.groups_outlined, label: 'Số trẻ', value: '${data.childCount} trẻ'),
            ],
          ),
        ),
        const _GroupTitle('Tùy chỉnh'),
        KCard(
          child: Column(
            children: [
              if (widget.onSelectClass != null) ...[
                _AccountRow(icon: Icons.swap_horiz_rounded, label: 'Quay lại chọn lớp khác', chevron: true, onTap: widget.onSelectClass),
                const Divider(),
              ],
              _AccountRow(
                icon: Icons.lock_outline_rounded,
                label: 'Đổi mật khẩu',
                chevron: true,
                onTap: () => showChangePasswordBottomSheet(context),
              ),
              const Divider(),
              const ThemeSelector(),
              const Divider(),
              _AccountRow(
                icon: Icons.bug_report_outlined,
                label: 'Báo cáo lỗi & Góp ý',
                chevron: true,
                onTap: () => showBugReportBottomSheet(context),
              ),
              const Divider(),
              const _AccountRow(icon: Icons.info_outline, label: 'Về KinderLog', value: 'v1.0.0'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        KButton(label: 'Đăng xuất', icon: Icons.logout, secondary: true, large: true, onPressed: _confirmLogout),
      ],
    );
  });

  void _confirmLogout() {
    showKSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn có muốn đăng xuất không ?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: KButton(label: 'Hủy', secondary: true, onPressed: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(child: KButton(label: 'Đăng xuất', icon: Icons.logout, onPressed: widget.onLogout)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountData { const _AccountData(this.teacher, this.className, this.childCount); final Teacher teacher; final String className; final int childCount; }

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
      );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.icon, required this.label, this.value, this.chevron = false, this.onTap});
  final IconData icon;
  final String label;
  final String? value;
  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: context.k.inkSoft),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          if (value != null) Text(value!, style: Theme.of(context).textTheme.bodySmall),
          if (chevron) Icon(Icons.chevron_right, size: 18, color: context.k.inkFaint),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, child: row);
    }
    return row;
  }
}

// Formats today's date for the Vietnamese dashboard.
// Parses "HH:MM" into minutes since midnight (null when invalid).
int? _timeToMinutes(String value) {
  if (value.trim().isEmpty) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  return hours * 60 + minutes;
}

String _longDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _shortDate(DateTime d) => _longDate(d);
