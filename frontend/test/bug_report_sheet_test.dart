import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:adark_frontend/domain/entities/bug_report/bug_report.dart';
import 'package:adark_frontend/domain/entities/bug_report/bug_report_list_response.dart';
import 'package:adark_frontend/domain/entities/bug_report/enums.dart';
import 'package:adark_frontend/domain/repositories/bug_report_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/bug_report_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class _FakeBugReportRepository implements BugReportRepository {
  BugReportCreatePayload? lastCreatedPayload;

  @override
  Future<BugReportDetail> create(BugReportCreatePayload payload) async {
    lastCreatedPayload = payload;
    return BugReportDetail(
      bugReportId: 'test-id',
      user: const BugReportUser(userId: 'u1', username: 'parent1', role: 'parent'),
      title: payload.title,
      description: payload.description,
      category: payload.category,
      severity: payload.severity,
      status: BugStatus.open,
      attachmentCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<BugReportListResponse> listMyReports({int page = 1, int pageSize = 20, String? status}) async {
    return const BugReportListResponse(
      items: [],
      total: 0,
      page: 1,
      pageSize: 20,
      totalPages: 0,
      hasNext: false,
      hasPrev: false,
    );
  }

  @override
  Future<BugReportListResponse> listAllReports({
    int page = 1,
    int pageSize = 20,
    BugReportFilter? filter,
    String orderBy = 'created_at_desc',
  }) async {
    return const BugReportListResponse(
      items: [],
      total: 0,
      page: 1,
      pageSize: 20,
      totalPages: 0,
      hasNext: false,
      hasPrev: false,
    );
  }

  @override
  Future<BugReportDetail> getReport(String reportId) async {
    throw UnimplementedError();
  }

  @override
  Future<BugReportDetail> updateReport(String reportId, BugReportUpdatePayload payload) async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'KinderLog',
      packageName: 'com.adark.kinderlog',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return ['wifi'];
        }
        return null;
      },
    );
  });

  testWidgets('BugReportBottomSheet does not let user pick category or severity', (tester) async {
    final fakeRepo = _FakeBugReportRepository();

    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: kinderTheme(),
        home: Scaffold(
          body: SizedBox(
            height: 1400,
            child: BugReportBottomSheet(repository: fakeRepo),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Description fields exist
    expect(find.text('Tiêu đề góp ý / vấn đề *'), findsOneWidget);
    expect(find.text('Mô tả chi tiết *'), findsOneWidget);

    // Verify Category and Severity pickers are NOT present
    expect(find.text('Phân loại vấn đề'), findsNothing);
    expect(find.text('Mức độ ảnh hưởng'), findsNothing);
    expect(find.text('Giao diện / UI'), findsNothing);
    expect(find.text('Nghiêm trọng'), findsNothing);

    // Enter valid inputs
    await tester.enterText(find.byType(TextFormField).at(0), 'Nút gửi báo cáo không bấm được');
    await tester.enterText(find.byType(TextFormField).at(1), 'Tôi bấm vào nút nhưng không có phản hồi.');
    await tester.pumpAndSettle();

    // Submit report
    final submitButton = find.text('Gửi góp ý cải thiện');
    expect(submitButton, findsOneWidget);
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();

    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify submitted payload defaulted to other and medium
    expect(fakeRepo.lastCreatedPayload, isNotNull);
    expect(fakeRepo.lastCreatedPayload!.category, BugCategory.other);
    expect(fakeRepo.lastCreatedPayload!.severity, BugSeverity.medium);
    expect(fakeRepo.lastCreatedPayload!.title, 'Nút gửi báo cáo không bấm được');
    expect(fakeRepo.lastCreatedPayload!.description, 'Tôi bấm vào nút nhưng không có phản hồi.');
  });
}
