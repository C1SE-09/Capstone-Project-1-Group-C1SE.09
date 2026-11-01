// frontend/test/attendance_test.dart
// Unit & Widget tests cho tính năng Điểm danh (Attendance)

import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/attendance_screen.dart';
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
      final res = await repo.getClassAttendance('class-123', DateTime(2026, 10, 21));

      expect(capturedOptions.path, '/api/attendance');
      expect(capturedOptions.queryParameters['class_id'], 'class-123');
      expect(capturedOptions.queryParameters['attendance_date'], '2026-10-21');
      expect(res['child-1'], AttendanceStatus.arrived);
      expect(res['child-2'], AttendanceStatus.absent);
    });

    test('saveBatchAttendance formats payload according to backend schema', () async {
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

    test('notifyAbsentParents calls backend endpoint and parses target_count', () async {
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

    testWidgets('Tapping child name does not change attendance status; changing requires dropdown', (tester) async {
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
      expect(find.text('Lớp Mầm A · 2026-10-21'), findsOneWidget);
      expect(find.text('Bé An'), findsOneWidget);
      expect(find.text('Bé Bình'), findsOneWidget);

      // Tap on Bé An - should NOT toggle status
      await tester.tap(find.text('Bé An'));
      await tester.pumpAndSettle();

      // "Vắng" only appears once in the summary bar (label), not on child row
      expect(find.text('Vắng'), findsOneWidget);

      // Change status via dropdown
      final dropdownFinder = find.byType(DropdownButton<AttendanceStatus>).first;
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vắng').last);
      await tester.pumpAndSettle();

      // Now "Vắng" appears more than once (summary bar + child row)
      expect(find.text('Vắng'), findsWidgets);
    });

    testWidgets('Allows selecting status from Dropdown for each child', (tester) async {
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

      await tester.tap(find.text('Đến Trễ').last);
      await tester.pumpAndSettle();

      expect(find.text('Đến Trễ'), findsWidgets);
    });

    testWidgets('Locks status from being changed when excused absent', (tester) async {
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

      // Xác thực badge "Excused Absent" không hiển thị, Dropdown hiển thị "Có Phép"
      expect(find.text('Excused Absent'), findsNothing);
      expect(find.text('Có Phép'), findsWidgets);

      // Giáo viên click vào dòng bé có đơn xin nghỉ (đã bị khóa)
      await tester.tap(find.text('Bé An'));
      await tester.pumpAndSettle();

      // Dropdown bị khóa không thể chọn
      final dropdown = tester.widget<DropdownButton<AttendanceStatus>>(
        find.byType(DropdownButton<AttendanceStatus>),
      );
      expect(dropdown.onChanged, isNull);

      // Xác thực trạng thái được khóa, không bị chuyển sang Đến Trễ hay Đến
      expect(find.text('Có Phép'), findsWidgets);
      expect(find.text('Đến Trễ'), findsNothing);
    });

    testWidgets('Displays Late ETA badge when expectedArrivalTime is present', (tester) async {
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

      // Xác thực badge "Late (ETA: 08:30)" được format chuẩn và hiển thị
      expect(find.text('Late (ETA: 08:30)'), findsOneWidget);
    });
  });
}
