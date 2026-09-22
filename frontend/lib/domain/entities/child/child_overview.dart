// frontend/lib/domain/entities/child/child_overview.dart

import 'package:adark_frontend/domain/entities/base_entity.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';

class ChildOverview extends BaseEntity {
  const ChildOverview({
    required this.child,
    required this.className,
    required this.teacherName,
  });

  final Child child;
  final String className;
  final String teacherName;
}
