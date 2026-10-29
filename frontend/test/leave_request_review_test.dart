import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/leave_request_review_screen.dart';
import 'package:dio/dio.dart';
import 'parent_request_repository_test.dart'
    show RequestTransport, jsonBody, requestJson;

class MockLeaveRequestRepository extends HttpLeaveRequestRepository {
  List<LeaveRequestEntity> pendingList = [
    LeaveRequestEntity(
      requestId: 'req-1',
      childId: 'child-1',
      parentId: 'parent-1',
      classId: 'class-1',
      fromDate: DateTime(2026, 10, 27),
      toDate: DateTime(2026, 10, 28),
      reason: 'Bé bị sốt phát ban, gia đình xin nghỉ 2 ngày.',
      status: LeaveStatus.pending,
      createdAt: DateTime(2026, 10, 26, 10, 0),
      childName: 'Nguyễn Minh An',
      parentName: 'Nguyễn Văn Ba',
    ),
  ];

  List<LeaveRequestEntity> reviewedList = [];
  bool approveCalled = false;
  String? rejectReasonReceived;

  @override
  Future<LeaveRequestBatchResult> getLeaveRequests({
    required String classId,
    required String tab,
    int offset = 0,
    int limit = 50,
  }) async {
    if (tab == 'pending') {
      return LeaveRequestBatchResult(
        pendingCount: pendingList.length,
        reviewedCount: reviewedList.length,
        items: pendingList,
      );
    } else {
      return LeaveRequestBatchResult(
        pendingCount: pendingList.length,
        reviewedCount: reviewedList.length,
        items: reviewedList,
      );
    }
  }

  @override
  Future<LeaveRequestEntity> approveLeaveRequest(String requestId) async {
    approveCalled = true;
    final item = pendingList.firstWhere((e) => e.requestId == requestId);
    pendingList.remove(item);
    final approvedItem = LeaveRequestEntity(
      requestId: item.requestId,
      childId: item.childId,
      parentId: item.parentId,
      classId: item.classId,
      fromDate: item.fromDate,
      toDate: item.toDate,
      reason: item.reason,
      status: LeaveStatus.approved,
      createdAt: item.createdAt,
      childName: item.childName,
      parentName: item.parentName,
      reviewedAt: DateTime.now(),
    );
    reviewedList.add(approvedItem);
    return approvedItem;
  }

  @override
  Future<LeaveRequestEntity> rejectLeaveRequest({
    required String requestId,
    required String rejectReason,
  }) async {
    rejectReasonReceived = rejectReason;
    final item = pendingList.firstWhere((e) => e.requestId == requestId);
    pendingList.remove(item);
    final rejectedItem = LeaveRequestEntity(
      requestId: item.requestId,
      childId: item.childId,
      parentId: item.parentId,
      classId: item.classId,
      fromDate: item.fromDate,
      toDate: item.toDate,
      reason: item.reason,
      status: LeaveStatus.rejected,
      rejectReason: rejectReason,
      createdAt: item.createdAt,
      childName: item.childName,
      parentName: item.parentName,
      reviewedAt: DateTime.now(),
    );
    reviewedList.add(rejectedItem);
    return rejectedItem;
  }
}

void main() {
  testWidgets('giáo viên tải tiếp được đơn đã xử lý thứ 51', (tester) async {
    var failNextPage = true;
    final transport = RequestTransport((options) {
      final tab = options.queryParameters['tab'];
      final offset = options.queryParameters['offset'] as int? ?? 0;
      if (tab == 'reviewed' && offset == 50 && failNextPage) {
        failNextPage = false;
        return jsonBody({'detail': 'Tạm thời gián đoạn'}, 503);
      }
      return jsonBody({
        'pending_count': 0,
        'reviewed_count': 51,
        'items': tab != 'reviewed'
            ? []
            : [
                for (var index = offset;
                    index < (offset == 0 ? 50 : 51);
                    index++)
                  {
                    ...requestJson(status: 'approved'),
                    'request_id': 'request-$index',
                    'child_name': 'Bé thứ ${index + 1}'
                  },
              ]
      });
    });
    final repository = HttpLeaveRequestRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://school.test'))
          ..httpClientAdapter = transport);
    await tester.pumpWidget(MaterialApp(
        home: LeaveRequestReviewScreen(
            classId: 'class-1', repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã xử lý'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -25000));
    await tester.pumpAndSettle();
    expect(find.text('Tải thêm'), findsOneWidget);
    await tester.tap(find.text('Tải thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Bé thứ 50'), findsOneWidget);
    expect(find.text('Thử lại tải thêm'), findsOneWidget);
    await tester.ensureVisible(find.text('Thử lại tải thêm'));
    await tester.tap(find.text('Thử lại tải thêm'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -25000));
    await tester.pumpAndSettle();
    expect(find.text('Bé thứ 51'), findsOneWidget);
    expect(
        transport.requests
            .where((request) => request.queryParameters['tab'] == 'reviewed')
            .map((request) => request.queryParameters['offset']),
        [0, 50, 50]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LeaveRequestReviewScreen renders tabs and cards correctly',
      (tester) async {
    final mockRepo = MockLeaveRequestRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: LeaveRequestReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          repository: mockRepo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Kiểm tra UI hiển thị
    expect(find.text('Duyệt đơn nghỉ / đi trễ • Lớp Mầm 1'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(find.text('Đã xử lý'), findsOneWidget);
    expect(find.text('Nguyễn Minh An'), findsOneWidget);
    expect(find.text('Duyệt đơn'), findsOneWidget);
    expect(find.text('Từ chối'), findsOneWidget);
  });

  testWidgets('Approve action triggers 1-tap approval', (tester) async {
    final mockRepo = MockLeaveRequestRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: LeaveRequestReviewScreen(
          classId: 'class-1',
          repository: mockRepo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Bấm Duyệt đơn
    await tester.tap(find.text('Duyệt đơn'));
    await tester.pumpAndSettle();

    expect(mockRepo.approveCalled, isTrue);
    expect(find.text('Không có đơn nào đang chờ duyệt'), findsOneWidget);
  });

  testWidgets('Reject action opens dialog with mandatory reason validation',
      (tester) async {
    final mockRepo = MockLeaveRequestRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: LeaveRequestReviewScreen(
          classId: 'class-1',
          repository: mockRepo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Bấm Từ chối
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();

    // Kiểm tra Dialog hiển thị
    expect(find.text('Từ chối đơn xin nghỉ'), findsOneWidget);
    final confirmButtonFinder =
        find.widgetWithText(ElevatedButton, 'Xác nhận từ chối');
    expect(confirmButtonFinder, findsOneWidget);

    // Khi ô nhập đang trống, nút không được kích hoạt (onPressed là null)
    final initialButton = tester.widget<ElevatedButton>(confirmButtonFinder);
    expect(initialButton.onPressed, isNull);

    // Nhập lý do từ chối
    await tester.enterText(
        find.byType(TextField), 'Trùng lịch thi bé cần có mặt');
    await tester.pumpAndSettle();

    // Nút đã sẵn sàng
    final enabledButton = tester.widget<ElevatedButton>(confirmButtonFinder);
    expect(enabledButton.onPressed, isNotNull);

    // Xác nhận từ chối
    await tester.tap(confirmButtonFinder);
    await tester.pumpAndSettle();

    expect(mockRepo.rejectReasonReceived, 'Trùng lịch thi bé cần có mặt');
    expect(find.text('Không có đơn nào đang chờ duyệt'), findsOneWidget);
  });
}
