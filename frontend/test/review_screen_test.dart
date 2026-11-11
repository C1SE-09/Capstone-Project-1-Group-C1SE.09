import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart'
    as domain_child;
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart'
    as domain_teacher;

class MockDashboardRepository extends HttpDashboardRepository {
  @override
  Future<List<domain_child.Child>> getClassChildren(String classId) async {
    return [
      domain_child.Child(
        childId: 'child-1',
        classId: 'class-1',
        fullName: 'Bé Nguyễn Văn A',
        nickname: 'Bi',
        dateOfBirth: DateTime(2020, 1, 1),
        gender: 'male',
      ),
      domain_child.Child(
        childId: 'child-2',
        classId: 'class-1',
        fullName: 'Bé Trần Thị B',
        nickname: 'Bông',
        dateOfBirth: DateTime(2020, 2, 2),
        gender: 'female',
      ),
    ];
  }

  @override
  Future<ClassDashboardSummary> getClassDashboard(
      String classId, DateTime date) async {
    return const ClassDashboardSummary(
      classInfo: ClassInfo(
        classId: 'class-1',
        schoolId: 'school-1',
        name: 'Lớp Mầm A',
      ),
      teacherName: 'Cô Mai',
      totalChildren: 2,
      completedCount: 0,
      draftCount: 0,
      missingCount: 2,
      pendingChildren: [],
    );
  }

  @override
  Future<domain_teacher.Teacher> getCurrentTeacher() async {
    return const domain_teacher.Teacher(
      teacherId: 'teacher-1',
      fullName: 'Cô Mai',
      email: 'mai@example.com',
      classId: 'class-1',
    );
  }
}

void main() {
  testWidgets(
      'ReviewScreen handles integer unmatched_segments from backend without crashing',
      (WidgetTester tester) async {
    // Backend returns integer count for unmatched_segments, e.g. "unmatched_segments": 0
    final extraction = const ExtractionData(
      transcript: 'Hôm nay các bé ăn cơm ngoan, ngủ trưa đúng giờ.',
      rawJson: {
        'unmatched_segments':
            0, // Integer from backend that previously caused type cast error
        'child_extractions': {
          'child-1': {
            'meals': 'Ăn hết 2 bát cơm',
            'sleeping': 'Ngủ đủ 120 phút',
          },
          'child-2': {
            'meals': 'Ăn đủ suất',
            'sleeping': 'Ngủ ngoan',
          },
        },
      },
      childExtractions: {
        'child-1': {
          'meals': 'Ăn hết 2 bát cơm',
          'sleeping': 'Ngủ đủ 120 phút',
        },
        'child-2': {
          'meals': 'Ăn đủ suất',
          'sleeping': 'Ngủ ngoan',
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm A',
          extraction: extraction,
          repository: MockDashboardRepository(),
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    );

    // Initial pump shows loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for future to complete
    await tester.pumpAndSettle();

    // Verify error message is NOT shown
    expect(find.text('Không tải được danh sách trẻ · Thử lại'), findsNothing);

    // Verify header and child observation items are rendered
    expect(find.text('Xem lại báo cáo'), findsOneWidget);
    expect(find.text('Bước 3/3 · Xem lại'), findsOneWidget);
    expect(find.text('Bé Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Bé Trần Thị B'), findsOneWidget);
    expect(find.textContaining('Ăn hết 2 bát cơm'), findsOneWidget);
    expect(tester.widget<CounterPill>(find.byType(CounterPill)).total, 2);

    // Verify Analyzed Text card is rendered
    expect(find.text('Văn bản đã phân tích'), findsOneWidget);
    expect(find.text('Đã tách 2 bé'), findsOneWidget);
  });

  testWidgets(
      'ReviewScreen expands analyzed text and shows unapprove button after approve',
      (WidgetTester tester) async {
    final extraction = const ExtractionData(
      transcript: 'Hôm nay các bé ăn cơm ngoan, ngủ trưa đúng giờ.',
      childExtractions: {
        'child-1': {
          'meals': 'Ăn hết 2 bát cơm',
          'sleeping': 'Ngủ đủ 120 phút',
        },
      },
    );

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockTeacher = MockTeacherRepo();

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm A',
          extraction: extraction,
          transcript: 'Hôm nay các bé ăn cơm ngoan, ngủ trưa đúng giờ.',
          voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
          repository: MockDashboardRepository(),
          teacherRepository: mockTeacher,
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Check Analyzed Text Card
    expect(find.text('Văn bản đã phân tích'), findsOneWidget);
    expect(find.text('Hôm nay các bé ăn cơm ngoan, ngủ trưa đúng giờ.'),
        findsOneWidget);
    await tester.tap(find.text('Văn bản đã phân tích'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay các bé ăn cơm ngoan, ngủ trưa đúng giờ.'),
        findsNothing);
    await tester.tap(find.text('Văn bản đã phân tích'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay các bé ăn cơm ngoan, ngủ trưa đúng giờ.'),
        findsOneWidget);

    // 2. Check initial Duyệt button and Send button disabled
    expect(find.text('Duyệt'), findsOneWidget);
    expect(find.text('Chưa duyệt mục nào để gửi'), findsOneWidget);
    final initialButton =
        tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(initialButton.onPressed, isNull);

    // Tap Duyệt
    await tester.ensureVisible(find.text('Duyệt'));
    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();

    // 3. Now it should show both "Đã duyệt" and "Bỏ duyệt", send button enabled
    expect(find.text('Đã duyệt'), findsWidgets);
    expect(find.text('Bỏ duyệt'), findsOneWidget);
    expect(find.text('Bỏ duyệt tất cả'), findsNothing);
    expect(find.text('Hoàn thành'), findsOneWidget);
    final approvedButton =
        tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(approvedButton.onPressed, isNotNull);

    // Tap Bỏ duyệt
    await tester.ensureVisible(find.text('Bỏ duyệt'));
    await tester.tap(find.text('Bỏ duyệt'));
    await tester.pumpAndSettle();

    // 4. Returns to "Duyệt", send button disabled again, and drafts deleted
    expect(find.text('Duyệt'), findsOneWidget);
    expect(find.text('Bỏ duyệt'), findsNothing);
    expect(find.text('Chưa duyệt mục nào để gửi'), findsOneWidget);
    final unapprovedButton =
        tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(unapprovedButton.onPressed, isNull);
    expect(mockTeacher.deletedReportIds, contains('draft-123'));
  });

  testWidgets('ReviewScreen opens full-screen edit form and saves content',
      (WidgetTester tester) async {
    final extraction = const ExtractionData(
      transcript: 'Hôm nay các bé ăn cơm ngoan.',
      childExtractions: {
        'child-1': {
          'meals': 'Ăn hết 2 bát cơm',
          'sleeping': 'Ngủ từ 12:00 đến 13:45, ngủ ngon, không quấy khóc.',
        },
      },
    );

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm A',
          extraction: extraction,
          transcript: 'Hôm nay các bé ăn cơm ngoan.',
          voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
          repository: MockDashboardRepository(),
          teacherRepository: MockTeacherRepo(),
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Check Chỉnh sửa button is rendered
    expect(find.text('Chỉnh sửa'), findsOneWidget);
    await tester.tap(find.text('Chỉnh sửa'));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh sửa báo cáo'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Thời lượng (phút)'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
              find.byKey(const ValueKey('sleep-duration-minutes')))
          .controller
          ?.text,
      '105',
    );
    expect(
      tester
          .widget<TextField>(
              find.byKey(const ValueKey('sleep-duration-minutes')))
          .controller
          ?.text,
      '105',
    );
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(find.textContaining('/500 ký tự'), findsOneWidget);

    // Tap Lưu thay đổi
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    // Verify modal is closed
    expect(find.text('Lưu thay đổi'), findsNothing);
    expect(find.textContaining('105 phút'), findsOneWidget);
  });

  testWidgets('assigning an unmatched segment leaves it pending for review',
      (tester) async {
    final extraction = const ExtractionData(
      transcript: 'Hôm nay Minh An ăn cơm. Chiều bé vẽ tranh mùa thu.',
      childExtractions: {
        'child-1': {'meals': 'Ăn cơm ngoan'},
      },
      rawJson: {
        'unmatched_segments': [
          {
            'text': 'Chiều bé vẽ tranh mùa thu.',
            'extraction': {'activities': 'Vẽ tranh mùa thu'},
          },
        ],
      },
    );
    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(
        classId: 'class-1',
        className: 'Lớp Mầm A',
        extraction: extraction,
        repository: MockDashboardRepository(),
        teacherRepository: MockTeacherRepo(),
        onBack: () {},
        onCompleted: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chưa xác định bé'), findsOneWidget);

    await tester.ensureVisible(find.text('Gán đoạn này'));
    await tester.tap(find.text('Gán đoạn này'));
    await tester.pumpAndSettle();
    expect(find.text('Gán đoạn ghi'), findsOneWidget);
    expect(find.text('Cả lớp Mầm A'), findsOneWidget);
    await tester.tap(find.text('Bé Nguyễn Văn A').last);
    await tester.pumpAndSettle();

    expect(find.text('Đã duyệt'), findsNothing);
    expect(find.text('Duyệt'), findsNWidgets(2));
    expect(find.text('Chưa duyệt mục nào để gửi'), findsOneWidget);
  });

  testWidgets('review remains scrollable at 320dp and 200% text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: MaterialApp(
        home: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm A',
          extraction: const ExtractionData(
            transcript: 'Hôm nay Minh An ăn hết suất cơm và ngủ trưa ngon.',
            childExtractions: {
              'child-1': {
                'meals': 'Ăn hết suất cơm với thịt kho và canh bí.',
                'sleeping': 'Ngủ từ 12:00 đến 13:45, ngủ ngon.',
                'activities': 'Vẽ tranh mùa thu và vui chơi với các bạn.',
              },
            },
          ),
          repository: MockDashboardRepository(),
          teacherRepository: MockTeacherRepo(),
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Xem lại báo cáo'), findsOneWidget);
    expect(find.text('Duyệt'), findsOneWidget);
    expect(
        MediaQuery.textScalerOf(
                tester.element(find.text('Văn bản đã phân tích')))
            .scale(1),
        2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ReviewScreen does not display missing fields and leaves note empty',
      (WidgetTester tester) async {
    final extraction = const ExtractionData(
      transcript: 'Hôm nay bé ăn rất ngoan hết suất.',
      childExtractions: {
        'child-1': {
          'meals': 'Ăn rất ngoan hết suất',
          // sleeping, activities, mood, health not provided
          // notes not provided
        },
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm A',
          extraction: extraction,
          repository: MockDashboardRepository(),
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify meals is extracted
    expect(find.textContaining('Ăn rất ngoan hết suất'), findsOneWidget);

    // Verify missing fields are NOT rendered
    expect(find.textContaining('Giấc ngủ:'), findsNothing);
    expect(find.textContaining('Hoạt động:'), findsNothing);
    expect(find.textContaining('Tâm trạng:'), findsNothing);
    expect(find.textContaining('Sức khỏe:'), findsNothing);

    // Verify Ghi chú is NOT rendered because it was left empty
    expect(find.textContaining('Ghi chú:'), findsNothing);
  });

  testWidgets(
      'ReviewScreen displays audio player card above analyzed text card when recordedBytes is provided',
      (WidgetTester tester) async {
    final extraction = const ExtractionData(
      transcript: 'Hôm nay các bé ăn cơm ngoan.',
      childExtractions: {
        'child-1': {'meals': 'Ăn hết suất'},
      },
    );

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockTeacher = MockTeacherRepo();
    final dummyBytes = Uint8List.fromList([0, 1, 2, 3, 4]);

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm A',
          extraction: extraction,
          recordedBytes: dummyBytes,
          repository: MockDashboardRepository(),
          teacherRepository: mockTeacher,
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify audio player card is rendered
    expect(find.text('Bản ghi gốc'), findsOneWidget);

    // Verify Analyzed Text card is also rendered below it
    expect(find.text('Văn bản đã phân tích'), findsOneWidget);
  });

  testWidgets(
      'ReviewScreen requires all items to be approved or discarded before enabling send button',
      (WidgetTester tester) async {
    final extraction = const ExtractionData(
      transcript: 'Hôm nay các bé ăn cơm ngoan. Bé Lan vẽ hoa rất đẹp.',
      classWideExtraction: {
        'meals': 'Ăn hết cơm',
      },
      childExtractions: {
        'child-1': {
          'activities': 'Vẽ hoa đẹp',
        },
      },
    );

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockTeacher = MockTeacherRepo();

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm A',
          extraction: extraction,
          transcript: 'Hôm nay các bé ăn cơm ngoan. Bé Lan vẽ hoa rất đẹp.',
          voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
          repository: MockDashboardRepository(),
          teacherRepository: mockTeacher,
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Initial state: 2 items, none approved -> Send button disabled
    expect(find.text('Chưa duyệt mục nào để gửi'), findsOneWidget);
    var sendButton =
        tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(sendButton.onPressed, isNull);

    // 2. Approve ONLY the first item ("Chung cả lớp")
    final approveButtons = find.text('Duyệt');
    expect(approveButtons, findsNWidgets(2));
    await tester.ensureVisible(approveButtons.first);
    await tester.tap(approveButtons.first);
    await tester.pumpAndSettle();

    // Now 1 item is approved, but 1 item is STILL pending!
    // Send button must still be disabled, with text showing remaining pending items
    expect(find.text('Còn 1 mục chưa duyệt hoặc loại bỏ'), findsOneWidget);
    expect(
        find.text(
            'Còn 1 mục chưa xử lý. Vui lòng duyệt hoặc loại bỏ tất cả các mục để có thể gửi.'),
        findsOneWidget);
    sendButton = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(sendButton.onPressed, isNull);

    // 3. Discard the second item ("Loại bỏ")
    final discardButtons = find.text('Loại bỏ');
    expect(discardButtons, findsWidgets);
    await tester.ensureVisible(discardButtons.last);
    await tester.tap(discardButtons.last);
    await tester.pumpAndSettle();

    // Now all items are processed (1 approved, 1 discarded) -> Send button MUST be enabled!
    expect(find.text('Hoàn thành'), findsOneWidget);
    sendButton = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(sendButton.onPressed, isNotNull);

    // 4. Restore the discarded item ("Hoàn tác")
    await tester.ensureVisible(find.text('Hoàn tác'));
    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();

    // Returns to pending -> Send button disabled again
    expect(find.text('Còn 1 mục chưa duyệt hoặc loại bỏ'), findsOneWidget);
    sendButton = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(sendButton.onPressed, isNull);

    // 5. Approve the second item
    final secondApprove = find.text('Duyệt');
    await tester.ensureVisible(secondApprove.first);
    await tester.tap(secondApprove.first);
    await tester.pumpAndSettle();

    // Both items are approved -> Send button enabled with 2 reports
    expect(find.text('Xác nhận gửi cho cả lớp'), findsOneWidget);
    sendButton = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(sendButton.onPressed, isNotNull);
  });
}

class MockTeacherRepo extends TeacherRepository {
  final List<String> deletedReportIds = [];

  @override
  Future<Map<String, dynamic>> approveItem({
    required String voiceRecordId,
    required String teacherId,
    required String kind,
    String? childId,
    String? classId,
    Map<String, String?>? extraction,
  }) async {
    return {
      'draft_report_ids': ['draft-123'],
    };
  }

  @override
  Future<void> deleteDraftReports(List<String> reportIds) async {
    deletedReportIds.addAll(reportIds);
  }
}
