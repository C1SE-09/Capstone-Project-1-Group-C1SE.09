// frontend/lib/domain/repositories/dashboard_repository.dart
// =========================================================
// INTERFACE (hợp đồng) cho toàn bộ data của màn Tổng quan +
// màn Phụ huynh.
//
// View/Controller chỉ phụ thuộc vào interface này.
// Hiện tại: HttpDashboardRepository — gọi API FastAPI thật.
// Để test: truyền implementation khác vào constructor của Controller.

import 'package:adark_frontend/domain/entities/activity/activity_item.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/class/class_report_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';

abstract class DashboardRepository {
  // ──────────────────────────────────────────────────────────
  // Teacher
  // ──────────────────────────────────────────────────────────

  /// Thông tin giáo viên đang đăng nhập.
  Future<Teacher> getCurrentTeacher();

  /// Danh sách các lớp giáo viên đang phụ trách.
  Future<List<ClassReportOverview>> getTeacherClasses();

  /// Tổng hợp báo cáo của lớp giáo viên quản lý trong [date].
  Future<ClassDashboardSummary> getClassDashboard(String classId, DateTime date);

  /// Các hoạt động gần đây của lớp (timeline) — mới nhất trước.
  Future<List<ActivityItem>> getRecentActivities(String classId, {int limit = 10});

  /// Danh sách trẻ trong lớp — dùng cho màn "Ghi nhận hoạt động".
  Future<List<Child>> getClassChildren(String classId);

  // ──────────────────────────────────────────────────────────
  // Parent
  // ──────────────────────────────────────────────────────────

  /// Thông tin phụ huynh đang đăng nhập.
  Future<Parent> getCurrentParent();

  /// Đứa con (duy nhất trong MVP) kèm lớp + giáo viên — cho card con.
  Future<ChildOverview> getPrimaryChildOverview(String parentId);

  /// Phụ huynh tự cập nhật SĐT của mình — PUT /api/parent/{parentId}.
  Future<void> updateMyPhone(String parentId, String phone);

  /// Hồ sơ sức khỏe dài hạn của bé — GET /api/children/{childId}/health-profile.
  Future<Child> getChildHealthProfile(String childId);

  /// Lưu hồ sơ sức khỏe — PATCH, kèm version để phát hiện ghi đè.
  Future<Child> updateChildHealthProfile({
    required String childId,
    required String allergyStatus,
    String? medicalAllergies,
    String? careNotes,
    required int expectedVersion,
  });

  /// Phụ huynh tự cập nhật thông tin hồ sơ (SĐT, Email, Quan hệ) — PUT /api/parent/{parentId}.
  Future<void> updateParentProfile(
    String parentId, {
    String? phone,
    String? email,
    String? relationship,
  });

  /// Phụ huynh cập nhật thông tin con — PUT /api/parent/{parentId}/child/{childId}.
  Future<Child> updateChildInfo({
    required String parentId,
    required String childId,
    String? fullName,
    String? nickname,
    DateTime? dateOfBirth,
    String? gender,
    String? medicalAllergies,
  });

  /// Báo cáo hôm nay của trẻ (null nếu chưa có) — dùng cho banner.
  Future<DailyReport?> getTodayReport(
    String childId,
    DateTime date, {
    bool includeDraft = true,
  });

  /// Danh sách báo cáo gần đây (mới nhất trước).
  Future<List<DailyReport>> getRecentReports(
    String childId, {
    int limit = 7,
    bool includeDraft = true,
  });

  /// Đánh dấu báo cáo ngày đã được phụ huynh đọc.
  Future<DailyReport> markReportAsRead(String reportId);
}