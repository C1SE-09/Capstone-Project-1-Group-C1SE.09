// frontend/lib/domain/repositories/bug_report_repository.dart
// =========================================================
// INTERFACE (hợp đồng) cho bug report feature.
//
// View/Controller chỉ phụ thuộc interface này.
// Hiện tại: HttpBugReportRepository (gọi FastAPI backend).
// Sau này có thể có MockBugReportRepository cho testing.
//
// 5 endpoint (MIRROR backend/app/api/endpoints/bug_reports.py):
//   1. create()                  → POST   /api/bug-reports
//   2. listAllReports() (admin)  → GET    /api/bug-reports
//   3. getReport() (admin)       → GET    /api/bug-reports/{id}
//   4. updateReport() (admin)    → PATCH  /api/bug-reports/{id}
//   5. addAttachments()          → POST   /api/bug-reports/{id}/attachments
//
// Lưu ý: User (teacher/parent) CHỈ gọi create() để gửi bug.
//        Admin gọi các endpoint còn lại để xem và xử lý.

import 'dart:typed_data';

import 'package:adark_frontend/domain/entities/bug_report/bug_report.dart';
import 'package:adark_frontend/domain/entities/bug_report/bug_report_list_response.dart';
import 'package:adark_frontend/domain/entities/bug_report/enums.dart';

/// Optional filter cho admin list endpoint.
/// Tất cả field optional; backend sẽ bỏ qua field null.
class BugReportFilter {
  const BugReportFilter({
    this.status,
    this.severity,
    this.category,
    this.userId,
    this.teacherId,
    this.userRole,
    this.search,
    this.dateFrom,
    this.dateTo,
  });

  final BugStatus? status;
  final BugSeverity? severity;
  final BugCategory? category;
  final String? userId;
  final String? teacherId;
  final String? userRole; // 'teacher' | 'parent' | 'admin'
  final String? search;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  Map<String, String> toQueryParams() {
    final map = <String, String>{};
    if (status != null) map['status'] = status!.name;
    if (severity != null) map['severity'] = severity!.name;
    if (category != null) map['category'] = category!.name;
    if (userId != null) map['user_id'] = userId!;
    if (teacherId != null) map['teacher_id'] = teacherId!;
    if (userRole != null) map['user_role'] = userRole!;
    if (search != null && search!.isNotEmpty) map['search'] = search!;
    if (dateFrom != null) map['date_from'] = dateFrom!.toIso8601String();
    if (dateTo != null) map['date_to'] = dateTo!.toIso8601String();
    return map;
  }
}

/// Payload cho create() — chỉ chứa field user nhập, metadata tự thêm.
class BugReportCreatePayload {
  const BugReportCreatePayload({
    required this.title,
    required this.description,
    this.category = BugCategory.other,
    this.severity = BugSeverity.medium,
    this.appVersion,
    this.buildNumber,
    this.osVersion,
    this.deviceModel,
    this.networkType,
    this.attachments = const [],
  });

  final String title;
  final String description;
  final BugCategory category;
  final BugSeverity severity;
  final String? appVersion;
  final String? buildNumber;
  final String? osVersion;
  final String? deviceModel;
  final String? networkType;
  final List<BugReportAttachmentDraft> attachments;
}

/// 1 file ảnh sẵn sàng upload (bytes + tên + mime).
/// Frontend đọc từ image_picker rồi chuyển thành object này.
class BugReportAttachmentDraft {
  const BugReportAttachmentDraft({
    required this.bytes,
    required this.fileName,
    this.mimeType = 'image/jpeg',
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

/// Payload cho admin update — chỉ gửi field muốn đổi.
class BugReportUpdatePayload {
  const BugReportUpdatePayload({
    this.status,
    this.teacherId,
    this.comment,
  });

  final BugStatus? status;
  final String? teacherId; // null = bỏ gán teacher
  final String? comment;
}

abstract class BugReportRepository {
  /// 1. Tạo bug report mới (form có ảnh đính kèm).
  ///    ← User (teacher/parent) gọi duy nhất method này.
  Future<BugReportDetail> create(BugReportCreatePayload payload);

  /// 2. [Admin] Danh sách tất cả report, có filter + phân trang.
  Future<BugReportListResponse> listAllReports({
    int page = 1,
    int pageSize = 20,
    BugReportFilter? filter,
    String orderBy = 'created_at_desc',
  });

  /// 3. [Admin] Chi tiết 1 report bất kỳ.
  Future<BugReportDetail> getReport(String reportId);

  /// 4. [Admin] Cập nhật status / teacher / comment.
  Future<BugReportDetail> updateReport(
    String reportId,
    BugReportUpdatePayload payload,
  );

  /// 5. Upload thêm ảnh vào report đã có (author hoặc admin).
  /// Trả về danh sách attachment mới + tổng số attachment của report.
  Future<AddAttachmentsResult> addAttachments(
    String reportId,
    List<BugReportAttachmentDraft> files,
  );
}

class AddAttachmentsResult {
  const AddAttachmentsResult({
    required this.bugReportId,
    required this.newAttachmentCount,
    required this.totalAttachments,
  });

  final String bugReportId;
  final int newAttachmentCount;
  final int totalAttachments;
}

/// Exception riêng cho bug report — UI sẽ dịch sang tiếng Việt.
class BugReportException implements Exception {
  const BugReportException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'BugReportException($statusCode): $message';
}
