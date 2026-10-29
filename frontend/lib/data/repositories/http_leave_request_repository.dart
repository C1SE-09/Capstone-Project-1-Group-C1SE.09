// frontend/lib/data/repositories/http_leave_request_repository.dart
// ===============================================================
// Repository giao tiếp API đơn nghỉ / báo trễ của phụ huynh và giáo viên.

import 'dart:typed_data';

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

class LeaveRequestException implements Exception {
  const LeaveRequestException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class ParentRequestPage {
  const ParentRequestPage({required this.items, required this.total});

  final List<LeaveRequestEntity> items;
  final int total;
}

class LeaveRequestCancelResult {
  const LeaveRequestCancelResult(
      {required this.requestId,
      required this.status,
      required this.rollbackedAttendance});
  final String requestId;
  final LeaveStatus status;
  final bool rollbackedAttendance;
}

class LeaveRequestBatchResult {
  const LeaveRequestBatchResult({
    required this.pendingCount,
    required this.reviewedCount,
    required this.items,
  });

  final int pendingCount;
  final int reviewedCount;
  final List<LeaveRequestEntity> items;
}

class HttpLeaveRequestRepository {
  HttpLeaveRequestRepository({Dio? dio, String? baseUrl})
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

  Future<ParentRequestPage> getMyRequests({
    required String childId,
    LeaveStatus? status,
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final response =
          await _dio.get('/api/leave-requests/mine', queryParameters: {
        'child_id': childId,
        if (status != null) 'status': status.name,
        'offset': offset,
        'limit': limit,
      });
      final data = response.data as Map<String, dynamic>;
      return ParentRequestPage(
        items: (data['items'] as List)
            .map((e) => LeaveRequestEntity.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: data['total'] as int,
      );
    } on DioException catch (e) {
      throw _failure(e.response?.data, e.response?.statusCode,
          'Không thể tải danh sách đơn. Vui lòng thử lại.');
    }
  }

  Future<LeaveRequestEntity> getRequest(String id) async {
    try {
      final response =
          await _dio.get('/api/leave-requests/${Uri.encodeComponent(id)}');
      return LeaveRequestEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _failure(e.response?.data, e.response?.statusCode,
          'Không thể tải chi tiết đơn. Vui lòng thử lại.');
    }
  }

  Future<LeaveRequestEntity> createRequest({
    required String childId,
    required String classId,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
    LeaveRequestType requestType = LeaveRequestType.absence,
    String? expectedArrivalTime,
    String? attachmentUrl,
    bool mealWarningAcknowledged = false,
  }) async {
    // Endpoint riêng để server cũ không âm thầm lưu báo trễ thành đơn nghỉ.
    final response = await _post('/api/leave-requests/parent', data: {
      'child_id': childId,
      'class_id': classId,
      'from_date': fromDate.toIso8601String().split('T').first,
      'to_date': toDate.toIso8601String().split('T').first,
      'reason': reason.trim(),
      'attachment_url': attachmentUrl,
      'request_type':
          requestType == LeaveRequestType.absence ? 'absence' : 'late_arrival',
      'expected_arrival_time': expectedArrivalTime,
      'meal_warning_acknowledged': mealWarningAcknowledged,
    });
    return LeaveRequestEntity.fromJson(response.data as Map<String, dynamic>);
  }

  Future<String> uploadAttachment({
    required String childId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const LeaveRequestException(
          'Ảnh phải có dung lượng từ 1 byte đến 5 MiB.');
    }
    bool starts(List<int> signature, [int offset = 0]) =>
        bytes.length >= offset + signature.length &&
        signature
            .asMap()
            .entries
            .every((e) => bytes[e.key + offset] == e.value);
    final String mime;
    if (starts([137, 80, 78, 71, 13, 10, 26, 10])) {
      mime = 'png';
    } else if (starts([255, 216, 255])) {
      mime = 'jpeg';
    } else if (starts([82, 73, 70, 70]) && starts([87, 69, 66, 80], 8)) {
      mime = 'webp';
    } else {
      throw const LeaveRequestException(
          'Vui lòng chọn ảnh JPEG, PNG hoặc WebP hợp lệ.');
    }
    final response = await _post(
      '/api/leave-requests/attachments',
      queryParameters: {'child_id': childId},
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName.split(RegExp(r'[/\\]')).last,
          contentType: MediaType('image', mime),
        )
      }),
    );
    final path =
        (response.data as Map<String, dynamic>)['attachment_url'] as String;
    _checkAttachmentPath(path);
    return path;
  }

  Future<Uint8List> getAttachmentBytes(String attachmentUrl) async {
    _checkAttachmentPath(attachmentUrl);
    try {
      final response = await _dio.get<List<int>>(
        attachmentUrl,
        options:
            Options(responseType: ResponseType.bytes, followRedirects: false),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      throw _failure(e.response?.data, e.response?.statusCode,
          'Không thể tải ảnh đính kèm. Vui lòng thử lại.');
    }
  }

  void _checkAttachmentPath(String path) {
    if (!RegExp(
            r'^/api/leave-requests/attachments/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+$')
        .hasMatch(path)) {
      throw const LeaveRequestException('Đường dẫn ảnh đính kèm không hợp lệ.');
    }
  }

  Future<Response<dynamic>> _post(String path,
      {required Object data, Map<String, dynamic>? queryParameters}) async {
    final sessions = SessionManagementService.instance;
    final sessionId = sessions.currentSession?.sessionId;
    try {
      // Làm mới thông tin xác thực khi 401, nhưng không tự phát lại đơn/ảnh.
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(validateStatus: (_) => true, followRedirects: false),
      );
      if (sessions.currentSession?.sessionId != sessionId) {
        throw const LeaveRequestException(
            'Phiên đã thay đổi. Vui lòng mở lại dữ liệu của bé.',
            code: 'session_changed');
      }
      if (response.statusCode == 401 &&
          sessionId != null &&
          sessions.currentSession?.sessionId == sessionId) {
        try {
          await sessions.refreshAccessToken(_dio);
        } on UserFacingException catch (error) {
          throw LeaveRequestException(error.userMessage,
              statusCode: error.statusCode);
        }
        throw const LeaveRequestException(
          'Phiên đã được làm mới. Nội dung được giữ lại; vui lòng bấm gửi lại.',
          statusCode: 401,
          code: 'session_refreshed',
        );
      }
      if ((response.statusCode ?? 500) >= 300) {
        if (path == '/api/leave-requests/parent' &&
            (response.statusCode == 404 || response.statusCode == 405)) {
          throw LeaveRequestException(
            'Máy chủ chưa hỗ trợ gửi đơn nghỉ / báo trễ. Cần cập nhật backend trước khi gửi.',
            statusCode: response.statusCode,
            code: 'backend_update_required',
          );
        }
        throw _failure(response.data, response.statusCode,
            'Không thể gửi đơn hoặc ảnh. Vui lòng thử lại.');
      }
      return response;
    } on DioException catch (e) {
      throw _failure(e.response?.data, e.response?.statusCode,
          'Mất kết nối. Chưa xác nhận gửi thành công; hãy tải lại lịch sử trước khi thử lại.');
    }
  }

  LeaveRequestException _failure(Object? data, int? status, String fallback) {
    final detail = data is Map ? data['detail'] : null;
    String? message;
    String? code;
    if (detail is String) {
      message = detail;
    } else if (detail is Map) {
      message = detail['message'] as String?;
      code = detail['code'] as String?;
    } else if (detail is List) {
      message = detail
          .whereType<Map>()
          .map((e) => e['msg'])
          .whereType<String>()
          .join('\n');
    }
    return LeaveRequestException(
        message?.isNotEmpty == true ? message! : fallback,
        statusCode: status,
        code: code);
  }

  /// Lấy danh sách đơn xin nghỉ theo lớp và tab (pending | reviewed)
  Future<LeaveRequestBatchResult> getLeaveRequests({
    required String classId,
    required String tab,
    int offset = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/api/leave-requests/class/$classId',
        queryParameters: {'tab': tab, 'offset': offset, 'limit': limit},
      );

      final data = response.data as Map<String, dynamic>;
      final itemsRaw = data['items'] as List<dynamic>? ?? [];
      final items = itemsRaw
          .map((e) => LeaveRequestEntity.fromJson(e as Map<String, dynamic>))
          .toList();

      return LeaveRequestBatchResult(
        pendingCount: data['pending_count'] as int? ?? 0,
        reviewedCount: data['reviewed_count'] as int? ?? 0,
        items: items,
      );
    } on DioException catch (e) {
      throw _failure(e.response?.data, e.response?.statusCode,
          'Không thể tải danh sách đơn xin nghỉ');
    }
  }

  /// Duyệt đơn 1 chạm
  Future<LeaveRequestEntity> approveLeaveRequest(String requestId) async {
    try {
      final response = await _post(
          '/api/leave-requests/${Uri.encodeComponent(requestId)}/approve',
          data: {});
      return LeaveRequestEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _failure(
          e.response?.data, e.response?.statusCode, 'Không thể phê duyệt đơn');
    }
  }

  /// Từ chối đơn kèm lý do bắt buộc
  Future<LeaveRequestEntity> rejectLeaveRequest({
    required String requestId,
    required String rejectReason,
  }) async {
    try {
      final response = await _post(
        '/api/leave-requests/${Uri.encodeComponent(requestId)}/reject',
        data: {'reject_reason': rejectReason.trim()},
      );
      return LeaveRequestEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _failure(
          e.response?.data, e.response?.statusCode, 'Không thể từ chối đơn');
    }
  }

  Future<LeaveRequestCancelResult> cancelRequest(String requestId) async {
    final response = await _post(
        '/api/leave-requests/${Uri.encodeComponent(requestId)}/cancel',
        data: {});
    final body = response.data;
    if (body is! Map ||
        body['success'] != true ||
        (body['leave_id'] ?? body['request_id']) != requestId ||
        body['status'] != 'cancelled') {
      throw const LeaveRequestException(
          'Chưa xác nhận hủy. Hãy tải lại trạng thái trước khi thử lại.',
          code: 'invalid_response');
    }
    return LeaveRequestCancelResult(
        requestId: requestId,
        status: LeaveStatus.cancelled,
        rollbackedAttendance: body['rollbacked_attendance'] == true);
  }
}
