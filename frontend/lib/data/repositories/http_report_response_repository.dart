import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import 'package:adark_frontend/core/errors/app_exception.dart';
import 'package:adark_frontend/core/network/api_client.dart';
import 'package:adark_frontend/domain/entities/report/report_response.dart';

class ReportResponseException implements AppException {
  const ReportResponseException(this.message, {this.statusCode});
  @override
  final String message;
  @override
  final int? statusCode;
  @override
  String? get userMessage => null;

  @override
  String toString() => message;
}

class HttpReportResponseRepository {
  HttpReportResponseRepository({Dio? dio, String? baseUrl})
      : _dio = ApiClient.resolveDio(dio: dio, baseUrl: baseUrl);

  final Dio _dio;
  final Map<String, Uint8List> _audioCache = {};

  Future<List<ReportResponse>> getResponses(
    String reportId, {
    bool markRead = true,
  }) async {
    try {
      final response = await _dio.get(
        '/api/report-responses/reports/$reportId',
        queryParameters: {'mark_read': markRead},
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['responses'] as List<dynamic>? ?? [];
      return list
          .map((e) => ReportResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ReportResponseException(
        _formatDioError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw ReportResponseException(e.toString());
    }
  }

  Future<ReportResponse> sendResponse({
    required String reportId,
    required String content,
    Uint8List? imageBytes,
    String? fileName,
    bool isTeacher = false,
  }) async {
    try {
      Response response;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final ext = (fileName != null && fileName.contains('.'))
            ? fileName.split('.').last.toLowerCase()
            : 'jpg';
        final mimeType = switch (ext) {
          'png' => MediaType('image', 'png'),
          'webp' => MediaType('image', 'webp'),
          _ => MediaType('image', 'jpeg'),
        };
        final formData = FormData.fromMap({
          'content': content,
          'file': MultipartFile.fromBytes(
            imageBytes,
            filename: fileName ?? 'attachment.$ext',
            contentType: mimeType,
          ),
        });
        final endpoint = isTeacher
            ? '/api/report-responses/reports/$reportId/reply-with-image'
            : '/api/report-responses/reports/$reportId/with-image';
        response = await _dio.post(
          endpoint,
          data: formData,
        );
      } else if (isTeacher) {
        response = await _dio.post(
          '/api/report-responses/reports/$reportId/reply',
          data: {'content': content},
        );
      } else {
        response = await _dio.post(
          '/api/report-responses/reports/$reportId',
          data: {'content': content},
        );
      }
      final data = response.data as Map<String, dynamic>;
      final resObj = data['response'] as Map<String, dynamic>;
      return ReportResponse.fromJson(resObj);
    } on DioException catch (e) {
      throw ReportResponseException(
        _formatDioError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw ReportResponseException(e.toString());
    }
  }

  Future<ReportResponse> resolveResponse(
    String responseId, {
    bool resolved = true,
  }) async {
    try {
      final response = await _dio.post(
        '/api/report-responses/$responseId/resolve',
        data: {'resolved': resolved},
      );
      final data = response.data as Map<String, dynamic>;
      final resObj = data['response'] as Map<String, dynamic>;
      return ReportResponse.fromJson(resObj);
    } on DioException catch (e) {
      throw ReportResponseException(
        _formatDioError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw ReportResponseException(e.toString());
    }
  }

  Future<Uint8List> getAttachmentBytes(String urlOrPath) async {
    try {
      final response = await _dio.get<List<int>>(
        urlOrPath,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      throw ReportResponseException(
        _formatDioError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw ReportResponseException(e.toString());
    }
  }

  Future<ReportResponse> sendVoiceResponse({
    required String reportId,
    required Uint8List audioBytes,
    required int durationSeconds,
    String? fileName,
    String? summaryText,
    bool isTeacher = false,
  }) async {
    try {
      final name = fileName ??
          'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ext = name.contains('.')
          ? name.split('.').last.toLowerCase()
          : 'm4a';
      final mimeType = switch (ext) {
        'mp3' => MediaType('audio', 'mpeg'),
        'wav' => MediaType('audio', 'wav'),
        'ogg' => MediaType('audio', 'ogg'),
        'aac' => MediaType('audio', 'aac'),
        _ => MediaType('audio', 'm4a'),
      };

      final formData = FormData.fromMap({
        'content': summaryText ?? 'Tin nhắn thoại ($durationSeconds giây)',
        'duration': durationSeconds,
        'file': MultipartFile.fromBytes(
          audioBytes,
          filename: name,
          contentType: mimeType,
        ),
      });

      final response = await _dio.post(
        '/api/report-responses/reports/$reportId/with-audio',
        data: formData,
      );

      final data = response.data as Map<String, dynamic>;
      final resObj = data['response'] as Map<String, dynamic>;
      final result = ReportResponse.fromJson(resObj);
      if (result.audioUrl != null && result.audioUrl!.isNotEmpty) {
        _audioCache[result.audioUrl!] = audioBytes;
      }
      return result;
    } on DioException catch (e) {
      throw ReportResponseException(
        _formatDioError(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw ReportResponseException(e.toString());
    }
  }

  Future<Uint8List> getAudioBytes(String audioUrl) async {
    if (_audioCache.containsKey(audioUrl)) {
      return _audioCache[audioUrl]!;
    }
    final bytes = await getAttachmentBytes(audioUrl);
    _audioCache[audioUrl] = bytes;
    return bytes;
  }

  String _formatDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Không thể kết nối đến máy chủ. Quý phụ huynh vui lòng kiểm tra lại kết nối mạng.';
    }
    final detail = e.response?.data;
    if (detail is Map && detail['detail'] != null) {
      return detail['detail'].toString();
    }
    return 'Đã có lỗi xảy ra trong quá trình xử lý. Vui lòng thử lại sau.';
  }
}

