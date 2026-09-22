// frontend/lib/domain/entities/report/activity_record_item.dart

import 'package:adark_frontend/domain/entities/base_entity.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart';

class ActivityRecordItem extends BaseEntity {
  const ActivityRecordItem({
    required this.child,
    this.status,
    this.updatedAt,
  });

  final Child child;
  final ReportStatus? status;
  final DateTime? updatedAt;
}
