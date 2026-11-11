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

  List<LeaveRequestEntity> reviewedList = [
    LeaveRequestEntity(
      requestId: 'req-reviewed',
      childId: 'child-reviewed',
      parentId: 'parent-reviewed',
      classId: 'class-1',
      fromDate: DateTime(2026, 10, 24),
      toDate: DateTime(2026, 10, 24),
      reason: 'Gia đình có việc riêng.',
      status: LeaveStatus.approved,
      createdAt: DateTime(2026, 10, 23, 10),
      childName: 'Trần Bảo Ngọc',
      parentName: 'Nguyễn Văn Bình',
    ),
  ];
  bool failReviewedRequests = false;
  bool approveCalled = false;
  String? rejectReasonReceived;

  @override
  Future<LeaveRequestEntity> getRequest(String id) async => [
        ...pendingList,
        ...reviewedList
      ].firstWhere((item) => item.requestId == id);

  @override
  Future<LeaveRequestBatchResult> getLeaveRequests({
    required String classId,
    required String tab,
    int offset = 0,
    int limit = 50,
  }) async {
    if (tab == 'reviewed' && failReviewedRequests) {
      throw const LeaveRequestException('Temporary failure');
    }
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
      requestType: item.requestType,
      expectedArrivalTime: item.expectedArrivalTime,
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
    expect(
      transport.requests
          .where((request) =>
              request.queryParameters['tab'] == 'reviewed' &&
              request.queryParameters['offset'] == 0)
          .length,
      2,
    );
    expect(find.text('Bé thứ 1'), findsOneWidget);
    final listScrollable = find
        .descendant(
            of: find.byType(ListView).first, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Tải thêm'), 400,
        scrollable: listScrollable);
    expect(find.text('Tải thêm'), findsOneWidget);
    await tester.tap(find.text('Tải thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Bé thứ 50'), findsOneWidget);
    expect(find.text('Thử lại tải thêm'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Thử lại tải thêm'), 400,
        scrollable: listScrollable);
    await tester.tap(find.text('Thử lại tải thêm'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Bé thứ 51'), 400,
        scrollable: listScrollable);
    expect(find.text('Bé thứ 51'), findsOneWidget);
    expect(
        transport.requests
            .where((request) => request.queryParameters['tab'] == 'reviewed')
            .map((request) => request.queryParameters['offset']),
        [0, 0, 50, 50]);
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
    expect(find.text('Lớp Mầm 1'), findsOneWidget);
    expect(find.text('Đơn xin nghỉ và báo đi trễ'), findsOneWidget);
    expect(find.textContaining('Chờ duyệt'), findsOneWidget);
    expect(find.text('Đã xử lý'), findsOneWidget);
    expect(find.text('Nguyễn Minh An'), findsOneWidget);
    expect(find.byKey(const ValueKey('leave-request-preview-req-1')),
        findsOneWidget);
  });

  testWidgets('leave inbox shows class navigation and recent real decisions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LeaveRequestReviewScreen(
        classId: 'class-1',
        className: 'Lớp Mầm 1',
        repository: MockLeaveRequestRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Danh sách'), findsOneWidget);
    expect(find.text('Điểm danh'), findsOneWidget);
    expect(find.text('Đơn nghỉ'), findsOneWidget);
    expect(find.text('Lịch học'), findsOneWidget);
    expect(find.text('Đã xử lý gần đây'), findsOneWidget);
    expect(find.text('Trần Bảo Ngọc'), findsOneWidget);
    expect(find.text('Đã duyệt'), findsWidgets);
    expect(
      find.byKey(const ValueKey('garden-voice-teacher-navigation')),
      findsOneWidget,
    );
  });

  testWidgets('pending requests remain visible if recent history fails',
      (tester) async {
    final repository = MockLeaveRequestRepository()
      ..failReviewedRequests = true;
    await tester.pumpWidget(MaterialApp(
      home: LeaveRequestReviewScreen(
        classId: 'class-1',
        repository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Minh An'), findsOneWidget);
    expect(find.text('Đã xử lý gần đây'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opened request detail follows Figma and retains review actions',
      (tester) async {
    final mockRepo = MockLeaveRequestRepository();
    final request = mockRepo.pendingList.first;
    await tester.pumpWidget(MaterialApp(
      home: LeaveRequestReviewScreen(
        classId: 'class-1',
        className: 'Lớp Mầm 1',
        repository: mockRepo,
        initialRequest: request,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết đơn · Lớp Mầm 1'), findsOneWidget);
    expect(find.text('Người gửi'), findsOneWidget);
    expect(find.text('Nguyễn Văn Ba'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Duyệt đơn'), findsOneWidget);
    expect(find.text('Từ chối'), findsOneWidget);
    await tester.tap(find.text('Duyệt đơn'));
    await tester.pumpAndSettle();
    expect(mockRepo.approveCalled, isTrue);
    expect(find.text('Đã duyệt đơn'), findsOneWidget);
    expect(find.text('Phụ huynh đã nhận thông báo kết quả.'), findsNothing);
    expect(find.text('Duyệt đơn'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duyệt báo trễ hiển thị ETA từ response, không giả giờ check-in',
      (tester) async {
    final mockRepo = MockLeaveRequestRepository();
    final lateRequest = LeaveRequestEntity(
      requestId: 'req-late',
      childId: 'child-late',
      parentId: 'parent-late',
      classId: 'class-1',
      fromDate: DateTime(2026, 11, 5),
      toDate: DateTime(2026, 11, 5),
      reason: 'Gia đình sẽ đưa bé đến muộn.',
      status: LeaveStatus.pending,
      createdAt: DateTime(2026, 11, 4, 17),
      childName: 'Lê Hoàng Nam',
      requestType: LeaveRequestType.lateArrival,
      expectedArrivalTime: '08:30:00',
    );
    mockRepo.pendingList = [lateRequest];
    DateTime? attendanceDate;

    await tester.pumpWidget(MaterialApp(
      home: LeaveRequestReviewScreen(
        classId: 'class-1',
        className: 'Lớp Mầm 1',
        repository: mockRepo,
        initialRequest: lateRequest,
        onOpenAttendanceForDate: (date) => attendanceDate = date,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duyệt đơn'));
    await tester.pumpAndSettle();

    expect(find.text('Báo trễ đã duyệt'), findsOneWidget);
    expect(find.text('Dự kiến đến lúc 08:30'), findsOneWidget);
    expect(
      find.textContaining('Giờ đến thực tế do giáo viên xác nhận'),
      findsOneWidget,
    );
    expect(find.text('Đến lúc 08:30'), findsNothing);

    await tester.tap(find.text('Về Điểm danh'));
    await tester.pumpAndSettle();
    expect(attendanceDate, DateTime(2026, 11, 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opened request detail scrolls at 320dp and 200% text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mockRepo = MockLeaveRequestRepository();
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: MaterialApp(
        home: LeaveRequestReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm 1',
          repository: mockRepo,
          initialRequest: mockRepo.pendingList.first,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bé bị sốt phát ban, gia đình xin nghỉ 2 ngày.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
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

    await tester.tap(find.byKey(const ValueKey('leave-request-preview-req-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duyệt đơn'));
    await tester.pumpAndSettle();

    expect(mockRepo.approveCalled, isTrue);
    expect(find.text('Đã duyệt'), findsOneWidget);
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
    await tester.tap(find.byKey(const ValueKey('leave-request-preview-req-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();

    // Kiểm tra Dialog hiển thị
    expect(find.text('Từ chối đơn'), findsOneWidget);
    final confirmButtonFinder =
        find.widgetWithText(FilledButton, 'Gửi từ chối');
    expect(confirmButtonFinder, findsOneWidget);

    // Khi ô nhập đang trống, nút không được kích hoạt (onPressed là null)
    final initialButton = tester.widget<FilledButton>(confirmButtonFinder);
    expect(initialButton.onPressed, isNull);

    // Nhập lý do từ chối
    await tester.enterText(
        find.byType(TextField), 'Trùng lịch thi bé cần có mặt');
    await tester.pumpAndSettle();

    // Nút đã sẵn sàng
    final enabledButton = tester.widget<FilledButton>(confirmButtonFinder);
    expect(enabledButton.onPressed, isNotNull);

    // Xác nhận từ chối
    await tester.tap(confirmButtonFinder);
    await tester.pumpAndSettle();

    expect(mockRepo.rejectReasonReceived, 'Trùng lịch thi bé cần có mặt');
    expect(find.text('Từ chối'), findsOneWidget);
  });
}
