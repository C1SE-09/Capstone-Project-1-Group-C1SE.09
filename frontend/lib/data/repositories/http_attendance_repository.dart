// frontend/lib/data/repositories/http_attendance_repository.dart
// =============================================================
// Repository giao tiếp API điểm danh học sinh & gửi thông báo vắng.

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:dio/dio.dart';

class HttpAttendanceRepository {
  HttpAttendanceRepository({Dio? dio, String? baseUrl})
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
    // Đảm bảo gắn Bearer token mới nhất nếu AuthRepository có token
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

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  AttendanceStatus _parseStatus(String? val) {
    switch (val?.toLowerCase()) {
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      case 'present':
      case 'arrived':
      default:
        return AttendanceStatus.arrived;
    }
  }

  String _statusToString(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.late:
        return 'late';
      case AttendanceStatus.arrived:
        return 'present';
    }
  }

  /// Lấy bản ghi điểm danh của lớp theo ngày.
  /// Endpoint: GET /api/attendance?class_id={classId}&attendance_date={YYYY-MM-DD}
  Future<Map<String, AttendanceStatus>> getClassAttendance(
    String classId,
    DateTime date,
  ) async {
    try {
      final res = await _dio.get(
        '/api/attendance',
        queryParameters: {
          'class_id': classId,
          'attendance_date': _formatDate(date),
        },
      );
      final data = res.data;
      if (data is Map && data['children'] is List) {
        final list = data['children'] as List;
        final map = <String, AttendanceStatus>{};
        for (final item in list) {
          if (item is Map && item['child_id'] != null) {
            map[item['child_id'].toString()] =
                _parseStatus(item['status']?.toString());
          }
        }
        return map;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Lưu bảng điểm danh cả lớp trong ngày (batch).
  /// Endpoint: POST /api/attendance/batch
  Future<void> saveBatchAttendance({
    required String classId,
    required DateTime date,
    required Map<String, AttendanceStatus> record,
  }) async {
    final records = record.entries
        .map((e) => {
              'child_id': e.key,
              'status': _statusToString(e.value),
              'check_in_time': null,
              'note': null,
            })
        .toList();

    await _dio.post(
      '/api/attendance/batch',
      data: {
        'class_id': classId,
        'date': _formatDate(date),
        'records': records,
      },
    );
  }

  /// Gửi push notification thông báo các bé vắng đến phụ huynh.
  /// Endpoint: POST /api/attendance/notify-absent
  Future<int> notifyAbsentParents({
    required String classId,
    required DateTime date,
    required List<String> childIds,
  }) async {
    final res = await _dio.post(
      '/api/attendance/notify-absent',
      data: {
        'class_id': classId,
        'date': _formatDate(date),
        'child_ids': childIds,
      },
    );
    if (res.data is Map && res.data['target_count'] is num) {
      return (res.data['target_count'] as num).toInt();
    }
    return childIds.length;
  }
}
