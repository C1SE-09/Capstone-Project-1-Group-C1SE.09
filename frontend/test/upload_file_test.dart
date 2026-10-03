import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';

class FailingTeacherRepo extends TeacherRepository {
  @override
  Future<VoiceRecord> uploadAudio({
    required String filePath,
    required String classId,
    required String teacherId,
    String? childId,
    Uint8List? fileBytes,
    String? fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    throw Exception(
      "On web 'path' is unavailable and accessing it causes this exception. "
      "You should access 'bytes' property instead. Read more about it [here](...)",
    );
  }
}

class SuccessTeacherRepo extends TeacherRepository {
  Uint8List? capturedBytes;
  String? capturedFileName;
  String? capturedFilePath;

  @override
  Future<VoiceRecord> uploadAudio({
    required String filePath,
    required String classId,
    required String teacherId,
    String? childId,
    Uint8List? fileBytes,
    String? fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    capturedBytes = fileBytes;
    capturedFileName = fileName;
    capturedFilePath = filePath;
    return const VoiceRecord(
      id: 'voice-123',
      status: 'completed',
      editedTranscript: 'Bé ăn ngoan',
    );
  }

  @override
  Future<VoiceRecord> getVoiceRecord({
    required String voiceId,
    String? teacherId,
  }) async {
    return const VoiceRecord(
      id: 'voice-123',
      status: 'completed',
      editedTranscript: 'Bé ăn ngoan',
    );
  }

  @override
  Future<ExtractionData> analyzeTranscript({
    required String voiceId,
    required String teacherId,
    required String editedTranscript,
  }) async {
    return const ExtractionData(
      transcript: 'Bé ăn ngoan',
      meals: 'Ăn hết suất',
      sleeping: 'Ngủ 120 phút',
      health: 'Bình thường',
      activities: 'Học vẽ',
      mood: 'Vui vẻ',
    );
  }
}

void main() {
  testWidgets('RecordingScreen displays upload file button when ready',
      (WidgetTester tester) async {
    PlatformFile? submittedFile;

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingScreen(
          mode: RecordMode.classroom,
          className: 'Mầm 1',
          onSubmit: (file) {
            submittedFile = file;
          },
        ),
      ),
    );

    // Verify upload file button exists
    expect(find.text('Tải lên file ghi âm'), findsOneWidget);
    expect(find.byIcon(Icons.upload_file_rounded), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Nhấn để bắt đầu ghi âm'), findsOneWidget);
    expect(submittedFile, isNull);
  });

  testWidgets(
      'ProcessingScreen converts technical code exception to friendly UI message',
      (WidgetTester tester) async {
    final file = PlatformFile(
      name: 'test_audio.m4a',
      size: 1024,
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProcessingScreen(
          mode: RecordMode.classroom,
          file: file,
          classId: 'test-class-id',
          teacherRepository: FailingTeacherRepo(),
          onBack: () {},
          onDone: (_, __) {},
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Must show friendly title
    expect(find.text('Không thể xử lý file âm thanh'), findsOneWidget);

    // Must NOT display raw code or technical exception string
    expect(find.textContaining('On web'), findsNothing);
    expect(find.textContaining('UnimplementedError'), findsNothing);
    expect(find.textContaining('flutter_file_picker'), findsNothing);

    // Must display user-friendly Vietnamese message
    expect(find.textContaining('trình duyệt'), findsOneWidget);

    // Must provide action buttons in dialog
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Quay lại'), findsOneWidget);
    expect(find.text('Bỏ qua & Tiếp tục'), findsNothing);
  });

  testWidgets(
      'ProcessingScreen successfully passes file bytes and file name for upload',
      (WidgetTester tester) async {
    final testBytes = Uint8List.fromList([10, 20, 30, 40]);
    final file = PlatformFile(
      name: 'my_recording.wav',
      size: testBytes.length,
      bytes: testBytes,
    );

    final repo = SuccessTeacherRepo();
    bool doneCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ProcessingScreen(
          mode: RecordMode.child,
          file: file,
          classId: 'test-class-id',
          teacherRepository: repo,
          onBack: () {},
          onDone: (record, extraction) {
            doneCalled = true;
          },
        ),
      ),
    );

    await tester.pump();
    // Allow upload step
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 700));

    expect(repo.capturedFileName, 'my_recording.wav');
    expect(repo.capturedBytes, testBytes);
    expect(doneCalled, isTrue);
  });
}
