import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';

import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/record_models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/recording_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/processing_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/review_screen.dart';

class RecordFlowScreen extends StatefulWidget {
  const RecordFlowScreen({
    super.key,
    required this.mode,
    this.child,
    this.classId = '',
    this.className = 'Mầm 1',
    this.repository,
    this.teacherRepository,
    this.audioRecorder,
    this.pathProvider,
  });
  final RecordMode mode;
  final Child? child;
  final String classId;
  final String className;
  final HttpDashboardRepository? repository;
  final TeacherRepository? teacherRepository;
  final AudioRecorder? audioRecorder;
  final Future<String> Function(String extension)? pathProvider;

  @override
  State<RecordFlowScreen> createState() => _RecordFlowScreenState();
}

class _RecordFlowScreenState extends State<RecordFlowScreen> {
  String step = 'record';
  PlatformFile? uploadedFile;
  VoiceRecordingSession? activeSession;
  String? editedMergedTranscript;
  Uint8List? previewAudioBytes;
  VoiceRecord? voiceRecord;
  ExtractionData? extractionData;
  String? transcript;

  late final TeacherRepository teacherRepository =
      widget.teacherRepository ?? TeacherRepository();

  @override
  Widget build(BuildContext context) {
    return GardenVoiceScope(
      child: Builder(
        builder: (context) => switch (step) {
          'processing' => ProcessingScreen(
              mode: widget.mode,
              file: uploadedFile,
              session: activeSession,
              editedMergedTranscript: editedMergedTranscript,
              classId: widget.classId,
              child: widget.child,
              teacherRepository: teacherRepository,
              onBack: () => setState(() => step = 'record'),
              onDone: (record, extraction) {
                voiceRecord = record;
                extractionData = extraction;
                transcript =
                    record?.effectiveTranscript ?? extraction?.transcript;
                setState(() => step = 'review');
              },
            ),
          'review' || 'segment' => ReviewScreen(
              mode: widget.mode,
              classId: widget.classId,
              child: widget.child,
              className: widget.className,
              extraction: extractionData,
              transcript: transcript,
              voiceRecord: voiceRecord,
              recordedBytes: previewAudioBytes ?? uploadedFile?.bytes,
              repository: widget.repository,
              teacherRepository: teacherRepository,
              onBack: () => setState(() => step = 'record'),
              onCompleted: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n?.sttSubmittedSuccess ??
                          (LocaleController.instance.isEnglish
                              ? 'Report created and sent successfully!'
                              : 'Đã tạo và gửi báo cáo thành công!'),
                    ),
                    backgroundColor: context.k.brand,
                  ),
                );
              },
            ),
          _ => RecordingScreen(
              mode: widget.mode,
              child: widget.child,
              classId: widget.classId,
              className: widget.className,
              enableMultiClipSession: true,
              teacherRepository: teacherRepository,
              audioRecorder: widget.audioRecorder,
              pathProvider: widget.pathProvider,
              onSubmit: (file) {
                setState(() {
                  uploadedFile = file;
                  activeSession = null;
                  editedMergedTranscript = null;
                  previewAudioBytes = file?.bytes;
                  step = 'processing';
                });
              },
              onSubmitSession: ({
                required session,
                editedMergedTranscript,
                previewAudioBytes,
              }) {
                setState(() {
                  activeSession = session;
                  this.editedMergedTranscript = editedMergedTranscript;
                  this.previewAudioBytes = previewAudioBytes;
                  uploadedFile = null;
                  step = 'processing';
                });
              },
            ),
        },
      ),
    );
  }
}

