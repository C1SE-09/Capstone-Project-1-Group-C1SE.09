// frontend/test/teacher_medication_test.dart
// =========================================================
// Unit & Widget tests cho Task #295:
// - Lịch uống thuốc hôm nay của giáo viên (TeacherMedicationScreen)
// - Phân nhóm theo buổi: Sáng / Trưa / Chiều
// - Xác nhận 1-chạm "Đã cho uống thuốc"
// - Khóa mờ nút (Grayed out) khi cô khác đã cho uống trước
// - Sheet báo động khẩn cấp tại lớp (TeacherEmergencySheet)

import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_medication_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/teacher_emergency_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockMedicationRepository extends HttpMedicationRepository {
  MockMedicationRepository({
    required this.mockData,
    this.throwConflictOnConfirm = false,
  });

  MedicationsTodayData mockData;
  final bool throwConflictOnConfirm;
  int confirmCalls = 0;
  int emergencyCalls = 0;

  @override
  Future<MedicationsTodayData> getTodayMedications({String? date}) async {
    return mockData;
  }

  @override
  Future<Map<String, dynamic>> confirmMedication({
    required String requestId,
    required String session,
    String? date,
    String? notes,
  }) async {
    confirmCalls++;
    final actor = throwConflictOnConfirm ? 'Cô Lan' : 'Cô Thu Hà';
    final givenAt = DateTime.parse('2026-10-28T04:30:00Z');
    List<MedicationItem> updated(List<MedicationItem> rows) => rows
        .map((item) => item.requestId == requestId && item.session == session
            ? item.copyWith(isGiven: true, givenByName: actor, givenAt: givenAt)
            : item)
        .toList();
    final morning = updated(mockData.morning),
        noon = updated(mockData.noon),
        afternoon = updated(mockData.afternoon);
    final all = [...morning, ...noon, ...afternoon];
    mockData = MedicationsTodayData(
        date: mockData.date,
        classId: mockData.classId,
        className: mockData.className,
        totalRequests: all.length,
        completedCount: all.where((d) => d.isGiven).length,
        pendingCount: all.where((d) => !d.isGiven).length,
        morning: morning,
        noon: noon,
        afternoon: afternoon);
    if (throwConflictOnConfirm) {
      throw MedicationAlreadyConfirmedException(
          'Cô Lan đã cho uống lúc 11:30 rồi.');
    }
    return {
      'success': true,
      'message': 'Đã xác nhận cho trẻ uống thuốc thành công',
      'log_id': 'log-123',
      'request_id': requestId,
      'session': session,
      'is_given': true,
      'given_by_name': actor,
      'given_at': givenAt.toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> createHealthIncident({
    required String childId,
    required String incidentType,
    String? description,
    double? temperature,
    String? actionTaken,
  }) async {
    emergencyCalls++;
    return {
      'incident_id': 'inc-999',
      'child_id': childId,
      'child_name': 'Bé Gia Bảo',
      'incident_type': incidentType,
      'reported_at': '2026-10-28T15:00:00Z',
      'emergency_contacts': [
        {'name': 'Nguyễn Văn Bố', 'relationship': 'Bố', 'phone': '0911222333'},
        {'name': 'Trần Thị Mẹ', 'relationship': 'Mẹ', 'phone': '0988777666'},
      ],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleMorningItem = const MedicationItem(
    requestId: 'req-1',
    childId: 'child-1',
    childName: 'Bé Gia Bảo',
    childNickname: 'Bé Bo',
    medicationName: 'Hapacol 250mg',
    dosage: '1 gói',
    instructions: 'Pha với nước ấm, uống sau ăn 15 phút',
    session: 'morning',
    isGiven: false,
  );

  final sampleNoonItemAdministered = MedicationItem(
    requestId: 'req-2',
    childId: 'child-2',
    childName: 'Bé Minh Anh',
    childNickname: 'Bé Miu',
    medicationName: 'Siro ho Prospan',
    dosage: '5ml',
    instructions: 'Uống trước giờ ngủ trưa',
    session: 'noon',
    isGiven: true,
    givenByName: 'Cô Mai',
    givenAt: DateTime.parse('2026-10-28T11:30:00Z'),
  );

  final sampleMockData = MedicationsTodayData(
    date: '2026-10-28',
    classId: 'class-1',
    className: 'Lớp Mầm 1',
    totalRequests: 2,
    completedCount: 1,
    pendingCount: 1,
    morning: [sampleMorningItem],
    noon: [sampleNoonItemAdministered],
    afternoon: const [],
  );

  group('1. Domain Entity Tests (MedicationSchedule)', () {
    test('MedicationItem fromJson & copyWith', () {
      final json = {
        'request_id': 'req-10',
        'child_id': 'child-10',
        'child_name': 'Bé Tuấn',
        'medication_name': 'Men tiêu hóa',
        'dosage': '1 ống',
        'session': 'afternoon',
        'is_given': false,
      };

      final item = MedicationItem.fromJson(json);
      expect(item.childName, 'Bé Tuấn');
      expect(item.isGiven, isFalse);

      final updated = item.copyWith(isGiven: true, givenByName: 'Cô Lan');
      expect(updated.isGiven, isTrue);
      expect(updated.givenByName, 'Cô Lan');
    });

    test('MedicationsTodayData allItems tính đúng', () {
      expect(sampleMockData.allItems.length, 2);
      expect(sampleMockData.morning.length, 1);
      expect(sampleMockData.noon.length, 1);
      expect(sampleMockData.afternoon.length, 0);
    });
  });

  group('2. TeacherMedicationScreen Widget Tests', () {
    testWidgets('Hiển thị tab và thẻ thuốc đầy đủ thông tin', (tester) async {
      final mockRepo = MockMedicationRepository(mockData: sampleMockData);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherMedicationScreen(repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề và tabs
      expect(find.text('Uống thuốc hôm nay'), findsOneWidget);
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Buổi Sáng'), findsOneWidget); // Bộ lọc
      expect(find.text('Buổi sáng'), findsOneWidget); // Nhóm theo Figma
      expect(find.text('Buổi Trưa'), findsOneWidget);
      expect(find.text('Buổi trưa'), findsOneWidget);
      expect(find.text('Buổi Chiều'),
          findsOneWidget); // Tab (chưa có thuốc buổi chiều)

      // Thẻ bé chưa uống: có nút ĐÃ CHO UỐNG THUỐC
      expect(find.text('Bé Gia Bảo'), findsOneWidget);
      expect(find.textContaining('Hapacol 250mg'), findsOneWidget);
      expect(find.textContaining('1 gói'), findsOneWidget);
      expect(find.text('Đã cho uống thuốc'), findsOneWidget);

      // Thẻ bé đã uống: nút xám hiển thị "Cô Mai đã cho uống..."
      expect(find.text('Bé Minh Anh'), findsOneWidget);
      expect(find.textContaining('Cô Mai đã cho uống lúc'), findsOneWidget);
    });

    testWidgets('Bấm 1-chạm xác nhận gọi API và cập nhật trạng thái',
        (tester) async {
      final mockRepo = MockMedicationRepository(mockData: sampleMockData);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherMedicationScreen(repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm nút ĐÃ CHO UỐNG THUỐC
      await tester.tap(find.text('Đã cho uống thuốc'));
      await tester.pump(); // Start async call
      await tester.pumpAndSettle(); // Settle response

      expect(mockRepo.confirmCalls, 1);
      // SnackBar thành công
      expect(
          find.text('Đã ghi nhận xác nhận cho bé Bé Gia Bảo.'), findsOneWidget);
      // Nút chuyển sang trạng thái đã uống
      expect(find.textContaining('Cô Thu Hà đã cho uống lúc'), findsOneWidget);
    });

    testWidgets('Xử lý xung đột (Cô khác đã cho uống) khóa nút và báo lỗi',
        (tester) async {
      final mockRepo = MockMedicationRepository(
        mockData: sampleMockData,
        throwConflictOnConfirm: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherMedicationScreen(repository: mockRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm xác nhận
      await tester.tap(find.text('Đã cho uống thuốc'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(mockRepo.confirmCalls, 1);
      // Báo lỗi xung đột từ server
      expect(find.text('Cô Lan đã cho uống lúc 11:30 rồi.'), findsOneWidget);
    });
  });

  group('3. TeacherEmergencySheet Widget Tests', () {
    final sampleChildren = <Child>[
      const Child(
        id: 'c-1',
        name: 'Bé Gia Bảo',
        status: ReportStatus.none,
        present: true,
        time: '08:00',
        severity: Severity.none,
      ),
      const Child(
        id: 'c-2',
        name: 'Bé Thảo Nhi',
        status: ReportStatus.none,
        present: true,
        time: '08:00',
        severity: Severity.none,
      ),
    ];

    testWidgets('Hiển thị form báo sự cố và phát cảnh báo thành công',
        (tester) async {
      final mockRepo = MockMedicationRepository(mockData: sampleMockData);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeacherEmergencySheet(
              children: sampleChildren,
              initialChildId: 'c-1',
              repository: mockRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra Header
      expect(find.text('Báo cáo sự cố khẩn cấp'), findsOneWidget);
      expect(find.text('Phát cảnh báo khẩn cấp'), findsOneWidget);

      // Bấm nút phát cảnh báo
      await tester.ensureVisible(find.text('Phát cảnh báo khẩn cấp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phát cảnh báo khẩn cấp'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(mockRepo.emergencyCalls, 1);
      // Hiện màn hình danh bạ gọi nhanh bố mẹ
      expect(find.text('Đã ghi nhận sự cố khẩn cấp'), findsOneWidget);
      expect(find.text('Bố · Nguyễn Văn Bố'), findsOneWidget);
      expect(find.text('Mẹ · Trần Thị Mẹ'), findsOneWidget);
      expect(find.text('0911222333'), findsOneWidget);
      expect(find.text('Gọi ngay'), findsNWidgets(2));
    });
  });
}
