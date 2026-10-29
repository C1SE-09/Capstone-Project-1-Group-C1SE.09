import 'dart:async';

import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_form_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_detail_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parent_medication_repository_test.dart'
    show medicationJson, medicationRepository;
import 'parent_medication_test.dart' show selectedImage, tapVisible;
import 'parent_request_repository_test.dart' show RequestTransport, jsonBody;
import 'parent_requests_test.dart' show app, child;
import 'teacher_medication_flow_test.dart' show todayJson;

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  test('missing or string dose state and mismatched given totals fail closed',
      () async {
    for (final state in [null, 'true', true]) {
      final body = todayJson(given: true);
      final item = (body['morning'] as List).single as Map<String, dynamic>;
      if (state == null) {
        item.remove('is_given');
      } else {
        item['is_given'] = state;
      }
      if (state == true) {
        body['completed_count'] = 0;
        body['pending_count'] = 1;
      }
      final transport = RequestTransport((_) => jsonBody(body));
      await expectLater(
          medicationRepository(transport).getTodayMedications(),
          throwsA(isA<MedicationRequestException>()
              .having((e) => e.code, 'code', 'invalid_response')));
    }
  });

  testWidgets(
      'same child moving to another class invalidates the open medication draft',
      (tester) async {
    final repo = medicationRepository(
        RequestTransport((_) => throw StateError('No request expected')));
    await tester.pumpWidget(app(ParentMedicationFormScreen(
        child: child, className: 'Lớp cũ', repository: repo)));
    await tester.enterText(find.byType(TextFormField).at(1), 'Theo đơn');
    await tester.pumpWidget(app(ParentMedicationFormScreen(
        child: Child(
            childId: child.childId,
            classId: 'class-2',
            fullName: child.fullName),
        className: 'Lớp mới',
        repository: repo)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gửi đơn dặn thuốc'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Gửi đơn dặn thuốc'))
            .onPressed,
        isNull);
    expect(
        find.textContaining('Hồ sơ bé đang soạn đã thay đổi'), findsOneWidget);
  });

  testWidgets(
      'form sends its class snapshot and lets server accept a date behind the device clock',
      (tester) async {
    final transport = RequestTransport((request) {
      if (request.path.endsWith('/attachments')) {
        return jsonBody({
          'prescription_image_url':
              '/api/medication-requests/attachments/child-1/image-1'
        }, 201);
      }
      final body = request.data as Map;
      return jsonBody({
        'batch_id': 'batch-1',
        'total_slots': 1,
        'items': [
          {
            ...medicationJson(),
            'request_date': body['from_date'],
            'start_date': body['from_date'],
            'end_date': body['to_date']
          }
        ]
      }, 201);
    });
    await tester.pumpWidget(app(ParentMedicationFormScreen(
        child: child,
        className: 'Mầm1',
        repository: medicationRepository(transport),
        imagePicker: selectedImage())));
    await tester.enterText(find.byType(TextFormField).at(1), 'Theo đơn');
    await tapVisible(tester, find.widgetWithText(ChoiceChip, '08:30'));
    await tapVisible(tester, find.text('+ Thêm ảnh đơn thuốc'));
    await tapVisible(tester, find.byTooltip('Từ ngày'));
    final picker =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    final serverToday = picker.initialDate!.subtract(const Duration(days: 1));
    expect(picker.firstDate.isAfter(serverToday), isFalse);
    picker.onDateChanged(serverToday);
    await tapVisible(tester, find.text('Xong'));
    await tapVisible(tester, find.byTooltip('Đến ngày'));
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(serverToday);
    await tapVisible(tester, find.text('Xong'));
    await tapVisible(tester, find.text('Gửi đơn dặn thuốc'));
    await tester.pumpAndSettle();
    final create = transport.requests
        .singleWhere((r) => r.path == '/api/medication-requests');
    expect((create.data as Map)['expected_class_id'], child.classId);
    expect((create.data as Map)['from_date'],
        '${serverToday.year}-${serverToday.month.toString().padLeft(2, '0')}-${serverToday.day.toString().padLeft(2, '0')}');
    expect(find.text('Đã tạo đơn dặn thuốc'), findsOneWidget);
  });

  testWidgets(
      'context switch during cancellation unlocks the new batch and ignores the old result',
      (tester) async {
    final cancel = Completer<ResponseBody>();
    final transport = RequestTransport((request) {
      if (request.method == 'POST') return cancel.future;
      return jsonBody([
        {
          ...medicationJson(),
          'prescription_image_url': null,
          'child_id': request.queryParameters['child_id'],
          'batch_id': request.queryParameters['batch_id']
        }
      ]);
    });
    final repo = medicationRepository(transport);
    await tester.pumpWidget(app(ParentMedicationDetailScreen(
        child: child,
        className: 'Mầm1',
        batchId: 'batch-1',
        repository: repo)));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Hủy cữ này'));
    await tapVisible(tester, find.text('Hủy cữ'));
    await tester.pumpWidget(app(ParentMedicationDetailScreen(
        child: const Child(
            childId: 'child-2', classId: 'class-2', fullName: 'Bé mới'),
        className: 'Mầm2',
        batchId: 'batch-2',
        repository: repo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Hủy cữ này'));
    expect(button.onPressed, isNotNull);
    cancel.complete(jsonBody(medicationJson(status: 'cancelled')));
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy'), findsNothing);
    expect(transport.requests.where((r) => r.method == 'GET'), hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
