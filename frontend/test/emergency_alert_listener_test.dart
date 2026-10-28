// frontend/test/emergency_alert_listener_test.dart
// =========================================================
// Unit & Widget tests cho Task #294:
// - Lắng nghe thông báo khẩn cấp từ giáo viên
// - Còi hú báo động khẩn cấp (Siren)
// - Màn hình tóm tắt sự cố & Nút gọi điện thoại trực tiếp cho cô giáo

import 'package:adark_frontend/core/notifications/emergency_siren_service.dart';
import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/core/routing/app_router.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/domain/entities/health/emergency_alert_data.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/emergency_alert_summary_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testParentSession = AppSession(
  accessToken: 'test-parent-token',
  refreshToken: 'test-parent-refresh',
  sessionId: 'test-parent-session',
  role: 'parent',
  parentId: 'parent-123',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final push = PushNotificationService.instance;

  group('1. EmergencyAlertData Entity Tests', () {
    test('Parse đầy đủ thông tin từ FCM data map', () {
      final map = {
        'type': 'health_incident_alert',
        'incident_id': 'inc-999',
        'child_id': 'child-456',
        'child_name': 'Bé Gia Bảo',
        'incident_type': 'Sốt cao co giật',
        'teacher_name': 'Cô Nguyễn Thu Hà',
        'teacher_phone': '0912345678',
        'description': 'Bé đang sốt 39.5 độ, đã chườm ấm',
        'temperature': '39.5',
        'created_at': '2026-10-28T14:30:00Z',
      };

      final alert = EmergencyAlertData.fromMap(map);

      expect(alert.incidentId, 'inc-999');
      expect(alert.childId, 'child-456');
      expect(alert.childName, 'Bé Gia Bảo');
      expect(alert.incidentType, 'Sốt cao co giật');
      expect(alert.teacherName, 'Cô Nguyễn Thu Hà');
      expect(alert.teacherPhone, '0912345678');
      expect(alert.description, 'Bé đang sốt 39.5 độ, đã chườm ấm');
      expect(alert.temperature, '39.5');
      expect(alert.createdAt?.toIso8601String(), '2026-10-28T14:30:00.000Z');
    });

    test('Chuyển đổi hai chiều sang query parameters bảo toàn dữ liệu', () {
      final original = EmergencyAlertData(
        incidentId: 'inc-100',
        childId: 'child-200',
        childName: 'Bé Linh Đan',
        incidentType: 'Dị ứng cấp tính',
        teacherName: 'Cô Lê Lan',
        teacherPhone: '0988777666',
        description: 'Bé mẩn đỏ quanh cổ sau giờ ăn trưa',
        temperature: '37.2',
        createdAt: DateTime.parse('2026-10-28T11:45:00Z'),
      );

      final queryParams = original.toQueryParameters();
      final reconstructed = EmergencyAlertData.fromMap(queryParams);

      expect(reconstructed.incidentId, original.incidentId);
      expect(reconstructed.childName, original.childName);
      expect(reconstructed.incidentType, original.incidentType);
      expect(reconstructed.teacherPhone, original.teacherPhone);
      expect(reconstructed.temperature, original.temperature);
      expect(reconstructed, equals(original));
    });
  });

  group('2. EmergencySirenService Tests', () {
    test('Khởi tạo singleton và trạng thái ban đầu an toàn', () {
      final service = EmergencySirenService.instance;
      expect(service, isNotNull);
      expect(service.isPlaying, isFalse);
    });

    test('playSiren và stopSiren an toàn khi enabled = false hoặc khi có lỗi plugin', () async {
      final service = EmergencySirenService.instance;
      service.enabled = false;
      await service.playSiren();
      expect(service.isPlaying, isFalse);
      await service.stopSiren();
      expect(service.isPlaying, isFalse);
      service.enabled = true;
    });
  });

  group('3. EmergencyAlertSummaryScreen Widget Tests', () {
    setUp(() {
      EmergencySirenService.instance.enabled = false;
    });

    tearDown(() {
      EmergencySirenService.instance.enabled = true;
    });

    final alert = EmergencyAlertData(
      incidentId: 'inc-101',
      childId: 'child-101',
      childName: 'Bé Minh Triết',
      incidentType: 'Ngã chấn thương đầu gối',
      teacherName: 'Cô Trần Ngọc Mai',
      teacherPhone: '0909123456',
      description: 'Bé vấp ngã khi chạy trong giờ ra chơi, cô đã sát trùng và băng lại.',
      temperature: '36.8',
      createdAt: DateTime.parse('2026-10-28T15:10:00Z'),
    );

    testWidgets('Hiển thị đầy đủ thông tin cảnh báo khẩn cấp và nút gọi điện thoại', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyAlertSummaryScreen(
              alert: alert,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Kiểm tra Header
      expect(find.text('CẢNH BÁO SỰ CỐ KHẨN CẤP'), findsOneWidget);

      // Kiểm tra thông tin bé
      expect(find.text('Bé Minh Triết'), findsOneWidget);
      expect(find.text('Ngã chấn thương đầu gối'), findsOneWidget);
      expect(find.text('36.8°C'), findsOneWidget);

      // Kiểm tra ghi chú của giáo viên
      expect(
        find.text('Bé vấp ngã khi chạy trong giờ ra chơi, cô đã sát trùng và băng lại.'),
        findsOneWidget,
      );

      // Kiểm tra tên cô giáo
      expect(find.text('Cô giáo xử lý: Cô Trần Ngọc Mai'), findsOneWidget);

      // Kiểm tra nút gọi điện thoại
      expect(find.text('GỌI CHO CÔ GIÁO: 0909123456'), findsOneWidget);
      expect(find.byIcon(Icons.phone_in_talk), findsOneWidget);

      // Kiểm tra nút tắt chuông
      expect(find.text('Đã nắm thông tin & Tắt chuông'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('Bấm nút tắt chuông kích hoạt callback onDismiss', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyAlertSummaryScreen(
              alert: alert,
              onDismiss: () {
                dismissed = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Đã nắm thông tin & Tắt chuông'));
      await tester.pump();

      expect(dismissed, isTrue);
    });
  });

  group('4. PushNotificationService Emergency Alert Routing Tests', () {
    setUp(() async {
      EmergencySirenService.instance.enabled = false;
      SharedPreferences.setMockInitialValues({});
      await SessionManagementService.instance.saveSession(_testParentSession);
      appRouter.go('/parent');
    });

    tearDown(() async {
      EmergencySirenService.instance.enabled = true;
      await push.deleteCurrentDevice();
      await SessionManagementService.instance.clearSession();
      await EmergencySirenService.instance.stopSiren();
    });

    testWidgets('Chạm push health_incident_alert mở đúng màn /parent/emergency-alert', (tester) async {
      push.handleNotificationTap(const RemoteMessage(data: {
        'type': 'health_incident_alert',
        'incident_id': 'inc-777',
        'child_id': 'child-777',
        'child_name': 'Bé Tuấn Kiệt',
        'incident_type': 'Sốt cao',
        'teacher_name': 'Cô Hoàng Yến',
        'teacher_phone': '0933112233',
        'description': 'Bé sốt 39.2 độ',
        'temperature': '39.2',
        'created_at': '2026-10-28T14:00:00Z',
      }));

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      final uri = appRouter.routeInformationProvider.value.uri;
      expect(uri.path, '/parent/emergency-alert');
      expect(uri.queryParameters['child_name'], 'Bé Tuấn Kiệt');
      expect(uri.queryParameters['incident_type'], 'Sốt cao');
      expect(uri.queryParameters['teacher_phone'], '0933112233');
      expect(uri.queryParameters['temperature'], '39.2');
      expect(tester.takeException(), isNull);
    });
  });
}
