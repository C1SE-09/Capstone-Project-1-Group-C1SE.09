// frontend/lib/domain/entities/class_report_overview.dart
// =========================================================
// Dữ liệu tóm tắt của một lớp trong màn "Báo cáo lớp".

import 'package:adark_frontend/domain/entities/base_entity.dart';
import 'package:adark_frontend/domain/entities/class_info.dart';

class ClassReportOverview extends BaseEntity {
  const ClassReportOverview({
    required this.classInfo,
    required this.teacherName,
    required this.totalChildren,
    required this.completedCount,
    required this.draftCount,
    required this.missingCount,
  });

  final ClassInfo classInfo;
  final String teacherName;
  final int totalChildren;
  final int completedCount;
  final int draftCount;
  final int missingCount;

  double get progress =>
      totalChildren == 0 ? 0 : completedCount / totalChildren;
}
