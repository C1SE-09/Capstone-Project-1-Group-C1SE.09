// frontend/test/attendance_test.dart
// Unit & Widget tests cho tính năng Điểm danh (Attendance)

import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/attendance_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

class _DateAttendanceRepository extends HttpAttendanceRepository {
  final requestedDates = <DateTime>[];

  @override
  Future<Map<String, AttendanceChildRecord>> getClassAttendanceDetails(
    String classId,
    DateTime date,
  ) async {
    requestedDates.add(date);
    return {
      'c1': const AttendanceChildRecord(
        childId: 'c1',
        status: AttendanceStatus.late,
        expectedArrivalTime: '08:30:00',
        checkInTime: '08:32:00',
      ),
    };
  }
}

void main() {
  group('HttpAttendanceRepository Integration Tests', () {
    test('getClassAttendance parses backend contract successfully', () async {
      late RequestOptions capturedOptions;

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.httpClientAdapter = _MockAdapter((options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          '''
          {
            "class_id": "c1",
            "date": "2026-10-21",
            "total_children": 2,
            "present_count": 1,
            "absent_count": 1,
            "late_count": 0,
            "children": [
              {
                "child_id": "child-1",
                "full_name": "Nguyen Van A",
                "status": "present"
              },
              {
                "child_id": "child-2",
                "full_name": "Tran Thi B",
                "status": "absent"
              }
            ]
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = HttpAttendanceRepository(dio: dio);
      final res =
          await repo.getClassAttendance('class-123', DateTime(2026, 10, 21));

      expect(capturedOptions.path, '/api/attendance');
      expect(capturedOptions.queryParameters['class_id'], 'class-123');
      expect(capturedOptions.queryParameters['attendance_date'], '2026-10-21');
      expect(res['child-1'], AttendanceStatus.arrived);
      expect(res['child-2'], AttendanceStatus.absent);
    });

    test('saveBatchAttendance formats payload according to backend schema',
        () async {
      late RequestOptions capturedOptions;

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.httpClientAdapter = _MockAdapter((options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          '{"success": true, "message": "OK", "saved_count": 2}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = HttpAttendanceRepository(dio: dio);
      await repo.saveBatchAttendance(
        classId: 'c1',
        date: DateTime(2026, 10, 21),
        record: {
          'child-1': AttendanceStatus.arrived,
          'child-2': AttendanceStatus.absent,
          'child-3': AttendanceStatus.late,
        },
      );

      expect(capturedOptions.path, '/api/attendance/batch');
      final data = capturedOptions.data as Map;
      expect(data['class_id'], 'c1');
      expect(data['date'], '2026-10-21');
      final records = data['records'] as List;
      expect(records.length, 3);
      expect(records[0]['status'], 'present');
      expect(records[1]['status'], 'absent');
      expect(records[2]['status'], 'late');
    });

    test('notifyAbsentParents calls backend endpoint and parses target_count',
        () async {
      late RequestOptions capturedOptions;

      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.httpClientAdapter = _MockAdapter((options) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          '{"success": true, "message": "Notification sent", "target_count": 2}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = HttpAttendanceRepository(dio: dio);
      final count = await repo.notifyAbsentParents(
        classId: 'c1',
        date: DateTime(2026, 10, 21),
        childIds: ['child-2', 'child-3'],
      );

      expect(capturedOptions.path, '/api/attendance/notify-absent');
      final data = capturedOptions.data as Map;
      expect(data['class_id'], 'c1');
      expect(data['date'], '2026-10-21');
      expect(data['child_ids'], ['child-2', 'child-3']);
      expect(count, 2);
    });
  });

  group('AttendanceScreen Widget Tests', () {
    const testChild1 = Child(
      id: 'c1',
      name: 'Bé An',
      status: ReportStatus.none,
      present: true,
      time: '',
      severity: Severity.none,
    );
    const testChild2 = Child(
      id: 'c2',
      name: 'Bé Bình',
      status: ReportStatus.none,
      present: true,
      time: '',
      severity: Severity.none,
    );

    testWidgets(
        'Tapping child name does not change attendance status; changing requires dropdown',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(
            classId: 'class-1',
            className: 'Lớp Mầm A',
            date: '2026-10-21',
            roster: [testChild1, testChild2],
            initialRecords: {
              'c1': AttendanceStatus.arrived,
              'c2': AttendanceStatus.arrived,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and class name
      expect(find.text('Điểm danh'), findsOneWidget);
      expect(find.text('Lớp Mầm A'), findsOneWidget);
      expect(find.text('Bé An'), findsOneWidget);
      expect(find.text('Bé Bình'), findsOneWidget);

      // Tap on Bé An - should NOT toggle status
      await tester.tap(find.text('Bé An'));
      await tester.pumpAndSettle();

      // The count remains unchanged until the dropdown selection is saved.
      expect(find.text('0 vắng'), findsOneWidget);

      // Change status via dropdown
      final dropdownFinder =
          find.byType(DropdownButton<AttendanceStatus>).first;
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vắng').last);
      await tester.pumpAndSettle();

      expect(find.text('1 vắng'), findsOneWidget);
    });

    testWidgets('Allows selecting status from Dropdown for each child',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(
            classId: 'class-1',
            className: 'Lớp Mầm A',
            date: '2026-10-21',
            roster: [testChild1],
            initialRecords: {
              'c1': AttendanceStatus.arrived,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButton<AttendanceStatus>);
      expect(dropdownFinder, findsOneWidget);

      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đến trễ').last);
      await tester.pumpAndSettle();

      expect(find.text('Đến trễ'), findsWidgets);
    });

    testWidgets('Locks status from being changed when excused absent',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(
            classId: 'class-1',
            className: 'Lớp Mầm A',
            date: '2026-10-21',
            roster: [testChild1],
            initialRecords: {
              'c1': AttendanceStatus.excusedAbsent,
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trạng thái có phép hiển thị trong pill, không dùng nhãn tiếng Anh.
      expect(find.text('Excused Absent'), findsNothing);
      expect(find.text('Có phép'), findsWidgets);

      // Giáo viên click vào dòng bé có đơn xin nghỉ (đã bị khóa)
      await tester.tap(find.text('Bé An'));
      await tester.pumpAndSettle();

      // Dropdown bị khóa không thể chọn
      final dropdown = tester.widget<DropdownButton<AttendanceStatus>>(
        find.byType(DropdownButton<AttendanceStatus>),
      );
      expect(dropdown.onChanged, isNull);

      // Xác thực trạng thái được khóa, không bị chuyển sang Đến trễ hay Đã đến.
      expect(find.text('Có phép'), findsWidgets);
      expect(find.text('Đến trễ'), findsNothing);
    });

    testWidgets('điểm danh render đúng header, tab lớp và nav Garden Voice',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GardenVoiceScope(
            child: AttendanceScreen(
              classId: 'class-1',
              className: 'Lớp Mầm 1',
              date: '2026-11-04',
              roster: [testChild1, testChild2],
              initialRecords: {
                'c1': AttendanceStatus.arrived,
                'c2': AttendanceStatus.late,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lớp Mầm 1'), findsOneWidget);
      expect(find.text('Danh sách'), findsOneWidget);
      expect(find.text('Điểm danh'), findsWidgets);
      expect(find.text('Lịch học'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('garden-voice-teacher-navigation')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('điểm danh cuộn được ở 320dp với chữ 200%', (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: GardenVoiceScope(
            child: AttendanceScreen(
              classId: 'class-1',
              className: 'Lớp Mầm 1',
              date: '2026-11-04',
              roster: [testChild1, testChild2],
              initialRecords: {
                'c1': AttendanceStatus.arrived,
                'c2': AttendanceStatus.late,
              },
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Danh sách điểm danh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('đổi ngày tải lại đúng bản ghi điểm danh từ repository',
        (tester) async {
      final repository = _DateAttendanceRepository();
      await tester.pumpWidget(MaterialApp(
        home: GardenVoiceScope(
          child: AttendanceScreen(
            classId: 'class-1',
            className: 'Lớp Mầm 1',
            date: '2026-11-04',
            roster: [testChild1],
            repository: repository,
            initialRecords: const {'c1': AttendanceStatus.arrived},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ngày sau'));
      await tester.pumpAndSettle();

      expect(repository.requestedDates, [DateTime(2026, 11, 5)]);
      expect(find.text('Thứ Năm · 05/11'), findsOneWidget);
      expect(find.text('Đến lúc 08:32'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Displays Late ETA badge when expectedArrivalTime is present',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(
            classId: 'class-1',
            className: 'Lớp Mầm A',
            date: '2026-10-21',
            roster: [testChild1],
            initialRecords: {
              'c1': AttendanceStatus.late,
            },
            initialDetails: {
              'c1': AttendanceChildRecord(
                childId: 'c1',
                status: AttendanceStatus.late,
                expectedArrivalTime: '08:30:00',
              ),
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dự kiến đến 08:30'), findsOneWidget);
      expect(find.text('Đến lúc 08:30'), findsNothing);
    });
  });
}
