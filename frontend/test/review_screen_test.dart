import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart' as domain_child;
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';

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
        },
      },
      childExtractions: {
        'child-1': {
          'meals': 'Ăn hết 2 bát cơm',
          'sleeping': 'Ngủ đủ 120 phút',
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
  });
}
