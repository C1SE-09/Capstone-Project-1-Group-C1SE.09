// frontend/lib/data/repositories/http_attendance_repository.dart
// =============================================================
// Repository giao tiếp API điểm danh học sinh & gửi thông báo vắng.

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:dio/dio.dart';

class AttendanceChildRecord {
  const AttendanceChildRecord({
    required this.childId,
    required this.status,
    this.expectedArrivalTime,
    this.checkInTime,
    this.note,
  });

  final String childId;
  final AttendanceStatus status;
  final String? expectedArrivalTime;
  final String? checkInTime;
  final String? note;
}

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
      case 'excused_absent':
        return AttendanceStatus.excusedAbsent;
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
      case AttendanceStatus.excusedAbsent:
        return 'excused_absent';
      case AttendanceStatus.late:
        return 'late';
      case AttendanceStatus.arrived:
        return 'present';
    }
  }

  /// Lấy chi tiết điểm danh của lớp theo ngày (bao gồm giờ ETA và ghi chú đơn).
  /// Endpoint: GET /api/attendance?class_id={classId}&attendance_date={YYYY-MM-DD}
  Future<Map<String, AttendanceChildRecord>> getClassAttendanceDetails(
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
        final map = <String, AttendanceChildRecord>{};
        for (final item in list) {
          if (item is Map && item['child_id'] != null) {
            final cid = item['child_id'].toString();
            map[cid] = AttendanceChildRecord(
              childId: cid,
              status: _parseStatus(item['status']?.toString()),
              expectedArrivalTime: item['expected_arrival_time']?.toString(),
              checkInTime: item['check_in_time']?.toString(),
              note: item['note']?.toString(),
            );
          }
        }
        return map;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Lấy bản ghi điểm danh của lớp theo ngày.
  /// Endpoint: GET /api/attendance?class_id={classId}&attendance_date={YYYY-MM-DD}
  Future<Map<String, AttendanceStatus>> getClassAttendance(
    String classId,
    DateTime date,
  ) async {
    final details = await getClassAttendanceDetails(classId, date);
    return details.map((k, v) => MapEntry(k, v.status));
  }

  /// Lưu bảng điểm danh cả lớp trong ngày (batch).
  /// Endpoint: POST /api/attendance/batch
  Future<void> saveBatchAttendance({
    required String classId,
    required DateTime date,
    required Map<String, AttendanceStatus> record,
    Map<String, String?>? expectedArrivalTimes,
    Map<String, String?>? notes,
  }) async {
    final records = record.entries
        .map((e) => {
              'child_id': e.key,
              'status': _statusToString(e.value),
              'check_in_time': null,
              'expected_arrival_time': expectedArrivalTimes?[e.key],
              'note': notes?[e.key],
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
