import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/attendance_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_shell.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _classInfo = ClassInfo(classId: 'class-2', schoolId: 'school-1', name: 'Mầm B');

class _DashboardRepository extends HttpDashboardRepository {
  bool failRoster = false;
  @override
  Future<Teacher> getCurrentTeacher() async => const Teacher(
    teacherId: 'teacher-1', fullName: 'Cô Lan', email: 'teacher@example.com', classId: 'class-2',
  );

  @override
  Future<List<Child>> getClassChildren(String classId) async {
    if (failRoster) throw StateError('Roster unavailable');
    return [Child(childId: 'child-2', fullName: 'Bé Bình', dateOfBirth: DateTime(2020))];
  }

  @override
  Future<ClassDashboardSummary> getClassDashboard(String classId, DateTime date) async =>
      const ClassDashboardSummary(
        classInfo: _classInfo, teacherName: 'Cô Lan', totalChildren: 1,
        completedCount: 0, draftCount: 0, missingCount: 1, pendingChildren: [],
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

void main() {
  testWidgets('refresh danh sách lớp lỗi vẫn giữ danh sách cũ và không ném lỗi', (tester) async {
    final repository = _DashboardRepository();
    await tester.pumpWidget(MaterialApp(home: TeacherShell(
      onLogout: () {}, classId: 'class-2', repository: repository,
      classRepository: _ClassRepository(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lớp'));
    await tester.pumpAndSettle();
    repository.failRoster = true;
    await tester.widget<ClassListScreen>(find.byType(ClassListScreen)).onRefresh!();
    await tester.pumpAndSettle();

    expect(find.text('Bé Bình'), findsOneWidget);
    expect(find.text('Không tải được danh sách lớp. Vui lòng thử lại.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final failure in ['roster', 'class']) {
    testWidgets('lỗi tải $failure không mở lớp rỗng; thử lại tiếp tục thông báo', (tester) async {
      final repository = _DashboardRepository()..failRoster = failure == 'roster';
      final classRepository = _ClassRepository()..failName = failure == 'class';
      await tester.pumpWidget(MaterialApp(home: TeacherShell(
        onLogout: () {}, classId: 'class-2', repository: repository,
        classRepository: classRepository, initialAttendanceDate: '2026-10-20',
      )));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScreen), findsNothing);
      expect(find.textContaining('Thử lại'), findsOneWidget);

      repository.failRoster = false;
      classRepository.failName = false;
      await tester.tap(find.textContaining('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScreen), findsOneWidget);
      expect(tester.widget<AttendanceScreen>(find.byType(AttendanceScreen)).roster.single.id, 'child-2');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nhắc điểm danh đợi dữ liệu rồi mở đúng lớp/ngày và danh sách bé', (tester) async {
    await tester.pumpWidget(MaterialApp(home: TeacherShell(
      onLogout: () {}, classId: 'class-2',
      repository: _DashboardRepository(), classRepository: _ClassRepository(),
      initialAttendanceDate: '2026-10-20',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(AttendanceScreen), findsOneWidget);
    final screen = tester.widget<AttendanceScreen>(find.byType(AttendanceScreen));
    expect(screen.classId, 'class-2');
    expect(screen.date, '2026-10-20');
    expect(screen.roster.single.id, 'child-2');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceScreen), findsNothing);
  });
}
