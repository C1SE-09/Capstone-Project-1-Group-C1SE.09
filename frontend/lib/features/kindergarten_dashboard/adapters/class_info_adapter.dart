// Adapts domain class entities and overviews to the dashboard UI model.
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart' as domain_class;
import 'package:adark_frontend/domain/entities/class/class_report_overview.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart' as ui;

ui.ClassInfo uiClassInfoFromOverview(
  ClassReportOverview overview,
) =>
    ui.ClassInfo(
      overview.classInfo.classId,
      overview.classInfo.name,
      LocaleController.instance.isEnglish
          ? 'No school information'
          : 'Chưa có thông tin trường',
      overview.totalChildren,
      LocaleController.instance.isEnglish
          ? 'Homeroom Teacher'
          : 'Giáo viên chủ nhiệm',
    );

ui.ClassInfo uiClassInfoFromDomain(
  domain_class.ClassInfo domain, {
  required int count,
}) =>
    ui.ClassInfo(
      domain.classId,
      domain.name,
      LocaleController.instance.isEnglish
          ? 'No school information'
          : 'Chưa có thông tin trường',
      count,
      LocaleController.instance.isEnglish
          ? 'Homeroom Teacher'
          : 'Giáo viên chủ nhiệm',
    );

// Backward-compatibility alias
ui.ClassInfo uiClassInfoFromLegacy(
  domain_class.ClassInfo legacy, {
  required int count,
}) =>
    uiClassInfoFromDomain(legacy, count: count);
