import 'dart:async';
import 'dart:typed_data';

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parent_request_repository_test.dart' show RequestTransport, jsonBody;

Map<String, dynamic> medicationJson(
        {String id = 'dose-1',
        String status = 'pending',
        String slot = '08:30'}) =>
    {
      'id': id,
      'batch_id': 'batch-1',
      'child_id': 'child-1',
      'child_name': 'Nguyễn Minh An',
      'class_id': 'class-1',
      'class_name': 'Mầm 1',
      'parent_id': 'parent-1',
      'parent_name': 'Phụ huynh An',
      'request_date': '2030-01-05',
      'time_slot': slot,
      'start_date': '2030-01-05',
      'end_date': '2030-01-05',
      'sessions': <String>[],
      'medicine_category': 'prescription',
      'medicine_name': 'Thuốc theo hướng dẫn',
      'dosage': '5ml',
      'notes': 'Uống sau ăn theo hướng dẫn',
      'prescription_image_url':
          '/api/medication-requests/attachments/child-1/image-1',
      'status': status,
      'created_by_user_id': 'user-1',
      'created_by_role': 'parent',
      'creator_name': 'Phụ huynh An',
      'created_at': '2030-01-05T00:05:00Z',
      'updated_at': '2030-01-05T00:05:00Z',
      'given_at': status == 'given' ? '2030-01-05T01:32:00Z' : null,
      'given_by_id': status == 'given' ? 'teacher-1' : null,
      'given_by_name': status == 'given' ? 'Cô Mai' : null,
    };

HttpMedicationRepository medicationRepository(RequestTransport transport) =>
    HttpMedicationRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);

Future<MedicationBatchCreateResult> create(HttpMedicationRepository repo) =>
    repo.createMedicationRequests(
        childId: 'child-1',
        fromDate: DateTime(2030, 1, 5),
        toDate: DateTime(2030, 1, 5),
        timeSlots: ['08:30', '11:30'],
        medicineCategory: 'supplement',
        medicineName: '  Vitamin D  ',
        dosage: ' 1 giọt ',
        prescriptionImageUrl:
            '/api/medication-requests/attachments/child-1/image-1');

void main() {
  test(
      'late response from an ended session cannot become visible medication data',
      () async {
    SharedPreferences.setMockInitialValues({});
    final sessions = SessionManagementService.instance;
    await sessions.clearSession();
    addTearDown(sessions.clearSession);
    await sessions.saveSession(const AppSession(
        accessToken: 'fixture-access',
        refreshToken: 'fixture-refresh',
        sessionId: 'old-medication-session',
        role: 'parent'));
    final pending = Completer<ResponseBody>();
    final transport = RequestTransport((_) => pending.future);
    final result = medicationRepository(transport)
        .getMedicationRequests(childId: 'child-1');
    final check = expectLater(
        result,
        throwsA(isA<MedicationRequestException>()
            .having((e) => e.code, 'code', 'session_changed')));
    await sessions.clearSession();
    pending.complete(jsonBody([medicationJson()]));
    await check;
  });
  test(
      'nullable legacy fields and unknown statuses never become a fabricated dose',
      () {
    final legacy = MedicationDose.fromJson({
      ...medicationJson(),
      'batch_id': null,
      'request_date': null,
      'time_slot': null,
      'medicine_category': null,
      'created_by_user_id': null,
      'created_by_role': null,
      'creator_name': null,
      'status': 'active',
      'sessions': ['morning', 'noon']
    });
    expect(legacy.isLegacy, isTrue);
    expect(legacy.timeSlot, isNull);
    expect(legacy.creatorName, isNull);
    expect(legacy.canCancel, isFalse);
    expect(
        MedicationDose.fromJson(medicationJson(status: 'future-status'))
            .canCancel,
        isFalse);
    expect(medicationDateInVietnam(DateTime.utc(2030, 1, 5, 18)),
        DateTime(2030, 1, 6));
  });

  test('date expiry never makes pending dose given or a batch completed', () {
    final batch =
        MedicationBatch('batch-1', [MedicationDose.fromJson(medicationJson())]);
    expect(batch.statusLabel(DateTime(2030, 1, 6)), 'Chưa hoàn tất');
    expect(batch.doses.single.isGiven, isFalse);
  });

  test(
      'GET pagination and batch filter preserve complete history and child scope',
      () async {
    final transport = RequestTransport((request) => jsonBody([
          if (request.queryParameters['offset'] == 0)
            for (var i = 0; i < 100; i++) medicationJson(id: 'dose-$i')
          else
            medicationJson(id: 'dose-100'),
        ]));
    final rows = await medicationRepository(transport)
        .getMedicationRequests(childId: 'child-1', batchId: 'batch-1');
    expect(rows, hasLength(101));
    expect(
        transport.requests.map((r) => r.queryParameters['offset']), [0, 100]);
    expect(
        transport.requests.every((r) =>
            r.queryParameters['child_id'] == 'child-1' &&
            r.queryParameters['batch_id'] == 'batch-1' &&
            r.queryParameters['limit'] == 100),
        isTrue);
  });

  test(
      'old server ignoring pagination fails instead of looping or showing partial completion',
      () async {
    final transport = RequestTransport((_) => jsonBody(
        [for (var i = 0; i < 100; i++) medicationJson(id: 'dose-$i')]));
    await expectLater(
        medicationRepository(transport)
            .getMedicationRequests(childId: 'child-1'),
        throwsA(isA<MedicationRequestException>()));
    expect(transport.requests, hasLength(2));
  });

  test(
      'create sends canonical dates slots category and trimmed medicine fields once',
      () async {
    final transport = RequestTransport((_) => jsonBody({
          'batch_id': 'batch-1',
          'total_slots': 2,
          'items': [
            medicationJson(),
            medicationJson(id: 'dose-2', slot: '11:30')
          ]
        }, 201));
    final result = await create(medicationRepository(transport));
    expect(result.items, hasLength(2));
    expect(transport.requests.single.data, {
      'child_id': 'child-1',
      'from_date': '2030-01-05',
      'to_date': '2030-01-05',
      'time_slots': ['08:30', '11:30'],
      'medicine_category': 'supplement',
      'medicine_name': 'Vitamin D',
      'dosage': '1 giọt',
      'notes': null,
      'prescription_image_url':
          '/api/medication-requests/attachments/child-1/image-1',
    });
  });

  test(
      'upload uses bytes MIME and private child path, never absolute local filename',
      () async {
    final transport = RequestTransport((_) => jsonBody({
          'prescription_image_url':
              '/api/medication-requests/attachments/child-1/image-1'
        }, 201));
    final path = await medicationRepository(transport).uploadPrescription(
        childId: 'child-1',
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]));
    expect(path, '/api/medication-requests/attachments/child-1/image-1');
    final file =
        (transport.requests.single.data as FormData).files.single.value;
    expect(file.contentType.toString(), 'image/png');
    expect(file.filename, 'prescription.png');
    expect(transport.requests.single.queryParameters['child_id'], 'child-1');
  });

  test(
      'foreign image URLs and query tricks are rejected before authenticated HTTP',
      () async {
    final transport = RequestTransport(
        (_) => throw StateError('Must not request foreign image'));
    final repo = medicationRepository(transport);
    for (final path in [
      'https://evil.example/image.png',
      '//evil.example/image.png',
      '/api/medication-requests/attachments/child-1/image-1?token=other'
    ]) {
      await expectLater(repo.getPrescriptionBytes(path),
          throwsA(isA<MedicationRequestException>()));
    }
    expect(transport.requests, isEmpty);
  });

  test('401 and 409 mutations are not automatically replayed', () async {
    for (final code in [401, 409]) {
      final transport = RequestTransport(
          (_) => jsonBody({'detail': 'Không thể thực hiện'}, code));
      await expectLater(create(medicationRepository(transport)),
          throwsA(isA<MedicationRequestException>()));
      expect(transport.requests, hasLength(1));
    }
  });

  test(
      'structured 422 and malformed success do not become casting crashes or false success',
      () async {
    for (final body in [
      jsonBody({
        'detail': [
          {'msg': 'Ảnh là bắt buộc'}
        ]
      }, 422),
      jsonBody('<html>error</html>')
    ]) {
      final transport = RequestTransport((_) => body);
      await expectLater(create(medicationRepository(transport)),
          throwsA(isA<MedicationRequestException>()));
    }
  });

  test('single and batch cancellation use exact IDs and server state',
      () async {
    final transport = RequestTransport((r) => r.path.contains('/batch/')
        ? jsonBody({'batch_id': 'batch-1', 'cancelled_count': 1})
        : jsonBody(medicationJson(status: 'cancelled')));
    final repo = medicationRepository(transport);
    expect((await repo.cancelMedicationRequest('dose-1')).status, 'cancelled');
    expect(await repo.cancelMedicationBatch('batch-1'), 1);
    expect(transport.requests.map((r) => r.path), [
      '/api/medication-requests/dose-1/cancel',
      '/api/medication-requests/batch/batch-1/cancel'
    ]);
  });
}
