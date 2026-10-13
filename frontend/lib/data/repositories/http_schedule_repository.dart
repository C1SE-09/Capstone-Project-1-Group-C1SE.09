// frontend/lib/data/repositories/http_schedule_repository.dart
// =========================================================
// Repository cho Thời khóa biểu — gọi backend /api/schedules, /api/time-slots, /api/subjects.

import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/domain/entities/timetable/class_schedule.dart';
import 'package:adark_frontend/domain/entities/timetable/subject.dart';
import 'package:adark_frontend/domain/entities/timetable/time_slot.dart';
import 'package:dio/dio.dart';

abstract class ScheduleRepository {
  Future<List<ClassSchedule>> getClassSchedule(String classId);
  Future<List<TimeSlot>> getTimeSlots();
  Future<List<Subject>> getSubjects();
  Future<ClassSchedule> createSchedule({
    required String classId,
    required String subjectId,
    required String slotId,
    required int dayOfWeek,
    String? activityName,
    String? roomName,
    String? teacherId,
  });
  Future<ClassSchedule> updateSchedule(
    String scheduleId, {
    String? subjectId,
    String? slotId,
    int? dayOfWeek,
    String? activityName,
    String? roomName,
    bool? isActive,
  });
  Future<void> deleteSchedule(String scheduleId);
}

class ScheduleException implements Exception {
  const ScheduleException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'ScheduleException($statusCode): $message';
}

class HttpScheduleRepository implements ScheduleRepository {
  HttpScheduleRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? kApiBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ));

  final Dio _dio;

  Map<String, String> get _headers {
    final token = AuthRepository.currentUser?.token;
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  Options get _options => Options(headers: _headers);

  @override
  Future<List<ClassSchedule>> getClassSchedule(String classId) async {
    try {
      final response = await _dio.get('/api/schedules/class/$classId', options: _options);
      return _asList(response.data)
          .map((item) => ClassSchedule.fromJson(item))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ScheduleException(_messageFor(error, 'Không thể tải thời khóa biểu.'), statusCode: error.response?.statusCode);
    }
  }

  @override
  Future<List<TimeSlot>> getTimeSlots() async {
    try {
      final response = await _dio.get('/api/time-slots', options: _options);
      return _asList(response.data).map(TimeSlot.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ScheduleException(_messageFor(error, 'Không thể tải khung giờ.'), statusCode: error.response?.statusCode);
    }
  }

  @override
  Future<List<Subject>> getSubjects() async {
    try {
      final response = await _dio.get('/api/subjects', options: _options);
      return _asList(response.data).map(Subject.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ScheduleException(_messageFor(error, 'Không thể tải môn học.'), statusCode: error.response?.statusCode);
    }
  }

  @override
  Future<ClassSchedule> createSchedule({
    required String classId,
    required String subjectId,
    required String slotId,
    required int dayOfWeek,
    String? activityName,
    String? roomName,
    String? teacherId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/schedules',
        data: {
          'class_id': classId,
          'subject_id': subjectId,
          'slot_id': slotId,
          'day_of_week': dayOfWeek,
          if (teacherId != null) 'teacher_id': teacherId,
          if (activityName != null && activityName.trim().isNotEmpty) 'activity_name': activityName.trim(),
          if (roomName != null && roomName.trim().isNotEmpty) 'room_name': roomName.trim(),
          'is_active': true,
        },
        options: _options,
      );
      return ClassSchedule.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ScheduleException(_messageFor(error, 'Không thể thêm hoạt động.'), statusCode: error.response?.statusCode);
    }
  }

  @override
  Future<ClassSchedule> updateSchedule(
    String scheduleId, {
    String? subjectId,
    String? slotId,
    int? dayOfWeek,
    String? activityName,
    String? roomName,
    bool? isActive,
  }) async {
    try {
      final response = await _dio.put(
        '/api/schedules/$scheduleId',
        data: {
          if (subjectId != null) 'subject_id': subjectId,
          if (slotId != null) 'slot_id': slotId,
          if (dayOfWeek != null) 'day_of_week': dayOfWeek,
          if (activityName != null) 'activity_name': activityName.trim(),
          if (roomName != null) 'room_name': roomName.trim(),
          if (isActive != null) 'is_active': isActive,
        },
        options: _options,
      );
      return ClassSchedule.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ScheduleException(_messageFor(error, 'Không thể cập nhật hoạt động.'), statusCode: error.response?.statusCode);
    }
  }

  @override
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      await _dio.delete('/api/schedules/$scheduleId', options: _options);
    } on DioException catch (error) {
      throw ScheduleException(_messageFor(error, 'Không thể xóa hoạt động.'), statusCode: error.response?.statusCode);
    }
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const ScheduleException('Dữ liệu thời khóa biểu nhận được không hợp lệ.');
  }

  /// Ưu tiên `detail` của backend (ví dụ thông báo trùng lịch) cho thân thiện hơn.
  String _messageFor(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map && data['detail'] is String && (data['detail'] as String).trim().isNotEmpty) {
      return (data['detail'] as String).trim();
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Thời gian kết nối quá lâu. Thầy cô vui lòng kiểm tra đường truyền mạng và thử lại.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.';
    }
    return fallback;
  }
}
