import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/domain/entities/report/report_response.dart';

class ReportResponseException implements Exception {
  const ReportResponseException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HttpReportResponseRepository {
  HttpReportResponseRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? kApiBaseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                headers: AuthRepository.currentUser?.token != null
                    ? {
                        'Authorization':
                            'Bearer ${AuthRepository.currentUser!.token}'
                      }
                    : null,
              ),
            ) {
    _dio.interceptors.add(
      SessionManagementService.instance.createDioInterceptor(_dio),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = AuthRepository.currentUser?.token;
          if (token != null &&
              token.isNotEmpty &&
              (!options.headers.containsKey('Authorization') ||
                  options.headers['Authorization'] == null)) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

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
      if (isTeacher) {
        response = await _dio.post(
          '/api/report-responses/reports/$reportId/reply',
          data: {'content': content},
        );
      } else if (imageBytes != null && imageBytes.isNotEmpty) {
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
        response = await _dio.post(
          '/api/report-responses/reports/$reportId/with-image',
          data: formData,
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

