import 'dart:async';

import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart' as domain;
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_medication_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/teacher_emergency_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parent_medication_repository_test.dart' show medicationRepository;
import 'parent_medication_test.dart' show tapVisible;
import 'parent_request_repository_test.dart' show RequestTransport, jsonBody;
import 'parent_requests_test.dart' show app;
import 'teacher_medication_flow_test.dart' show todayJson;

const pupil = Child(
    id: 'child-1',
    name: 'Bảo Châu',
    status: ReportStatus.none,
    present: true,
    time: '',
    severity: Severity.none);
Map<String, dynamic> incidentJson(
        {Object? contacts = const [
          {'name': 'Nguyễn Thu Hà', 'relationship': 'Mẹ', 'phone': '0911222333'}
        ]}) =>
    {
      'incident_id': 'incident-1',
      'child_id': 'child-1',
      'child_name': 'Bảo Châu từ server',
      'incident_type': 'high_fever',
      'incident_type_label': 'Sốt cao',
      'temperature': 39,
      'reported_at': '2030-01-05T03:24:00Z',
      'reported_by_name': 'Cô Ngọc Anh',
      'description': 'Bé đang nghỉ tại phòng y tế lớp.',
      'emergency_contacts': contacts,
    };

class RosterFixture extends HttpDashboardRepository {
  @override
  Future<List<domain.Child>> getClassChildren(String classId) async => const [
        domain.Child(
            childId: 'child-1', classId: 'class-1', fullName: 'Bảo Châu'),
        domain.Child(
            childId: 'child-without-medication',
            classId: 'class-1',
            fullName: 'Bé không có thuốc'),
      ];
}

void main() {
  testWidgets(
      'recorded incident keeps Figma heading at top rather than a bottom-only card',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final transport = RequestTransport((_) => jsonBody(incidentJson(), 201));
    await tester.pumpWidget(app(Scaffold(
        body: TeacherEmergencySheet(
            children: const [pupil],
            initialChildId: 'child-1',
            repository: medicationRepository(transport)))));
    await tapVisible(tester, find.text('Gửi cảnh báo khẩn'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Đã lưu biên bản sự cố')).dy,
        lessThan(230));
  });
  WidgetController.hitTestWarningShouldBeFatal = true;
  final launched = <String>[];
  var launchWorks = true;
  setUp(() {
    launched.clear();
    launchWorks = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url'] as String);
        return launchWorks;
      }
      return true;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'), null));

  testWidgets('no selected child and empty class cannot post an incident',
      (tester) async {
    final transport = RequestTransport((_) => jsonBody(incidentJson(), 201));
    await tester.pumpWidget(app(Scaffold(
        body: TeacherEmergencySheet(
            children: const [], repository: medicationRepository(transport)))));
    await tapVisible(tester, find.text('Gửi cảnh báo khẩn'));
    expect(transport.requests, isEmpty);
    expect(find.textContaining('chọn'), findsWidgets);
  });

  testWidgets('M8 lists only API-backed emergency contacts before submit',
      (tester) async {
    final transport = RequestTransport((request) {
      if (request.path.contains('/emergency-contacts/')) {
        return jsonBody({
          'child_id': 'child-1',
          'child_name': 'Bảo Châu',
          'class_name': 'Mầm 1',
          'emergency_contacts': [
            {
              'name': 'Nguyễn Thu Hà',
              'relationship': 'Mẹ',
              'phone': '0911222333',
            },
          ],
        });
      }
      return jsonBody(incidentJson(), 201);
    });
    await tester.pumpWidget(app(GardenVoiceScope(
      child: Scaffold(
        body: TeacherEmergencySheet(
          children: const [pupil],
          initialChildId: 'child-1',
          repository: medicationRepository(transport),
        ),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Người nhận cảnh báo'), findsOneWidget);
    expect(find.textContaining('Nguyễn Thu Hà'), findsOneWidget);
    expect(find.text('Báo sự cố'), findsOneWidget);
    expect(find.text('Gửi cảnh báo khẩn'), findsOneWidget);
    expect(find.text('Gọi phụ huynh'), findsOneWidget);
    expect(transport.requests.where((request) => request.method == 'POST'),
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'M8 parent call uses an API-backed contact and skips incident POST',
      (tester) async {
    final transport = RequestTransport((request) => request.method == 'GET'
        ? jsonBody({
            'child_id': 'child-1',
            'emergency_contacts': [
              {
                'name': 'Nguyễn Thu Hà',
                'relationship': 'Mẹ',
                'phone': '0911222333',
              },
            ],
          })
        : jsonBody(incidentJson(), 201));
    await tester.pumpWidget(app(GardenVoiceScope(
      child: Scaffold(
        body: TeacherEmergencySheet(
          children: const [pupil],
          initialChildId: 'child-1',
          repository: medicationRepository(transport),
        ),
      ),
    )));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Gọi phụ huynh'));

    expect(launched, ['tel:0911222333']);
    expect(transport.requests.where((request) => request.method == 'POST'),
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M8 requires choosing when the API returns multiple contacts',
      (tester) async {
    final transport = RequestTransport((request) => jsonBody({
          'child_id': 'child-1',
          'emergency_contacts': [
            {'name': 'Mẹ Minh An', 'relationship': 'Mẹ', 'phone': '0911222333'},
            {'name': 'Bố Minh An', 'relationship': 'Bố', 'phone': '0988777666'},
          ],
        }));
    await tester.pumpWidget(app(GardenVoiceScope(
      child: Scaffold(
        body: TeacherEmergencySheet(
          children: const [pupil],
          initialChildId: 'child-1',
          repository: medicationRepository(transport),
        ),
      ),
    )));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Gọi phụ huynh'));
    expect(find.text('Chọn phụ huynh để gọi'), findsOneWidget);
    await tapVisible(tester, find.textContaining('Bố Minh An').last);

    expect(launched, ['tel:0988777666']);
    expect(transport.requests.where((request) => request.method == 'POST'),
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final invalid in ['NaN', 'không phải số', '33.9', '44.1', 'Infinity']) {
    testWidgets('nonempty invalid temperature $invalid never posts',
        (tester) async {
      final transport = RequestTransport((_) => jsonBody(incidentJson(), 201));
      await tester.pumpWidget(app(Scaffold(
          body: TeacherEmergencySheet(
              children: const [pupil],
              initialChildId: 'child-1',
              repository: medicationRepository(transport)))));
      await tester.enterText(find.byType(TextField).first, invalid);
      await tapVisible(tester, find.text('Gửi cảnh báo khẩn'));
      expect(transport.requests.where((r) => r.method == 'POST'), isEmpty);
      expect(find.textContaining('Nhiệt độ'), findsWidgets);
    });
  }

  testWidgets(
      'rapid submit records once, displays server proof and only dials on tap',
      (tester) async {
    final pending = Completer<ResponseBody>();
    final transport = RequestTransport((request) async {
      if (request.method == 'GET') {
        return jsonBody({
          'child_id': 'child-1',
          'emergency_contacts': [
            {
              'name': 'Nguyễn Thu Hà',
              'relationship': 'Mẹ',
              'phone': '0911222333',
            },
          ],
        });
      }
      return pending.future;
    });
    await tester.pumpWidget(app(Scaffold(
        body: TeacherEmergencySheet(
            children: const [pupil],
            initialChildId: 'child-1',
            repository: medicationRepository(transport)))));
    final button = find.text('Gửi cảnh báo khẩn');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
    pending.complete(jsonBody(incidentJson(), 201));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu biên bản sự cố'), findsOneWidget);
    expect(find.textContaining('Bảo Châu từ server'), findsOneWidget);
    expect(find.textContaining('10:24'), findsWidgets);
    expect(find.textContaining('đã nhận thông báo'), findsNothing);
    expect(launched, isEmpty);
    await tapVisible(tester, find.text('Gọi phụ huynh ngay'));
    expect(launched, ['tel:0911222333']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during a pending incident never updates a dead widget',
      (tester) async {
    final pending = Completer<ResponseBody>();
    final transport = RequestTransport((_) => pending.future);
    await tester.pumpWidget(app(Scaffold(
        body: TeacherEmergencySheet(
            children: const [pupil],
            initialChildId: 'child-1',
            repository: medicationRepository(transport)))));
    await tapVisible(tester, find.text('Gửi cảnh báo khẩn'));
    await tester.pumpWidget(app(const SizedBox()));
    pending.complete(jsonBody(incidentJson(), 201));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'timeout and 401 preserve entered notes without retry or delivery claim',
      (tester) async {
    for (final status in [0, 401]) {
      final transport = RequestTransport((request) {
        if (status == 0) {
          throw DioException(
              requestOptions: request, type: DioExceptionType.receiveTimeout);
        }
        return jsonBody({'detail': 'Phiên hết hạn'}, 401);
      });
      await tester.pumpWidget(app(Scaffold(
          body: TeacherEmergencySheet(
              key: ValueKey(status),
              children: const [pupil],
              initialChildId: 'child-1',
              repository: medicationRepository(transport)))));
      await tester.enterText(find.byType(TextField).last, 'Mô tả đang soạn');
      await tapVisible(tester, find.text('Gửi cảnh báo khẩn'));
      await tester.pumpAndSettle();
      expect(find.text('Mô tả đang soạn'), findsOneWidget);
      expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(find.text('Đã lưu biên bản sự cố'), findsNothing);
    }
  });

  testWidgets(
      'malformed contacts preserve incident proof and allow contact-only retry',
      (tester) async {
    final transport = RequestTransport((request) => request.method == 'POST'
        ? jsonBody(incidentJson(contacts: ['not-a-contact']), 201)
        : jsonBody({
            'child_id': 'child-1',
            'emergency_contacts': [
              {'name': 'Mẹ', 'phone': '0911222333'}
            ]
          }));
    await tester.pumpWidget(app(Scaffold(
        body: TeacherEmergencySheet(
            children: const [pupil],
            initialChildId: 'child-1',
            repository: medicationRepository(transport)))));
    await tapVisible(tester, find.text('Gửi cảnh báo khẩn'));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu biên bản sự cố'), findsOneWidget);
    await tapVisible(tester, find.text('Tải lại danh bạ'));
    await tester.pumpAndSettle();
    expect(find.text('Gọi phụ huynh ngay'), findsOneWidget);
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  testWidgets(
      'invalid contact is skipped and unavailable launcher shows helpful error',
      (tester) async {
    final transport = RequestTransport((_) => jsonBody(
        incidentJson(contacts: [
          {'name': 'Số không hợp lệ', 'phone': '*21*0911222333#'},
          {'name': 'Mẹ', 'phone': '0911222333'}
        ]),
        201));
    await tester.pumpWidget(app(Scaffold(
        body: TeacherEmergencySheet(
            children: const [pupil],
            initialChildId: 'child-1',
            repository: medicationRepository(transport)))));
    await tapVisible(tester, find.text('Gửi cảnh báo khẩn'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có số điện thoại hợp lệ'), findsOneWidget);
    launchWorks = false;
    await tapVisible(tester, find.text('Gọi phụ huynh ngay'));
    expect(
        find.textContaining('Không mở được ứng dụng gọi điện'), findsOneWidget);
    expect(launched, ['tel:0911222333']);
  });

  testWidgets('M9 call action is disabled when all API phones are invalid',
      (tester) async {
    final transport = RequestTransport((request) => request.method == 'POST'
        ? jsonBody(
            incidentJson(contacts: [
              {'name': 'Mẹ', 'phone': '*21*0911222333#'}
            ]),
            201)
        : jsonBody({'detail': 'Danh bạ chưa tải được'}, 503));
    await tester.pumpWidget(app(Scaffold(
        body: TeacherEmergencySheet(
            children: const [pupil],
            initialChildId: 'child-1',
            repository: medicationRepository(transport)))));
    await tapVisible(tester, find.text('Gửi cảnh báo khẩn'));
    await tester.pumpAndSettle();

    final callButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Gọi phụ huynh ngay'));
    expect(callButton.onPressed, isNull);
    expect(launched, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('emergency narrow dark text2 success scrolls without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final transport = RequestTransport((_) => jsonBody(incidentJson(), 201));
    await tester.pumpWidget(app(
        Scaffold(
            body: TeacherEmergencySheet(
                children: const [pupil],
                initialChildId: 'child-1',
                repository: medicationRepository(transport))),
        dark: true,
        textScale: 2));
    await tapVisible(tester, find.text('Gửi cảnh báo khẩn'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hoàn tất'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'medication footer loads entire actual class roster including children without medication',
      (tester) async {
    final transport = RequestTransport((_) => jsonBody(todayJson()));
    await tester.pumpWidget(app(TeacherMedicationScreen(
        repository: medicationRepository(transport),
        dashboardRepository: RosterFixture())));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Báo cáo sự cố khẩn cấp'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TeacherEmergencySheet>(find.byType(TeacherEmergencySheet))
            .children
            .map((c) => c.id),
        ['child-1', 'child-without-medication']);
  });
}
