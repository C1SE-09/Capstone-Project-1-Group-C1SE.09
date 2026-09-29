// Adapts domain class entities and overviews to the dashboard UI model.
import 'package:adark_frontend/domain/entities/class/class_info.dart' as domain_class;
import 'package:adark_frontend/domain/entities/class/class_report_overview.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;

ui.ClassInfo uiClassInfoFromOverview(
  ClassReportOverview overview,
) =>
    ui.ClassInfo(
      overview.classInfo.classId,
      overview.classInfo.name,
      'Chưa có thông tin trường',
      overview.totalChildren,
      'Giáo viên chủ nhiệm',
    );

ui.ClassInfo uiClassInfoFromDomain(
  domain_class.ClassInfo domain, {
  required int count,
}) =>
    ui.ClassInfo(
      domain.classId,
      domain.name,
      'Chưa có thông tin trường',
      count,
      'Giáo viên chủ nhiệm',
    );

// Backward-compatibility alias
ui.ClassInfo uiClassInfoFromLegacy(
  domain_class.ClassInfo legacy, {
  required int count,
}) =>
    uiClassInfoFromDomain(legacy, count: count);
