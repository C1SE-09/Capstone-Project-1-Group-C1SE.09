// Adapts backend and legacy report statuses to the dashboard UI status.
import 'package:adark_frontend/domain/entities/report/report_status.dart' as legacy_status;
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;

ui.ReportStatus uiReportStatusFromBackend(String? backendStatus) =>
    switch (backendStatus?.toLowerCase()) {
      'draft' => ui.ReportStatus.draft,
      'sent' || 'published' => ui.ReportStatus.submitted,
      'read' => ui.ReportStatus.read,
      'archived' || null || '' => ui.ReportStatus.none,
      _ => ui.ReportStatus.none,
    };

ui.ReportStatus uiReportStatusFromLegacy(
  legacy_status.ReportStatus? legacyStatus, {
  required bool hasSeverity,
}) =>
    switch (legacyStatus) {
      legacy_status.ReportStatus.draft =>
        hasSeverity ? ui.ReportStatus.attention : ui.ReportStatus.draft,
      legacy_status.ReportStatus.published => ui.ReportStatus.submitted,
      legacy_status.ReportStatus.archived || null => ui.ReportStatus.none,
    };
