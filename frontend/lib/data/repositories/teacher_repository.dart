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


import 'package:dio/dio.dart';

// ---------------------------------------------------------------------------
// Entity: VoiceRecord
// ---------------------------------------------------------------------------

// Lightweight entity returned after a successful upload.
//
// Fields mirror the backend response schema:
//   { "id": "uuid", "status": "pending" }
class VoiceRecord {
  const VoiceRecord({required this.id, required this.status});

  final String id;
  final String status;

  factory VoiceRecord.fromJson(Map<String, dynamic> json) {
    return VoiceRecord(
      id: json['id'] as String,
      status: json['status'] as String,
    );
  }

  @override
  String toString() => 'VoiceRecord(id: $id, status: $status)';
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

// Thrown when [TeacherRepository.uploadAudio] fails.
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
    void Function(int sent, int total)? onProgress,
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
                baseUrl: baseUrl ?? 'http://10.0.2.2:8000',
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
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      // Build multipart form data
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          // Keep original filename so the backend can validate the extension
          filename: filePath.split('/').last.split('\\').last,
        ),
        'class_id': classId,
        'teacher_id': teacherId,
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
