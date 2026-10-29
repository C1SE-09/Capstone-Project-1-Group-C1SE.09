import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/leave_request_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'giáo viên thấy ETA đi trễ thay vì khoảng ngày nghỉ, màn hẹp không tràn',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final item = LeaveRequestEntity.fromJson({
      'request_id': 'request-1',
      'child_id': 'child-1',
      'parent_id': 'parent-1',
      'class_id': 'class-1',
      'from_date': '2026-10-29',
      'to_date': '2026-10-29',
      'request_type': 'late_arrival',
      'expected_arrival_time': '08:30:00',
      'reason': 'Gia đình có việc buổi sáng.',
      'status': 'pending',
      'created_at': '2026-10-28T20:00:00Z',
      'child_name': 'Bé An',
      'parent_name': 'Gia đình bé An',
    });
    await tester.pumpWidget(MaterialApp(
      theme: kinderTheme(),
      home: Scaffold(
          body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: LeaveRequestCard(item: item, onApprove: () {}, onReject: () {}),
      )),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Báo đi trễ'), findsOneWidget);
    expect(find.textContaining('08:30'), findsOneWidget);
    expect(find.text('Lý do đi trễ:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
