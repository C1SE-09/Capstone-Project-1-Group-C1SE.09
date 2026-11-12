// frontend/lib/domain/entities/bug_report/bug_report_attachment.dart
// =========================================================
// Entity BugReportAttachment — MIRROR backend
// app/models/bug_report.py (BugReportAttachment) +
// app/schemas/bug_report.py (BugReportAttachmentOut).
//
// Một file ảnh / log được đính kèm vào bug report.
// File thật nằm trên MinIO, frontend chỉ giữ URL.

import 'package:adark_frontend/domain/entities/base_entity.dart';

class BugReportAttachment extends BaseEntity {
  const BugReportAttachment({
    required this.attachmentId,
    required this.fileUrl,
    required this.fileName,
    this.fileSize,
    this.mimeType,
    this.description,
    this.createdAt,
  });

  final String attachmentId;
  final String fileUrl;
  final String fileName;
  final int? fileSize;
  final String? mimeType;
  final String? description;
  final DateTime? createdAt;

  factory BugReportAttachment.fromJson(Map<String, dynamic> json) {
    return BugReportAttachment(
      attachmentId: json['attachment_id'] as String,
      fileUrl: json['file_url'] as String,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
