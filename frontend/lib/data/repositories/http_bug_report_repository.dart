// frontend/lib/data/repositories/http_bug_report_repository.dart
// =========================================================
// HttpBugReportRepository — gọi FastAPI backend qua dio.
// MIRROR backend/app/api/endpoints/bug_reports.py
//
// Pattern mirror data/repositories/http_dashboard_repository.dart
// (auth header lấy từ AuthRepository.currentUser, baseUrl từ kApiBaseUrl).

import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/domain/entities/bug_report/bug_report.dart';
import 'package:adark_frontend/domain/entities/bug_report/bug_report_list_response.dart';
import 'package:adark_frontend/domain/repositories/bug_report_repository.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;

class HttpBugReportRepository implements BugReportRepository {
  HttpBugReportRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? kApiBaseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  /// Header Authorization Bearer `<token>` nếu user đã login.
  Options get _authOptions {
    final token = AuthRepository.currentUser?.token;
    if (token == null || token.isEmpty) return Options();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ══════════════════════════════════════════════════════════
  // 1. CREATE
  // ══════════════════════════════════════════════════════════

  @override
  Future<BugReportDetail> create(BugReportCreatePayload payload) async {
    try {
      // Form fields (text)
      final form = FormData.fromMap({
        'title': payload.title,
        'description': payload.description,
        'category': payload.category.name,
        'severity': payload.severity.name,
        if (payload.appVersion != null) 'app_version': payload.appVersion,
        if (payload.buildNumber != null) 'build_number': payload.buildNumber,
        if (payload.osVersion != null) 'os_version': payload.osVersion,
        if (payload.deviceModel != null) 'device_model': payload.deviceModel,
        if (payload.networkType != null) 'network_type': payload.networkType,
      });

      // Attachments (file) — multipart từ bytes
      for (final f in payload.attachments) {
        form.files.add(
          MapEntry(
            'attachments',
            MultipartFile.fromBytes(
              f.bytes,
              filename: f.fileName,
              contentType: _parseMediaType(f.mimeType),
            ),
          ),
        );
      }

      final response = await _dio.post(
        '/api/bug-reports',
        data: form,
        options: _authOptions.copyWith(
          contentType: 'multipart/form-data',
        ),
      );
      return BugReportDetail.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _toException(error, fallback: 'Không thể gửi báo cáo lỗi.');
    }
  }

  // ══════════════════════════════════════════════════════════
  // 1b. LIST MY REPORTS (teacher/parent)
  // ══════════════════════════════════════════════════════════

  @override
  Future<BugReportListResponse> listMyReports({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    try {
      final query = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (status != null && status.isNotEmpty) {
        query['status'] = status;
      }
      final response = await _dio.get(
        '/api/bug-reports/me',
        queryParameters: query,
        options: _authOptions,
      );
      return BugReportListResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _toException(error, fallback: 'Không thể tải danh sách báo cáo của bạn.');
    }
  }

  // ══════════════════════════════════════════════════════════
  // 2. LIST ALL REPORTS (admin)
  // ══════════════════════════════════════════════════════════

  @override
  Future<BugReportListResponse> listAllReports({
    int page = 1,
    int pageSize = 20,
    BugReportFilter? filter,
    String orderBy = 'created_at_desc',
  }) async {
    try {
      final query = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'order_by': orderBy,
      };
      if (filter != null) {
        query.addAll(filter.toQueryParams());
      }
      final response = await _dio.get(
        '/api/bug-reports',
        queryParameters: query,
        options: _authOptions,
      );
      return BugReportListResponse.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _toException(error, fallback: 'Không thể tải danh sách (admin).');
    }
  }

  // ══════════════════════════════════════════════════════════
  // 3. GET REPORT DETAIL (admin)
  // ══════════════════════════════════════════════════════════

  @override
  Future<BugReportDetail> getReport(String reportId) async {
    try {
      final response = await _dio.get(
        '/api/bug-reports/$reportId',
        options: _authOptions,
      );
      return BugReportDetail.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _toException(error, fallback: 'Không thể tải báo cáo.');
    }
  }

  // ══════════════════════════════════════════════════════════
  // 4. UPDATE REPORT (admin)
  // ══════════════════════════════════════════════════════════

  @override
  Future<BugReportDetail> updateReport(
    String reportId,
    BugReportUpdatePayload payload,
  ) async {
    try {
      // Backend schema: status (string enum) | teacher_id (uuid | null) | comment
      final body = <String, dynamic>{};
      if (payload.status != null) {
        // Map sang snake_case enum name cho backend
        body['status'] = switch (payload.status!.name) {
          'inProgress' => 'in_progress',
          'wontFix' => 'wont_fix',
          final s => s,
        };
      }
      if (payload.teacherId != null) {
        body['teacher_id'] = payload.teacherId;
      }
      if (payload.comment != null && payload.comment!.isNotEmpty) {
        body['comment'] = payload.comment;
      }

      final response = await _dio.patch(
        '/api/bug-reports/$reportId',
        data: body,
        options: _authOptions,
      );
      return BugReportDetail.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _toException(error, fallback: 'Không thể cập nhật báo cáo.');
    }
  }

  // ══════════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════════

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  /// Convert "image/jpeg" → MediaType('image', 'jpeg'). Trả null nếu parse lỗi
  /// để MultipartFile tự suy ra từ extension.
  MediaType? _parseMediaType(String mime) {
    final slash = mime.indexOf('/');
    if (slash <= 0 || slash >= mime.length - 1) return null;
    return MediaType(mime.substring(0, slash), mime.substring(slash + 1));
  }

  /// Map DioException → BugReportException với message tiếng Việt thân thiện.
  BugReportException _toException(
    DioException error, {
    required String fallback,
  }) {
    final status = error.response?.statusCode;
    final detail = _extractDetailMessage(error.response?.data) ?? fallback;
    return BugReportException(detail, statusCode: status);
  }

  /// Backend FastAPI trả về { "detail": "..." } cho HTTPException
  /// hoặc { "detail": [ { "msg": "..." } ] } cho validation error.
  String? _extractDetailMessage(dynamic data) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          return first['msg'] as String?;
        }
        return detail.first.toString();
      }
    }
    return null;
  }
}
