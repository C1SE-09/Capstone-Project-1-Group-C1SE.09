// frontend/lib/domain/entities/daily_report.dart
// =========================================================
// Entity DailyReport — MIRROR backend app/models/report.py
// (model DailyReport).
//
// Dùng cho cả Teacher (xem danh sách báo cáo lớp) và
// Parent (xem báo cáo của con mình).

import 'package:adark_frontend/domain/entities/base_entity.dart';
import 'package:adark_frontend/domain/entities/report_status.dart';

class DailyReport extends BaseEntity {
  const DailyReport({
    required this.dailyReportId,
    required this.reportDate,
    required this.status,
    this.teacherId,
    this.childId,
    this.voiceRecordId,
    this.summaryText,
    this.publishedAt,
  });

  final String dailyReportId;
  final String? teacherId;
  final String? childId;
  final String? voiceRecordId;
  final DateTime reportDate;
  final String? summaryText;
  final ReportStatus status;
  final DateTime? publishedAt;

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    return DailyReport(
      dailyReportId: json['daily_report_id'] as String,
      teacherId: json['teacher_id'] as String?,
      childId: json['child_id'] as String?,
      voiceRecordId: json['voice_record_id'] as String?,
      reportDate: DateTime.parse(json['report_date'] as String),
      summaryText: json['summary_text'] as String?,
      status: ReportStatus.fromJson(json['status'] as String?),
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
    );
  }
}