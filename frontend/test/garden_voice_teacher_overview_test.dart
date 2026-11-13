import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/data/repositories/http_schedule_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:adark_frontend/domain/entities/timetable/class_schedule.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart'
    show AttendanceStatus;
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_tabs.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Dashboard extends HttpDashboardRepository {
  @override
  Future<Teacher> getCurrentTeacher() async => const Teacher(
        teacherId: 'teacher-1',
        fullName: 'Cô Nguyễn Thị Mai',
        email: 'teacher@example.com',
      );

  @override
  Future<ClassDashboardSummary> getClassDashboard(
    String classId,
    DateTime date,
  ) async =>
      const ClassDashboardSummary(
        classInfo: ClassInfo(
          classId: 'class-1',
          schoolId: 'school-1',
          name: 'Lớp Mầm 1',
        ),
        teacherName: 'Cô Nguyễn Thị Mai',
        totalChildren: 5,
        completedCount: 0,
        draftCount: 0,
        missingCount: 5,
        pendingChildren: [
          ChildReportItem(
            child: Child(
              childId: 'child-1',
              fullName: 'Minh An',
              medicalAllergies: 'Dị ứng đậu phộng',
            ),
          ),
          ChildReportItem(
            child: Child(childId: 'child-2', fullName: 'Bảo Châu'),
          ),
        ],
      );
}

class _Attendance extends HttpAttendanceRepository {
  @override
  Future<Map<String, AttendanceChildRecord>> getClassAttendanceDetails(
    String classId,
    DateTime date,
  ) async =>
      const {
        'child-1': AttendanceChildRecord(
          childId: 'child-1',
          status: AttendanceStatus.arrived,
        ),
        'child-2': AttendanceChildRecord(
          childId: 'child-2',
          status: AttendanceStatus.late,
          checkInTime: '08:30',
        ),
        'child-3': AttendanceChildRecord(
          childId: 'child-3',
          status: AttendanceStatus.arrived,
        ),
        'child-4': AttendanceChildRecord(
          childId: 'child-4',
          status: AttendanceStatus.arrived,
        ),
        'child-5': AttendanceChildRecord(
          childId: 'child-5',
          status: AttendanceStatus.arrived,
        ),
      };
}

class _Medication extends HttpMedicationRepository {
  @override
  Future<MedicationsTodayData> getTodayMedications({String? date}) async =>
      const MedicationsTodayData(
        date: '2026-11-05',
        classId: 'class-1',
        totalRequests: 2,
        completedCount: 0,
        pendingCount: 2,
        morning: [],
        noon: [],
        afternoon: [],
      );
}

class _Schedule extends HttpScheduleRepository {
  @override
  Future<List<ClassSchedule>> getClassSchedule(String classId) async =>
      const [];
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-ExtraBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-Black.ttf'));
    await fonts.load();
  });

  testWidgets('Garden Voice teacher overview renders truthful actions and data',
      (tester) async {
    var reportOpened = false;
    var notificationsOpened = false;
    var attendanceOpened = false;
    var medicationOpened = false;
    var emergencyOpened = false;

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: Scaffold(
          body: OverviewScreen(
            classId: 'class-1',
            repository: _Dashboard(),
            attendanceRepository: _Attendance(),
            medicationRepository: _Medication(),
            scheduleRepository: _Schedule(),
            notificationCount: 2,
            onStartReport: () => reportOpened = true,
            onOpenNotifications: () => notificationsOpened = true,
            onOpenAttendance: () => attendanceOpened = true,
            onOpenMedications: () => medicationOpened = true,
            onEmergencyAlert: () => emergencyOpened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cô Nguyễn Thị Mai'), findsOneWidget);
    expect(find.textContaining('Lớp Mầm 1 ·'), findsOneWidget);
    expect(find.text('Ghi lại một ngày\ncủa bé'), findsOneWidget);
    expect(find.text('Bắt đầu báo cáo'), findsOneWidget);
    expect(find.text('Báo sự cố'), findsOneWidget);
    expect(find.text('Thuốc hôm nay'), findsOneWidget);
    expect(find.text('2 việc cần xử lý'), findsOneWidget);
    expect(find.text('Điểm danh hôm nay'), findsOneWidget);
    expect(find.text('5/5 bé đã đến'), findsOneWidget);
    expect(find.text('1 đến trễ'), findsOneWidget);
    expect(find.text('0 vắng'), findsOneWidget);
    expect(
        tester.getSize(find.text('1 đến trễ')).height, lessThanOrEqualTo(17));
    expect(
      tester
          .getSize(
              find.byKey(const ValueKey('garden-voice-attendance-summary')))
          .height,
      closeTo(54, 1),
    );
    expect(find.text('Cần chú ý'), findsOneWidget);
    expect(find.text('Dị ứng đậu phộng'), findsOneWidget);
    expect(find.text('Đã đến trễ lúc 08:30'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('garden-voice-garden-art')))
          .dy,
      closeTo(76, 1),
    );
    expect(
      tester
          .getTopLeft(
              find.byKey(const ValueKey('garden-voice-report-invitation')))
          .dy,
      closeTo(246, 1),
    );
    expect(
      tester.getTopLeft(find.text('Cần chú ý')).dy,
      closeTo(542, 1),
    );

    await tester.tap(find.text('Bắt đầu báo cáo'));
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.tap(find.text('Báo sự cố'));
    await tester.tap(find.text('Thuốc hôm nay'));
    await tester.tap(find.text('Điểm danh hôm nay'));

    expect(reportOpened, isTrue);
    expect(notificationsOpened, isTrue);
    expect(emergencyOpened, isTrue);
    expect(medicationOpened, isTrue);
    expect(attendanceOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Garden Voice teacher overview không tràn ở 320dp chữ 200%',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: OverviewScreen(
            classId: 'class-1',
            repository: _Dashboard(),
            attendanceRepository: _Attendance(),
            medicationRepository: _Medication(),
            scheduleRepository: _Schedule(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ghi lại một ngày\ncủa bé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
