import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';

class FakeAudioRecorder extends AudioRecorder {
  bool permission = true;
  bool isRecordingState = false;
  RecordConfig? lastConfig;
  String? lastPath;
  String? stopResultPath;
  bool disposed = false;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    lastConfig = config;
    lastPath = path;
    isRecordingState = true;
  }

  @override
  Future<String?> stop() async {
    isRecordingState = false;
    return stopResultPath;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

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

  testWidgets(
      'RecordingScreen starts recording, stops, and submits real PlatformFile',
      (WidgetTester tester) async {
    final tempDir = Directory.systemTemp.createTempSync('audio_test');
    final tempFile = File('${tempDir.path}/test_rec.m4a');
    final sampleAudioBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
    tempFile.writeAsBytesSync(sampleAudioBytes);

    final fakeRecorder = FakeAudioRecorder();
    fakeRecorder.stopResultPath = tempFile.path;

    PlatformFile? submittedFile;

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingScreen(
          mode: RecordMode.classroom,
          audioRecorder: fakeRecorder,
          pathProvider: (_) async => tempFile.path,
          onSubmit: (file) {
            submittedFile = file;
          },
        ),
      ),
    );

    // Initial state: ready
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Nhấn để bắt đầu ghi âm'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

    // Tap record button to start
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeRecorder.isRecordingState, isTrue);
    expect(find.text('Đang ghi âm · Nói tự nhiên'), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    // Advance 2 seconds
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);

    // Tap stop button to finish inside runAsync so File.readAsBytes() completes
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();

    expect(fakeRecorder.isRecordingState, isFalse);
    expect(find.textContaining('Đã ghi âm 00:02'), findsOneWidget);
    expect(find.text('Gửi xử lý'), findsOneWidget);

    // Tap submit button
    await tester.tap(find.text('Gửi xử lý'));
    await tester.pump();

    expect(submittedFile, isNotNull);
    expect(submittedFile!.bytes, sampleAudioBytes);
    expect(submittedFile!.size, sampleAudioBytes.length);
    expect(submittedFile!.name, contains('.m4a'));

    tempDir.deleteSync(recursive: true);
  });

  testWidgets(
      'RecordingScreen shows warning when microphone permission is denied',
      (WidgetTester tester) async {
    final fakeRecorder = FakeAudioRecorder();
    fakeRecorder.permission = false;

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingScreen(
          mode: RecordMode.classroom,
          audioRecorder: fakeRecorder,
          onSubmit: (_) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Vui lòng cấp quyền truy cập micro để ghi âm.'),
        findsOneWidget);
    expect(fakeRecorder.isRecordingState, isFalse);
  });

  testWidgets(
      'RecordingScreen resets state when "Ghi âm lại" is clicked',
      (WidgetTester tester) async {
    final tempDir = Directory.systemTemp.createTempSync('audio_test_reset');
    final tempFile = File('${tempDir.path}/test_rec2.m4a');
    tempFile.writeAsBytesSync([10, 20, 30]);

    final fakeRecorder = FakeAudioRecorder();
    fakeRecorder.stopResultPath = tempFile.path;

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingScreen(
          mode: RecordMode.classroom,
          audioRecorder: fakeRecorder,
          pathProvider: (_) async => tempFile.path,
          onSubmit: (_) {},
        ),
      ),
    );

    // Start recording
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Stop recording
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();

    expect(find.text('Ghi âm lại'), findsOneWidget);

    // Tap 'Ghi âm lại'
    await tester.tap(find.text('Ghi âm lại'));
    await tester.pump();

    // Verifies returned to initial state
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Nhấn để bắt đầu ghi âm'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

    tempDir.deleteSync(recursive: true);
  });
}
