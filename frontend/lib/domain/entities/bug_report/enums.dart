// frontend/lib/domain/entities/bug_report/enums.dart
// =========================================================
// 3 enum: BugCategory / BugSeverity / BugStatus
// MIRROR backend app/models/bug_report.py
//
// Vì JSON trả về chuỗi "ui" | "performance" | ... nên mỗi enum
// cần hàm fromJson() để parse nhanh, giống pattern của
// domain/entities/report/report_status.dart.

/// Loại lỗi mà user báo cáo.
enum BugCategory {
  ui, // Lỗi giao diện (button lệch, layout tràn, ...)
  performance, // App chậm / lag
  crash, // App bị crash / đứng / thoát
  data, // Sai dữ liệu / mất dữ liệu
  notification, // Thông báo không gửi / gửi sai
  network, // Lỗi kết nối mạng
  auth, // Lỗi đăng nhập / xác thực
  other, // Lỗi khác không thuộc category trên
  ;

  static BugCategory fromJson(String? value) {
    switch (value?.toLowerCase()) {
      case 'ui':
        return BugCategory.ui;
      case 'performance':
        return BugCategory.performance;
      case 'crash':
        return BugCategory.crash;
      case 'data':
        return BugCategory.data;
      case 'notification':
        return BugCategory.notification;
      case 'network':
        return BugCategory.network;
      case 'auth':
        return BugCategory.auth;
      case 'other':
      default:
        return BugCategory.other;
    }
  }

  String get label => switch (this) {
        BugCategory.ui => 'Giao diện',
        BugCategory.performance => 'Hiệu năng',
        BugCategory.crash => 'Crash',
        BugCategory.data => 'Dữ liệu',
        BugCategory.notification => 'Thông báo',
        BugCategory.network => 'Mạng',
        BugCategory.auth => 'Xác thực',
        BugCategory.other => 'Khác',
      };
}

/// Mức độ nghiêm trọng của bug.
enum BugSeverity {
  low, // Không ảnh hưởng nhiều
  medium, // Ảnh hưởng một phần
  high, // Ảnh hưởng lớn, cần sửa sớm
  critical, // App không thể dùng được
  ;

  static BugSeverity fromJson(String? value) {
    switch (value?.toLowerCase()) {
      case 'low':
        return BugSeverity.low;
      case 'high':
        return BugSeverity.high;
      case 'critical':
        return BugSeverity.critical;
      case 'medium':
      default:
        return BugSeverity.medium;
    }
  }

  String get label => switch (this) {
        BugSeverity.low => 'Thấp',
        BugSeverity.medium => 'Trung bình',
        BugSeverity.high => 'Cao',
        BugSeverity.critical => 'Nghiêm trọng',
      };
}

/// Vòng đời xử lý của một bug report.
enum BugStatus {
  open, // Mới gửi, chưa có admin xem
  inProgress, // Admin đang xử lý
  resolved, // Đã sửa xong, chờ user xác nhận
  closed, // User xác nhận OK / admin đóng
  wontFix, // Không sửa (backlog / duplicate / ngoài scope)
  ;

  static BugStatus fromJson(String? value) {
    switch (value?.toLowerCase()) {
      case 'in_progress':
        return BugStatus.inProgress;
      case 'resolved':
        return BugStatus.resolved;
      case 'closed':
        return BugStatus.closed;
      case 'wont_fix':
        return BugStatus.wontFix;
      case 'open':
      default:
        return BugStatus.open;
    }
  }

  String get label => switch (this) {
        BugStatus.open => 'Mới',
        BugStatus.inProgress => 'Đang xử lý',
        BugStatus.resolved => 'Đã sửa',
        BugStatus.closed => 'Đã đóng',
        BugStatus.wontFix => 'Không sửa',
      };
}
