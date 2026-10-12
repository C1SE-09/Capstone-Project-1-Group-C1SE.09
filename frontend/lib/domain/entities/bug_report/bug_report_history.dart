// frontend/lib/domain/entities/bug_report/bug_report_history.dart
// =========================================================
// Entity BugReportHistory — MIRROR backend
// app/models/bug_report.py (BugReportHistory) +
// app/schemas/bug_report.py (BugReportHistoryOut).
//
// Mỗi entry là 1 lần thay đổi status/assignee (audit trail).
// Timeline trong màn chi tiết sẽ render list này theo thứ tự thời gian.

import 'package:adark_frontend/domain/entities/base_entity.dart';
import 'package:adark_frontend/domain/entities/bug_report/enums.dart';

/// User rút gọn (chỉ 3 field) mà backend trả về trong history.changed_by.
class HistoryChangedBy {
  const HistoryChangedBy({
    required this.userId,
    required this.username,
    required this.role,
  });

  final String userId;
  final String username;
  final String role; // 'teacher' | 'parent' | 'admin'

  String get roleLabel => switch (role.toLowerCase()) {
        'teacher' => 'Giáo viên',
        'parent' => 'Phụ huynh',
        'admin' => 'Quản trị viên',
        _ => role,
      };

  factory HistoryChangedBy.fromJson(Map<String, dynamic> json) {
    return HistoryChangedBy(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
    );
  }
}

class BugReportHistory extends BaseEntity {
  const BugReportHistory({
    required this.historyId,
    required this.createdAt,
    this.changedBy,
    this.oldStatus,
    this.newStatus,
    this.oldTeacherId,
    this.newTeacherId,
    this.comment,
  });

  final String historyId;
  final HistoryChangedBy? changedBy;
  final BugStatus? oldStatus;
  final BugStatus? newStatus;
  final String? oldTeacherId;
  final String? newTeacherId;
  final String? comment;
  final DateTime createdAt;

  /// True nếu entry này chỉ ghi nhận "report vừa được tạo".
  bool get isCreated => oldStatus == null && newStatus == BugStatus.open;

  /// True nếu entry chỉ đổi teacher mà không đổi status.
  bool get isReassignmentOnly =>
      oldStatus == newStatus &&
      oldTeacherId != newTeacherId &&
      comment != null;

  factory BugReportHistory.fromJson(Map<String, dynamic> json) {
    final changedByRaw = json['changed_by'];
    return BugReportHistory(
      historyId: json['history_id'] as String,
      changedBy: changedByRaw is Map
          ? HistoryChangedBy.fromJson(Map<String, dynamic>.from(changedByRaw))
          : null,
      oldStatus: json['old_status'] == null
          ? null
          : BugStatus.fromJson(json['old_status'] as String?),
      newStatus: json['new_status'] == null
          ? null
          : BugStatus.fromJson(json['new_status'] as String?),
      oldTeacherId: json['old_teacher_id'] as String?,
      newTeacherId: json['new_teacher_id'] as String?,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
