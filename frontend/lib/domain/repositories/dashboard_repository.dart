// frontend/lib/domain/repositories/dashboard_repository.dart
// =========================================================
// INTERFACE (hợp đồng) cho toàn bộ data của màn Tổng quan +
// màn Phụ huynh.
//
// ĐÂY LÀ ĐIỂM MẤU CHỐT CỦA "API-READY":
//   - View/Controller chỉ phụ thuộc vào interface này.
//   - Bây giờ: MockDashboardRepository (data cứng).
//   - Sau này: HttpDashboardRepository (gọi API thật) — chỉ cần
//     triển khai đúng interface, View KHÔNG cần sửa.

import 'package:adark_frontend/domain/entities/activity_item.dart';
import 'package:adark_frontend/domain/entities/child_overview.dart';
import 'package:adark_frontend/domain/entities/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/daily_report.dart';
import 'package:adark_frontend/domain/entities/parent.dart';
import 'package:adark_frontend/domain/entities/teacher.dart';

abstract class DashboardRepository {
  // ──────────────────────────────────────────────────────────
  // Teacher
  // ──────────────────────────────────────────────────────────

  /// Thông tin giáo viên đang đăng nhập.
  Future<Teacher> getCurrentTeacher();

  /// Tổng hợp báo cáo của lớp giáo viên quản lý trong [date].
  Future<ClassDashboardSummary> getClassDashboard(String classId, DateTime date);

  /// Các hoạt động gần đây của lớp (timeline) — mới nhất trước.
  Future<List<ActivityItem>> getRecentActivities(String classId, {int limit = 10});

  // ──────────────────────────────────────────────────────────
  // Parent
  // ──────────────────────────────────────────────────────────

  /// Thông tin phụ huynh đang đăng nhập.
  Future<Parent> getCurrentParent();

  /// Đứa con (duy nhất trong MVP) kèm lớp + giáo viên — cho card con.
  Future<ChildOverview> getPrimaryChildOverview(String parentId);

  /// Báo cáo hôm nay của trẻ (null nếu chưa có) — dùng cho banner.
  Future<DailyReport?> getTodayReport(String childId, DateTime date);

  /// Danh sách báo cáo gần đây (mới nhất trước).
  Future<List<DailyReport>> getRecentReports(String childId, {int limit = 7});
}