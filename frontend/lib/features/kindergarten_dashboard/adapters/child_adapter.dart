// Adapts legacy child and report entities to the dashboard UI model.
import 'package:adark_frontend/domain/entities/child/child.dart' as legacy_child;
import 'package:adark_frontend/domain/entities/report/report_status.dart' as legacy_status;
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/report_status_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;

ui.Child uiChildFromLegacy({
  required legacy_child.Child legacy,
  required ui.ReportStatus reportStatus,
  required ui.Severity severity,
  String? timeLabel,
}) =>
    ui.Child(
      id: legacy.childId,
      name: legacy.fullName,
      nickname: legacy.nickname,
      allergy: legacy.medicalAllergies,
      status: reportStatus,
      severity: severity,
      present: true,
      time: timeLabel ?? '',
    );

ui.Child uiChildFromLegacyWithReport({
  required legacy_child.Child legacy,
  required legacy_status.ReportStatus? legacyStatus,
  required ui.Severity severity,
  DateTime? updatedAt,
}) {
  final hasSeverity = severity != ui.Severity.none;
  final reportStatus = uiReportStatusFromLegacy(
    legacyStatus,
    hasSeverity: hasSeverity,
  );
  final timeLabel = updatedAt == null
      ? ''
      : '${updatedAt.hour.toString().padLeft(2, '0')}:'
          '${updatedAt.minute.toString().padLeft(2, '0')}';

  return uiChildFromLegacy(
    legacy: legacy,
    reportStatus: reportStatus,
    severity: severity,
    timeLabel: timeLabel,
  );
}
