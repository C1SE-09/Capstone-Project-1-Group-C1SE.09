// frontend/lib/domain/entities/bug_report/bug_report.dart
// =========================================================
// Entity BugReport + BugReportDetail — MIRROR backend
// app/schemas/bug_report.py (BugReportOut + BugReportDetail).
//
// Hai class tách riêng vì backend trả 2 shape khác nhau:
//   - GET /me, /api/bug-reports        → BugReportOut (không có attachment, history)
//   - GET /me/{id}, /api/bug-reports/{id} → BugReportDetail (full)
//
// Pattern mirror domain/entities/report/daily_report.dart (extend BaseEntity).

import 'package:adark_frontend/domain/entities/base_entity.dart';
import 'package:adark_frontend/domain/entities/bug_report/bug_report_attachment.dart';
import 'package:adark_frontend/domain/entities/bug_report/bug_report_history.dart';
import 'package:adark_frontend/domain/entities/bug_report/enums.dart';

/// Thông tin rút gọn của user (chỉ 3 field) trong response bug report.
class BugReportUser {
  const BugReportUser({
    required this.userId,
    required this.username,
    required this.role,
  });

  final String userId;
  final String username;
  final String role;

  String get roleLabel => switch (role.toLowerCase()) {
        'teacher' => 'Giáo viên',
        'parent' => 'Phụ huynh',
        'admin' => 'Quản trị viên',
        _ => role,
      };

  factory BugReportUser.fromJson(Map<String, dynamic> json) => BugReportUser(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        role: json['role'] as String,
      );
}

/// Thông tin rút gọn của teacher (chỉ 3 field) khi admin gán xử lý.
class BugReportTeacher {
  const BugReportTeacher({
    required this.teacherId,
    required this.fullName,
    required this.email,
  });

  final String teacherId;
  final String fullName;
  final String email;

  factory BugReportTeacher.fromJson(Map<String, dynamic> json) =>
      BugReportTeacher(
        teacherId: json['teacher_id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
      );
}

// ═════════════════════════════════════════════════════════════════════
// BugReport — lightweight (dùng cho list)
// ═════════════════════════════════════════════════════════════════════

class BugReport extends BaseEntity {
  const BugReport({
    required this.bugReportId,
    required this.user,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    required this.status,
    required this.attachmentCount,
    required this.createdAt,
    required this.updatedAt,
    this.teacher,
    this.appVersion,
    this.buildNumber,
    this.osVersion,
    this.deviceModel,
    this.networkType,
    this.resolvedAt,
    this.closedAt,
  });

  final String bugReportId;
  final BugReportUser user;
  final BugReportTeacher? teacher;
  final String title;
  final String description;
  final BugCategory category;
  final BugSeverity severity;
  final BugStatus status;
  final String? appVersion;
  final String? buildNumber;
  final String? osVersion;
  final String? deviceModel;
  final String? networkType;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final int attachmentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True nếu status hiện tại là open (mới gửi, chưa ai xem).
  bool get isOpen => status == BugStatus.open;

  /// True nếu report đã open > 7 ngày mà chưa có ai xử lý (dùng cho badge SLA).
  bool get isStale =>
      status == BugStatus.open &&
      DateTime.now().difference(createdAt).inDays > 7;

  /// True nếu report đã có teacher được gán.
  bool get hasAssignee => teacher != null;

  factory BugReport.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    final teacherRaw = json['teacher'];
    return BugReport(
      bugReportId: json['bug_report_id'] as String,
      user: BugReportUser.fromJson(
        userRaw is Map ? Map<String, dynamic>.from(userRaw) : const {},
      ),
      teacher: teacherRaw is Map
          ? BugReportTeacher.fromJson(Map<String, dynamic>.from(teacherRaw))
          : null,
      title: json['title'] as String,
      description: json['description'] as String,
      category: BugCategory.fromJson(json['category'] as String?),
      severity: BugSeverity.fromJson(json['severity'] as String?),
      status: BugStatus.fromJson(json['status'] as String?),
      appVersion: json['app_version'] as String?,
      buildNumber: json['build_number'] as String?,
      osVersion: json['os_version'] as String?,
      deviceModel: json['device_model'] as String?,
      networkType: json['network_type'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'] as String)
          : null,
      attachmentCount: json['attachment_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// BugReportDetail — full (dùng cho detail screen)
// Bao gồm attachments + history (audit trail)
// ═════════════════════════════════════════════════════════════════════

class BugReportDetail extends BugReport {
  const BugReportDetail({
    required super.bugReportId,
    required super.user,
    required super.title,
    required super.description,
    required super.category,
    required super.severity,
    required super.status,
    required super.attachmentCount,
    required super.createdAt,
    required super.updatedAt,
    super.teacher,
    super.appVersion,
    super.buildNumber,
    super.osVersion,
    super.deviceModel,
    super.networkType,
    super.resolvedAt,
    super.closedAt,
    this.attachments = const [],
    this.history = const [],
  });

  final List<BugReportAttachment> attachments;
  final List<BugReportHistory> history;

  /// Helper: lấy history đã sort theo thời gian tăng dần (cũ → mới).
  List<BugReportHistory> get historyAsc {
    final copy = [...history];
    copy.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return copy;
  }

  factory BugReportDetail.fromJson(Map<String, dynamic> json) {
    final base = BugReport.fromJson(json);
    final attachmentsRaw = json['attachments'];
    final historyRaw = json['history'];
    return BugReportDetail(
      bugReportId: base.bugReportId,
      user: base.user,
      teacher: base.teacher,
      title: base.title,
      description: base.description,
      category: base.category,
      severity: base.severity,
      status: base.status,
      appVersion: base.appVersion,
      buildNumber: base.buildNumber,
      osVersion: base.osVersion,
      deviceModel: base.deviceModel,
      networkType: base.networkType,
      resolvedAt: base.resolvedAt,
      closedAt: base.closedAt,
      attachmentCount: base.attachmentCount,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      attachments: attachmentsRaw is List
          ? attachmentsRaw
              .whereType<Map>()
              .map((e) => BugReportAttachment.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList(growable: false)
          : const [],
      history: historyRaw is List
          ? historyRaw
              .whereType<Map>()
              .map((e) => BugReportHistory.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList(growable: false)
          : const [],
    );
  }
}
