import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RequestTransport implements HttpClientAdapter {
  RequestTransport(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return await respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );

Map<String, dynamic> requestJson({String status = 'pending'}) => {
      'request_id': 'request-1',
      'child_id': 'child-1',
      'parent_id': 'parent-1',
      'class_id': 'class-1',
      'from_date': '2026-10-29',
      'to_date': '2026-10-29',
      'reason': 'Khám sức khỏe',
      'status': status,
      'created_at': '2026-10-28T10:00:00+07:00',
      'attachment_url': null,
      'reject_reason': null,
      'reviewed_by': null,
      'reviewed_at': null,
      'child_name': 'Nguyễn Minh An',
      'parent_name': 'Phụ huynh An',
      'reviewer_name': null,
    };

void main() {
  test('đọc contract mới và trạng thái cancelled không thành chờ duyệt', () {
    final data = {
      ...requestJson(status: 'cancelled'),
      'leave_id': 'canonical-request',
      'type': 'late',
      'expected_arrival_time': '08:30:00',
      'approved_by_name': 'Cô Mai',
      'action_at': '2026-10-29T06:30:00+07:00'
    };
    data.remove('request_id');
    data.remove('reviewer_name');
    final item = LeaveRequestEntity.fromJson(data);
    expect(item.requestId, 'canonical-request');
    expect(item.status.name, 'cancelled');
    expect(item.requestType, LeaveRequestType.lateArrival);
    expect(item.reviewerName, 'Cô Mai');
  });

  test(
      'server cũ không hỗ trợ thì không fallback tạo nhầm đơn trên endpoint cũ',
      () async {
    final transport = RequestTransport(
        (_) => jsonBody({'detail': 'Method Not Allowed'}, 405));
    final repo = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await expectLater(
        repo.createRequest(
            childId: 'child-1',
            classId: 'class-1',
            fromDate: DateTime(2026, 10, 29),
            toDate: DateTime(2026, 10, 29),
            reason: 'Khám buổi sáng',
            requestType: LeaveRequestType.lateArrival,
            expectedArrivalTime: '08:30:00'),
        throwsA(isA<LeaveRequestException>()
            .having((e) => e.code, 'code', 'backend_update_required')));
    expect(transport.requests, hasLength(1));
    expect(transport.requests.single.path, '/api/leave-requests/parent');
  });

  test('401 làm mới token để gửi lại ngay trong form, không replay POST',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = SessionManagementService.instance;
    await service.clearSession();
    addTearDown(service.clearSession);
    await service.saveSession(const AppSession(
        accessToken: 'expired-access',
        refreshToken: 'refresh-fixture',
        sessionId: 'request-session',
        role: 'parent'));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var refreshes = 0;
    server.listen((request) async {
      expect(request.uri.path, '/api/auth/refresh');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body['session_id'], 'request-session');
      refreshes++;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(
          {'access_token': 'fresh-access', 'refresh_token': 'fresh-refresh'}));
      await request.response.close();
    });
    final transport = RequestTransport((options) =>
        options.headers['Authorization'] == 'Bearer fresh-access'
            ? jsonBody(requestJson(), 201)
            : jsonBody({'detail': 'Access token expired'}, 401));
    final repo = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:${server.port}',
    ))
          ..httpClientAdapter = transport);
    Future<LeaveRequestEntity> submit() => repo.createRequest(
        childId: 'child-1',
        classId: 'class-1',
        fromDate: DateTime(2026, 10, 29),
        toDate: DateTime(2026, 10, 29),
        reason: 'Khám sức khỏe');

    await expectLater(submit(), throwsA(isA<LeaveRequestException>()));
    expect(transport.requests, hasLength(1),
        reason: 'Làm mới phiên không được tự gửi lại đơn');
    expect(service.currentSession?.accessToken, 'fresh-access');
    expect(refreshes, 1);
    expect((await submit()).requestId, 'request-1');
    expect(transport.requests, hasLength(2));
  });

  test('legacy DTO defaults to absence and late DTO preserves ETA and review',
      () {
    final old = LeaveRequestEntity.fromJson(requestJson());
    expect(old.requestType, LeaveRequestType.absence);
    expect(old.expectedArrivalTime, isNull);
    expect(old.mealWarningAcknowledged, isFalse);
    final late = LeaveRequestEntity.fromJson({
      ...requestJson(status: 'rejected'),
      'request_type': 'late_arrival',
      'expected_arrival_time': '08:30:00',
      'meal_warning_acknowledged': true,
      'reject_reason': 'Vui lòng cập nhật giờ dự kiến',
      'reviewed_by': 'teacher-1',
      'reviewer_name': 'Cô Hương',
      'reviewed_at': '2026-10-28T11:00:00+07:00',
    });
    expect(late.requestType, LeaveRequestType.lateArrival);
    expect(late.expectedArrivalTime, '08:30:00');
    expect(late.mealWarningAcknowledged, isTrue);
    expect(late.status, LeaveStatus.rejected);
    expect(late.reviewerName, 'Cô Hương');
    expect(late.rejectReason, 'Vui lòng cập nhật giờ dự kiến');
  });

  test('mine passes child, status and pagination; detail reads fresh DTO',
      () async {
    final transport =
        RequestTransport((options) => options.path.endsWith('/mine')
            ? jsonBody({
                'items': [requestJson()],
                'total': 24,
                'offset': 20,
                'limit': 20
              })
            : jsonBody(requestJson(status: 'approved')));
    final dio = Dio(BaseOptions(baseUrl: 'https://school.test'))
      ..httpClientAdapter = transport;
    final repository = HttpLeaveRequestRepository(dio: dio);
    final page = await repository.getMyRequests(
      childId: 'child-1',
      status: LeaveStatus.pending,
      offset: 20,
    );
    expect(transport.requests.first.path, '/api/leave-requests/mine');
    expect(transport.requests.first.queryParameters, {
      'child_id': 'child-1',
      'status': 'pending',
      'offset': 20,
      'limit': 20
    });
    expect(page.total, 24);
    expect(page.items.single.childId, 'child-1');
    final detail = await repository.getRequest('request-1');
    expect(transport.requests.last.path, '/api/leave-requests/request-1');
    expect(detail.status, LeaveStatus.approved);
    await repository.getMyRequests(childId: 'child-1');
    expect(
        transport.requests.last.queryParameters.containsKey('status'), isFalse);
  });

  test(
      'create sends date-only JSON, late type, ETA, trim and explicit acknowledgment',
      () async {
    final transport = RequestTransport((_) => jsonBody(requestJson(), 201));
    final dio = Dio(BaseOptions(
        baseUrl: 'https://school.test',
        headers: {'Authorization': 'Bearer offline-fixture'}))
      ..httpClientAdapter = transport;
    final repository = HttpLeaveRequestRepository(dio: dio);
    await repository.createRequest(
      childId: 'child-1',
      classId: 'class-1',
      fromDate: DateTime(2026, 10, 29),
      toDate: DateTime(2026, 10, 29),
      reason: '  Khám sức khỏe  ',
      requestType: LeaveRequestType.lateArrival,
      expectedArrivalTime: '08:30:00',
      mealWarningAcknowledged: true,
    );
    expect(transport.requests.single.method, 'POST');
    expect(transport.requests.single.path, '/api/leave-requests/parent');
    expect(transport.requests.single.headers['Authorization'],
        'Bearer offline-fixture');
    expect(transport.requests.single.data, {
      'child_id': 'child-1',
      'class_id': 'class-1',
      'from_date': '2026-10-29',
      'to_date': '2026-10-29',
      'reason': 'Khám sức khỏe',
      'attachment_url': null,
      'request_type': 'late_arrival',
      'expected_arrival_time': '08:30:00',
      'meal_warning_acknowledged': true,
    });
    await repository.createRequest(
      childId: 'child-1',
      classId: 'class-1',
      fromDate: DateTime(2026, 10, 29),
      toDate: DateTime(2026, 10, 30),
      reason: 'Nghỉ ốm',
    );
    expect(transport.requests.last.data['request_type'], 'absence');
    expect(transport.requests.last.data['expected_arrival_time'], isNull);
    expect(transport.requests.last.data['meal_warning_acknowledged'], isFalse);
  });

  test('upload accepts bytes not a local path and derives MIME from signature',
      () async {
    final transport = RequestTransport((_) => jsonBody({
          'attachment_url': '/api/leave-requests/attachments/child-1/image-1',
        }));
    final dio = Dio(BaseOptions(baseUrl: 'https://school.test'))
      ..httpClientAdapter = transport;
    final repository = HttpLeaveRequestRepository(dio: dio);
    final path = await repository.uploadAttachment(
        childId: 'child-1',
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]),
        fileName: 'scan.bin');
    expect(path, '/api/leave-requests/attachments/child-1/image-1');
    final options = transport.requests.single;
    expect(options.path, '/api/leave-requests/attachments');
    expect(options.queryParameters, {'child_id': 'child-1'});
    final file = (options.data as FormData).files.single;
    expect(file.key, 'file');
    expect(file.value.filename, 'scan.bin');
    expect(file.value.contentType.toString(), 'image/png');
    expect(file.value.length, 9);
    await expectLater(
        repository.uploadAttachment(
            childId: 'child-1',
            bytes: Uint8List.fromList(utf8.encode('not an image')),
            fileName: 'fake.jpg'),
        throwsA(isA<LeaveRequestException>()));
    await expectLater(
        repository.uploadAttachment(
            childId: 'child-1',
            bytes: Uint8List(5 * 1024 * 1024 + 1),
            fileName: 'huge.png'),
        throwsA(isA<LeaveRequestException>()));
    expect(transport.requests, hasLength(1));
  });

  test(
      'private attachment uses configured auth and rejects arbitrary URLs before HTTP',
      () async {
    final transport =
        RequestTransport((_) => ResponseBody.fromBytes([1, 2, 3], 200));
    final dio = Dio(BaseOptions(
        baseUrl: 'https://school.test',
        headers: {'Authorization': 'Bearer offline-fixture'}))
      ..httpClientAdapter = transport;
    final repository = HttpLeaveRequestRepository(dio: dio);
    expect(
        await repository.getAttachmentBytes(
            '/api/leave-requests/attachments/child-1/image-1'),
        Uint8List.fromList([1, 2, 3]));
    expect(transport.requests.single.headers['Authorization'],
        'Bearer offline-fixture');
    expect(transport.requests.single.responseType, ResponseType.bytes);
    expect(transport.requests.single.followRedirects, isFalse);
    for (final path in [
      'https://evil.test/image',
      '//evil.test/image',
      'https://school.test/api/leave-requests/attachments/child-1/image-1',
      '/api/leave-requests/attachments/child-1/../../auth',
      '/api/leave-requests/attachments/child-1/image-1?redirect=evil',
    ]) {
      await expectLater(repository.getAttachmentBytes(path),
          throwsA(isA<LeaveRequestException>()));
    }
    expect(transport.requests, hasLength(1));
  });

  test('meal warning is typed and POST errors are never automatically retried',
      () async {
    const warning =
        'Đơn gửi sau 7:30 vẫn có thể tính tiền ăn bán trú hôm nay. Bạn có đồng ý không';
    final transport = RequestTransport((_) => jsonBody({
          'detail': {'code': 'meal_warning_required', 'message': warning},
        }, 409));
    final dio = Dio(BaseOptions(baseUrl: 'https://school.test'))
      ..httpClientAdapter = transport;
    final repository = HttpLeaveRequestRepository(dio: dio);
    await expectLater(
        repository.createRequest(
            childId: 'child-1',
            classId: 'class-1',
            fromDate: DateTime(2026, 10, 29),
            toDate: DateTime(2026, 10, 29),
            reason: 'Nghỉ ốm'),
        throwsA(isA<LeaveRequestException>()
            .having((e) => e.code, 'code', 'meal_warning_required')
            .having((e) => e.message, 'message', warning)
            .having((e) => e.statusCode, 'status', 409)));
    expect(transport.requests, hasLength(1));
    transport.requests.clear();
    dio.httpClientAdapter =
        RequestTransport((_) => jsonBody({'detail': 'Hết phiên'}, 401));
    await expectLater(
        repository.createRequest(
            childId: 'child-1',
            classId: 'class-1',
            fromDate: DateTime(2026, 10, 29),
            toDate: DateTime(2026, 10, 29),
            reason: 'Nghỉ ốm'),
        throwsA(isA<LeaveRequestException>()
            .having((e) => e.statusCode, 'status', 401)));
    expect((dio.httpClientAdapter as RequestTransport).requests, hasLength(1));
  });

  test(
      'string detail, 422 lists and non-JSON errors never cause Map casting crashes',
      () async {
    for (final data in [
      {'detail': 'Không có quyền truy cập'},
      {
        'detail': [
          {
            'loc': ['body', 'reason'],
            'msg': 'Lý do quá ngắn',
            'type': 'value_error'
          }
        ]
      },
      'upstream unavailable',
    ]) {
      final dio = Dio(BaseOptions(baseUrl: 'https://school.test'))
        ..httpClientAdapter = RequestTransport((_) => jsonBody(data, 422));
      await expectLater(
          HttpLeaveRequestRepository(dio: dio).getRequest('request-1'),
          throwsA(isA<LeaveRequestException>()
              .having((e) => e.message, 'safe message', isNotEmpty)));
    }
  });

  test('business errors expose the server message, not a serialized map',
      () async {
    const warning =
        'Đơn gửi sau 7:30 vẫn có thể tính tiền ăn bán trú hôm nay. Bạn có đồng ý không';
    final dio = Dio(BaseOptions(baseUrl: 'https://school.test'));
    dio.httpClientAdapter = RequestTransport((_) => jsonBody({
          'detail': {'code': 'meal_warning_required', 'message': warning},
        }, 409));
    final repository = HttpLeaveRequestRepository(dio: dio);

    await expectLater(
      repository.getLeaveRequests(classId: 'class-1', tab: 'pending'),
      throwsA(predicate((Object e) => e.toString() == warning)),
    );
  });
}
