import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adark_frontend/data/repositories/http_report_response_repository.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_response.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/report_discussion_section.dart';
import 'package:dio/dio.dart';

class MockReportResponseRepository extends HttpReportResponseRepository {
  MockReportResponseRepository({
    this.initialList,
    this.sendCallback,
    this.attachmentBytes,
  }) : super(dio: Dio());

  final List<ReportResponse>? initialList;
  final Future<ReportResponse> Function(String reportId, String content, Uint8List? imageBytes)?
      sendCallback;
  final Uint8List? attachmentBytes;

  final List<ReportResponse> sentResponses = [];

  @override
  Future<List<ReportResponse>> getResponses(String reportId) async {
    return initialList ?? [];
  }

  @override
  Future<Uint8List> getAttachmentBytes(String urlOrPath) async {
    return attachmentBytes ??
        Uint8List.fromList(const [
          137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0,
          0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73,
          68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0,
          0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
        ]);
  }

  @override
  Future<ReportResponse> sendResponse({
    required String reportId,
    required String content,
    Uint8List? imageBytes,
    String? fileName,
    bool isTeacher = false,
  }) async {
    if (sendCallback != null) {
      return sendCallback!(reportId, content, imageBytes);
    }
    final response = ReportResponse(
      responseId: 'res-${sentResponses.length + 1}',
      dailyReportId: reportId,
      authorRole: isTeacher ? 'teacher' : 'parent',
      authorName: isTeacher ? 'Cô Hà' : 'Mẹ Bảo Châu',
      content: content,
      hasImage: imageBytes != null,
      isRead: false,
      isResolved: false,
      createdAt: DateTime.now(),
    );
    sentResponses.add(response);
    return response;
  }
}

void main() {
  group('ReportResponse Entity', () {
    test('fromJson and toJson round-trip preserves all fields', () {
      final json = {
        'response_id': '11111111-2222-3333-4444-555555555555',
        'daily_report_id': '22222222-3333-4444-5555-666666666666',
        'child_id': '33333333-4444-5555-6666-777777777777',
        'author_user_id': '44444444-5555-6666-7777-888888888888',
        'author_role': 'teacher',
        'author_name': 'Cô Nguyễn Thị Mai',
        'author_avatar_url': 'https://example.com/avatar.jpg',
        'content': 'Bé ăn ngủ rất ngoan ạ.',
        'image_url': '/api/report-responses/attachments/c1/a1',
        'has_image': true,
        'is_read': true,
        'is_resolved': true,
        'resolved_at': '2026-11-12T10:00:00.000Z',
        'created_at': '2026-11-12T09:30:00.000Z',
        'updated_at': null,
      };

      final entity = ReportResponse.fromJson(json);
      expect(entity.responseId, '11111111-2222-3333-4444-555555555555');
      expect(entity.authorRole, 'teacher');
      expect(entity.authorName, 'Cô Nguyễn Thị Mai');
      expect(entity.isFromTeacher, isTrue);
      expect(entity.isFromParent, isFalse);
      expect(entity.isResolved, isTrue);
      expect(entity.hasImage, isTrue);

      final out = entity.toJson();
      expect(out['response_id'], entity.responseId);
      expect(out['content'], entity.content);
      expect(out['is_resolved'], isTrue);
    });
  });

  group('ReportDiscussionSection Widget', () {
    final parentMessage = ReportResponse(
      responseId: 'r1',
      dailyReportId: 'rep-1',
      authorRole: 'parent',
      authorName: 'Mẹ Bảo Châu',
      content: 'Dạ em cảm ơn cô Mai. Hôm nay ở nhà bé hơi sổ mũi nhẹ.',
      isRead: true,
      isResolved: false,
      createdAt: DateTime(2026, 11, 12, 16, 45),
    );

    final teacherMessage = ReportResponse(
      responseId: 'r2',
      dailyReportId: 'rep-1',
      authorRole: 'teacher',
      authorName: 'Cô Nguyễn Thị Mai',
      content: 'Dạ mẹ yên tâm nhé, trưa nay cô cho bé nằm phòng ấm.',
      isRead: true,
      isResolved: true,
      createdAt: DateTime(2026, 11, 12, 17, 5),
    );

    testWidgets('renders discussion header, messages, badges, and resolved chip',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: kinderTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportDiscussionSection(
                reportId: 'rep-1',
                childName: 'Bảo Châu',
                teacherName: 'Cô Mai',
                initialResponses: [parentMessage, teacherMessage],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header checks
      expect(find.text('Trao đổi với giáo viên'), findsOneWidget);
      expect(find.text('2 phản hồi'), findsOneWidget);
      expect(find.text('Đã phản hồi'), findsOneWidget);

      // Parent message
      expect(find.text('Mẹ Bảo Châu'), findsOneWidget);
      expect(find.textContaining('ở nhà bé hơi sổ mũi nhẹ'), findsOneWidget);
      expect(find.text('16:45'), findsOneWidget);
      expect(find.text('Đã gửi · Cô đã đọc'), findsOneWidget);

      // Teacher message
      expect(find.text('Cô Nguyễn Thị Mai'), findsOneWidget);
      expect(find.text('GVCN'), findsOneWidget);
      expect(find.textContaining('mẹ yên tâm nhé'), findsOneWidget);
      expect(find.text('17:05'), findsOneWidget);
      expect(find.text('✓ Đã ghi nhận & xử lý'), findsOneWidget);

      // Bottom input bar
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });

    testWidgets('shows empty state when there are no responses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: kinderTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ReportDiscussionSection(
                reportId: 'rep-empty',
                childName: 'Bảo Châu',
                teacherName: 'Cô Mai',
                initialResponses: [],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('0 phản hồi'), findsOneWidget);
      expect(find.text('Chưa có phản hồi nào'), findsOneWidget);
      expect(
        find.textContaining('Quý phụ huynh có thể gửi tin nhắn trao đổi'),
        findsOneWidget,
      );
    });

    testWidgets('parent can type message and submit, adding message to the thread',
        (tester) async {
      final mockRepo = MockReportResponseRepository(
        initialList: [parentMessage],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: kinderTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportDiscussionSection(
                reportId: 'rep-1',
                childName: 'Bảo Châu',
                teacherName: 'Cô Mai',
                repository: mockRepo,
                initialResponses: [parentMessage],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('1 phản hồi'), findsOneWidget);

      // Type new message
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Dạ chiều nay bố bé đón lúc 17h ạ!');
      await tester.pump();

      // Tap send button
      final sendBtn = find.byIcon(Icons.send_rounded);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      // Verify message is added to list
      expect(find.text('Dạ chiều nay bố bé đón lúc 17h ạ!'), findsOneWidget);
      expect(find.text('2 phản hồi'), findsOneWidget);
      expect(mockRepo.sentResponses.length, 1);
      expect(mockRepo.sentResponses.first.content, 'Dạ chiều nay bố bé đón lúc 17h ạ!');

      // Verify input field is cleared
      final tf = tester.widget<TextField>(inputFinder);
      expect(tf.controller?.text, isEmpty);
    });

    testWidgets('image attachment selection shows preview and allows removal',
        (tester) async {
      final fakeBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: kinderTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportDiscussionSection(
                reportId: 'rep-1',
                childName: 'Bảo Châu',
                teacherName: 'Cô Mai',
                onPickImage: (source) async => fakeBytes,
                initialResponses: const [],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap attachment button
      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pumpAndSettle();

      // Verify bottom sheet options
      expect(find.text('Đính kèm hình ảnh'), findsOneWidget);
      expect(find.text('Chụp ảnh từ máy ảnh'), findsOneWidget);
      expect(find.text('Chọn ảnh từ thư viện'), findsOneWidget);

      // Select camera option
      await tester.tap(find.text('Chụp ảnh từ máy ảnh'));
      await tester.pumpAndSettle();

      // Verify preview is displayed
      expect(find.text('Đã sẵn sàng gửi kèm tin nhắn'), findsOneWidget);
      expect(find.byTooltip('Hủy chọn ảnh'), findsOneWidget);

      // Remove photo
      await tester.tap(find.byTooltip('Hủy chọn ảnh'));
      await tester.pumpAndSettle();

      expect(find.text('Đã sẵn sàng gửi kèm tin nhắn'), findsNothing);
    });

    testWidgets('teacher mode renders teacher header and resolve action', (tester) async {
      final repo = MockReportResponseRepository(
        initialList: [
          ReportResponse(
            responseId: 'res-parent-1',
            dailyReportId: 'rep-1',
            authorRole: 'parent',
            authorName: 'Mẹ Bảo Châu',
            content: 'Nhờ cô cho bé uống thuốc lúc 10h.',
            hasImage: false,
            isRead: false,
            isResolved: false,
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: kinderTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportDiscussionSection(
                reportId: 'rep-1',
                childName: 'Bảo Châu',
                teacherName: 'Cô Mai',
                repository: repo,
                isTeacher: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Trao đổi với phụ huynh'), findsOneWidget);
      expect(find.text('Đánh dấu đã xử lý'), findsOneWidget);
      expect(find.text('Nhắn phản hồi cho phụ huynh về báo cáo này...'), findsOneWidget);
    });

    testWidgets('displays image thumbnail and opens lightbox viewer on tap', (tester) async {
      final repo = MockReportResponseRepository(
        initialList: [
          ReportResponse(
            responseId: 'res-img-1',
            dailyReportId: 'rep-1',
            authorRole: 'parent',
            authorName: 'Mẹ Bảo Châu',
            content: 'Hình ảnh đơn thuốc của bé gửi cô',
            hasImage: true,
            imageUrl: '/api/report-responses/attachments/c1/a1',
            isRead: true,
            isResolved: false,
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: kinderTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportDiscussionSection(
                reportId: 'rep-1',
                childName: 'Bảo Châu',
                teacherName: 'Cô Mai',
                repository: repo,
                isTeacher: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the attachment widget is rendered
      expect(find.byType(AttachmentThumbnailWidget), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);

      // Tap on the thumbnail to open the Lightbox
      await tester.tap(find.byType(AttachmentThumbnailWidget));
      await tester.pumpAndSettle();

      // Lightbox dialog should now be visible with InteractiveViewer and close button
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap close button to dismiss Lightbox
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Lightbox is closed
      expect(find.byType(InteractiveViewer), findsNothing);
    });
  });

  group('DailyReport Discussion Indicator Fields', () {
    test('computes hasDiscussion and hasUnreadResponses correctly from counts', () {
      final baseJson = {
        'id': 'rep-10',
        'child_id': 'c-1',
        'report_date': '2026-11-12T08:00:00.000Z',
        'status': 'submitted',
      };

      // Case 1: No responses
      final repEmpty = DailyReport.fromJson({
        ...baseJson,
        'response_count': 0,
        'unread_response_count': 0,
      });
      expect(repEmpty.hasDiscussion, isFalse);
      expect(repEmpty.hasUnreadResponses, isFalse);

      // Case 2: Read discussion
      final repRead = DailyReport.fromJson({
        ...baseJson,
        'response_count': 2,
        'unread_response_count': 0,
      });
      expect(repRead.hasDiscussion, isTrue);
      expect(repRead.hasUnreadResponses, isFalse);

      // Case 3: Unread responses
      final repUnread = DailyReport.fromJson({
        ...baseJson,
        'response_count': 3,
        'unread_response_count': 2,
      });
      expect(repUnread.hasDiscussion, isTrue);
      expect(repUnread.hasUnreadResponses, isTrue);
      expect(repUnread.unreadResponseCount, 2);
    });
  });
}
