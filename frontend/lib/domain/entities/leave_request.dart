// frontend/lib/domain/entities/leave_request.dart
// ===============================================
// Entity biểu diễn đơn xin nghỉ học của học sinh.

enum LeaveStatus {
  pending,
  approved,
  rejected,
}

enum LeaveRequestType { absence, lateArrival }

class LeaveRequestEntity {
  const LeaveRequestEntity({
    required this.requestId,
    required this.childId,
    required this.parentId,
    required this.classId,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.attachmentUrl,
    this.rejectReason,
    this.reviewedBy,
    this.reviewedAt,
    this.childName,
    this.childAvatarUrl,
    this.parentName,
    this.reviewerName,
    this.requestType = LeaveRequestType.absence,
    this.expectedArrivalTime,
    this.mealWarningAcknowledged = false,
  });

  final String requestId;
  final String childId;
  final String parentId;
  final String classId;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? rejectReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? childName;
  final String? childAvatarUrl;
  final String? parentName;
  final String? reviewerName;
  final LeaveRequestType requestType;
  final String? expectedArrivalTime;
  final bool mealWarningAcknowledged;

  int get totalDays {
    final diff = toDate.difference(fromDate).inDays;
    return diff >= 0 ? diff + 1 : 1;
  }

  factory LeaveRequestEntity.fromJson(Map<String, dynamic> json) {
    LeaveStatus parseStatus(String? val) {
      switch (val?.toLowerCase()) {
        case 'approved':
          return LeaveStatus.approved;
        case 'rejected':
          return LeaveStatus.rejected;
        case 'pending':
        default:
          return LeaveStatus.pending;
      }
    }

    return LeaveRequestEntity(
      requestId: json['request_id'] as String? ?? '',
      childId: json['child_id'] as String? ?? '',
      parentId: json['parent_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      fromDate: DateTime.tryParse(json['from_date'] as String? ?? '') ??
          DateTime.now(),
      toDate:
          DateTime.tryParse(json['to_date'] as String? ?? '') ?? DateTime.now(),
      reason: json['reason'] as String? ?? '',
      status: parseStatus(json['status'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      attachmentUrl: json['attachment_url'] as String?,
      rejectReason: json['reject_reason'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      childName: json['child_name'] as String?,
      childAvatarUrl: json['child_avatar_url'] as String?,
      parentName: json['parent_name'] as String?,
      reviewerName: json['reviewer_name'] as String?,
      requestType: json['request_type'] == 'late_arrival'
          ? LeaveRequestType.lateArrival
          : LeaveRequestType.absence,
      expectedArrivalTime: json['expected_arrival_time'] as String?,
      mealWarningAcknowledged:
          json['meal_warning_acknowledged'] as bool? ?? false,
    );
  }
}
