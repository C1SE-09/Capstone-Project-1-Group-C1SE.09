// frontend/lib/domain/entities/report/daily_report.dart
// =========================================================
// Entity DailyReport — MIRROR backend app/models/report.py
// (model DailyReport).
//
// Dùng cho cả Teacher (xem danh sách báo cáo lớp) và
// Parent (xem báo cáo của con mình).

import 'package:adark_frontend/domain/entities/base_entity.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';

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
    this.activities = const [],
    this.eating,
    this.sleeping,
    this.health,
    this.activitiesText,
    this.mood,
  });

  final String dailyReportId;
  final String? teacherId;
  final String? childId;
  final String? voiceRecordId;
  final DateTime reportDate;
  final String? summaryText;
  final ReportStatus status;
  final DateTime? publishedAt;
  final List<Map<String, dynamic>> activities;
  final String? eating;
  final String? sleeping;
  final String? health;
  final String? activitiesText;
  final String? mood;

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final rawActivities = json['activities'];
    final activitiesList = rawActivities is List
        ? rawActivities
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    String? findDesc(String cat) {
      for (final a in activitiesList) {
        final c = a['category']?.toString().toLowerCase();
        if (c == cat) return a['description']?.toString();
      }
      return null;
    }

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
      activities: activitiesList,
      eating: json['eating'] as String? ?? findDesc('meal'),
      sleeping: json['sleeping'] as String? ?? findDesc('nap'),
      health: json['health'] as String? ?? findDesc('health'),
      activitiesText: json['activities_text'] as String? ?? findDesc('play'),
      mood: json['mood'] as String? ?? findDesc('behavior'),
    );
  }
}