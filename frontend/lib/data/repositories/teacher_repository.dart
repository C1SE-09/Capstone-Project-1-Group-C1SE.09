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
import 'package:adark_frontend/core/errors/app_exception.dart';
import 'package:adark_frontend/core/network/api_client.dart';
import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/domain/entities/voice/voice_entities.dart';
import 'package:dio/dio.dart';

export 'package:adark_frontend/domain/entities/voice/voice_entities.dart';

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

// Thrown when [TeacherRepository.uploadAudio] or [updateTranscript] fails.
class TeacherRepositoryException implements AppException {
  const TeacherRepositoryException(this.message, {this.statusCode});

  @override
  final String message;
  @override
  final int? statusCode;
  @override
  String? get userMessage => null;

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

  /// Xóa các bản nháp báo cáo từ DB khi giáo viên bỏ duyệt.
  Future<void> deleteDraftReports(List<String> reportIds);

  // ------------------------------------------------------------------
  // Multi-clip voice session (User Story #78)
  // ------------------------------------------------------------------

  /// Tạo mới hoặc khôi phục phiên ghi âm ACTIVE trong ngày cho (teacher, lớp).
  Future<VoiceRecordingSession> createOrResumeVoiceSession({
    required String teacherId,
    required String classId,
    String? childId,
    String scope = 'whole_class',
    bool forceNew = false,
  });

  /// Lấy chi tiết phiên ghi âm kèm danh sách clip và trạng thái STT mới nhất.
  Future<VoiceRecordingSession> getVoiceSession({
    required String sessionId,
    required String teacherId,
  });

  /// Upload 1 đoạn audio mới và gắn vào phiên ghi âm [sessionId].
  Future<VoiceRecord> uploadAudioToSession({
    required String sessionId,
    required String filePath,
    required String classId,
    required String teacherId,
    String? childId,
    Uint8List? fileBytes,
    String? fileName,
    void Function(int sent, int total)? onProgress,
  });

  /// Xoá 1 bản ghi âm trong phiên (DB + MinIO).
  Future<void> deleteVoiceClip({
    required String voiceId,
    required String teacherId,
  });

  /// Ghép transcript các bản ghi đã STT xong trong phiên.
  Future<MergeVoiceSessionResult> mergeVoiceSession({
    required String sessionId,
    required String teacherId,
    String? editedTranscript,
  });

  /// Huỷ bỏ phiên ghi âm đang mở.
  Future<void> discardVoiceSession({
    required String sessionId,
    required String teacherId,
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
            ) {
    ApiClient.attachSessionInterceptorIfNeeded(_dio);
  }

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
  }) =>
      _uploadAudioInternal(
        filePath: filePath,
        classId: classId,
        teacherId: teacherId,
        childId: childId,
        fileBytes: fileBytes,
        fileName: fileName,
        onProgress: onProgress,
      );

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
  }) =>
      _uploadAudioInternal(
        sessionId: sessionId,
        filePath: filePath,
        classId: classId,
        teacherId: teacherId,
        childId: childId,
        fileBytes: fileBytes,
        fileName: fileName,
        onProgress: onProgress,
      );

  Future<VoiceRecord> _uploadAudioInternal({
    String? sessionId,
    required String filePath,
    required String classId,
    required String teacherId,
    String? childId,
    Uint8List? fileBytes,
    String? fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    return _runDioRequest(() async {
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
        if ((sessionId ?? '').trim().isNotEmpty)
          'session_id': sessionId!.trim(),
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
          'Máy chủ không phản hồi dữ liệu. Vui lòng thử lại sau.',
        );
      }

      return VoiceRecord.fromJson(body);
    });
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
      throw const TeacherRepositoryException('Đã xảy ra sự cố ngoài ý muốn. Thầy cô vui lòng thử lại sau ít phút.');
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
      throw const TeacherRepositoryException('Đã xảy ra sự cố ngoài ý muốn. Thầy cô vui lòng thử lại sau ít phút.');
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
          'Không nhận được kết quả nhận diện từ hệ thống. Vui lòng thử lại.',
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
      throw const TeacherRepositoryException('Đã xảy ra sự cố ngoài ý muốn. Thầy cô vui lòng thử lại sau ít phút.');
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
          'Không nhận được kết quả phân tích lại từ hệ thống. Vui lòng thử lại.',
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
      throw const TeacherRepositoryException('Đã xảy ra sự cố ngoài ý muốn. Thầy cô vui lòng thử lại sau ít phút.');
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
          'Không nhận được phản hồi tạo báo cáo từ hệ thống. Vui lòng thử lại.',
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
      throw const TeacherRepositoryException('Đã xảy ra sự cố ngoài ý muốn. Thầy cô vui lòng thử lại sau ít phút.');
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
      throw const TeacherRepositoryException('Đã xảy ra sự cố ngoài ý muốn. Thầy cô vui lòng thử lại sau ít phút.');
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
      throw const TeacherRepositoryException('Đã xảy ra sự cố ngoài ý muốn. Thầy cô vui lòng thử lại sau ít phút.');
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
          'Không nhận được phản hồi duyệt báo cáo từ hệ thống. Vui lòng thử lại.',
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
      throw const TeacherRepositoryException('Đã xảy ra sự cố ngoài ý muốn. Thầy cô vui lòng thử lại sau ít phút.');
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
    if (reportIds != null) {
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
          'Không nhận được phản hồi gửi báo cáo từ hệ thống. Vui lòng thử lại.',
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
      throw const TeacherRepositoryException('Đã xảy ra sự cố ngoài ý muốn. Thầy cô vui lòng thử lại sau ít phút.');
    }
  }

  @override
  Future<void> deleteDraftReports(List<String> reportIds) async {
    if (reportIds.isEmpty) return;
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/teacher/reports/delete-drafts',
        data: {'report_ids': reportIds},
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );
    } catch (e) {
      // Fallback: delete từng cái
      for (final id in reportIds) {
        try {
          await _dio.delete<void>('/api/teacher/reports/$id');
        } catch (_) {}
      }
    }
  }

  @override
  Future<VoiceRecordingSession> createOrResumeVoiceSession({
    required String teacherId,
    required String classId,
    String? childId,
    String scope = 'whole_class',
    bool forceNew = false,
  }) async {
    return _runDioRequest(() async {
      final body = <String, dynamic>{
        'teacher_id': teacherId,
        'class_id': classId,
        'scope': scope,
        'force_new': forceNew,
        if ((childId ?? '').trim().isNotEmpty) 'child_id': childId!.trim(),
      };
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/teacher/voice/sessions',
        data: body,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final data = response.data;
      if (data == null) {
        throw const TeacherRepositoryException(
          'Không nhận được thông tin phiên ghi âm từ máy chủ.',
        );
      }
      return VoiceRecordingSession.fromJson(data);
    });
  }

  @override
  Future<VoiceRecordingSession> getVoiceSession({
    required String sessionId,
    required String teacherId,
  }) async {
    return _runDioRequest(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/teacher/voice/sessions/$sessionId',
        queryParameters: {'teacher_id': teacherId},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final data = response.data;
      if (data == null) {
        throw const TeacherRepositoryException(
          'Không tải được chi tiết phiên ghi âm.',
        );
      }
      return VoiceRecordingSession.fromJson(data);
    });
  }

  @override
  Future<void> deleteVoiceClip({
    required String voiceId,
    required String teacherId,
  }) async {
    await _runDioRequest(() async {
      await _dio.delete<Map<String, dynamic>>(
        '/api/teacher/voice/$voiceId',
        queryParameters: {'teacher_id': teacherId},
        options: Options(headers: {'Accept': 'application/json'}),
      );
    });
  }

  @override
  Future<MergeVoiceSessionResult> mergeVoiceSession({
    required String sessionId,
    required String teacherId,
    String? editedTranscript,
  }) async {
    return _runDioRequest(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/teacher/voice/sessions/$sessionId/merge',
        data: {
          'teacher_id': teacherId,
          if (editedTranscript != null && editedTranscript.trim().isNotEmpty)
            'edited_transcript': editedTranscript.trim(),
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final data = response.data;
      if (data == null) {
        throw const TeacherRepositoryException(
          'Không ghép được nội dung phiên ghi âm.',
        );
      }
      return MergeVoiceSessionResult.fromJson(data);
    });
  }

  @override
  Future<void> discardVoiceSession({
    required String sessionId,
    required String teacherId,
  }) async {
    await _runDioRequest(() async {
      await _dio.delete<Map<String, dynamic>>(
        '/api/teacher/voice/sessions/$sessionId',
        queryParameters: {'teacher_id': teacherId},
        options: Options(headers: {'Accept': 'application/json'}),
      );
    });
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  Future<T> _runDioRequest<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on TeacherRepositoryException {
      rethrow;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = _extractDetail(e.response?.data) ??
          e.message ??
          'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.';
      throw TeacherRepositoryException(detail, statusCode: statusCode);
    } catch (_) {
      throw const TeacherRepositoryException(
        'Đã xảy ra sự cố ngoài ý muốn. Thầy cô vui lòng thử lại sau ít phút.',
      );
    }
  }

  static String? _extractDetail(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail != null) return detail.toString();
    }
    return null;
  }
}

