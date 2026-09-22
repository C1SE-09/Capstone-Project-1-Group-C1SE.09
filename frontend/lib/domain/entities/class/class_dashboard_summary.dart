// frontend/lib/domain/entities/class/class_dashboard_summary.dart
// =========================================================
// Đối tượng tổng hợp cho màn "Tổng quan" của giáo viên.

import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';

/// 1 trẻ + trạng thái báo cáo hôm nay của trẻ đó (dùng ở "Cần xử lý").
class ChildReportItem {
  const ChildReportItem({
    required this.child,
    this.status, // null = chưa có báo cáo hôm nay
    this.updatedAt, // thời điểm cập nhật gần nhất (hiển thị "15:40")
  });

  final Child child;
  final ReportStatus? status;
  final DateTime? updatedAt;
}

/// Tổng hợp toàn lớp trong 1 ngày.
class ClassDashboardSummary {
  const ClassDashboardSummary({
    required this.classInfo,
    required this.teacherName,
    required this.totalChildren,
    required this.completedCount,
    required this.draftCount,
    required this.missingCount,
    required this.pendingChildren,
  });

  final ClassInfo classInfo;
  final String teacherName;
  final int totalChildren; // 20
  final int completedCount; // 15 (published - đã gửi)
  final int draftCount; // 3 (draft - bản nháp)
  final int missingCount; // 2 (chưa có)
  final List<ChildReportItem> pendingChildren; // danh sách "Cần xử lý"

  /// Tỉ lệ hoàn thành 0.0 → 1.0 (cho thanh tiến độ).
  double get ratio => totalChildren == 0 ? 0 : completedCount / totalChildren;

  /// Phần trăm hoàn thành (số nguyên) — "75%".
  int get percent => (ratio * 100).round();

  /// Số trẻ CHƯA có báo cáo hoàn chỉnh (nháp + chưa có).
  int get notCompletedCount => totalChildren - completedCount;
}
