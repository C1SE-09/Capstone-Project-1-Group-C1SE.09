// frontend/lib/data/repositories/teacher_repository.dart
// =========================================================
// Data-layer implementation of [TeacherRepositoryBase].
//
// Task #58: uploadAudio
// - Builds FormData with MultipartFile (audio) + class_id field
// - Calls POST /api/teacher/voice/upload
// - Reports upload progress via [onSendProgress] callback
// - Returns [VoiceRecord] entity on success
// - Throws [TeacherRepositoryException] on failure


import 'dart:io';
import 'dart:typed_data';

import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:dio/dio.dart';

// ---------------------------------------------------------------------------
// Entity: VoiceRecord
// ---------------------------------------------------------------------------

// Lightweight entity returned after a successful upload.
//
// Fields mirror the backend response schema:
//   { "id": "uuid", "status": "pending" }
class VoiceRecord {
  const VoiceRecord({
    required this.id,
    required this.status,
    this.rawTranscript,
    this.editedTranscript,
    this.transcription,
  });

  final String id;
  final String status;
  final String? rawTranscript;
  final String? editedTranscript;
  final String? transcription;

  /// Returns the effective transcript text (edited > raw > transcription).
  String get effectiveTranscript =>
      editedTranscript ?? rawTranscript ?? transcription ?? '';

  factory VoiceRecord.fromJson(Map<String, dynamic> json) {
    return VoiceRecord(
      id: json['id'] as String,
      status: json['status'] as String,
      rawTranscript: json['raw_transcript'] as String?,
      editedTranscript: json['edited_transcript'] as String?,
      transcription: json['transcription'] as String?,
    );
  }

  @override
  String toString() =>
      'VoiceRecord(id: $id, status: $status, edited: ${editedTranscript != null})';
}

// ---------------------------------------------------------------------------
// Entity: ExtractionData
// ---------------------------------------------------------------------------

class ExtractionData {
  const ExtractionData({
    this.transcript,
    this.meals,
    this.sleeping,
    this.health,
    this.activities,
    this.mood,
  });

  final String? transcript;
  final String? meals;
  final String? sleeping;
  final String? health;
  final String? activities;
  final String? mood;

  factory ExtractionData.fromJson(Map<String, dynamic> json) {
    return ExtractionData(
      transcript: json['transcript'] as String?,
      meals: json['meals'] as String?,
      sleeping: json['sleeping'] as String?,
      health: json['health'] as String?,
      activities: json['activities'] as String?,
      mood: json['mood'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'transcript': transcript,
        'meals': meals,
        'sleeping': sleeping,
        'health': health,
        'activities': activities,
        'mood': mood,
      };

  ExtractionData copyWith({
    String? transcript,
    String? meals,
    String? sleeping,
    String? health,
    String? activities,
    String? mood,
  }) {
    return ExtractionData(
      transcript: transcript ?? this.transcript,
      meals: meals ?? this.meals,
      sleeping: sleeping ?? this.sleeping,
      health: health ?? this.health,
      activities: activities ?? this.activities,
      mood: mood ?? this.mood,
    );
  }
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

// Thrown when [TeacherRepository.uploadAudio] or [updateTranscript] fails.
class TeacherRepositoryException implements Exception {
  const TeacherRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'TeacherRepositoryException($statusCode): $message';
}

// ---------------------------------------------------------------------------
// Abstract interface (domain layer contract)
// ---------------------------------------------------------------------------

abstract class TeacherRepositoryBase {
  /// Upload an audio file and create a [VoiceRecord] on the server.
  ///
  /// [filePath]    – absolute path to the audio file on the device.
  /// [classId]     – UUID string of the associated class.
  /// [teacherId]   – UUID string of the uploading teacher (MVP: passed directly).
  /// [onProgress]  – optional callback; receives [sent] and [total] bytes.
  Future<VoiceRecord> uploadAudio({
    required String filePath,
    required String classId,
    required String teacherId,
    String? childId,
    Uint8List? fileBytes,
    String? fileName,
    void Function(int sent, int total)? onProgress,
  });

  /// Update the transcript of a [VoiceRecord].
  Future<VoiceRecord> updateTranscript({
    required String voiceId,
    required String editedTranscript,
    String? teacherId,
  });

  /// Fetch detail & status of a [VoiceRecord].
  Future<VoiceRecord> getVoiceRecord({
    required String voiceId,
    String? teacherId,
  });

  /// Extract AI structured data from a voice recording's transcript.
  Future<ExtractionData> extractVoice({
    required String voiceId,
    required String teacherId,
  });

  /// Run the NLP analysis model on the teacher-edited PhoWhisper transcript.
  Future<ExtractionData> analyzeTranscript({
    required String voiceId,
    required String teacherId,
    required String editedTranscript,
  });

  /// Create a draft DailyReport from AI extraction result.
  Future<Map<String, dynamic>> createDraftReport({
    required String voiceId,
    required String teacherId,
    String? childId,
    ExtractionData? editedExtraction,
  });

  /// Create a manual DailyReport (fallback without voice recording).
  Future<Map<String, dynamic>> createManualReport({
    required String teacherId,
    required String childId,
    String? eating,
    String? sleeping,
    String? health,
    String? activities,
    String? mood,
    String? teacherNote,
  });
}

// ---------------------------------------------------------------------------
// Concrete implementation
// ---------------------------------------------------------------------------

class TeacherRepository implements TeacherRepositoryBase {
  TeacherRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? kApiBaseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(minutes: 5),
              ),
            );

  final Dio _dio;

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
    try {
      if (filePath.trim().isEmpty && fileBytes == null) {
        throw const TeacherRepositoryException(
          'File ghi âm trống hoặc không hợp lệ.',
        );
      }

      final safeFileName =
          (fileName ?? filePath.split('/').last.split('\\').last).trim();

      final resolvedBytes = fileBytes ??
          (filePath.trim().isEmpty
              ? null
              : await _readAudioBytes(filePath));

      if (resolvedBytes == null || resolvedBytes.isEmpty) {
        throw const TeacherRepositoryException(
          'Không thể đọc dữ liệu file ghi âm từ thiết bị.',
        );
      }

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          resolvedBytes,
          filename:
              safeFileName.isNotEmpty ? safeFileName : 'recording_audio.m4a',
        ),
        'class_id': classId,
        'teacher_id': teacherId,
        if ((childId ?? '').trim().isNotEmpty) 'child_id': childId!.trim(),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/teacher/voice/upload',
        data: formData,
        onSendProgress: onProgress,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final body = response.data;
      if (body == null) {
        throw const TeacherRepositoryException(
          'Server returned an empty response.',
        );
      }

      return VoiceRecord.fromJson(body);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = _extractDetail(e.response?.data) ??
          e.message ??
          'Unknown network error.';
      throw TeacherRepositoryException(detail, statusCode: statusCode);
    } catch (e) {
      throw TeacherRepositoryException(e.toString());
    }
  }

  Future<Uint8List> _readAudioBytes(String filePath) async {
    final file = File(filePath);

    for (var attempt = 0; attempt < 8; attempt++) {
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          return bytes;
        }
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }

    throw TeacherRepositoryException(
      'Không tìm thấy hoặc không thể đọc file ghi âm tại đường dẫn: $filePath',
    );
  }

  @override
  Future<VoiceRecord> updateTranscript({
    required String voiceId,
    required String editedTranscript,
    String? teacherId,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/teacher/voice/$voiceId/transcript',
        data: {'edited_transcript': editedTranscript},
        queryParameters: teacherId != null ? {'teacher_id': teacherId} : null,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final body = response.data;
      if (body == null) {
        throw const TeacherRepositoryException(
          'Server returned an empty response.',
        );
      }

      return VoiceRecord.fromJson(body);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = _extractDetail(e.response?.data) ??
          e.message ??
          'Unknown network error.';
      throw TeacherRepositoryException(detail, statusCode: statusCode);
    } catch (e) {
      throw TeacherRepositoryException(e.toString());
    }
  }

  @override
  Future<VoiceRecord> getVoiceRecord({
    required String voiceId,
    String? teacherId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/teacher/voice/$voiceId',
        queryParameters: teacherId != null ? {'teacher_id': teacherId} : null,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final body = response.data;
      if (body == null) {
        throw const TeacherRepositoryException(
          'Server returned an empty response.',
        );
      }

      return VoiceRecord.fromJson(body);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = _extractDetail(e.response?.data) ??
          e.message ??
          'Unknown network error.';
      throw TeacherRepositoryException(detail, statusCode: statusCode);
    } catch (e) {
      throw TeacherRepositoryException(e.toString());
    }
  }

  @override
  Future<ExtractionData> extractVoice({
    required String voiceId,
    required String teacherId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/teacher/voice/$voiceId/extract',
        queryParameters: {'teacher_id': teacherId},
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final body = response.data;
      if (body == null || body['extraction'] == null) {
        throw const TeacherRepositoryException(
          'Server returned an empty extraction result.',
        );
      }

      return ExtractionData.fromJson(body['extraction'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = _extractDetail(e.response?.data) ??
          e.message ??
          'Unknown network error.';
      throw TeacherRepositoryException(detail, statusCode: statusCode);
    } catch (e) {
      throw TeacherRepositoryException(e.toString());
    }
  }

  @override
  Future<ExtractionData> analyzeTranscript({
    required String voiceId,
    required String teacherId,
    required String editedTranscript,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/teacher/voice/$voiceId/analyze',
        queryParameters: {'teacher_id': teacherId},
        data: {'edited_transcript': editedTranscript},
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final body = response.data;
      if (body == null || body['extraction'] == null) {
        throw const TeacherRepositoryException(
          'Server returned an empty re-extraction result.',
        );
      }

      return ExtractionData.fromJson(body['extraction'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = _extractDetail(e.response?.data) ??
          e.message ??
          'Unknown network error.';
      throw TeacherRepositoryException(detail, statusCode: statusCode);
    } catch (e) {
      throw TeacherRepositoryException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> createDraftReport({
    required String voiceId,
    required String teacherId,
    String? childId,
    ExtractionData? editedExtraction,
  }) async {
    try {
      final payload = {
        'voice_id': voiceId,
        'teacher_id': teacherId,
        if ((childId ?? '').trim().isNotEmpty) 'child_id': childId!.trim(),
        if (editedExtraction != null) 'edited_extraction': {
          'transcript': editedExtraction.transcript,
          'meals': editedExtraction.meals,
          'sleeping': editedExtraction.sleeping,
          'health': editedExtraction.health,
          'activities': editedExtraction.activities,
          'mood': editedExtraction.mood,
        },
      };

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/teacher/reports/draft',
        data: payload,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final body = response.data;
      if (body == null) {
        throw const TeacherRepositoryException(
          'Server returned an empty draft report response.',
        );
      }

      return body;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = _extractDetail(e.response?.data) ??
          e.message ??
          'Unknown network error.';
      throw TeacherRepositoryException(detail, statusCode: statusCode);
    } catch (e) {
      throw TeacherRepositoryException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> createManualReport({
    required String teacherId,
    required String childId,
    String? eating,
    String? sleeping,
    String? health,
    String? activities,
    String? mood,
    String? teacherNote,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/teacher/reports/manual',
        data: {
          'teacher_id': teacherId,
          'child_id': childId,
          'eating': eating,
          'sleeping': sleeping,
          'health': health,
          'activities': activities,
          'mood': mood,
          'teacher_note': teacherNote,
        },
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final body = response.data;
      if (body == null) {
        throw const TeacherRepositoryException(
          'Server returned an empty manual report response.',
        );
      }

      return body;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = _extractDetail(e.response?.data) ??
          e.message ??
          'Unknown network error.';
      throw TeacherRepositoryException(detail, statusCode: statusCode);
    } catch (e) {
      throw TeacherRepositoryException(e.toString());
    }
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  static String? _extractDetail(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail != null) return detail.toString();
    }
    return null;
  }
}

