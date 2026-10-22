// Adapts domain child and report entities to the dashboard UI model.
import 'package:adark_frontend/domain/entities/child/child.dart' as domain_child;
import 'package:adark_frontend/domain/entities/report/report_status.dart' as domain_status;
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/report_status_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;

ui.Child uiChildFromDomain({
  required domain_child.Child child,
  required ui.ReportStatus reportStatus,
  required ui.Severity severity,
  String? timeLabel,
}) =>
    ui.Child(
      id: child.childId,
      name: child.fullName,
      nickname: child.nickname,
      allergy: child.medicalAllergies,
      careNotes: child.careNotes,
      status: reportStatus,
      severity: severity,
      present: true,
      time: timeLabel ?? '',
    );

ui.Child uiChildFromDomainWithReport({
  required domain_child.Child child,
  required domain_status.ReportStatus? reportStatus,
  required ui.Severity severity,
  DateTime? updatedAt,
}) {
  final hasSeverity = severity != ui.Severity.none;
  final mappedStatus = uiReportStatusFromDomain(
    reportStatus,
    hasSeverity: hasSeverity,
  );
  final timeLabel = updatedAt == null
      ? ''
      : '${updatedAt.hour.toString().padLeft(2, '0')}:'
          '${updatedAt.minute.toString().padLeft(2, '0')}';

  return uiChildFromDomain(
    child: child,
    reportStatus: mappedStatus,
    severity: severity,
    timeLabel: timeLabel,
  );
}

// Backward-compatibility aliases
ui.Child uiChildFromLegacy({
  required domain_child.Child legacy,
  required ui.ReportStatus reportStatus,
  required ui.Severity severity,
  String? timeLabel,
}) =>
    uiChildFromDomain(
      child: legacy,
      reportStatus: reportStatus,
      severity: severity,
      timeLabel: timeLabel,
    );

ui.Child uiChildFromLegacyWithReport({
  required domain_child.Child legacy,
  required domain_status.ReportStatus? legacyStatus,
  required ui.Severity severity,
  DateTime? updatedAt,
}) =>
    uiChildFromDomainWithReport(
      child: legacy,
      reportStatus: legacyStatus,
      severity: severity,
      updatedAt: updatedAt,
    );
