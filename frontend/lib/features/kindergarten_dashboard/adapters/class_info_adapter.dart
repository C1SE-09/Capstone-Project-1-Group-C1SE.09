// Adapts legacy class entities and overviews to the dashboard UI model.
import 'package:adark_frontend/domain/entities/class/class_info.dart' as legacy_class;
import 'package:adark_frontend/domain/entities/class/class_report_overview.dart' as legacy_overview;
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;

ui.ClassInfo uiClassInfoFromOverview(
  legacy_overview.ClassReportOverview overview,
) =>
    ui.ClassInfo(
      overview.classInfo.classId,
      overview.classInfo.name,
      'Chưa có thông tin trường',
      overview.totalChildren,
      'Giáo viên chủ nhiệm',
    );

ui.ClassInfo uiClassInfoFromLegacy(
  legacy_class.ClassInfo legacy, {
  required int count,
}) =>
    ui.ClassInfo(
      legacy.classId,
      legacy.name,
      'Chưa có thông tin trường',
      count,
      'Giáo viên chủ nhiệm',
    );
