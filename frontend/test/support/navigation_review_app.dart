// Preview dùng dữ liệu giả, không đăng nhập hoặc gọi backend. P: đổi vai trò, D: đổi theme.
import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_shell.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() => runApp(const NavigationReviewApp());

class NavigationReviewApp extends StatefulWidget {
  const NavigationReviewApp({super.key});

  @override
  State<NavigationReviewApp> createState() => _NavigationReviewAppState();
}

class _NavigationReviewAppState extends State<NavigationReviewApp> {
  final _focus = FocusNode();
  final _dashboard = NavigationReviewDashboard();
  bool _parent = false;
  bool _dark = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: kinderTheme(),
        darkTheme: kinderThemeDark(),
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: KeyboardListener(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is! KeyDownEvent) return;
            if (event.logicalKey == LogicalKeyboardKey.keyP) {
              setState(() => _parent = !_parent);
            } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
              setState(() => _dark = !_dark);
            }
          },
          child: _parent
              ? ParentFlow(repository: _dashboard, onLogout: () {})
              : TeacherShell(
                  classId: 'review-class',
                  repository: _dashboard,
                  classRepository: _ReviewClass(),
                  attendanceRepository: _ReviewAttendance(),
                  medicationRepository: _ReviewMedication(),
                  onLogout: () {},
                ),
        ),
      );
}

class NavigationReviewDashboard extends HttpDashboardRepository {
  static const _child = Child(
    childId: 'review-child',
    classId: 'review-class',
    fullName: 'Nguyễn Minh An',
    medicalAllergies: 'Đậu phộng',
  );

  @override
  Future<Teacher> getCurrentTeacher() async => const Teacher(
        teacherId: 'review-teacher',
        fullName: 'Cô Nguyễn Thị Mai',
        email: 'review@example.test',
      );

  @override
  Future<Parent> getCurrentParent() async =>
      const Parent(parentId: 'review-parent', fullName: 'Nguyễn Văn Tuấn');

  @override
  Future<List<Child>> getClassChildren(String classId) async => [_child];

  @override
  Future<ChildOverview> getPrimaryChildOverview(String parentId) async =>
      const ChildOverview(
        child: _child,
        className: 'Mầm 1',
        teacherName: 'Cô Nguyễn Thị Mai',
      );

  @override
  Future<ClassDashboardSummary> getClassDashboard(
          String classId, DateTime date) async =>
      const ClassDashboardSummary(
        classInfo: ClassInfo(
            classId: 'review-class',
            schoolId: 'review-school',
            name: 'Lớp Mầm 1'),
        teacherName: 'Cô Nguyễn Thị Mai',
        totalChildren: 1,
        completedCount: 0,
        draftCount: 0,
        missingCount: 1,
        pendingChildren: [],
      );

  @override
  Future<List<DailyReport>> getRecentReports(String childId,
          {int limit = 7, bool includeDraft = true}) async =>
      List.generate(
          30,
          (index) => DailyReport(
                dailyReportId: 'review-report-$index',
                childId: _child.childId,
                reportDate:
                    DateTime(2026, 11, 4).subtract(Duration(days: index)),
                status: ReportStatus.published,
                eating: 'Ăn hết suất · cơm, thịt kho, canh bí',
                sleeping: 'Ngủ ngon · 12:00 – 13:45',
                activitiesText: 'Vẽ tranh mùa thu · rất hứng thú',
                summaryText: 'Hôm nay An ăn ngoan, tự xúc hết phần cơm.',
              ));

  @override
  Future<DailyReport?> getTodayReport(String childId, DateTime date,
          {bool includeDraft = true}) async =>
      (await getRecentReports(childId)).first;

  @override
  Future<DailyReport> markReportAsRead(String reportId) async =>
      (await getRecentReports(_child.childId))
          .firstWhere((report) => report.dailyReportId == reportId)
          .copyWith(status: ReportStatus.read);
}

class _ReviewClass extends HttpClassDataRepository {
  @override
  Future<ClassInfo> getClassInfo(String classId) async => const ClassInfo(
      classId: 'review-class', schoolId: 'review-school', name: 'Lớp Mầm 1');
}

class _ReviewAttendance extends HttpAttendanceRepository {
  @override
  Future<Map<String, AttendanceChildRecord>> getClassAttendanceDetails(
          String classId, DateTime date) async =>
      {};
}

class _ReviewMedication extends HttpMedicationRepository {
  @override
  Future<MedicationsTodayData> getTodayMedications({String? date}) async =>
      throw StateError('Preview không cung cấp dữ liệu thuốc');
}
