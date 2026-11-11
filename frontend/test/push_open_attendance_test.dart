import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/attendance_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/leave_request_review_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_notifications_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_shell.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _classInfo =
    ClassInfo(classId: 'class-2', schoolId: 'school-1', name: 'Mầm B');

class _DashboardRepository extends HttpDashboardRepository {
  bool failRoster = false;
  @override
  Future<Teacher> getCurrentTeacher() async => const Teacher(
        teacherId: 'teacher-1',
        fullName: 'Cô Lan',
        email: 'teacher@example.com',
        classId: 'class-2',
      );

  @override
  Future<List<Child>> getClassChildren(String classId) async {
    if (failRoster) throw StateError('Roster unavailable');
    return [
      Child(
          childId: 'child-2', fullName: 'Bé Bình', dateOfBirth: DateTime(2020))
    ];
  }

  @override
  Future<ClassDashboardSummary> getClassDashboard(
          String classId, DateTime date) async =>
      const ClassDashboardSummary(
        classInfo: _classInfo,
        teacherName: 'Cô Lan',
        totalChildren: 1,
        completedCount: 0,
        draftCount: 0,
        missingCount: 1,
        pendingChildren: [],
      );
}

class _ClassRepository extends HttpClassDataRepository {
  bool failName = false;
  @override
  Future<ClassInfo> getClassInfo(String classId) async {
    if (failName) throw StateError('Class unavailable');
    return _classInfo;
  }
}

class _LeaveRequestRepository extends HttpLeaveRequestRepository {
  @override
  Future<LeaveRequestBatchResult> getLeaveRequests(
          {required String classId,
          required String tab,
          int offset = 0,
          int limit = 50}) async =>
      const LeaveRequestBatchResult(
          pendingCount: 0, reviewedCount: 0, items: []);
}

class _AttendanceRepository extends HttpAttendanceRepository {
  @override
  Future<Map<String, AttendanceChildRecord>> getClassAttendanceDetails(
          String classId, DateTime date) async =>
      const {};
}

class _MedicationRepository extends HttpMedicationRepository {
  @override
  Future<MedicationsTodayData> getTodayMedications({String? date}) async =>
      const MedicationsTodayData(
        date: '2026-11-05',
        classId: 'class-2',
        totalRequests: 0,
        completedCount: 0,
        pendingCount: 0,
        morning: [],
        noon: [],
        afternoon: [],
      );
}

void main() {
  testWidgets('CTA tổng quan Garden Voice mở hub ghi nhận trước khi chọn lớp',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: TeacherShell(
      onLogout: () {},
      classId: 'class-2',
      repository: _DashboardRepository(),
      classRepository: _ClassRepository(),
      attendanceRepository: _AttendanceRepository(),
      medicationRepository: _MedicationRepository(),
    )));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bắt đầu báo cáo'));
    await tester.tap(find.text('Bắt đầu báo cáo'));
    await tester.pumpAndSettle();

    expect(find.byType(RecordHubScreen), findsOneWidget);
    await tester.tap(find.text('Cả Lớp Mầm B'));
    await tester.pumpAndSettle();

    final flow = tester.widget<RecordFlowScreen>(find.byType(RecordFlowScreen));
    expect(flow.mode, RecordMode.classroom);
    expect(flow.className, 'Mầm B');
  });

  testWidgets('RecordHub mở ghi âm cho đúng trẻ được chọn', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: TeacherShell(
      onLogout: () {},
      classId: 'class-2',
      repository: _DashboardRepository(),
      classRepository: _ClassRepository(),
      attendanceRepository: _AttendanceRepository(),
      medicationRepository: _MedicationRepository(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu báo cáo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bé Bình'));
    await tester.pumpAndSettle();

    final flow = tester.widget<RecordFlowScreen>(find.byType(RecordFlowScreen));
    expect(flow.mode, RecordMode.child);
    expect(flow.child?.name, 'Bé Bình');
  });

  testWidgets('thông báo tổng quan mở inbox trước màn duyệt đơn',
      (tester) async {
    final leaveRequests = _LeaveRequestRepository();
    await tester.pumpWidget(MaterialApp(
        home: TeacherShell(
      onLogout: () {},
      classId: 'class-2',
      repository: _DashboardRepository(),
      classRepository: _ClassRepository(),
      leaveRequestRepository: leaveRequests,
      attendanceRepository: _AttendanceRepository(),
      medicationRepository: _MedicationRepository(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Ghi lại một ngày\ncủa bé'), findsOneWidget);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();

    expect(find.byType(LeaveRequestReviewScreen), findsNothing);
    final screen = tester.widget<TeacherNotificationsScreen>(
        find.byType(TeacherNotificationsScreen));
    expect(screen.classId, 'class-2');
    expect(screen.repository, same(leaveRequests));
  });

  testWidgets('refresh danh sách lớp lỗi vẫn giữ danh sách cũ và không ném lỗi',
      (tester) async {
    final repository = _DashboardRepository();
    await tester.pumpWidget(MaterialApp(
        home: TeacherShell(
      onLogout: () {},
      classId: 'class-2',
      repository: repository,
      classRepository: _ClassRepository(),
      attendanceRepository: _AttendanceRepository(),
      medicationRepository: _MedicationRepository(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lớp'));
    await tester.pumpAndSettle();
    expect(find.byType(ClassListScreen), findsOneWidget);
    expect(
      tester.widget<ClassListScreen>(find.byType(ClassListScreen)).children,
      hasLength(1),
    );
    repository.failRoster = true;
    await tester
        .widget<ClassListScreen>(find.byType(ClassListScreen))
        .onRefresh!();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ClassListScreen>(find.byType(ClassListScreen))
          .children
          .single
          .name,
      'Bé Bình',
    );
    expect(find.text('Không tải được danh sách lớp. Vui lòng thử lại.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final failure in ['roster', 'class']) {
    testWidgets(
        'lỗi tải $failure không mở lớp rỗng; thử lại tiếp tục thông báo',
        (tester) async {
      final repository = _DashboardRepository()
        ..failRoster = failure == 'roster';
      final classRepository = _ClassRepository()..failName = failure == 'class';
      await tester.pumpWidget(MaterialApp(
          home: TeacherShell(
        onLogout: () {},
        classId: 'class-2',
        repository: repository,
        classRepository: classRepository,
        initialAttendanceDate: '2026-10-20',
        attendanceRepository: _AttendanceRepository(),
        medicationRepository: _MedicationRepository(),
      )));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScreen), findsNothing);
      expect(find.textContaining('Thử lại'), findsOneWidget);

      repository.failRoster = false;
      classRepository.failName = false;
      await tester.tap(find.textContaining('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScreen), findsOneWidget);
      expect(
          tester
              .widget<AttendanceScreen>(find.byType(AttendanceScreen))
              .roster
              .single
              .id,
          'child-2');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nhắc điểm danh đợi dữ liệu rồi mở đúng lớp/ngày và danh sách bé',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: TeacherShell(
      onLogout: () {},
      classId: 'class-2',
      repository: _DashboardRepository(),
      classRepository: _ClassRepository(),
      attendanceRepository: _AttendanceRepository(),
      medicationRepository: _MedicationRepository(),
      initialAttendanceDate: '2026-10-20',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(AttendanceScreen), findsOneWidget);
    final screen =
        tester.widget<AttendanceScreen>(find.byType(AttendanceScreen));
    expect(screen.classId, 'class-2');
    expect(screen.date, '2026-10-20');
    expect(screen.roster.single.id, 'child-2');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceScreen), findsNothing);
  });
}
