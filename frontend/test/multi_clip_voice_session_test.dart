import 'dart:io';
import 'dart:typed_data';

import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

class _FakeRecorder extends AudioRecorder {
  bool started = false;
  String? nextStopPath;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    started = true;
  }

  @override
  Future<String?> stop() async {
    started = false;
    return nextStopPath;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeSessionTeacherRepo extends TeacherRepository {
  _FakeSessionTeacherRepo({required this.session});

  VoiceRecordingSession session;
  int createOrResumeCalls = 0;
  int uploadToSessionCalls = 0;
  int deleteClipCalls = 0;
  int updateTranscriptCalls = 0;
  int mergeCalls = 0;
  int analyzeCalls = 0;
  int discardCalls = 0;
  String? lastEditedMergedTranscript;
  String? lastUpdatedClipTranscript;
  String? lastDeletedVoiceId;

  @override
  Future<VoiceRecordingSession> createOrResumeVoiceSession({
    required String teacherId,
    required String classId,
    String? childId,
    String scope = 'whole_class',
    bool forceNew = false,
  }) async {
    createOrResumeCalls++;
    return session;
  }

  @override
  Future<VoiceRecordingSession> getVoiceSession({
    required String sessionId,
    required String teacherId,
  }) async {
    return session;
  }

  @override
  Future<VoiceRecord> uploadAudioToSession({
    required String sessionId,
    required String filePath,
    required String classId,
    required String teacherId,
    String? childId,
    Uint8List? fileBytes,
    String? fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadToSessionCalls++;
    final newId = 'clip-uploaded-$uploadToSessionCalls';
    final newClip = VoiceClip(
      voiceRecordId: newId,
      status: 'completed',
      audioDuration: 10,
      transcript: 'Chiều nay bé học vẽ rất chăm chú.',
      createdAt: DateTime(2026, 11, 12, 15, 50),
    );
    final updatedClips = [...session.clips, newClip];
    session = VoiceRecordingSession(
      sessionId: session.sessionId,
      scope: session.scope,
      status: session.status,
      teacherId: session.teacherId,
      classId: session.classId,
      clips: updatedClips,
      pendingCount:
          updatedClips.where((c) => !c.isCompleted).length,
      completedCount:
          updatedClips.where((c) => c.isCompleted).length,
    );
    return VoiceRecord(id: newId, status: 'completed');
  }

  @override
  Future<VoiceRecord> updateTranscript({
    required String voiceId,
    required String editedTranscript,
    String? teacherId,
  }) async {
    updateTranscriptCalls++;
    lastUpdatedClipTranscript = editedTranscript;
    final updatedClips = session.clips
        .map((c) => c.voiceRecordId == voiceId
            ? c.copyWith(transcript: editedTranscript)
            : c)
        .toList();
    session = VoiceRecordingSession(
      sessionId: session.sessionId,
      scope: session.scope,
      status: session.status,
      teacherId: session.teacherId,
      classId: session.classId,
      clips: updatedClips,
      pendingCount: session.pendingCount,
      completedCount: session.completedCount,
    );
    return VoiceRecord(
      id: voiceId,
      status: 'completed',
      editedTranscript: editedTranscript,
    );
  }

  @override
  Future<void> deleteVoiceClip({
    required String voiceId,
    required String teacherId,
  }) async {
    deleteClipCalls++;
    lastDeletedVoiceId = voiceId;
    final remaining =
        session.clips.where((c) => c.voiceRecordId != voiceId).toList();
    session = VoiceRecordingSession(
      sessionId: session.sessionId,
      scope: session.scope,
      status: session.status,
      teacherId: session.teacherId,
      classId: session.classId,
      clips: remaining,
      pendingCount: remaining.where((c) => !c.isCompleted).length,
      completedCount: remaining.where((c) => c.isCompleted).length,
    );
  }

  @override
  Future<MergeVoiceSessionResult> mergeVoiceSession({
    required String sessionId,
    required String teacherId,
    String? editedTranscript,
  }) async {
    mergeCalls++;
    lastEditedMergedTranscript = editedTranscript;
    final merged = editedTranscript ??
        session.clips
            .where((c) => c.isCompleted && (c.transcript ?? '').isNotEmpty)
            .map((c) => c.transcript!)
            .join('\n');
    return MergeVoiceSessionResult(
      sessionId: sessionId,
      mergedTranscript: merged,
      clipCount: session.completedCount,
      skippedClips: 0,
      representativeVoiceRecordId: session.clips.first.voiceRecordId,
    );
  }

  @override
  Future<ExtractionData> analyzeTranscript({
    required String voiceId,
    required String teacherId,
    required String editedTranscript,
  }) async {
    analyzeCalls++;
    return ExtractionData(
      transcript: editedTranscript,
      classWideExtraction: const {
        'meals': 'Cả lớp ăn hết suất cháo.',
        'sleeping': 'Ngủ ngoan từ 12g-14g.',
      },
    );
  }

  @override
  Future<void> discardVoiceSession({
    required String sessionId,
    required String teacherId,
  }) async {
    discardCalls++;
  }
}

VoiceRecordingSession _sampleActiveSession({
  List<VoiceClip>? clips,
}) {
  final list = clips ??
      [
        VoiceClip(
          voiceRecordId: 'clip-1',
          status: 'completed',
          audioDuration: 18,
          transcript: 'Sáng nay bé Gia Bảo ăn hết suất cháo.',
          createdAt: DateTime(2026, 11, 12, 8, 25),
        ),
        VoiceClip(
          voiceRecordId: 'clip-2',
          status: 'completed',
          audioDuration: 22,
          transcript: 'Trưa nay cả lớp ngủ ngoan.',
          createdAt: DateTime(2026, 11, 12, 11, 40),
        ),
      ];
  return VoiceRecordingSession(
    sessionId: 'session-1',
    scope: 'whole_class',
    status: 'active',
    teacherId: 'teacher-1',
    classId: 'class-1',
    clips: list,
    pendingCount: list.where((c) => !c.isCompleted).length,
    completedCount: list.where((c) => c.isCompleted).length,
  );
}

void main() {
  testWidgets(
      'Restores active multi-clip session, expands transcript via arrow under X, edits, and deletes clip',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeSessionTeacherRepo(session: _sampleActiveSession());
    VoiceRecordingSession? submittedSession;
    String? submittedMergedText;

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingScreen(
          mode: RecordMode.classroom,
          classId: 'class-1',
          className: 'Lớp Mầm A',
          enableMultiClipSession: true,
          teacherRepository: repo,
          onSubmit: (_) {},
          onSubmitSession: ({
            required session,
            editedMergedTranscript,
            previewAudioBytes,
          }) {
            submittedSession = session;
            submittedMergedText = editedMergedTranscript;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.createOrResumeCalls, 1);
    expect(find.text('2 bản ghi'), findsOneWidget);
    expect(find.text('Đoạn 1'), findsOneWidget);
    expect(find.text('Đoạn 2'), findsOneWidget);
    expect(find.text('Gửi phân tích (2)'), findsOneWidget);
    expect(find.text('Nội dung đã nói'), findsNothing);

    // Expand Đoạn 1 via arrow button below X
    await tester.tap(find.byKey(const ValueKey('clip-expand-clip-1')));
    await tester.pumpAndSettle();

    expect(find.text('Nội dung đã nói'), findsOneWidget);
    expect(find.byKey(const ValueKey('clip-transcript-input-clip-1')),
        findsOneWidget);

    // Edit text and save
    await tester.enterText(
      find.byKey(const ValueKey('clip-transcript-input-clip-1')),
      'Sáng nay bé Gia Bảo và Ngọc Ánh ăn hết suất.',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu chữ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu chữ'));
    await tester.pumpAndSettle();

    expect(repo.updateTranscriptCalls, 1);
    expect(repo.lastUpdatedClipTranscript,
        'Sáng nay bé Gia Bảo và Ngọc Ánh ăn hết suất.');

    // Delete Đoạn 2 via X button
    await tester.tap(find.byKey(const ValueKey('clip-delete-clip-2')));
    await tester.pumpAndSettle();

    expect(repo.deleteClipCalls, 1);
    expect(repo.lastDeletedVoiceId, 'clip-2');
    expect(find.text('1 bản ghi'), findsOneWidget);
    expect(find.text('Gửi phân tích (1)'), findsOneWidget);

    // Tap Send to merge & analyze
    await tester.tap(find.byKey(const ValueKey('btn-analyze-session')));
    await tester.pumpAndSettle();

    expect(submittedSession?.sessionId, 'session-1');
    expect(
      submittedMergedText,
      'Sáng nay bé Gia Bảo và Ngọc Ánh ăn hết suất',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Disables Send button while clips are still processing or failed',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeSessionTeacherRepo(
      session: _sampleActiveSession(
        clips: [
          VoiceClip(
            voiceRecordId: 'clip-ok',
            status: 'completed',
            audioDuration: 14,
            transcript: 'Sáng nay lớp ăn sáng đầy đủ.',
            createdAt: DateTime(2026, 11, 12, 8, 10),
          ),
          VoiceClip(
            voiceRecordId: 'clip-fail',
            status: 'failed',
            audioDuration: 8,
            errorMessage: 'Không nghe rõ',
            createdAt: DateTime(2026, 11, 12, 9, 15),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingScreen(
          mode: RecordMode.classroom,
          classId: 'class-1',
          className: 'Lớp Mầm A',
          enableMultiClipSession: true,
          teacherRepository: repo,
          onSubmit: (_) {},
          onSubmitSession: ({
            required session,
            editedMergedTranscript,
            previewAudioBytes,
          }) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xoá đoạn lỗi để gửi'), findsOneWidget);
    expect(
      find.textContaining('Có 1 đoạn nhận dạng lỗi'),
      findsOneWidget,
    );

    final sendBtn = tester.widget<FilledButton>(
      find.byKey(const ValueKey('btn-analyze-session')),
    );
    expect(sendBtn.onPressed, isNull);

    // Delete failed clip -> Send becomes enabled
    await tester.tap(find.byKey(const ValueKey('clip-delete-clip-fail')));
    await tester.pumpAndSettle();

    expect(find.text('Gửi phân tích (1)'), findsOneWidget);
    final sendBtnAfter = tester.widget<FilledButton>(
      find.byKey(const ValueKey('btn-analyze-session')),
    );
    expect(sendBtnAfter.onPressed, isNotNull);
  });

  testWidgets('Records extra clip into session then merges and analyzes once',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tempDir = Directory.systemTemp.createTempSync('us78_test_');
    final tempAudio = File('${tempDir.path}/clip.m4a');
    tempAudio.writeAsBytesSync([1, 2, 3, 4, 5]);
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final recorder = _FakeRecorder()..nextStopPath = tempAudio.path;
    final repo = _FakeSessionTeacherRepo(
      session: _sampleActiveSession(clips: [
        VoiceClip(
          voiceRecordId: 'clip-1',
          status: 'completed',
          audioDuration: 15,
          transcript: 'Sáng nay lớp ăn sáng ngoan.',
          createdAt: DateTime(2026, 11, 12, 8, 25),
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordFlowScreen(
          mode: RecordMode.classroom,
          classId: 'class-1',
          className: 'Lớp Mầm A',
          teacherRepository: repo,
          audioRecorder: recorder,
          pathProvider: (_) async => tempAudio.path,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Start recording new clip from compact dock
    await tester.tap(find.byKey(const ValueKey('session-mic-btn')));
    await tester.pump();
    expect(find.text('Lưu đoạn'), findsOneWidget);

    // Stop & save clip into session
    // Đọc file thật ngoài fake-async, giống test upload hiện có.
    await tester.runAsync(() async {
      await tester.tap(find.text('Lưu đoạn'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();

    expect(repo.uploadToSessionCalls, 1);
    expect(find.text('2 bản ghi'), findsOneWidget);
    expect(find.text('Gửi phân tích (2)'), findsOneWidget);

    // Submit once -> ProcessingScreen merges & analyzes
    await tester.tap(find.byKey(const ValueKey('btn-analyze-session')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(repo.mergeCalls, 1);
    expect(repo.analyzeCalls, 1);
    expect(
      repo.lastEditedMergedTranscript,
      'Sáng nay lớp ăn sáng ngoan Chiều nay bé học vẽ rất chăm chú',
    );
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

