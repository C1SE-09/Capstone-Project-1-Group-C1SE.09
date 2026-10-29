import 'dart:async';
import 'dart:convert';

import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_form_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_detail_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'parent_request_repository_test.dart'
    show RequestTransport, jsonBody, requestJson;

const child =
    Child(childId: 'child-1', classId: 'class-1', fullName: 'Nguyễn Minh An');
const warning =
    'Đơn gửi sau 7:30 vẫn có thể tính tiền ăn bán trú hôm nay. Bạn có đồng ý không';

class GalleryPicker extends ImagePicker {
  XFile? file;

  @override
  Future<XFile?> pickImage(
          {required ImageSource source,
          double? maxWidth,
          double? maxHeight,
          int? imageQuality,
          CameraDevice preferredCameraDevice = CameraDevice.rear,
          bool requestFullMetadata = true}) async =>
      file;
}

HttpLeaveRequestRepository repository(RequestTransport transport) =>
    HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);

Widget app(Widget screen, {double textScale = 1, bool dark = false}) =>
    MaterialApp(
      theme: dark ? kinderThemeDark() : kinderTheme(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('vi'), Locale('en')],
      locale: const Locale('vi'),
      builder: (context, page) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: page!,
      ),
      home: screen,
    );

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
      'đơn đã hủy không bị hiển thị thành chờ duyệt hoặc giáo viên từ chối',
      (tester) async {
    final cancelled = {
      ...requestJson(status: 'cancelled'),
      'approved_by_name': 'Cô Mai',
      'action_at': '2026-10-29T06:30:00+07:00'
    };
    final transport =
        RequestTransport((options) => options.path.endsWith('/mine')
            ? jsonBody({
                'items': [cancelled],
                'total': 1,
                'offset': 0,
                'limit': 20
              })
            : jsonBody(cancelled));
    await tester.pumpWidget(app(ParentRequestsScreen(
        child: child,
        className: 'Mầm 1',
        teacherName: 'Cô Mai',
        repository: repository(transport))));
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy'), findsWidgets);
    expect(find.textContaining('Phụ huynh đã hủy đơn'), findsOneWidget);
    await tapVisible(tester, find.text('Nghỉ học'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết đơn'), findsOneWidget);
    expect(find.textContaining('Phụ huynh đã hủy đơn'), findsWidgets);
    expect(find.text('Giáo viên đã từ chối'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'history filters and pagination use this child, and detail fetches fresh review',
      (tester) async {
    final transport = RequestTransport((options) {
      if (!options.path.endsWith('/mine')) {
        return jsonBody({
          ...requestJson(status: 'rejected'),
          'reject_reason': 'Vui lòng ghi rõ thời gian',
          'reviewer_name': 'Cô Hương',
          'reviewed_by': 'teacher-1',
          'reviewed_at': '2026-10-28T11:30:00+07:00'
        });
      }
      final query = options.queryParameters;
      return jsonBody({
        'items': [
          {
            ...requestJson(),
            'request_id': query['offset'] == 0 ? 'request-1' : 'request-2',
            'status': query['status'] ?? 'pending',
          }
        ],
        'total': query['status'] == null ? 2 : 1,
        'offset': query['offset'],
        'limit': 20
      });
    });
    await tester.pumpWidget(app(ParentRequestsScreen(
        child: child,
        className: 'Lớp Mầm 1',
        teacherName: 'Cô Hương',
        repository: repository(transport))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nguyễn Minh An'), findsOneWidget);
    expect(transport.requests.single.queryParameters['child_id'], 'child-1');
    await tapVisible(tester, find.text('Tải thêm'));
    expect(transport.requests.last.queryParameters['offset'], 1);
    expect(find.text('Nghỉ học'), findsNWidgets(2));
    for (final entry
        in {'Chờ duyệt': 'pending', 'Từ chối': 'rejected'}.entries) {
      await tapVisible(tester, find.text(entry.key).first);
      expect(transport.requests.last.queryParameters['status'], entry.value);
      expect(transport.requests.last.queryParameters['child_id'], 'child-1');
    }
    await tapVisible(tester, find.text('Đã duyệt').first);
    expect(transport.requests.last.queryParameters['status'], 'approved');
    expect(transport.requests.last.queryParameters['offset'], 0);
    await tapVisible(tester, find.text('Nghỉ học'));
    expect(transport.requests.last.path, '/api/leave-requests/request-1');
    expect(find.text('Chi tiết đơn'), findsOneWidget);
    expect(find.textContaining('Vui lòng ghi rõ thời gian'), findsOneWidget);
    expect(find.textContaining('Cô Hương'), findsWidgets);
    expect(find.textContaining('Đã ghi Nghỉ có phép'), findsNothing);
  });

  testWidgets('history error retries and an empty result remains truthful',
      (tester) async {
    var fail = true;
    final transport = RequestTransport((_) => fail
        ? jsonBody({'detail': 'Không thể tải danh sách đơn'}, 503)
        : jsonBody({'items': [], 'total': 0, 'offset': 0, 'limit': 20}));
    await tester.pumpWidget(app(ParentRequestsScreen(
        child: child,
        className: 'Lớp Mầm 1',
        teacherName: '',
        repository: repository(transport))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không thể tải danh sách đơn'), findsOneWidget);
    fail = false;
    await tapVisible(tester, find.text('Thử lại'));
    expect(find.text('Chưa có đơn nào'), findsOneWidget);
    expect(find.text('TẠO ĐƠN MỚI'), findsOneWidget);
    expect(transport.requests, hasLength(2));
    await tapVisible(tester, find.byTooltip('Tạo đơn mới'));
    expect(find.text('Tạo đơn xin nghỉ'), findsOneWidget);
  });

  testWidgets(
      'absence validates trimmed reason and cancel keeps form; agree resends identical values once',
      (tester) async {
    final posts = <Map<String, dynamic>>[];
    final gate = Completer<ResponseBody>();
    final transport = RequestTransport((options) {
      final data = Map<String, dynamic>.from(options.data as Map);
      posts.add(data);
      if (data['meal_warning_acknowledged'] == true) return gate.future;
      return jsonBody({
        'detail': {'code': 'meal_warning_required', 'message': warning}
      }, 409);
    });
    await tester.pumpWidget(app(ParentRequestFormScreen(
        child: child,
        className: 'Lớp Mầm 1',
        teacherName: 'Cô Hương',
        repository: repository(transport))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  a  ');
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    expect(find.textContaining('ít nhất 3 ký tự'), findsOneWidget);
    expect(posts, isEmpty);
    await tester.enterText(find.byType(TextFormField), '  Khám sức khỏe  ');
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    expect(find.text(warning), findsOneWidget);
    await tapVisible(tester, find.text('Hủy'));
    expect(posts, hasLength(1));
    expect(find.text('  Khám sức khỏe  '), findsOneWidget);
    expect(find.text('Đã gửi đơn thành công'), findsNothing);
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    await tester.tap(find.text('Đồng ý'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(posts, hasLength(3));
    expect(posts[2], {...posts[0], 'meal_warning_acknowledged': true});
    expect(posts[0]['reason'], 'Khám sức khỏe');
    expect(posts[0]['from_date'], posts[0]['to_date']);
    expect(posts[0]['request_type'], 'absence');
    expect(posts[0]['attachment_url'], isNull);
    await tester.tap(find.text('GỬI ĐƠN'));
    await tester.pump();
    expect(posts, hasLength(3));
    gate.complete(jsonBody({...requestJson(), ...posts[2]}, 201));
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi đơn thành công'), findsOneWidget);
    expect(find.textContaining('chưa được duyệt'), findsOneWidget);
    expect(find.text('XEM ĐƠN CỦA TÔI'), findsOneWidget);
    expect(find.text('Về trang chủ'), findsOneWidget);
  });

  testWidgets(
      'network and overlap errors keep form and do not automatically resend',
      (tester) async {
    var offline = true;
    final transport = RequestTransport((options) {
      if (offline) {
        throw DioException(
            requestOptions: options, type: DioExceptionType.connectionError);
      }
      return jsonBody({
        'detail': {
          'code': 'overlapping_request',
          'message': 'Bé đã có đơn trong khoảng ngày này.'
        }
      }, 409);
    });
    await tester.pumpWidget(app(ParentRequestFormScreen(
        child: child,
        className: 'Lớp Mầm 1',
        teacherName: '',
        repository: repository(transport))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Lý do được giữ lại');
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    expect(find.textContaining('Mất kết nối'), findsOneWidget);
    expect(find.text('Lý do được giữ lại'), findsOneWidget);
    expect(transport.requests, hasLength(1));
    offline = false;
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    expect(find.text('Bé đã có đơn trong khoảng ngày này.'), findsOneWidget);
    expect(find.text('Xem lịch sử đơn'), findsOneWidget);
    expect(transport.requests, hasLength(2));
  });

  testWidgets(
      'late arrival has single date, quick ETAs and Material picker, never says arrived',
      (tester) async {
    final transport = RequestTransport((options) => jsonBody({
          ...requestJson(),
          ...Map<String, dynamic>.from(options.data as Map),
        }, 201));
    await tester.pumpWidget(app(ParentRequestFormScreen(
        child: child,
        className: 'Lớp Mầm 1',
        teacherName: '',
        repository: repository(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Báo đi trễ'));
    expect(find.text('Đến ngày'), findsNothing);
    for (final time in ['07:45', '08:00', '08:30', '09:00']) {
      expect(find.text(time), findsWidgets);
    }
    await tapVisible(tester, find.text('Chọn giờ'));
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tapVisible(tester, find.text('Hủy'));
    await tapVisible(tester, find.text('Chọn ngày'));
    final calendar =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    final tomorrow =
        DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    expect(calendar.firstDate, DateUtils.dateOnly(DateTime.now()));
    calendar.onDateChanged(tomorrow);
    await tester.pump();
    await tapVisible(tester, find.text('OK'));
    await tapVisible(tester, find.text('09:00'));
    await tester.enterText(find.byType(TextFormField), 'Khám buổi sáng');
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    await tester.pumpAndSettle();
    final body = transport.requests.single.data as Map;
    expect(body['request_type'], 'late_arrival');
    expect(body['expected_arrival_time'], '09:00:00');
    expect(body['from_date'], body['to_date']);
    expect(find.text('Đã gửi đơn thành công'), findsOneWidget);
    expect(find.textContaining('đã đến lớp'), findsNothing);
    expect(find.textContaining('đã điểm danh'), findsNothing);
  });

  testWidgets('native back asks before discarding unsaved input',
      (tester) async {
    final repo = repository(RequestTransport((_) => jsonBody(requestJson())));
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => ParentRequestFormScreen(
                              child: child,
                              className: 'Mầm 1',
                              teacherName: '',
                              repository: repo))),
                  child: const Text('Mở form')),
            ))));
    await tapVisible(tester, find.text('Mở form'));
    await tester.enterText(find.byType(TextFormField), 'Nội dung chưa gửi');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);
    await tapVisible(tester, find.text('Tiếp tục soạn'));
    expect(find.text('Nội dung chưa gửi'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Bỏ thay đổi'));
    expect(find.text('Mở form'), findsOneWidget);
  });

  testWidgets(
      'multi-day picker caps range, rejects >1000 chars, and future dates do not show a client meal warning',
      (tester) async {
    final transport = RequestTransport((options) => jsonBody({
          ...requestJson(),
          ...Map<String, dynamic>.from(options.data as Map),
        }, 201));
    await tester.pumpWidget(app(ParentRequestFormScreen(
        child: child,
        className: 'Mầm 1',
        teacherName: '',
        repository: repository(transport))));
    await tester.pumpAndSettle();
    final tomorrow =
        DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    await tapVisible(tester, find.text('Chọn ngày').first);
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(tomorrow);
    await tapVisible(tester, find.text('OK'));
    await tapVisible(tester, find.text('Chọn ngày').last);
    final endPicker =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(endPicker.firstDate, tomorrow);
    expect(endPicker.lastDate.difference(tomorrow).inDays, 365);
    endPicker.onDateChanged(tomorrow.add(const Duration(days: 1)));
    await tapVisible(tester, find.text('OK'));
    expect(find.text('Tổng thời gian nghỉ: 2 ngày'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'x' * 1001);
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    expect(find.text('Lý do tối đa 1000 ký tự.'), findsOneWidget);
    expect(transport.requests, isEmpty);
    await tester.enterText(
        find.byType(TextFormField), 'Gia đình có việc riêng');
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    await tester.pumpAndSettle();
    expect(transport.requests, hasLength(1));
    expect(
        transport.requests.single.data['meal_warning_acknowledged'], isFalse);
    expect(transport.requests.single.data['from_date'],
        isNot(transport.requests.single.data['to_date']));
    expect(find.text(warning), findsNothing);
    expect(find.text('Đã gửi đơn thành công'), findsOneWidget);
  });

  testWidgets(
      'optional gallery image uploads only on submit and uses the private path in JSON',
      (tester) async {
    final picker = GalleryPicker();
    final transport = RequestTransport((options) => options.path
            .endsWith('/attachments')
        ? jsonBody({
            'attachment_url': '/api/leave-requests/attachments/child-1/image-1'
          })
        : jsonBody({
            ...requestJson(),
            ...Map<String, dynamic>.from(options.data as Map)
          }, 201));
    await tester.pumpWidget(app(ParentRequestFormScreen(
        child: child,
        className: 'Mầm 1',
        teacherName: '',
        repository: repository(transport),
        imagePicker: picker)));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('+ Thêm ảnh giấy khám / đơn thuốc'));
    expect(find.byTooltip('Xóa ảnh đính kèm'), findsNothing);
    picker.file = XFile.fromData(
        base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg=='),
        name: 'medical.png');
    await tapVisible(tester, find.text('+ Thêm ảnh giấy khám / đơn thuốc'));
    expect(find.byTooltip('Xóa ảnh đính kèm'), findsOneWidget);
    expect(transport.requests, isEmpty);
    await tester.enterText(find.byType(TextFormField), 'Bé đi khám định kỳ');
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    await tester.pumpAndSettle();
    expect(transport.requests.map((e) => e.path), [
      '/api/leave-requests/attachments',
      '/api/leave-requests/parent',
    ]);
    expect(transport.requests.last.data['attachment_url'],
        '/api/leave-requests/attachments/child-1/image-1');
    expect(find.text('Đã gửi đơn thành công'), findsOneWidget);
  });

  testWidgets(
      'submitted history refreshes and home returns to the actual parent route',
      (tester) async {
    var created = 0;
    final transport = RequestTransport((options) {
      if (options.method == 'POST') {
        created++;
        return jsonBody({
          ...requestJson(),
          ...Map<String, dynamic>.from(options.data as Map)
        }, 201);
      }
      return jsonBody({
        'items': created == 0 ? [] : [requestJson()],
        'total': created == 0 ? 0 : 1,
        'offset': 0,
        'limit': 20
      });
    });
    final repo = repository(transport);
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => ParentRequestsScreen(
                            child: child,
                            className: 'Mầm 1',
                            teacherName: '',
                            repository: repo))),
                child: const Text('Trang chủ thật'))))));
    await tapVisible(tester, find.text('Trang chủ thật'));
    await tapVisible(tester, find.text('TẠO ĐƠN MỚI'));
    await tester.enterText(find.byType(TextFormField), 'Khám sức khỏe');
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('XEM ĐƠN CỦA TÔI'));
    await tester.pumpAndSettle();
    expect(find.text('Nghỉ học'), findsOneWidget);
    expect(find.text('Xin phép nghỉ / báo trễ'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Tạo đơn mới'));
    await tester.enterText(find.byType(TextFormField), 'Khám sức khỏe lần sau');
    await tapVisible(tester, find.text('GỬI ĐƠN'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Về trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ thật'), findsOneWidget);
    expect(find.text('Xin phép nghỉ / báo trễ'), findsNothing);
  });

  testWidgets('switching children discards an older history response',
      (tester) async {
    final old = Completer<ResponseBody>();
    final transport = RequestTransport((options) async =>
        options.queryParameters['child_id'] == 'child-1'
            ? await old.future
            : jsonBody({'items': [], 'total': 0, 'offset': 0, 'limit': 20}));
    final repo = repository(transport);
    await tester.pumpWidget(app(ParentRequestsScreen(
        child: child, className: 'Mầm 1', teacherName: '', repository: repo)));
    await tester.pump();
    await tester.pumpWidget(app(ParentRequestsScreen(
        child: const Child(
            childId: 'child-2', classId: 'class-2', fullName: 'Bé Bình'),
        className: 'Chồi 2',
        teacherName: '',
        repository: repo)));
    await tester.pumpAndSettle();
    old.complete(jsonBody({
      'items': [requestJson()],
      'total': 1,
      'offset': 0,
      'limit': 20
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bé Bình'), findsOneWidget);
    expect(find.text('Chưa có đơn nào'), findsOneWidget);
    expect(find.text('Nghỉ học'), findsNothing);
    expect(find.textContaining('Nguyễn Minh An'), findsNothing);
  });

  testWidgets(
      'private attachment errors can retry through repository rather than an unauthenticated image URL',
      (tester) async {
    var reads = 0;
    final transport = RequestTransport((options) {
      if (options.path.contains('/attachments/')) {
        reads++;
        if (reads == 1) {
          return jsonBody({'detail': 'Storage tạm thời gián đoạn'}, 503);
        }
        return ResponseBody.fromBytes(
            base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg=='),
            200);
      }
      return jsonBody({
        ...requestJson(),
        'attachment_url': '/api/leave-requests/attachments/child-1/image-1'
      });
    });
    await tester.pumpWidget(app(ParentRequestDetailScreen(
        requestId: 'request-1',
        child: child,
        className: 'Mầm 1',
        repository: repository(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.bySemanticsLabel('Ảnh y tế đính kèm đơn'), findsOneWidget);
    expect(transport.requests.last.responseType, ResponseType.bytes);
  });

  testWidgets(
      'detail retries API errors and shows actual late review without attendance claims',
      (tester) async {
    var fail = true;
    final transport = RequestTransport((_) => fail
        ? jsonBody({'detail': 'Không thể tải chi tiết đơn'}, 503)
        : jsonBody({
            ...requestJson(status: 'approved'),
            'request_type': 'late_arrival',
            'expected_arrival_time': '08:30:00',
            'reviewer_name': 'Cô Hương',
            'reviewed_at': '2026-10-28T11:00:00+07:00'
          }));
    await tester.pumpWidget(app(ParentRequestDetailScreen(
        requestId: 'request-1',
        child: child,
        className: 'Mầm 1',
        repository: repository(transport))));
    await tester.pumpAndSettle();
    fail = false;
    await tapVisible(tester, find.text('Thử lại'));
    expect(find.text('Báo đi trễ'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Tiến trình xử lý'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('không thay thế điểm danh'), 200);
    expect(find.textContaining('không thay thế điểm danh'), findsOneWidget);
    expect(find.textContaining('Đã đến lớp'), findsNothing);
    expect(transport.requests, hasLength(2));
  });

  testWidgets(
      'narrow large-text dark form scrolls without overflow; wide history stays <=480',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = repository(RequestTransport(
        (_) => jsonBody({'items': [], 'total': 0, 'offset': 0, 'limit': 20})));
    await tester.pumpWidget(app(
        ParentRequestFormScreen(
            child: child,
            className: 'Lớp Mầm với tên rất dài',
            teacherName: 'Cô chủ nhiệm có tên dài',
            repository: repo),
        textScale: 2,
        dark: true));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Đơn với chữ lớn');
    await tester.ensureVisible(find.text('GỬI ĐƠN'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(app(ParentRequestsScreen(
        child: child, className: 'Mầm 1', teacherName: '', repository: repo)));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Scaffold)).width, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);
  });
}
