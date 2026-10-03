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

import 'package:flutter/foundation.dart';
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
    this.errorMessage,
  });

  final String id;
  final String status;
  final String? rawTranscript;
  final String? editedTranscript;
  final String? transcription;
  final String? errorMessage;

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
      errorMessage: json['error_message'] as String?,
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
    this.rawJson,
    this.segments,
    this.classWideExtraction,
    this.childExtractions,
  });

  final String? transcript;
  final String? meals;
  final String? sleeping;
  final String? health;
  final String? activities;
  final String? mood;
  final Map<String, dynamic>? rawJson;
  final List<dynamic>? segments;
  /// Default content cho cả lớp (vd: "Cả lớp ăn ngon").
  /// Backend trả về trong key `class_wide_extraction`.
  /// Chỉ thực sự có nội dung khi giáo viên nói "cả lớp...".
  final Map<String, dynamic>? classWideExtraction;
  /// Override content cho từng bé (vd: "Lan ho nhẹ").
  /// Backend trả về trong key `child_extractions`.
  /// Chỉ chứa các bé CÓ override (không phải cả lớp).
  final Map<String, dynamic>? childExtractions;

  factory ExtractionData.fromJson(Map<String, dynamic> json) {
    return ExtractionData(
      transcript: json['transcript'] as String?,
      meals: json['meals'] as String?,
      sleeping: json['sleeping'] as String?,
      health: json['health'] as String?,
      activities: json['activities'] as String?,
      mood: json['mood'] as String?,
      rawJson: json,
      segments: json['segments'] as List<dynamic>?,
      classWideExtraction: json['class_wide_extraction'] is Map
          ? (json['class_wide_extraction'] as Map).cast<String, dynamic>()
          : null,
      childExtractions: json['child_extractions'] is Map
          ? (json['child_extractions'] as Map).cast<String, dynamic>()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'transcript': transcript,
        'meals': meals,
        'sleeping': sleeping,
        'health': health,
        'activities': activities,
        'mood': mood,
        if (segments != null) 'segments': segments,
        if (classWideExtraction != null)
          'class_wide_extraction': classWideExtraction,
        if (childExtractions != null) 'child_extractions': childExtractions,
      };

  ExtractionData copyWith({
    String? transcript,
    String? meals,
    String? sleeping,
    String? health,
    String? activities,
    String? mood,
    Map<String, dynamic>? rawJson,
    List<dynamic>? segments,
    Map<String, dynamic>? classWideExtraction,
    Map<String, dynamic>? childExtractions,
  }) {
    return ExtractionData(
      transcript: transcript ?? this.transcript,
      meals: meals ?? this.meals,
      sleeping: sleeping ?? this.sleeping,
      health: health ?? this.health,
      activities: activities ?? this.activities,
      mood: mood ?? this.mood,
      rawJson: rawJson ?? this.rawJson,
      segments: segments ?? this.segments,
      classWideExtraction: classWideExtraction ?? this.classWideExtraction,
      childExtractions: childExtractions ?? this.childExtractions,
    );
  }

  /// Classwide có nội dung thật (ít nhất 1 field không null/rỗng).
  bool get hasClassWideContent {
    final cw = classWideExtraction;
    if (cw == null || cw.isEmpty) return false;
    return cw.values.any((v) {
      if (v == null) return false;
      final s = v.toString().trim();
      return s.isNotEmpty;
    });
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
  /// If [overwrite] is true, the backend will upsert (replace existing draft for today).
  Future<Map<String, dynamic>> createManualReport({
    required String teacherId,
    required String childId,
    String? eating,
    String? sleeping,
    String? health,
    String? activities,
    String? mood,
    String? teacherNote,
    String? reportDate,
    bool overwrite = false,
  });

  /// Publish a daily report so parents can view it.
  Future<Map<String, dynamic>> publishReport({
    required String reportId,
    required String teacherId,
  });

  // ------------------------------------------------------------------
  // Auto-detect flow (Task 2.1)
  // ------------------------------------------------------------------

  /// Approve 1 item from the review screen → backend tạo draft NGAY.
  ///
  /// [kind] = "classwide" | "child" | "unmatched"
  /// - classwide: [classId] bắt buộc, tạo N drafts (1/child trong lớp).
  /// - child:     [childId] bắt buộc, tạo/update 1 draft cho child đó.
  /// - unmatched: [classId] bắt buộc, không tạo draft (placeholder).
  ///
  /// [extraction] (optional): Override content nếu user đã sửa trong UI.
  /// Trả về Map gồm: kind, draft_report_ids, count, child_id_to_report_id (optional),
  /// merged_extraction (optional).
  Future<Map<String, dynamic>> approveItem({
    required String voiceRecordId,
    required String teacherId,
    required String kind,
    String? childId,
    String? classId,
    Map<String, String?>? extraction,
  });

  /// Gửi batch các draft reports đã được user duyệt trước đó.
  ///
  /// Nếu [reportIds] được cung cấp → gửi đúng các report đó.
  /// Nếu rỗng → backend filter theo [classId] + [reportDate] + [teacherId].
  ///
  /// Trả về Map gồm: sent, skipped, failed, results (List<Map>).
  Future<Map<String, dynamic>> sendBatch({
    required String teacherId,
    List<String>? reportIds,
    String? classId,
    String? reportDate,
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
                connectTimeout: const Duration(seconds: 60),
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
      if (filePath.trim().isEmpty && (fileBytes == null || fileBytes.isEmpty)) {
        throw const TeacherRepositoryException(
          'File ghi âm trống hoặc không hợp lệ.',
        );
      }

      final safeFileName = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : (filePath.trim().isNotEmpty
              ? filePath.split('/').last.split('\\').last
              : 'recording_audio.m4a');

      final resolvedBytes = fileBytes ??
          ((kIsWeb || filePath.trim().isEmpty)
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
          sendTimeout: const Duration(minutes: 3),
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
    String? reportDate,
    bool overwrite = false,
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
          if (reportDate != null && reportDate.isNotEmpty)
            'report_date': reportDate,
          if (overwrite) 'overwrite': true,
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

  @override
  Future<Map<String, dynamic>> publishReport({
    required String reportId,
    required String teacherId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/teacher/reports/$reportId/publish',
        queryParameters: {'teacher_id': teacherId},
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final body = response.data;
      if (body == null) {
        throw const TeacherRepositoryException(
          'Server returned an empty publish report response.',
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
  Future<Map<String, dynamic>> approveItem({
    required String voiceRecordId,
    required String teacherId,
    required String kind,
    String? childId,
    String? classId,
    Map<String, String?>? extraction,
  }) async {
    // Build body (only include optional fields when present)
    final body = <String, dynamic>{
      'voice_record_id': voiceRecordId,
      'teacher_id': teacherId,
      'kind': kind,
    };
    if (childId != null) body['child_id'] = childId;
    if (classId != null) body['class_id'] = classId;
    if (extraction != null) body['extraction'] = extraction;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/teacher/reports/approve-item',
        data: body,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final data = response.data;
      if (data == null) {
        throw const TeacherRepositoryException(
          'Server returned an empty approve-item response.',
        );
      }
      return data;
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
  Future<Map<String, dynamic>> sendBatch({
    required String teacherId,
    List<String>? reportIds,
    String? classId,
    String? reportDate,
  }) async {
    final body = <String, dynamic>{
      'teacher_id': teacherId,
    };
    if (reportIds != null && reportIds.isNotEmpty) {
      body['report_ids'] = reportIds;
    }
    if (classId != null) body['class_id'] = classId;
    if (reportDate != null) body['report_date'] = reportDate;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/teacher/reports/send-batch',
        data: body,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final data = response.data;
      if (data == null) {
        throw const TeacherRepositoryException(
          'Server returned an empty send-batch response.',
        );
      }
      return data;
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

