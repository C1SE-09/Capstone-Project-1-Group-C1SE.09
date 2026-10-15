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
  final String? username;
  final String? classId;
  final List<String> classIds;
  final String className;
  final String status;

  AdminTeacherDto({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.username,
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
      username: json['username'] as String?,
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
  final String? username;
  final String status;
  final String childrenSummary;
  final String? childId;
  final List<String> childIds;

  AdminParentDto({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    this.username,
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
      username: json['username'] as String?,
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
    String? username,
    String? password,
    String? classId,
    List<String>? classIds,
  }) async {
    await _dio.post('/api/admin/teachers', data: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'username': username,
      'password': password,
      'class_id': classId,
      'class_ids': classIds,
    });
  }

  Future<void> updateTeacher(
    String id, {
    required String fullName,
    required String email,
    required String phone,
    String? username,
    String? password,
    String? classId,
    List<String>? classIds,
  }) async {
    await _dio.put('/api/admin/teachers/$id', data: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'username': username,
      'password': password,
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
    String? username,
    String? password,
    String? childId,
    List<String>? childIds,
  }) async {
    await _dio.post('/api/admin/parents', data: {
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'username': username,
      'password': password,
      'child_id': childId,
      'child_ids': childIds,
    });
  }

  Future<void> updateParent(
    String id, {
    required String fullName,
    required String phone,
    String? email,
    String? username,
    String? password,
    String? childId,
    List<String>? childIds,
  }) async {
    await _dio.put('/api/admin/parents/$id', data: {
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'username': username,
      'password': password,
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

  // ---------------------------------------------------------
  // Dashboard Metrics & Charts API (/api/admin/dashboard)
  // ---------------------------------------------------------

  Future<AdminOverviewStatsDto> getDashboardOverviewStats({DateTime? targetDate}) async {
    final dateStr = targetDate?.toIso8601String().substring(0, 10);
    final response = await _dio.get(
      '/api/admin/dashboard/stats',
      queryParameters: dateStr != null ? {'target_date': dateStr} : null,
    );
    return AdminOverviewStatsDto.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<AdminClassProgressDto>> getDashboardClassesProgress({DateTime? targetDate}) async {
    final dateStr = targetDate?.toIso8601String().substring(0, 10);
    final response = await _dio.get(
      '/api/admin/dashboard/classes-progress',
      queryParameters: dateStr != null ? {'target_date': dateStr} : null,
    );
    final list = response.data as List? ?? [];
    return list.map((e) => AdminClassProgressDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<AdminVoiceStatsDto> getDashboardVoiceStats() async {
    final response = await _dio.get('/api/admin/dashboard/voice-stats');
    return AdminVoiceStatsDto.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<AdminReportTrendDto>> getDashboardReportTrends({int days = 7}) async {
    final response = await _dio.get(
      '/api/admin/dashboard/report-trends',
      queryParameters: {'days': days},
    );
    final list = response.data as List? ?? [];
    return list.map((e) => AdminReportTrendDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<AdminSystemHealthDto> getDashboardSystemHealth() async {
    final response = await _dio.get('/api/admin/dashboard/system-health');
    return AdminSystemHealthDto.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}

class AdminOverviewStatsDto {
  final int totalSchools;
  final int totalClasses;
  final int totalChildren;
  final int totalTeachers;
  final int totalParents;
  final int todayReportsCount;
  final int todaySentReportsCount;
  final int todayDraftReportsCount;
  final double todayCompletionRate;
  final int totalVoiceRecords;
  final int todayVoiceRecords;

  AdminOverviewStatsDto({
    required this.totalSchools,
    required this.totalClasses,
    required this.totalChildren,
    required this.totalTeachers,
    required this.totalParents,
    required this.todayReportsCount,
    required this.todaySentReportsCount,
    required this.todayDraftReportsCount,
    required this.todayCompletionRate,
    required this.totalVoiceRecords,
    required this.todayVoiceRecords,
  });

  factory AdminOverviewStatsDto.fromJson(Map<String, dynamic> json) => AdminOverviewStatsDto(
        totalSchools: json['total_schools'] as int? ?? 0,
        totalClasses: json['total_classes'] as int? ?? 0,
        totalChildren: json['total_children'] as int? ?? 0,
        totalTeachers: json['total_teachers'] as int? ?? 0,
        totalParents: json['total_parents'] as int? ?? 0,
        todayReportsCount: json['today_reports_count'] as int? ?? 0,
        todaySentReportsCount: json['today_sent_reports_count'] as int? ?? 0,
        todayDraftReportsCount: json['today_draft_reports_count'] as int? ?? 0,
        todayCompletionRate: (json['today_completion_rate'] as num?)?.toDouble() ?? 0.0,
        totalVoiceRecords: json['total_voice_records'] as int? ?? 0,
        todayVoiceRecords: json['today_voice_records'] as int? ?? 0,
      );
}

class AdminClassProgressDto {
  final String classId;
  final String className;
  final String gradeLabel;
  final String teacherName;
  final int totalChildren;
  final int reportedChildren;
  final int pendingChildren;
  final double completionRate;

  AdminClassProgressDto({
    required this.classId,
    required this.className,
    required this.gradeLabel,
    required this.teacherName,
    required this.totalChildren,
    required this.reportedChildren,
    required this.pendingChildren,
    required this.completionRate,
  });

  factory AdminClassProgressDto.fromJson(Map<String, dynamic> json) => AdminClassProgressDto(
        classId: json['class_id'] as String? ?? '',
        className: json['class_name'] as String? ?? '',
        gradeLabel: json['grade_label'] as String? ?? '',
        teacherName: json['teacher_name'] as String? ?? 'Chưa phân công',
        totalChildren: json['total_children'] as int? ?? 0,
        reportedChildren: json['reported_children'] as int? ?? 0,
        pendingChildren: json['pending_children'] as int? ?? 0,
        completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      );
}

class AdminVoiceStatsDto {
  final int totalRecords;
  final int completedRecords;
  final int pendingRecords;
  final int failedRecords;
  final double totalDurationSeconds;

  AdminVoiceStatsDto({
    required this.totalRecords,
    required this.completedRecords,
    required this.pendingRecords,
    required this.failedRecords,
    required this.totalDurationSeconds,
  });

  factory AdminVoiceStatsDto.fromJson(Map<String, dynamic> json) => AdminVoiceStatsDto(
        totalRecords: json['total_records'] as int? ?? 0,
        completedRecords: json['completed_records'] as int? ?? 0,
        pendingRecords: json['pending_records'] as int? ?? 0,
        failedRecords: json['failed_records'] as int? ?? 0,
        totalDurationSeconds: (json['total_duration_seconds'] as num?)?.toDouble() ?? 0.0,
      );
}

class AdminReportTrendDto {
  final String reportDate;
  final int totalReports;
  final int sentReports;
  final int draftReports;

  AdminReportTrendDto({
    required this.reportDate,
    required this.totalReports,
    required this.sentReports,
    required this.draftReports,
  });

  factory AdminReportTrendDto.fromJson(Map<String, dynamic> json) => AdminReportTrendDto(
        reportDate: json['report_date'] as String? ?? '',
        totalReports: json['total_reports'] as int? ?? 0,
        sentReports: json['sent_reports'] as int? ?? 0,
        draftReports: json['draft_reports'] as int? ?? 0,
      );
}

class AdminSystemHealthDto {
  final String databaseStatus;
  final String redisStatus;
  final String apiStatus;
  final String serverTime;

  AdminSystemHealthDto({
    required this.databaseStatus,
    required this.redisStatus,
    required this.apiStatus,
    required this.serverTime,
  });

  factory AdminSystemHealthDto.fromJson(Map<String, dynamic> json) => AdminSystemHealthDto(
        databaseStatus: json['database_status'] as String? ?? 'healthy',
        redisStatus: json['redis_status'] as String? ?? 'healthy',
        apiStatus: json['api_status'] as String? ?? 'healthy',
        serverTime: json['server_time'] as String? ?? '',
      );
}
