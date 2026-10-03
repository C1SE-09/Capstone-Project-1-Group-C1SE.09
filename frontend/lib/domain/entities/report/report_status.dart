// frontend/lib/domain/entities/report/report_status.dart
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
  read, // Đã đọc — phụ huynh đã mở xem
  archived, // Đã lưu trữ — không còn hiển thị

  ;

  /// Parse chuỗi JSON → enum.
  /// Nếu gặp 'sent' hoặc 'published' đều nhận diện là [published] (đã gửi cho phụ huynh).
  static ReportStatus fromJson(String? value) {
    final lower = value?.toLowerCase();
    if (lower == 'sent' || lower == 'published') {
      return ReportStatus.published;
    }
    if (lower == 'read') {
      return ReportStatus.read;
    }
    if (lower == 'archived') {
      return ReportStatus.archived;
    }
    return ReportStatus.draft;
  }

  /// Nhãn tiếng Việt hiển thị trên badge.
  String get label => switch (this) {
        ReportStatus.draft => 'Bản nháp',
        ReportStatus.published => 'Đã gửi',
        ReportStatus.read => 'Đã đọc',
        ReportStatus.archived => 'Đã lưu trữ',
      };
}