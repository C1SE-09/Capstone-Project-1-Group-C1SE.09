import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_notifications_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/leave_request_review_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parent_request_repository_test.dart'
    show RequestTransport, jsonBody, requestJson;
import 'parent_requests_test.dart' show app;

HttpMedicationRepository medicationRepository(RequestTransport leaveTransport) {
  final transport = RequestTransport((options) {
    if (options.path == '/api/medication-requests' ||
        options.path == '/api/teacher/health-incidents') {
      return jsonBody([]);
    }
    return leaveTransport.respond(options);
  });
  return HttpMedicationRepository(
      dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
        ..httpClientAdapter = transport);
}

HttpAttendanceRepository attendanceRepository(RequestTransport transport) =>
    HttpAttendanceRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter =
              RequestTransport((options) => options.path == '/api/attendance'
                  ? jsonBody({
                      'class_id': 'class-1',
                      'date': '2026-11-09',
                      'total_children': 0,
                      'present_count': 0,
                      'absent_count': 0,
                      'excused_absent_count': 0,
                      'late_count': 0,
                      'children': [],
                    })
                  : transport.respond(options)));

HttpDashboardRepository dashboardRepository(RequestTransport transport) =>
    HttpDashboardRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = RequestTransport(
              (options) => options.path == '/api/class/class-1/dashboard'
                  ? jsonBody({
                      'class_info': {
                        'class_id': 'class-1',
                        'school_id': 'school-1',
                        'name': 'Mầm 1',
                      },
                      'teacher_name': 'Cô Mai',
                      'total_children': 0,
                      'completed_count': 0,
                      'draft_count': 0,
                      'missing_count': 0,
                      'pending_children': [],
                    })
                  : transport.respond(options)));

void main() {
  testWidgets('inbox follows Garden Voice Figma canvas, card and navigation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final transport = RequestTransport((options) => jsonBody({
          'pending_count': 1,
          'reviewed_count': 0,
          'items': options.queryParameters['tab'] == 'pending'
              ? [
                  {...requestJson(), 'child_name': 'Bảo Châu'}
                ]
              : [],
        }));
    final repository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(app(TeacherNotificationsScreen(
        classId: 'class-1',
        repository: repository,
        medicationRepository: medicationRepository(transport),
        attendanceRepository: attendanceRepository(transport),
        dashboardRepository: dashboardRepository(transport))));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('teacher-notifications-back')),
        findsOneWidget);
    expect(
      tester
          .widget<ColoredBox>(
              find.byKey(const ValueKey('teacher-notifications-canvas')))
          .color,
      Colors.white,
    );
    expect(find.byKey(const ValueKey('garden-voice-teacher-navigation')),
        findsOneWidget);
    expect(
      tester
          .getTopLeft(
              find.byKey(const ValueKey('garden-voice-teacher-navigation')))
          .dy,
      inInclusiveRange(740, 790),
    );
    final notice = find.byKey(const ValueKey('notification-card-request-1'));
    expect(notice, findsOneWidget);
    expect(
      tester.widget<Material>(notice).shape,
      isA<RoundedRectangleBorder>().having(
        (shape) => shape.borderRadius,
        'border radius',
        BorderRadius.circular(24),
      ),
    );
    expect(find.textContaining('Trạng thái đã đọc chỉ lưu'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Đơn xin nghỉ mới — Bảo Châu')).dy,
      greaterThan(tester.getTopLeft(find.text('ĐƠN NGHỈ')).dy),
    );
  });

  testWidgets('inbox cards remain scrollable at 320dp and 200% text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final transport = RequestTransport((options) => jsonBody({
          'pending_count': 1,
          'reviewed_count': 0,
          'items': options.queryParameters['tab'] == 'pending'
              ? [
                  {
                    ...requestJson(),
                    'child_name': 'Bảo Châu',
                    'reason':
                        'Bé sốt nhẹ, gia đình xin cô cho nghỉ để theo dõi thêm.'
                  }
                ]
              : [],
        }));
    final repository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);

    await tester.pumpWidget(app(
        TeacherNotificationsScreen(
            classId: 'class-1',
            repository: repository,
            medicationRepository: medicationRepository(transport),
            attendanceRepository: attendanceRepository(transport),
            dashboardRepository: dashboardRepository(transport)),
        textScale: 2,
        dark: true));
    await tester.pumpAndSettle();

    expect(find.text('Đơn xin nghỉ mới — Bảo Châu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'refresh lỗi giữ dữ liệu và thử lại trang đầu, không nhảy sang tải thêm',
      (tester) async {
    var fail = false;
    final transport = RequestTransport((options) => fail
        ? jsonBody({'detail': 'Mất mạng'}, 503)
        : jsonBody({
            'pending_count': 2,
            'reviewed_count': 0,
            'items': options.queryParameters['tab'] == 'pending'
                ? [requestJson()]
                : [],
          }));
    final repository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(app(TeacherNotificationsScreen(
        classId: 'class-1',
        repository: repository,
        medicationRepository: medicationRepository(transport),
        attendanceRepository: attendanceRepository(transport),
        dashboardRepository: dashboardRepository(transport))));
    await tester.pumpAndSettle();
    fail = true;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    await refresh;
    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(
        transport.requests
            .lastWhere((r) => r.queryParameters['tab'] == 'pending')
            .queryParameters['offset'],
        0);
  });

  testWidgets('đơn vừa được cô khác duyệt vẫn mở đúng tab kết quả từ inbox cũ',
      (tester) async {
    final pending = LeaveRequestEntity.fromJson(requestJson());
    final approved = {
      ...requestJson(status: 'approved'),
      'child_name': 'Bé vừa được duyệt'
    };
    final transport =
        RequestTransport((options) => !options.path.contains('/class/')
            ? jsonBody(approved)
            : jsonBody({
                'pending_count': 0,
                'reviewed_count': 1,
                'items': options.queryParameters['tab'] == 'reviewed'
                    ? [approved]
                    : []
              }));
    final repository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(app(LeaveRequestReviewScreen(
        classId: 'class-1', repository: repository, initialRequest: pending)));
    await tester.pumpAndSettle();
    expect(find.text('Bé vừa được duyệt'), findsOneWidget);
    expect(find.text('Duyệt đơn'), findsNothing);
  });

  testWidgets('mở đúng đơn từ inbox dù đơn nằm ngoài trang đầu danh sách duyệt',
      (tester) async {
    final target = LeaveRequestEntity.fromJson({
      ...requestJson(),
      'request_id': 'target',
      'child_name': 'Bé cần duyệt'
    });
    final transport = RequestTransport((options) =>
        options.path.endsWith('/target')
            ? jsonBody({
                ...requestJson(),
                'request_id': 'target',
                'child_name': 'Bé cần duyệt'
              })
            : jsonBody({
                'pending_count': 51,
                'reviewed_count': 0,
                'items': [requestJson()]
              }));
    final repository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(app(LeaveRequestReviewScreen(
        classId: 'class-1', repository: repository, initialRequest: target)));
    await tester.pumpAndSettle();
    final focusedScreen = tester.widget<LeaveRequestReviewScreen>(
        find.byType(LeaveRequestReviewScreen));
    expect(focusedScreen.initialRequest?.requestId, 'target');
    expect(find.text('Bé cần duyệt'), findsOneWidget);
    expect(find.text('Chi tiết đơn · Lớp học'), findsOneWidget);
    expect(transport.requests.last.path, '/api/leave-requests/target');
    expect(tester.takeException(), isNull);
  });

  testWidgets('inbox tải tiếp và chặn dữ liệu lẫn lớp', (tester) async {
    var mixedClass = false;
    final transport = RequestTransport((options) {
      final offset = options.queryParameters['offset'] as int;
      return jsonBody({
        'pending_count': 2,
        'reviewed_count': 0,
        'items': options.queryParameters['tab'] == 'reviewed'
            ? []
            : [
                {
                  ...requestJson(),
                  'request_id': 'request-$offset',
                  'child_name': 'Bé số $offset',
                  'class_id': mixedClass ? 'other-class' : 'class-1'
                },
              ]
      });
    });
    final repository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(app(TeacherNotificationsScreen(
        classId: 'class-1',
        repository: repository,
        medicationRepository: medicationRepository(transport),
        attendanceRepository: attendanceRepository(transport),
        dashboardRepository: dashboardRepository(transport))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải thêm'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bé số 1'), findsOneWidget);
    mixedClass = true;
    await tester.pumpWidget(app(TeacherNotificationsScreen(
        key: const ValueKey('new-session'),
        classId: 'class-1',
        repository: repository,
        medicationRepository: medicationRepository(transport),
        attendanceRepository: attendanceRepository(transport),
        dashboardRepository: dashboardRepository(transport))));
    await tester.pumpAndSettle();
    expect(find.text('Không thể xác minh thông báo của lớp.'), findsOneWidget);
    expect(find.textContaining('Bé số 0'), findsNothing);
  });

  testWidgets(
      'inbox dùng đơn thật, đọc trong phiên, lọc không tạo thông báo giả',
      (tester) async {
    final transport = RequestTransport((options) => jsonBody({
          'pending_count': 2,
          'reviewed_count': 0,
          'items': options.queryParameters['tab'] == 'pending'
              ? [
                  {
                    ...requestJson(),
                    'request_id': 'older',
                    'child_name': 'Bé An',
                    'created_at': '2026-10-29T07:00:00+07:00'
                  },
                  {
                    ...requestJson(),
                    'request_id': 'newer',
                    'child_name': 'Bé Bình',
                    'request_type': 'late_arrival',
                    'expected_arrival_time': '08:30:00',
                    'created_at': '2026-10-29T07:10:00+07:00'
                  },
                ]
              : [],
        }));
    final repository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(app(TeacherNotificationsScreen(
        classId: 'class-1',
        className: 'Mầm 1',
        repository: repository,
        medicationRepository: medicationRepository(transport),
        attendanceRepository: attendanceRepository(transport),
        dashboardRepository: dashboardRepository(transport))));
    await tester.pumpAndSettle();
    expect(find.text('Đơn xin nghỉ mới — Bé An'), findsOneWidget);
    expect(find.text('Báo đi trễ mới — Bé Bình'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Báo đi trễ mới — Bé Bình')).dy,
        lessThan(tester.getTopLeft(find.text('Đơn xin nghỉ mới — Bé An')).dy));
    expect(find.byKey(const ValueKey('unread-newer')), findsOneWidget);
    await tester.tap(find.text('Báo đi trễ mới — Bé Bình'));
    await tester.pumpAndSettle();
    expect(find.byType(LeaveRequestReviewScreen), findsOneWidget);
    expect(
        tester
            .widget<LeaveRequestReviewScreen>(
                find.byType(LeaveRequestReviewScreen))
            .initialRequest
            ?.requestId,
        'newer');
    expect(find.text('Bé Bình'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread-newer')), findsNothing);
    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread-older')), findsNothing);
    await tester.tap(find.text('Thuốc'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo thuốc.'), findsOneWidget);
    expect(find.text('Đơn xin nghỉ mới — Bé An'), findsNothing);
    await tester.tap(find.text('Sự cố'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo sự cố.'), findsOneWidget);
    expect(transport.requests.every((r) => r.path.contains('/class/class-1')),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inbox lỗi tải không giả thành rỗng và thử lại được ở màn hẹp',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var failed = true;
    final transport = RequestTransport((_) => failed
        ? jsonBody({'detail': 'Mất kết nối'}, 503)
        : jsonBody({'pending_count': 0, 'reviewed_count': 0, 'items': []}));
    final repository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(app(
        TeacherNotificationsScreen(
            classId: 'class-1',
            repository: repository,
            medicationRepository: medicationRepository(transport),
            attendanceRepository: attendanceRepository(transport),
            dashboardRepository: dashboardRepository(transport)),
        textScale: 2,
        dark: true));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo.'), findsNothing);
    failed = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inbox shows class-scoped health, attendance and report data',
      (tester) async {
    final leaveTransport = RequestTransport((options) => jsonBody({
          'pending_count': 0,
          'reviewed_count': 0,
          'items': [],
        }));
    final sourceTransport = RequestTransport((options) {
      if (options.path == '/api/medication-requests') {
        expect(options.queryParameters['class_id'], 'class-1');
        return jsonBody([
          {
            'id': 'dose-1',
            'child_id': 'child-1',
            'class_id': 'class-1',
            'child_name': 'Bé An',
            'medicine_name': 'Siro ho',
            'dosage': '5ml',
            'status': 'pending',
            'created_at': '2026-11-09T08:00:00+07:00',
          }
        ]);
      }
      expect(options.path, '/api/teacher/health-incidents');
      expect(options.queryParameters['class_id'], 'class-1');
      return jsonBody([
        {
          'incident_id': 'incident-1',
          'child_id': 'child-2',
          'child_name': 'Bé Bình',
          'class_id': 'class-1',
          'incident_type': 'high_fever',
          'incident_type_label': 'Sốt cao',
          'description': 'Bé sốt cao khi ở lớp',
          'temperature': 39,
          'action_taken': null,
          'reported_at': '2026-11-09T09:00:00+07:00',
          'reported_by_name': 'Cô Mai',
        }
      ]);
    });
    final leaveRepository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = leaveTransport);
    final medicationRepository = HttpMedicationRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = sourceTransport);
    final attendanceRepository = HttpAttendanceRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = RequestTransport((options) => jsonBody({
                'class_id': 'class-1',
                'date': '2026-11-09',
                'total_children': 1,
                'present_count': 0,
                'absent_count': 0,
                'excused_absent_count': 0,
                'late_count': 1,
                'children': [
                  {
                    'child_id': 'child-3',
                    'full_name': 'Bé Chi',
                    'status': 'late',
                    'expected_arrival_time': '08:30:00',
                    'check_in_time': null,
                    'note': null,
                  }
                ],
              })));
    final dashboardRepository = HttpDashboardRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = RequestTransport((options) => jsonBody({
                'class_info': {
                  'class_id': 'class-1',
                  'school_id': 'school-1',
                  'name': 'Mầm 1',
                },
                'teacher_name': 'Cô Mai',
                'total_children': 5,
                'completed_count': 4,
                'draft_count': 0,
                'missing_count': 1,
                'pending_children': [
                  {
                    'child': {
                      'child_id': 'child-4',
                      'full_name': 'Gia Hân',
                    },
                    'status': null,
                  }
                ],
              })));

    await tester.pumpWidget(app(TeacherNotificationsScreen(
        classId: 'class-1',
        repository: leaveRepository,
        medicationRepository: medicationRepository,
        attendanceRepository: attendanceRepository,
        dashboardRepository: dashboardRepository)));
    await tester.pumpAndSettle();

    expect(find.text('Đơn thuốc mới — Bé An'), findsOneWidget);
    expect(find.textContaining('Siro ho · 5ml'), findsOneWidget);
    expect(find.text('Sự cố sức khỏe — Bé Bình'), findsOneWidget);
    expect(find.text('Điểm danh cập nhật — Bé Chi'), findsOneWidget);
    expect(find.textContaining('Đến trễ · ETA 08:30'), findsOneWidget);
    expect(find.text('Báo cáo ngày đã gửi 4/5'), findsOneWidget);
    expect(find.text('Còn Gia Hân chưa có báo cáo'), findsOneWidget);
    await tester.tap(find.text('Thuốc'));
    await tester.pumpAndSettle();
    expect(find.text('Đơn thuốc mới — Bé An'), findsOneWidget);
    expect(find.text('Sự cố sức khỏe — Bé Bình'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
