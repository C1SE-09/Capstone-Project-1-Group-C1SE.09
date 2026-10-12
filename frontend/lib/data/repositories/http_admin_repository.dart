// frontend/lib/data/repositories/http_admin_repository.dart
// =========================================================
// Repository kết nối API /api/admin để quản lý:
// - Lớp học (Classes)
// - Giáo viên (Teachers)
// - Phụ huynh (Parents)
// - Học sinh (Children)
// - Lịch sinh hoạt (Schedules)

import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:dio/dio.dart';

class AdminClassDto {
  final String id;
  final String name;
  final String gradeLabel;
  final String roomNumber;

  AdminClassDto({
    required this.id,
    required this.name,
    required this.gradeLabel,
    required this.roomNumber,
  });

  factory AdminClassDto.fromJson(Map<String, dynamic> json) => AdminClassDto(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        gradeLabel: json['grade_label'] as String? ?? '',
        roomNumber: json['room_number'] as String? ?? '',
      );
}

class AdminTeacherDto {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? classId;
  final List<String> classIds;
  final String className;
  final String status;

  AdminTeacherDto({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.classId,
    required this.classIds,
    required this.className,
    required this.status,
  });

  factory AdminTeacherDto.fromJson(Map<String, dynamic> json) {
    final rawClassIds = json['class_ids'] as List? ?? [];
    final classIds = rawClassIds.map((e) => e.toString()).toList();
    if (classIds.isEmpty && json['class_id'] != null) {
      classIds.add(json['class_id'].toString());
    }
    return AdminTeacherDto(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      classId: json['class_id'] as String?,
      classIds: classIds,
      className: json['class_name'] as String? ?? 'Chưa phân lớp',
      status: json['status'] as String? ?? 'active',
    );
  }
}

class AdminParentDto {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String status;
  final String childrenSummary;
  final String? childId;
  final List<String> childIds;

  AdminParentDto({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.status,
    required this.childrenSummary,
    this.childId,
    required this.childIds,
  });

  factory AdminParentDto.fromJson(Map<String, dynamic> json) {
    final rawChildIds = json['child_ids'] as List? ?? [];
    final childIds = rawChildIds.map((e) => e.toString()).toList();
    if (childIds.isEmpty && json['child_id'] != null) {
      childIds.add(json['child_id'].toString());
    }
    return AdminParentDto(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      childrenSummary: json['children_summary'] as String? ?? '',
      childId: json['child_id'] as String?,
      childIds: childIds,
    );
  }
}

class AdminChildDto {
  final String id;
  final String fullName;
  final String nickname;
  final String? classId;
  final String className;
  final String? parentId;
  final String? parentName;
  final String? parentPhone;
  final String? dateOfBirth;
  final String note;
  final String status;

  AdminChildDto({
    required this.id,
    required this.fullName,
    required this.nickname,
    this.classId,
    required this.className,
    this.parentId,
    this.parentName,
    this.parentPhone,
    this.dateOfBirth,
    required this.note,
    required this.status,
  });

  factory AdminChildDto.fromJson(Map<String, dynamic> json) => AdminChildDto(
        id: json['id'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
        classId: json['class_id'] as String?,
        className: json['class_name'] as String? ?? 'Chưa xếp lớp',
        parentId: json['parent_id'] as String?,
        parentName: json['parent_name'] as String?,
        parentPhone: json['parent_phone'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        note: json['note'] as String? ?? '',
        status: json['status'] as String? ?? 'enrolled',
      );
}

class AdminTimeSlotDto {
  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final int orderIndex;

  AdminTimeSlotDto({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.orderIndex,
  });

  factory AdminTimeSlotDto.fromJson(Map<String, dynamic> json) => AdminTimeSlotDto(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        startTime: json['start_time'] as String? ?? '',
        endTime: json['end_time'] as String? ?? '',
        orderIndex: json['order_index'] as int? ?? 0,
      );
}

class AdminScheduleDto {
  final String id;
  final String activityName;
  final String content;
  final String roomName;
  final String timeRange;
  final String? slotId;
  final String? startTime;
  final String? endTime;
  final int? dayOfWeek;
  final bool isActive;

  AdminScheduleDto({
    required this.id,
    required this.activityName,
    required this.content,
    required this.roomName,
    required this.timeRange,
    this.slotId,
    this.startTime,
    this.endTime,
    this.dayOfWeek,
    required this.isActive,
  });

  factory AdminScheduleDto.fromJson(Map<String, dynamic> json) => AdminScheduleDto(
        id: json['id'] as String? ?? '',
        activityName: json['activity_name'] as String? ?? '',
        content: json['content'] as String? ?? '',
        roomName: json['room_name'] as String? ?? 'Phòng học',
        timeRange: json['time_range'] as String? ?? '',
        slotId: json['slot_id'] as String?,
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
        dayOfWeek: json['day_of_week'] as int?,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class HttpAdminRepository {
  HttpAdminRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? kApiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;

  // 0. Classes
  Future<List<AdminClassDto>> getClasses() async {
    final response = await _dio.get('/api/admin/classes');
    final list = response.data as List? ?? [];
    return list.map((e) => AdminClassDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  // 1. Teachers
  Future<List<AdminTeacherDto>> getTeachers() async {
    final response = await _dio.get('/api/admin/teachers');
    final list = response.data as List? ?? [];
    return list.map((e) => AdminTeacherDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> createTeacher({
    required String fullName,
    required String email,
    required String phone,
    String? classId,
    List<String>? classIds,
  }) async {
    await _dio.post('/api/admin/teachers', data: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'class_id': classId,
      'class_ids': classIds,
    });
  }

  Future<void> updateTeacher(
    String id, {
    required String fullName,
    required String email,
    required String phone,
    String? classId,
    List<String>? classIds,
  }) async {
    await _dio.put('/api/admin/teachers/$id', data: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'class_id': classId,
      'class_ids': classIds,
    });
  }

  Future<void> deleteTeacher(String id) async {
    await _dio.delete('/api/admin/teachers/$id');
  }

  // 2. Parents
  Future<List<AdminParentDto>> getParents() async {
    final response = await _dio.get('/api/admin/parents');
    final list = response.data as List? ?? [];
    return list.map((e) => AdminParentDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> createParent({
    required String fullName,
    required String phone,
    String? email,
    String? childId,
    List<String>? childIds,
  }) async {
    await _dio.post('/api/admin/parents', data: {
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'child_id': childId,
      'child_ids': childIds,
    });
  }

  Future<void> updateParent(
    String id, {
    required String fullName,
    required String phone,
    String? email,
    String? childId,
    List<String>? childIds,
  }) async {
    await _dio.put('/api/admin/parents/$id', data: {
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'child_id': childId,
      'child_ids': childIds,
    });
  }

  Future<void> deleteParent(String id) async {
    await _dio.delete('/api/admin/parents/$id');
  }

  // 3. Children
  Future<List<AdminChildDto>> getChildren() async {
    final response = await _dio.get('/api/admin/children');
    final list = response.data as List? ?? [];
    return list.map((e) => AdminChildDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> createChild({
    required String fullName,
    String? nickname,
    String? classId,
    String? parentId,
    String? note,
  }) async {
    await _dio.post('/api/admin/children', data: {
      'full_name': fullName,
      'nickname': nickname,
      'class_id': classId,
      'parent_id': parentId,
      'medical_allergies': note,
    });
  }

  Future<void> updateChild(
    String id, {
    required String fullName,
    String? nickname,
    String? classId,
    String? parentId,
    String? note,
  }) async {
    await _dio.put('/api/admin/children/$id', data: {
      'full_name': fullName,
      'nickname': nickname,
      'class_id': classId,
      'parent_id': parentId,
      'medical_allergies': note,
    });
  }

  Future<void> deleteChild(String id) async {
    await _dio.delete('/api/admin/children/$id');
  }

  // 4. Schedules & TimeSlots
  Future<List<AdminTimeSlotDto>> getTimeSlots() async {
    final response = await _dio.get('/api/admin/time-slots');
    final list = response.data as List? ?? [];
    return list.map((e) => AdminTimeSlotDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<AdminScheduleDto>> getSchedules({int? dayOfWeek}) async {
    final response = await _dio.get(
      '/api/admin/schedules',
      queryParameters: dayOfWeek != null ? {'day_of_week': dayOfWeek} : null,
    );
    final list = response.data as List? ?? [];
    return list.map((e) => AdminScheduleDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> createSchedule({
    required String activityName,
    String? content,
    String? roomName,
    String? timeRange,
    String? slotId,
    String? startTime,
    String? endTime,
    int? dayOfWeek,
  }) async {
    await _dio.post('/api/admin/schedules', data: {
      'activity_name': activityName,
      'content': content,
      'room_name': roomName,
      'time_range': timeRange,
      'slot_id': slotId,
      'start_time': startTime,
      'end_time': endTime,
      'day_of_week': dayOfWeek ?? 2,
    });
  }

  Future<void> updateSchedule(
    String id, {
    required String activityName,
    String? content,
    String? roomName,
    String? slotId,
    String? startTime,
    String? endTime,
    int? dayOfWeek,
  }) async {
    await _dio.put('/api/admin/schedules/$id', data: {
      'activity_name': activityName,
      'content': content,
      'room_name': roomName,
      'slot_id': slotId,
      'start_time': startTime,
      'end_time': endTime,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
    });
  }

  Future<void> deleteSchedule(String id) async {
    await _dio.delete('/api/admin/schedules/$id');
  }
}
