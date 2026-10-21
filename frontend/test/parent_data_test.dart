// TestParentData — tầng dữ liệu cho màn Parent (Task 2):
// - Parent.fromJson đọc `relationship` + `created_at` (màn Tài khoản cần)
// - ChildOverview đọc liên hệ GVCN + phòng (sheet chi tiết bé)
// - updateMyPhone gọi đúng PUT /api/parent/{id}

import 'dart:convert';
import 'dart:typed_data';

import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_health_profile_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter giả để bắt request mà không cần server thật.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.onRequest);

  final Future<ResponseBody> Function(RequestOptions options) onRequest;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    lastRequest = options;
    return onRequest(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Map<String, dynamic> body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

(HttpDashboardRepository, _FakeAdapter) _repo(
  Map<String, dynamic> response,
) {
  final adapter = _FakeAdapter((_) async => _jsonBody(response));
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = adapter;
  return (
    HttpDashboardRepository(dio: dio, parentId: 'parent-1'),
    adapter,
  );
}

void main() {
  group('Parent entity', () {
    test('fromJson đọc relationship và created_at từ API', () {
      final parent = Parent.fromJson({
        'parent_id': 'parent-1',
        'full_name': 'Trần Văn Tuấn',
        'phone': '0901234567',
        'email': 'tuan.tran@gmail.com',
        'relationship': 'Bố',
        'created_at': '2026-06-08T09:30:00+00:00',
      });

      expect(parent.relationship, 'Bố');
      expect(parent.createdAt, DateTime.utc(2026, 6, 8, 9, 30));
    });

    test('fromJson chịu được response cũ thiếu relationship/created_at', () {
      final parent = Parent.fromJson({
        'parent_id': 'parent-1',
        'full_name': 'Trần Văn Tuấn',
      });

      expect(parent.relationship, isNull);
      expect(parent.createdAt, isNull);
    });
  });

  group('ChildOverview', () {
    test('getPrimaryChildOverview đọc liên hệ GVCN và phòng', () async {
      final (repo, adapter) = _repo({
        'child': {
          'child_id': 'child-1',
          'full_name': 'Trần Gia Bảo',
          'nickname': 'Bảo',
          'medical_allergies': 'Đậu phộng',
        },
        'class_name': 'Mầm A',
        'teacher_name': 'Cô Nguyễn Thị Mai',
        'teacher_id': 'teacher-1',
        'teacher_phone': '0987654321',
        'room_number': 'Phòng 1',
      });

      final overview = await repo.getPrimaryChildOverview('parent-1');

      expect(adapter.lastRequest!.path, '/api/parent/parent-1/child');
      expect(overview.teacherId, 'teacher-1');
      expect(overview.teacherPhone, '0987654321');
      expect(overview.roomNumber, 'Phòng 1');
      expect(overview.child.medicalAllergies, 'Đậu phộng');
    });

    test('trường thiếu thì thành null, không vỡ màn', () async {
      final (repo, _) = _repo({
        'child': {'child_id': 'child-1', 'full_name': 'Trần Gia Bảo'},
        'class_name': 'Mầm A',
        'teacher_name': 'Cô Nguyễn Thị Mai',
      });

      final overview = await repo.getPrimaryChildOverview('parent-1');

      expect(overview.teacherPhone, isNull);
      expect(overview.roomNumber, isNull);
    });
  });

  group('updateMyPhone', () {
    test('gửi PUT tới /api/parent/{id} với số điện thoại mới', () async {
      final (repo, adapter) = _repo({
        'message': 'Cập nhật số điện thoại thành công',
        'phone': '0987654321',
      });

      await repo.updateMyPhone('parent-1', '0987654321');

      expect(adapter.lastRequest!.method, 'PUT');
      expect(adapter.lastRequest!.path, '/api/parent/parent-1');
      expect(adapter.lastRequest!.data, {'phone': '0987654321'});
    });

    test('lỗi 409 ném ClassDataException để UI hiện thông báo', () async {
      final adapter = _FakeAdapter(
        (_) async => ResponseBody.fromString(
          jsonEncode({'detail': 'Số điện thoại đã được sử dụng'}),
          409,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
        ..httpClientAdapter = adapter;
      final repo = HttpDashboardRepository(dio: dio, parentId: 'parent-1');

      expect(
        () => repo.updateMyPhone('parent-1', '0987654321'),
        throwsA(
          isA<ClassDataException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });
  });

  group('Child.allergy — seed ghi "Không có" thay vì để trống', () {
    Child childWith(String? raw) => Child(
      childId: '1',
      fullName: 'Bé',
      dateOfBirth: DateTime(2024, 1, 1),
      medicalAllergies: raw,
    );

    test('"không có" / rỗng / null → null (không hiện banner)', () {
      expect(childWith('Không có').allergy, isNull);
      expect(childWith('  không có  ').allergy, isNull);
      expect(childWith('không').allergy, isNull);
      expect(childWith('NONE').allergy, isNull);
      expect(childWith('   ').allergy, isNull);
      expect(childWith('').allergy, isNull);
      expect(childWith(null).allergy, isNull);
    });

    test('giữ nguyên bản ghi thật, kể cả bắt đầu bằng "không"', () {
      expect(
        childWith('Không dung nạp lactose').allergy,
        equals('Không dung nạp lactose'),
      );
      expect(
        childWith('Viêm mũi dị ứng thời tiết').allergy,
        equals('Viêm mũi dị ứng thời tiết'),
      );
    });

    test('bỏ tiền tố "Dị ứng" để không thành "Dị ứng Dị ứng đậu phộng"', () {
      expect(childWith('Dị ứng đậu phộng').allergy, equals('đậu phộng'));
      expect(
        childWith('Dị ứng tôm cua, hải sản').allergy,
        equals('tôm cua, hải sản'),
      );
    });
  });

  group('Hồ sơ sức khỏe của bé', () {
    test('Child.fromJson đọc đúng trường sức khỏe', () {
      final child = Child.fromJson({
        'child_id': 'c1',
        'full_name': 'Bé A',
        'allergy_status': 'present',
        'medical_allergies': 'Đậu phộng',
        'care_notes': 'Tránh nắng',
        'health_version': 3,
        'health_update_source': 'parent',
        'health_updated_at': '2026-10-21T01:00:00+00:00',
      });

      expect(child.allergyStatus, 'present');
      expect(child.careNotes, 'Tránh nắng');
      expect(child.healthVersion, 3);
      expect(child.healthUpdateSource, 'parent');
      expect(child.healthUpdatedAt, isNotNull);
    });

    test('fromJson chịu được response cũ thiếu trường sức khỏe', () {
      final child = Child.fromJson({'child_id': 'c1', 'full_name': 'Bé A'});

      expect(child.allergyStatus, 'unknown');
      expect(child.careNotes, isNull);
      expect(child.healthVersion, 1);
    });

    test('getChildHealthProfile gọi GET health-profile', () async {
      final (repo, adapter) = _repo({
        'child_id': 'child-1',
        'full_name': 'Bé A',
        'allergy_status': 'present',
        'medical_allergies': 'Đậu phộng',
        'health_version': 2,
      });

      final child = await repo.getChildHealthProfile('child-1');

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/api/children/child-1/health-profile');
      expect(child.allergyStatus, 'present');
    });

    test('updateChildHealthProfile gửi PATCH kèm expected_version', () async {
      final (repo, adapter) = _repo({
        'child_id': 'child-1',
        'full_name': 'Bé A',
        'allergy_status': 'none',
        'medical_allergies': null,
        'care_notes': 'Tránh nắng',
        'health_version': 3,
      });

      await repo.updateChildHealthProfile(
        childId: 'child-1',
        allergyStatus: 'none',
        careNotes: 'Tránh nắng',
        expectedVersion: 2,
      );

      expect(adapter.lastRequest!.method, 'PATCH');
      expect(adapter.lastRequest!.path, '/api/children/child-1/health-profile');
      expect(adapter.lastRequest!.data, {
        'allergy_status': 'none',
        'medical_allergies': null,
        'care_notes': 'Tránh nắng',
        'expected_version': 2,
      });
    });

    test('lỗi 409 ném ClassDataException để màn hiện banner tải lại', () async {
      final adapter = _FakeAdapter(
        (_) async => ResponseBody.fromString(
          jsonEncode({'detail': 'Hồ sơ vừa được cập nhật ở nơi khác'}),
          409,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
        ..httpClientAdapter = adapter;
      final repo = HttpDashboardRepository(dio: dio, parentId: 'parent-1');

      expect(
        () => repo.updateChildHealthProfile(
          childId: 'child-1',
          allergyStatus: 'none',
          expectedVersion: 1,
        ),
        throwsA(
          isA<ClassDataException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('healthCharCount đếm code point như backend', () {
      expect(healthCharCount('Đậu phộng'), 9);
      expect(healthCharCount('👨‍👩‍👧'), 5);
    });
  });
}
