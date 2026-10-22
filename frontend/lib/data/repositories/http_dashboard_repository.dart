// frontend/lib/data/repositories/http_dashboard_repository.dart
// =========================================================
// Triển khai DashboardRepository bằng API THẬT (endpoint
// dashboard.py + class_data.py). Tất cả method đều gọi Dio.
//
// MVP note: chưa có login thật nên teacher_id / parent_id được
// cố định theo seed.sql (backend/seed.sql). Khi có Firebase auth,
// chỉ cần thay 2 hằng số này bằng id từ phiên đăng nhập — View &
// entity không đổi.

import 'package:adark_frontend/core/utils/api_config.dart';

import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/domain/entities/activity/activity_item.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/domain/entities/class/class_report_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/domain/repositories/dashboard_repository.dart';
import 'package:dio/dio.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';

class HttpDashboardRepository implements DashboardRepository {
  HttpDashboardRepository({
    ClassDataRepository? classDataRepository,
    Dio? dio,
    String? baseUrl,
    String? teacherId,
    String? parentId,
  })  : teacherId = teacherId ??
            AuthRepository.currentUser?.teacherId ??
            'bbbbbbbb-0000-0000-0000-000000000001',
        parentId = parentId ??
            AuthRepository.currentUser?.parentId ??
            'cccccccc-0000-0000-0000-000000000001',
        _classData =
            classDataRepository ?? HttpClassDataRepository(dio: dio, baseUrl: baseUrl),
        _dio = dio ??
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
  }

  final ClassDataRepository _classData;
  final Dio _dio;

  /// Id giáo viên hiện tại (seed: Cô Nguyễn Thị Mai — Lớp Mầm A).
  final String teacherId;

  /// Id phụ huynh hiện tại (seed: Trần Văn Tuấn — bé Bảo Bảo).
  final String parentId;

  // ══════════════════════════════════════════════════════════
  // Teacher
  // ══════════════════════════════════════════════════════════

  @override
  Future<Teacher> getCurrentTeacher() async {
    final data = await _get('/api/teacher/$teacherId');
    return Teacher.fromJson(data);
  }

  @override
  Future<List<ClassReportOverview>> getTeacherClasses() async {
    final data = await _get('/api/teacher/$teacherId/classes');
    final raw = data['classes'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final m = Map<String, dynamic>.from(item);
          final classInfo = ClassInfo.fromJson(
            _asMap(m['class_info']),
          );
          return ClassReportOverview(
            classInfo: classInfo,
            teacherName: m['teacher_name'] as String? ?? '',
            totalChildren: m['total_children'] as int? ?? 0,
            completedCount: m['completed_count'] as int? ?? 0,
            draftCount: m['draft_count'] as int? ?? 0,
            missingCount: m['missing_count'] as int? ?? 0,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<ClassDashboardSummary> getClassDashboard(
    String classId,
    DateTime date,
  ) async {
    final data = await _get(
      '/api/class/$classId/dashboard',
      query: {'date': _isoDate(date)},
    );
    return _parseDashboard(data);
  }

  @override
  Future<List<ActivityItem>> getRecentActivities(
    String classId, {
    int limit = 10,
  }) async {
    final data = await _get(
      '/api/class/$classId/activities',
      query: {'limit': limit.toString()},
    );
    final raw = data['activities'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => ActivityItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<List<Child>> getClassChildren(String classId) {
    return _classData.getClassChildren(classId);
  }

  // ══════════════════════════════════════════════════════════
  // Parent
  // ══════════════════════════════════════════════════════════

  @override
  Future<Parent> getCurrentParent() async {
    final data = await _get('/api/parent/$parentId');
    return Parent.fromJson(data);
  }

  @override
  Future<ChildOverview> getPrimaryChildOverview(String parentId) async {
    final data = await _get('/api/parent/$parentId/child');
    return ChildOverview(
      child: Child.fromJson(_asMap(data['child'])),
      className: data['class_name'] as String? ?? '',
      teacherName: data['teacher_name'] as String? ?? '',
      teacherId: data['teacher_id'] as String?,
      teacherPhone: data['teacher_phone'] as String?,
      roomNumber: data['room_number'] as String?,
    );
  }

  @override
  Future<void> updateMyPhone(String parentId, String phone) async {
    await updateParentProfile(parentId, phone: phone);
  }

  @override
  Future<void> updateParentProfile(
    String parentId, {
    String? phone,
    String? email,
    String? relationship,
  }) async {
    final payload = <String, dynamic>{
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (relationship != null) 'relationship': relationship,
    };
    await _put('/api/parent/$parentId', data: payload);
  }

  @override
  Future<Child> updateChildInfo({
    required String parentId,
    required String childId,
    String? fullName,
    String? nickname,
    DateTime? dateOfBirth,
    String? gender,
    String? medicalAllergies,
  }) async {
    final payload = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (nickname != null) 'nickname': nickname,
      if (dateOfBirth != null) 'date_of_birth': _isoDate(dateOfBirth),
      if (gender != null) 'gender': gender,
      if (medicalAllergies != null) 'medical_allergies': medicalAllergies,
    };
    final data = await _put('/api/parent/$parentId/child/$childId', data: payload);
    return Child.fromJson(_asMap(data['child']));
  }

  @override
  Future<Child> getChildHealthProfile(String childId) async {
    final data = await _get('/api/children/$childId/health-profile');
    return Child.fromJson(data);
  }

  @override
  Future<Child> updateChildHealthProfile({
    required String childId,
    required String allergyStatus,
    String? medicalAllergies,
    String? careNotes,
    required int expectedVersion,
  }) async {
    final data = await _patch(
      '/api/children/$childId/health-profile',
      data: {
        'allergy_status': allergyStatus,
        'medical_allergies': medicalAllergies,
        'care_notes': careNotes,
        'expected_version': expectedVersion,
      },
    );
    return Child.fromJson(data);
  }

  @override
  Future<DailyReport?> getTodayReport(
    String childId,
    DateTime date, {
    bool includeDraft = true,
  }) async {
    final data = await _get(
      '/api/child/$childId/reports',
      query: {
        'date': _isoDate(date),
        'limit': '7',
        'include_draft': includeDraft.toString(),
      },
    );
    final raw = data['today_report'];
    if (raw == null) return null;
    return DailyReport.fromJson(_asMap(raw));
  }

  @override
  Future<List<DailyReport>> getRecentReports(
    String childId, {
    int limit = 7,
    bool includeDraft = true,
  }) async {
    final data = await _get(
      '/api/child/$childId/reports',
      query: {
        'limit': limit.toString(),
        'include_draft': includeDraft.toString(),
      },
    );
    final list = <DailyReport>[];
    final seen = <String>{};
    if (data['today_report'] is Map) {
      final rep = DailyReport.fromJson(_asMap(data['today_report']));
      if (includeDraft || rep.status != ReportStatus.draft) {
        if (rep.dailyReportId.isNotEmpty) seen.add(rep.dailyReportId);
        list.add(rep);
      }
    }
    final raw = data['recent_reports'];
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final rep = DailyReport.fromJson(Map<String, dynamic>.from(item));
        if (rep.dailyReportId.isEmpty || seen.add(rep.dailyReportId)) {
          list.add(rep);
        }
      }
    }
    return list;
  }

  @override
  Future<DailyReport> markReportAsRead(String reportId) async {
    final data = await _post('/api/reports/$reportId/read');
    return DailyReport.fromJson(_asMap(data));
  }

  // ══════════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════════

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  ClassDashboardSummary _parseDashboard(Map<String, dynamic> data) {
    final classInfo = ClassInfo.fromJson(_asMap(data['class_info']));
    final pendingRaw = data['pending_children'];
    final pending = <ChildReportItem>[];
    if (pendingRaw is List) {
      for (final item in pendingRaw.whereType<Map>()) {
        final m = Map<String, dynamic>.from(item);
        final child = Child.fromJson(_asMap(m['child']));
        final statusRaw = m['status'] as String?;
        pending.add(
          ChildReportItem(
            child: child,
            status: switch (statusRaw) {
              null => null,
              'draft' => ReportStatus.draft,
              'published' || 'sent' => ReportStatus.published,
              'read' => ReportStatus.read,
              _ => null,
            },
          ),
        );
      }
    }
    pending.sort(_comparePendingChildrenByStatus);

    return ClassDashboardSummary(
      classInfo: classInfo,
      teacherName: data['teacher_name'] as String? ?? '',
      totalChildren: data['total_children'] as int? ?? 0,
      completedCount: data['completed_count'] as int? ?? 0,
      draftCount: data['draft_count'] as int? ?? 0,
      missingCount: data['missing_count'] as int? ?? 0,
      pendingChildren: pending,
    );
  }

  int _comparePendingChildrenByStatus(ChildReportItem a, ChildReportItem b) {
    final rankA = _statusRank(a.status);
    final rankB = _statusRank(b.status);
    if (rankA != rankB) return rankA.compareTo(rankB);
    return a.child.fullName.toLowerCase().compareTo(b.child.fullName.toLowerCase());
  }

  int _statusRank(ReportStatus? status) => switch (status) {
        null => 0, // Chưa báo cáo
        ReportStatus.draft => 1, // Bản nháp
        ReportStatus.published => 2, // Đã gửi
        ReportStatus.read => 3, // Đã đọc
        ReportStatus.archived => 4, // Đã lưu trữ
      };

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _extractErrorMessage(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return fallback;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: query);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw ClassDataException(
        _extractErrorMessage(error, 'Không thể tải dữ liệu. Vui lòng kiểm tra lại mạng hoặc thử lại sau.'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    dynamic data,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw ClassDataException(
        _extractErrorMessage(error, 'Không thể gửi dữ liệu. Vui lòng kiểm tra lại mạng hoặc thử lại sau.'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> _put(
    String path, {
    dynamic data,
  }) async {
    try {
      final response = await _dio.put(path, data: data);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw ClassDataException(
        _extractErrorMessage(error, 'Không thể lưu dữ liệu. Vui lòng kiểm tra lại mạng hoặc thử lại sau.'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> _patch(
    String path, {
    dynamic data,
  }) async {
    try {
      final response = await _dio.patch(path, data: data);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw ClassDataException(
        error.message ?? 'Không thể lưu dữ liệu.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
