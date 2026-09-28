// Adapts backend and domain report statuses to the dashboard UI status.
import 'package:adark_frontend/domain/entities/report/report_status.dart' as domain_status;
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;

ui.ReportStatus uiReportStatusFromBackend(String? backendStatus) =>
    switch (backendStatus?.toLowerCase()) {
      'draft' => ui.ReportStatus.draft,
      'sent' || 'published' => ui.ReportStatus.submitted,
      'read' => ui.ReportStatus.read,
      'archived' || null || '' => ui.ReportStatus.none,
      _ => ui.ReportStatus.none,
    };

ui.ReportStatus uiReportStatusFromDomain(
  domain_status.ReportStatus? domainStatus, {
  required bool hasSeverity,
}) =>
    switch (domainStatus) {
      domain_status.ReportStatus.draft =>
        hasSeverity ? ui.ReportStatus.attention : ui.ReportStatus.draft,
      domain_status.ReportStatus.published => ui.ReportStatus.submitted,
      domain_status.ReportStatus.archived || null => ui.ReportStatus.none,
    };

// Backward-compatibility alias
ui.ReportStatus uiReportStatusFromLegacy(
  domain_status.ReportStatus? legacyStatus, {
  required bool hasSeverity,
}) =>
    uiReportStatusFromDomain(legacyStatus, hasSeverity: hasSeverity);
