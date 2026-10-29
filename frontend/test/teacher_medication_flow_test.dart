import 'dart:async';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_medication_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parent_medication_repository_test.dart' show medicationRepository;
import 'parent_request_repository_test.dart' show RequestTransport, jsonBody;
import 'parent_requests_test.dart' show app;

Map<String, dynamic> todayJson(
        {bool given = false,
        bool audit = true,
        String date = '2030-01-05',
        bool empty = false}) =>
    {
      'date': date,
      'class_id': 'class-1',
      'class_name': 'Mầm 1',
      'total_requests': empty ? 0 : 1,
      'completed_count': given && !empty ? 1 : 0,
      'pending_count': !given && !empty ? 1 : 0,
      'morning': [
        if (!empty)
          {
            'request_id': 'dose-1',
            'child_id': 'child-1',
            'child_name': 'Bảo Châu',
            'medication_name': 'Thuốc theo hướng dẫn',
            'dosage': '5ml',
            'session': 'morning',
            'time_slot': '08:30',
            'request_date': date,
            'is_given': given,
            'given_by_name': given && audit ? 'Cô Mai' : null,
            'given_by_id': given && audit ? 'teacher-1' : null,
            'given_at': given && audit ? '${date}T01:32:00Z' : null,
            'notes': 'Theo chỉ dẫn trên đơn',
            'instructions': null,
          }
      ],
      'noon': [],
      'afternoon': [],
    };

void main() {
  testWidgets(
      'server500 uses friendly error copy and retry without losing the new layout',
      (tester) async {
    final transport = RequestTransport(
        (_) => jsonBody({'detail': 'Internal Server Error'}, 500));
    await tester.pumpWidget(app(
        TeacherMedicationScreen(repository: medicationRepository(transport))));
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'Máy chủ đang gặp sự cố khi xử lý dữ liệu dặn thuốc'),
        findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Uống thuốc hôm nay'), findsOneWidget);
  });
  testWidgets('empty selected session has a truthful empty state',
      (tester) async {
    final transport = RequestTransport((_) => jsonBody(todayJson()));
    await tester.pumpWidget(app(
        TeacherMedicationScreen(repository: medicationRepository(transport))));
    await tester.pumpAndSettle();
    final filter = find.widgetWithText(ChoiceChip, 'Buổi Chiều');
    await tester.ensureVisible(filter);
    await tester.pumpAndSettle();
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(
        find.text('Không có cữ thuốc trong buổi đang chọn.'), findsOneWidget);
    expect(find.text('Bảo Châu'), findsNothing);
  });
  testWidgets(
      'confirmation reloads canonical state and never invents missing audit',
      (tester) async {
    var given = false;
    final transport = RequestTransport((request) {
      if (request.method == 'PUT') {
        given = true;
        return jsonBody({});
      }
      return jsonBody(todayJson(given: given, audit: false));
    });
    await tester.pumpWidget(app(
        TeacherMedicationScreen(repository: medicationRepository(transport))));
    await tester.pumpAndSettle();
    await tester.tap(find
        .textContaining(RegExp(r'^(ĐÃ CHO UỐNG THUỐC|Đã cho uống thuốc)$')));
    await tester.pumpAndSettle();
    expect(transport.requests.where((r) => r.method == 'GET'), hasLength(2));
    expect(
        transport.requests
            .singleWhere((r) => r.method == 'PUT')
            .queryParameters['date'],
        '2030-01-05');
    expect(find.textContaining('Chưa có thời điểm xác nhận'), findsOneWidget);
    expect(find.textContaining('vừa xong'), findsNothing);
    expect(find.textContaining('Tôi đã'), findsNothing);
    expect(find.text('Đã cho uống thuốc'), findsNothing);
  });

  testWidgets('409 reload shows actual winner time in Vietnam and one mutation',
      (tester) async {
    var given = false;
    final transport = RequestTransport((request) {
      if (request.method == 'PUT') {
        given = true;
        return jsonBody({'detail': 'Cô Mai đã xác nhận'}, 409);
      }
      return jsonBody(todayJson(given: given));
    });
    await tester.pumpWidget(app(
        TeacherMedicationScreen(repository: medicationRepository(transport))));
    await tester.pumpAndSettle();
    await tester.tap(find
        .textContaining(RegExp(r'^(ĐÃ CHO UỐNG THUỐC|Đã cho uống thuốc)$')));
    await tester.pumpAndSettle();
    expect(find.textContaining('08:32'), findsOneWidget);
    expect(find.textContaining('Cô Mai'), findsWidgets);
    expect(find.text('Đã cho uống thuốc'), findsNothing);
    expect(transport.requests.where((r) => r.method == 'PUT'), hasLength(1));
  });

  testWidgets('date update discards an older pending schedule response',
      (tester) async {
    final old = Completer<ResponseBody>();
    final transport = RequestTransport((request) {
      if (request.queryParameters['date'] == '2030-01-05') return old.future;
      return jsonBody(todayJson(date: '2030-01-06', empty: true));
    });
    final repo = medicationRepository(transport);
    await tester.pumpWidget(app(
        TeacherMedicationScreen(repository: repo, initialDate: '2030-01-05')));
    await tester.pump();
    await tester.pumpWidget(app(
        TeacherMedicationScreen(repository: repo, initialDate: '2030-01-06')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    old.complete(jsonBody(todayJson()));
    await tester.pumpAndSettle();
    expect(find.text('Bảo Châu'), findsNothing);
    expect(find.textContaining('06/01/2030'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Figma mobile layout keeps long medicine and dosage readable in dark text2',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final body = todayJson();
    final item = (body['morning'] as List).single as Map<String, dynamic>;
    item['medication_name'] = List.filled(8, 'Tên thuốc nhiều chữ').join(' ');
    item['dosage'] = List.filled(8, 'Liều theo đơn bác sĩ').join(' ');
    final transport = RequestTransport((_) => jsonBody(body));
    await tester.pumpWidget(app(
        TeacherMedicationScreen(repository: medicationRepository(transport)),
        dark: true,
        textScale: 2));
    await tester.pumpAndSettle();
    expect(find.text('Uống thuốc hôm nay'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Scaffold)).width, lessThanOrEqualTo(480));
  });
}
