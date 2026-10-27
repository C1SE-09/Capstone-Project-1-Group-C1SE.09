// frontend/lib/data/repositories/http_leave_request_repository.dart
// ===============================================================
// Repository giao tiếp API duyệt đơn xin nghỉ học của giáo viên.

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:dio/dio.dart';

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
                    ? {'Authorization': 'Bearer ${AuthRepository.currentUser!.token}'}
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

  /// Lấy danh sách đơn xin nghỉ theo lớp và tab (pending | reviewed)
  Future<LeaveRequestBatchResult> getLeaveRequests({
    required String classId,
    required String tab,
  }) async {
    try {
      final response = await _dio.get(
        '/api/leave-requests/class/$classId',
        queryParameters: {'tab': tab},
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
      final msg = e.response?.data?['detail'] ?? 'Không thể tải danh sách đơn xin nghỉ';
      throw Exception(msg);
    }
  }

  /// Duyệt đơn 1 chạm
  Future<LeaveRequestEntity> approveLeaveRequest(String requestId) async {
    try {
      final response = await _dio.post('/api/leave-requests/$requestId/approve');
      return LeaveRequestEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Không thể phê duyệt đơn';
      throw Exception(msg);
    }
  }

  /// Từ chối đơn kèm lý do bắt buộc
  Future<LeaveRequestEntity> rejectLeaveRequest({
    required String requestId,
    required String rejectReason,
  }) async {
    try {
      final response = await _dio.post(
        '/api/leave-requests/$requestId/reject',
        data: {'reject_reason': rejectReason.trim()},
      );
      return LeaveRequestEntity.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Không thể từ chối đơn';
      throw Exception(msg);
    }
  }
}
