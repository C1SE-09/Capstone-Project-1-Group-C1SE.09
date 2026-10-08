import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart' as domain_child;
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart' as domain_teacher;

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
  Future<ClassDashboardSummary> getClassDashboard(String classId, DateTime date) async {
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
  testWidgets('ReviewScreen handles integer unmatched_segments from backend without crashing',
      (WidgetTester tester) async {
    // Backend returns integer count for unmatched_segments, e.g. "unmatched_segments": 0
    final extraction = ExtractionData(
      transcript: 'Hôm nay các bé ăn cơm ngoan, ngủ trưa đúng giờ.',
      rawJson: {
        'unmatched_segments': 0, // Integer from backend that previously caused type cast error
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
    expect(find.text('Xem lại & tách theo bé'), findsOneWidget);
    expect(find.text('Bé Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Bé Trần Thị B'), findsOneWidget);
    expect(find.textContaining('Ăn hết 2 bát cơm'), findsOneWidget);

    // Verify Analyzed Text card is rendered
    expect(find.text('Xem lại text đã phân tích'), findsOneWidget);
  });

  testWidgets('ReviewScreen expands analyzed text and shows unapprove button after approve',
      (WidgetTester tester) async {
    final extraction = ExtractionData(
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

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewScreen(
          classId: 'class-1',
          className: 'Lớp Mầm A',
          extraction: extraction,
          transcript: 'Hôm nay các bé ăn cơm ngoan, ngủ trưa đúng giờ.',
          voiceRecord: const VoiceRecord(id: 'voice-1', status: 'completed'),
          repository: MockDashboardRepository(),
          teacherRepository: MockTeacherRepo(),
          onBack: () {},
          onCompleted: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Check Analyzed Text Card
    expect(find.text('Xem lại text đã phân tích'), findsOneWidget);
    await tester.tap(find.text('Xem lại text đã phân tích'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay các bé ăn cơm ngoan, ngủ trưa đúng giờ.'), findsOneWidget);

    // 2. Check initial Duyệt button
    expect(find.text('Duyệt'), findsOneWidget);

    // Tap Duyệt
    await tester.ensureVisible(find.text('Duyệt'));
    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();

    // 3. Now it should show both "Đã duyệt" and "Bỏ duyệt"
    expect(find.text('Đã duyệt'), findsWidgets);
    expect(find.text('Bỏ duyệt'), findsOneWidget);
    expect(find.text('Bỏ duyệt tất cả'), findsOneWidget);

    // Tap Bỏ duyệt
    await tester.ensureVisible(find.text('Bỏ duyệt'));
    await tester.tap(find.text('Bỏ duyệt'));
    await tester.pumpAndSettle();

    // 4. Returns to "Duyệt"
    expect(find.text('Duyệt'), findsOneWidget);
    expect(find.text('Bỏ duyệt'), findsNothing);
  });

  testWidgets('ReviewScreen allows editing observation content via edit sheet',
      (WidgetTester tester) async {
    final extraction = ExtractionData(
      transcript: 'Hôm nay các bé ăn cơm ngoan.',
      childExtractions: {
        'child-1': {
          'meals': 'Ăn hết 2 bát cơm',
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

    // Verify modal bottom sheet is open
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(find.textContaining('/500 ký tự'), findsOneWidget);

    // Tap Lưu thay đổi
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    // Verify modal is closed
    expect(find.text('Lưu thay đổi'), findsNothing);
  });

  testWidgets('ReviewScreen sets missing fields to "bình thường" and leaves note empty',
      (WidgetTester tester) async {
    final extraction = ExtractionData(
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

    // Verify missing fields are set to "bình thường"
    expect(find.textContaining('Giấc ngủ: bình thường'), findsOneWidget);
    expect(find.textContaining('Hoạt động: bình thường'), findsOneWidget);
    expect(find.textContaining('Tâm trạng: bình thường'), findsOneWidget);
    expect(find.textContaining('Sức khỏe: bình thường'), findsOneWidget);

    // Verify Ghi chú is NOT rendered because it was left empty
    expect(find.textContaining('Ghi chú:'), findsNothing);
  });
}

class MockTeacherRepo extends TeacherRepository {
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
}
