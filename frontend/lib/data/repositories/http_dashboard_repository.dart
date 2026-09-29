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
import 'package:adark_frontend/domain/repositories/dashboard_repository.dart';
import 'package:dio/dio.dart';

class HttpDashboardRepository implements DashboardRepository {
  HttpDashboardRepository({
    ClassDataRepository? classDataRepository,
    Dio? dio,
    String? baseUrl,
    this.teacherId = 'bbbbbbbb-0000-0000-0000-000000000001',
    this.parentId = 'cccccccc-0000-0000-0000-000000000001',
  })  : _classData =
            classDataRepository ?? HttpClassDataRepository(dio: dio, baseUrl: baseUrl),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? kApiBaseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

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
    );
  }

  @override
  Future<DailyReport?> getTodayReport(String childId, DateTime date) async {
    final data = await _get(
      '/api/child/$childId/reports',
      query: {'date': _isoDate(date), 'limit': '7'},
    );
    final raw = data['today_report'];
    if (raw == null) return null;
    return DailyReport.fromJson(_asMap(raw));
  }

  @override
  Future<List<DailyReport>> getRecentReports(
    String childId, {
    int limit = 7,
  }) async {
    final data = await _get(
      '/api/child/$childId/reports',
      query: {'limit': limit.toString()},
    );
    final raw = data['recent_reports'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => DailyReport.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
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
        ReportStatus.archived => 3, // Đã đọc
      };

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
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
        error.message ?? 'Không thể tải dữ liệu.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}