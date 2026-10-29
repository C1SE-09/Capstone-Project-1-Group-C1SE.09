import 'dart:async';
import 'dart:convert';

import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_health_profile_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_form_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_detail_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'parent_medication_repository_test.dart'
    show medicationJson, medicationRepository;
import 'parent_request_repository_test.dart' show RequestTransport, jsonBody;
import 'parent_requests_test.dart' show GalleryPicker, app, child;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

GalleryPicker selectedImage() => GalleryPicker()
  ..file = XFile.fromData(
      base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg=='),
      name: 'prescription.png');

class HealthFixtureRepository extends HttpDashboardRepository {
  @override
  Future<Child> getChildHealthProfile(String childId) async => child;
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
      'health profile opens medication history with the actual child context',
      (tester) async {
    final transport = RequestTransport((_) => jsonBody([]));
    await tester.pumpWidget(app(ParentHealthProfileScreen(
        child: child,
        className: 'Mầm 1',
        repository: HealthFixtureRepository(),
        medicationRepository: medicationRepository(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byTooltip('Dặn dò uống thuốc'));
    await tester.pumpAndSettle();
    expect(find.byType(ParentMedicationScreen), findsOneWidget);
    expect(
        transport.requests.single.queryParameters['child_id'], child.childId);
  });

  testWidgets(
      'conflicting cancellation reloads the real given state without saying cancelled',
      (tester) async {
    var given = false;
    final transport = RequestTransport((request) {
      if (request.method == 'POST') {
        given = true;
        return jsonBody({'detail': 'Cô khác đã cho uống'}, 409);
      }
      return jsonBody([
        {
          ...medicationJson(status: given ? 'given' : 'pending'),
          'prescription_image_url': null
        }
      ]);
    });
    await tester.pumpWidget(app(ParentMedicationDetailScreen(
        child: child,
        className: 'Mầm 1',
        batchId: 'batch-1',
        repository: medicationRepository(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Hủy cữ này'));
    await tapVisible(tester, find.text('Hủy cữ'));
    await tester.pumpAndSettle();
    expect(find.text('Đã uống'), findsOneWidget);
    expect(find.textContaining('Cô Mai'), findsOneWidget);
    expect(find.text('Đã hủy'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Hủy cữ này'))
            .onPressed,
        isNull);
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  testWidgets('private image failure retries through authenticated repository',
      (tester) async {
    var failed = true;
    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==');
    final transport = RequestTransport((request) {
      if (request.path.contains('/attachments/')) {
        return failed
            ? jsonBody({'detail': 'Kho ảnh gián đoạn'}, 503)
            : ResponseBody.fromBytes(png, 200, headers: {
                Headers.contentTypeHeader: ['image/png']
              });
      }
      return jsonBody([medicationJson()]);
    });
    await tester.pumpWidget(app(ParentMedicationDetailScreen(
        child: child,
        className: 'Mầm 1',
        batchId: 'batch-1',
        repository: medicationRepository(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Xem ảnh đơn thuốc'));
    await tester.pumpAndSettle();
    failed = false;
    await tapVisible(tester, find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(transport.requests.where((r) => r.path.contains('/attachments/')),
        hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'native back preserves dirty form unless discard is explicitly confirmed',
      (tester) async {
    final transport =
        RequestTransport((_) => throw StateError('No request expected'));
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                        builder: (_) => ParentMedicationFormScreen(
                            child: child,
                            className: 'Mầm 1',
                            repository: medicationRepository(transport)))),
                child: const Text('Mở đơn thuốc'))))));
    await tapVisible(tester, find.text('Mở đơn thuốc'));
    await tester.enterText(find.byType(TextFormField).first, 'Bản nháp thuốc');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Tiếp tục soạn'));
    expect(find.text('Bản nháp thuốc'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Mở đơn thuốc'), findsOneWidget);
    expect(transport.requests, isEmpty);
  });
  testWidgets('confirmed cancellation remains clear when history refresh fails',
      (tester) async {
    var confirmed = false;
    final transport = RequestTransport((request) {
      if (request.method == 'POST') {
        confirmed = true;
        return jsonBody(medicationJson(status: 'cancelled'));
      }
      return confirmed
          ? jsonBody({'detail': 'Không tải được lịch sử'}, 503)
          : jsonBody([
              {...medicationJson(), 'prescription_image_url': null}
            ]);
    });
    await tester.pumpWidget(app(ParentMedicationDetailScreen(
        child: child,
        className: 'Mầm 1',
        batchId: 'batch-1',
        repository: medicationRepository(transport))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Hủy cữ này'));
    await tapVisible(tester, find.text('Hủy cữ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã hủy cữ thuốc'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('history opens real batch and only pending dose can be cancelled',
      (tester) async {
    var cancelled = false;
    final transport = RequestTransport((request) {
      if (request.method == 'POST') {
        cancelled = true;
        return jsonBody(
            medicationJson(id: 'dose-2', slot: '11:30', status: 'cancelled'));
      }
      return jsonBody([
        {...medicationJson(status: 'given'), 'prescription_image_url': null},
        {
          ...medicationJson(
              id: 'dose-2',
              slot: '11:30',
              status: cancelled ? 'cancelled' : 'pending'),
          'prescription_image_url': null
        },
      ]);
    });
    await tester.pumpWidget(app(ParentMedicationScreen(
        child: child,
        className: 'Mầm 1',
        repository: medicationRepository(transport))));
    await tester.pumpAndSettle();
    expect(find.textContaining(child.fullName), findsWidgets);
    await tapVisible(tester, find.text('Xem chi tiết đợt'));
    await tester.pumpAndSettle();
    expect(find.byType(ParentMedicationDetailScreen), findsOneWidget);
    expect(transport.requests.last.queryParameters['batch_id'], 'batch-1');
    final buttons = tester
        .widgetList<FilledButton>(
            find.widgetWithText(FilledButton, 'Hủy cữ này'))
        .toList();
    expect(buttons.first.onPressed, isNull);
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Hủy cữ này').last);
    await tapVisible(tester, find.text('Giữ lại'));
    expect(transport.requests.where((r) => r.method == 'POST'), isEmpty);
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Hủy cữ này').last);
    await tapVisible(tester, find.text('Hủy cữ'));
    await tester.pumpAndSettle();
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(find.text('Đã hủy'), findsWidgets);
    expect(find.textContaining('Cô Mai'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'form requires deliberate time selection and prescription image, and confirms real returned batch',
      (tester) async {
    var rows = <Map<String, dynamic>>[];
    final transport = RequestTransport((request) {
      if (request.path.endsWith('/attachments')) {
        return jsonBody({
          'prescription_image_url':
              '/api/medication-requests/attachments/child-1/image-1'
        }, 201);
      }
      if (request.method == 'POST') {
        final body = request.data as Map;
        rows = [
          for (var i = 0; i < (body['time_slots'] as List).length; i++)
            {
              ...medicationJson(
                  id: 'dose-$i', slot: body['time_slots'][i] as String),
              'medicine_name': body['medicine_name'],
              'dosage': body['dosage'],
              'request_date': body['from_date'],
              'start_date': body['from_date'],
              'end_date': body['to_date'],
            }
        ];
        return jsonBody(
            {'batch_id': 'batch-1', 'total_slots': rows.length, 'items': rows},
            201);
      }
      return jsonBody(rows);
    });
    await tester.pumpWidget(app(ParentMedicationScreen(
        child: child,
        className: 'Mầm 1',
        repository: medicationRepository(transport),
        imagePicker: selectedImage())));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('+ Tạo đơn dặn thuốc mới'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Thuốc của bé');
    await tester.enterText(find.byType(TextFormField).at(1), '5ml');
    await tapVisible(tester, find.widgetWithText(ChoiceChip, '08:30'));
    await tapVisible(tester, find.widgetWithText(ChoiceChip, '11:30'));
    await tapVisible(tester, find.text('Gửi đơn dặn thuốc'));
    expect(find.textContaining('Ảnh đơn thuốc là bắt buộc'), findsOneWidget);
    expect(transport.requests.where((r) => r.method == 'POST'), isEmpty);
    await tapVisible(tester, find.text('+ Thêm ảnh đơn thuốc'));
    expect(transport.requests.where((r) => r.method == 'POST'), isEmpty);
    await tapVisible(tester, find.text('Gửi đơn dặn thuốc'));
    await tester.pumpAndSettle();
    expect(find.text('Đã tạo đơn dặn thuốc'), findsOneWidget);
    expect(find.text('Hệ thống đã tạo 2 cữ riêng:'), findsOneWidget);
    expect(
        transport.requests.where((r) => r.method == 'POST').map((r) => r.path),
        ['/api/medication-requests/attachments', '/api/medication-requests']);
    await tapVisible(tester, find.text('Xem danh sách đợt thuốc'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Thuốc của bé'), findsWidgets);
    expect(find.text('Dặn dò uống thuốc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'timeout preserves form and uploaded image without automatically resending',
      (tester) async {
    final transport = RequestTransport((request) =>
        request.path.endsWith('/attachments')
            ? jsonBody({
                'prescription_image_url':
                    '/api/medication-requests/attachments/child-1/image-1'
              }, 201)
            : throw DioException(
                requestOptions: request,
                type: DioExceptionType.receiveTimeout));
    await tester.pumpWidget(app(ParentMedicationFormScreen(
        child: child,
        className: 'Mầm 1',
        repository: medicationRepository(transport),
        imagePicker: selectedImage())));
    await tester.enterText(find.byType(TextFormField).at(0), 'Thuốc đang soạn');
    await tester.enterText(find.byType(TextFormField).at(1), '5ml');
    await tapVisible(tester, find.widgetWithText(ChoiceChip, '08:30'));
    await tapVisible(tester, find.text('+ Thêm ảnh đơn thuốc'));
    await tapVisible(tester, find.text('Gửi đơn dặn thuốc'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa xác nhận'), findsWidgets);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '5ml');
    expect(
        transport.requests.where((r) => r.path == '/api/medication-requests'),
        hasLength(1));
    expect(find.text('Đã tạo đơn dặn thuốc'), findsNothing);
  });

  testWidgets(
      'native pickers cap inclusive date range at seven and custom time does not auto-submit',
      (tester) async {
    final transport =
        RequestTransport((_) => throw StateError('No submit expected'));
    await tester.pumpWidget(app(ParentMedicationFormScreen(
        child: child,
        className: 'Mầm 1',
        repository: medicationRepository(transport))));
    await tapVisible(tester, find.text('+ Thêm giờ'));
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tapVisible(tester, find.text('Hủy'));
    await tapVisible(tester, find.byTooltip('Đến ngày'));
    final calendar =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(calendar.lastDate.difference(calendar.firstDate).inDays, 6);
    await tapVisible(tester, find.text('Hủy'));
    expect(transport.requests, isEmpty);
  });

  testWidgets('switching children discards older history response',
      (tester) async {
    final old = Completer<ResponseBody>();
    final transport = RequestTransport((request) {
      if (request.queryParameters['child_id'] == 'child-1') return old.future;
      return jsonBody([]);
    });
    final repo = medicationRepository(transport);
    await tester.pumpWidget(app(ParentMedicationScreen(
        child: child, className: 'Mầm 1', repository: repo)));
    await tester.pump();
    await tester.pumpWidget(app(ParentMedicationScreen(
        child: const Child(
            childId: 'child-2', classId: 'class-2', fullName: 'Bé mới'),
        className: 'Mầm 2',
        repository: repo)));
    await tester.pumpAndSettle();
    old.complete(jsonBody([
      {...medicationJson(), 'medicine_name': 'Thuốc của bé trước'}
    ]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Thuốc của bé trước'), findsNothing);
    expect(find.textContaining('Bé mới'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history errors retry, empty results stay truthful',
      (tester) async {
    var fail = true;
    final transport = RequestTransport((_) =>
        fail ? jsonBody({'detail': 'Không tải được'}, 503) : jsonBody([]));
    await tester.pumpWidget(app(ParentMedicationScreen(
        child: child,
        className: 'Mầm 1',
        repository: medicationRepository(transport))));
    await tester.pumpAndSettle();
    fail = false;
    await tapVisible(tester, find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có đợt thuốc'), findsOneWidget);
    expect(find.textContaining('Paracetamol'), findsNothing);
  });

  testWidgets(
      'narrow dark text2 form scrolls and desktop history stays mobile width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = RequestTransport((_) => jsonBody([]));
    final repo = medicationRepository(transport);
    await tester.pumpWidget(app(
        ParentMedicationFormScreen(
            child: child, className: 'Mầm 1', repository: repo),
        textScale: 2,
        dark: true));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Gửi đơn dặn thuốc'));
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(app(ParentMedicationScreen(
        child: child, className: 'Mầm 1', repository: repo)));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Scaffold)).width, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);
  });
}
