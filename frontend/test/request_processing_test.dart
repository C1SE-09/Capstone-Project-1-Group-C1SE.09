import 'dart:async';

import 'package:adark_frontend/core/utils/phone_utils.dart';
import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_detail_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/leave_request_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'parent_request_repository_test.dart'
    show RequestTransport, jsonBody, requestJson;
import 'parent_requests_test.dart' show app, child;
import 'parent_medication_test.dart' show tapVisible;

HttpLeaveRequestRepository repo(RequestTransport transport) =>
    HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
Map<String, dynamic> cancellable({bool allowed = true}) => {
      ...requestJson(),
      'from_date': '2030-01-05',
      'to_date': '2030-01-05',
      'can_cancel': allowed,
      'cancel_before': '2030-01-05T07:30:00+07:00',
      'cancel_block_reason':
          allowed ? null : 'Đã quá hạn hủy, vui lòng liên hệ giáo viên'
    };

void main() {
  testWidgets(
      'cancel locks rapid taps and confirmed result needs no follow-up read',
      (tester) async {
    final pending = Completer<ResponseBody>();
    var written = false;
    final transport = RequestTransport((request) {
      if (request.method == 'POST') {
        written = true;
        return pending.future;
      }
      if (written) return jsonBody({'detail': 'Lịch sử tạm gián đoạn'}, 503);
      return jsonBody(cancellable());
    });
    await tester.pumpWidget(app(ParentRequestDetailScreen(
        requestId: 'request-1',
        child: child,
        className: 'Mầm 1',
        repository: repo(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Hủy đơn này'));
    final confirm = find.widgetWithText(FilledButton, 'Hủy đơn');
    final target = tester.getCenter(confirm);
    await tester.tapAt(target);
    await tester.tapAt(target);
    await tester.pump();
    pending.complete(jsonBody({
      'success': true,
      'leave_id': 'request-1',
      'status': 'cancelled',
      'rollbacked_attendance': true
    }));
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy đơn'), findsOneWidget);
    expect(find.textContaining('khi chưa check-in'), findsOneWidget);
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'uncertain cancellation keeps detail and asks to reload instead of claiming success',
      (tester) async {
    final transport = RequestTransport((request) {
      if (request.method == 'POST') {
        throw DioException(
            requestOptions: request, type: DioExceptionType.receiveTimeout);
      }
      return jsonBody(cancellable());
    });
    await tester.pumpWidget(app(ParentRequestDetailScreen(
        requestId: 'request-1',
        child: child,
        className: 'Mầm 1',
        repository: repo(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Hủy đơn này'));
    await tapVisible(tester, find.text('Hủy đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy đơn'), findsNothing);
    expect(find.textContaining('hãy tải lại'), findsOneWidget);
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
  });
  test(
      'telephone normalization never permits call-control or injected URI schemes',
      () {
    expect(phoneCallUri('0905 123 123')?.toString(), 'tel:0905123123');
    expect(phoneCallUri('+84 (905) 123-123')?.toString(), 'tel:+84905123123');
    for (final invalid in [
      '*21*0905123123#',
      'javascript:alert(1)',
      'tel:0905123123',
      '12'
    ]) {
      expect(phoneCallUri(invalid), isNull);
    }
    expect(maskedPhone('0905123123'), '0905 ••• 123');
  });

  testWidgets(
      'parent cancel keep does nothing, confirm uses server proof and truthful attendance copy',
      (tester) async {
    var cancelled = false;
    final transport = RequestTransport((request) {
      if (request.method == 'POST') {
        cancelled = true;
        return jsonBody({
          'success': true,
          'leave_id': 'request-1',
          'status': 'cancelled',
          'rollbacked_attendance': false
        });
      }
      return jsonBody({
        ...cancellable(),
        'status': cancelled ? 'cancelled' : 'pending',
        'can_cancel': !cancelled
      });
    });
    await tester.pumpWidget(app(ParentRequestDetailScreen(
        requestId: 'request-1',
        child: child,
        className: 'Mầm 1',
        repository: repo(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Hủy đơn này'));
    await tapVisible(tester, find.text('Giữ đơn'));
    expect(transport.requests.where((r) => r.method == 'POST'), isEmpty);
    await tapVisible(tester, find.text('Hủy đơn này'));
    await tapVisible(tester, find.text('Hủy đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy đơn'), findsOneWidget);
    expect(find.textContaining('Điểm danh thực tế được giữ nguyên'),
        findsOneWidget);
    expect(find.textContaining('trở lại trạng thái "chưa điểm danh"'),
        findsNothing);
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'server cutoff wins over device clock and stale eligibility is refreshed after refusal',
      (tester) async {
    var refused = false;
    final transport = RequestTransport((request) {
      if (request.method == 'POST') {
        refused = true;
        return jsonBody({'detail': 'Đã quá hạn hủy'}, 400);
      }
      return jsonBody(cancellable(allowed: !refused));
    });
    await tester.pumpWidget(app(ParentRequestDetailScreen(
        requestId: 'request-1',
        child: child,
        className: 'Mầm 1',
        repository: repo(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Hủy đơn này'));
    await tapVisible(tester, find.text('Hủy đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy đơn'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Hủy đơn này'))
            .onPressed,
        isNull);
    expect(find.textContaining('Đã quá hạn hủy'), findsWidgets);
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  testWidgets(
      'reject requires two to five hundred characters and preserves reason after network error',
      (tester) async {
    final transport = RequestTransport((request) {
      if (request.method == 'POST') {
        return jsonBody({'detail': 'Tạm thời gián đoạn'}, 503);
      }
      return jsonBody({
        'pending_count': 1,
        'reviewed_count': 0,
        'items': [requestJson()]
      });
    });
    await tester.pumpWidget(app(LeaveRequestReviewScreen(
        classId: 'class-1', className: 'Mầm 1', repository: repo(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Từ chối'));
    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Gửi từ chối'))
            .onPressed,
        isNull);
    await tester.enterText(
        find.byType(TextField), 'Vui lòng bổ sung thông tin');
    await tapVisible(tester, find.text('Gửi từ chối'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Từ chối'));
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Vui lòng bổ sung thông tin');
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  testWidgets('teacher changes class without accepting old pending response',
      (tester) async {
    final old = Completer<ResponseBody>();
    final transport = RequestTransport((request) {
      if (request.path.endsWith('/class/class-1')) return old.future;
      return jsonBody({'pending_count': 0, 'reviewed_count': 0, 'items': []});
    });
    final repository = repo(transport);
    await tester.pumpWidget(app(
        LeaveRequestReviewScreen(classId: 'class-1', repository: repository)));
    await tester.pump();
    await tester.pumpWidget(app(
        LeaveRequestReviewScreen(classId: 'class-2', repository: repository)));
    await tester.pump();
    old.complete(jsonBody({
      'pending_count': 1,
      'reviewed_count': 0,
      'items': [requestJson()]
    }));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Minh An'), findsNothing);
    expect(transport.requests.any((r) => r.path.endsWith('/class/class-2')),
        isTrue);
  });
}
