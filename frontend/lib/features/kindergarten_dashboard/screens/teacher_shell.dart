import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/child_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/severity_adapter.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/child/child.dart' as domain_child;

import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/report_editor.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_tabs.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/timetable_screens.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/report_status_adapter.dart';
import 'package:adark_frontend/core/routing/app_router.dart';

enum TeacherTab { overview, classList, history, account }

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key, required this.onLogout, this.classId = 'aaaaaaaa-0000-0000-0000-000000000001', this.repository, this.classRepository});
  final VoidCallback onLogout;
  final String classId;
  final HttpDashboardRepository? repository;
  final HttpClassDataRepository? classRepository;

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  TeacherTab tab = TeacherTab.overview;
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late final HttpClassDataRepository classRepository = widget.classRepository ?? HttpClassDataRepository();
  late Future<String> classNameFuture;
  @override
  void initState() { super.initState(); childrenFuture = _loadChildren(); classNameFuture = classRepository.getClassInfo(widget.classId).then((value) => value.name); }
  late Future<List<Child>> childrenFuture;
  // Loads roster and maps report status with existing adapters.
  Future<List<Child>> _loadChildren() async {
    final values = await Future.wait([
      repository.getClassChildren(widget.classId),
      repository.getClassDashboard(widget.classId, DateTime.now()),
    ]);
    final roster = values[0] as List<domain_child.Child>;
    final dashboard = values[1] as ClassDashboardSummary;
    final statuses = {for (final item in dashboard.pendingChildren) item.child.childId: item};
    return roster.map((child) {
      final item = statuses[child.childId];
      return item == null
          ? uiChildFromDomain(child: child, reportStatus: ReportStatus.none, severity: severityFromDescription(null))
          : uiChildFromDomainWithReport(child: child, reportStatus: item.status, severity: severityFromDescription(null), updatedAt: item.updatedAt);
    }).toList();
  }
  bool healthOnly = false;

  Child childByName(String name, List<Child> children) {
    final clean = name.trim().toLowerCase();
    for (final child in children) {
      final childClean = child.name.trim().toLowerCase();
      if (childClean == clean || clean.contains(childClean) || childClean.contains(clean)) {
        return child;
      }
    }
    return Child(
      id: '',
      name: name.trim().isEmpty ? 'Trẻ' : name.trim(),
      status: ReportStatus.submitted,
      present: true,
      time: '',
      severity: Severity.none,
    );
  }

  void openReport(Child child, [DailyReport? report]) {
    final reportStatus = report != null
        ? uiReportStatusFromBackend(report.status.name)
        : child.status;
    final readOnly = {ReportStatus.submitted, ReportStatus.read, ReportStatus.attention}.contains(reportStatus);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportEditorScreen(
        classId: widget.classId,
        repository: repository,
        classRepository: classRepository,
        child: child,
        initialReport: report,
        readOnly: readOnly,
        onSent: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu bản nháp báo cáo')));
        },
      ),
    ));
  }

  void openRecord(String className) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecordFlowScreen(
        mode: RecordMode.classroom,
        classId: widget.classId,
        className: className,
        repository: repository,
      ),
    ));
  }

  void openTimetable(String className) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TimetableScreen(
        classId: widget.classId,
        className: className,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Child>>(future: childrenFuture, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (snapshot.hasError) return Scaffold(body: Center(child: TextButton(onPressed: () => setState(() => childrenFuture = _loadChildren()), child: const Text('Không tải được danh sách lớp · Thử lại'))));
    final children = snapshot.data ?? const <Child>[];
    return FutureBuilder<String>(future: classNameFuture, builder: (context, classSnapshot) {
    if (classSnapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (classSnapshot.hasError || classSnapshot.data == null) return Scaffold(body: Center(child: TextButton(onPressed: () => setState(() => classNameFuture = classRepository.getClassInfo(widget.classId).then((value) => value.name)), child: const Text('Không tải được thông tin lớp · Thử lại'))));
    final className = classSnapshot.data!;
    final page = switch (tab) {
      TeacherTab.overview => OverviewScreen(
        classId: widget.classId,
        repository: repository,
        onSelectClass: () => appRouter.go('/class-select'),
        onOpenTimetable: () => openTimetable(className),
        onOpenReport: (name) => openReport(childByName(name, children)),
        onHistory: () => setState(() => tab = TeacherTab.history),
        onHealth: () => setState(() { healthOnly = true; tab = TeacherTab.classList; }),
      ),
      TeacherTab.classList => ClassListScreen(
        initialHealthOnly: healthOnly,
        children: children,
        classId: widget.classId,
        className: className,
        schoolName: 'Chưa có thông tin trường',
        onSelectClass: () => appRouter.go('/class-select'),
        onOpenTimetable: () => openTimetable(className),
        onRecord: (child) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecordFlowScreen(mode: RecordMode.child, child: child, classId: widget.classId, className: className, repository: repository))),
        onEdit: openReport,
      ),
      TeacherTab.history => HistoryScreen(children: children, onOpenReport: (child, report) => openReport(child, report)),
      TeacherTab.account => AccountScreen(
        onLogout: widget.onLogout,
        onSelectClass: () => appRouter.go('/class-select'),
        classId: widget.classId,
        repository: repository,
      ),
    };
    return Scaffold(
      body: page,
      bottomNavigationBar: _TeacherNavigation(
        tab: tab,
        onTab: (value) => setState(() {
          if (value != TeacherTab.classList) healthOnly = false;
          tab = value;
        }),
        onRecord: () => openRecord(className),
      ),
    );
    });
  });
}

class _TeacherNavigation extends StatelessWidget {
  const _TeacherNavigation({required this.tab, required this.onTab, required this.onRecord});
  final TeacherTab tab;
  final ValueChanged<TeacherTab> onTab;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    const items = [
      (TeacherTab.overview, Icons.grid_view_outlined, 'Tổng quan'),
      (TeacherTab.classList, Icons.groups_outlined, 'Lớp'),
      (TeacherTab.history, Icons.description_outlined, 'Lịch sử'),
      (TeacherTab.account, Icons.person_outline, 'Tài khoản'),
    ];
    Widget navItem((TeacherTab, IconData, String) item) => Expanded(
          child: InkWell(
            onTap: () => onTab(item.$1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$2, size: 22, color: tab == item.$1 ? context.k.brand : context.k.inkFaint),
                  const SizedBox(height: 3),
                  Text(
                    item.$3,
                    style: TextStyle(fontSize: 11, fontWeight: tab == item.$1 ? FontWeight.w600 : FontWeight.w500, color: tab == item.$1 ? context.k.brand : context.k.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(color: context.k.surface, border: Border(top: BorderSide(color: context.k.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              navItem(items[0]),
              navItem(items[1]),
              SizedBox(
                width: 68,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: Material(
                      color: context.k.brand,
                      elevation: 7,
                      shadowColor: context.k.brand.withValues(alpha: .45),
                      shape: CircleBorder(side: BorderSide(color: context.k.surface, width: 4)),
                      child: Semantics(
                        button: true,
                        label: 'Ghi nhận hoạt động',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onRecord,
                          child: const SizedBox.square(dimension: 60, child: Icon(Icons.mic_none_rounded, size: 28, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              navItem(items[2]),
              navItem(items[3]),
            ],
          ),
        ),
      ),
    );
  }
}
