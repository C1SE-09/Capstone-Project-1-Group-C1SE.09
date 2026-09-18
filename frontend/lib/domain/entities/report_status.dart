// frontend/lib/domain/entities/report_status.dart
// =========================================================
// Trạng thái báo cáo ngày — MIRROR enum DailyReportStatus
// ở backend (backend/app/models/report.py):
//     DRAFT / PUBLISHED / ARCHIVED
//
// Vì JSON trả về chuỗi "draft" | "published" | "archived",
// nên enum này cần hàm fromJson() để parse nhanh.

/// Trạng thái xuất bản của một [DailyReport].
enum ReportStatus {
  draft, // Bản nháp — chưa gửi cho phụ huynh
  published, // Đã gửi — phụ huynh xem được
  archived, // Đã lưu trữ — không còn hiển thị

  ;

  /// Parse chuỗi JSON → enum.
  /// Nếu gặp giá trị lạ thì mặc định coi là [draft] (an toàn).
  static ReportStatus fromJson(String? value) {
    return ReportStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ReportStatus.draft,
    );
  }

  /// Nhãn tiếng Việt hiển thị trên badge.
  String get label => switch (this) {
        ReportStatus.draft => 'Bản nháp',
        ReportStatus.published => 'Đã gửi',
        ReportStatus.archived => 'Đã lưu trữ',
      };
}