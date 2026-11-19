// frontend/lib/domain/entities/child/child_overview.dart

import 'package:adark_frontend/domain/entities/base_entity.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';

class ChildOverview extends BaseEntity {
  const ChildOverview({
    required this.child,
    required this.className,
    required this.teacherName,
    this.teacherId,
    this.teacherPhone,
    this.roomNumber,
    this.allChildren = const [],
  });

  final Child child;
  final String className;
  final String teacherName;

  /// Liên hệ giáo viên chủ nhiệm — sheet chi tiết bé hiện SĐT để bấm copy.
  final String? teacherId;
  final String? teacherPhone;

  /// Phòng học của lớp — sheet chi tiết bé.
  final String? roomNumber;

  /// Danh sách toàn bộ các bé của phụ huynh (khi gia đình có nhiều con).
  final List<ChildOverview> allChildren;

  ChildOverview copyWith({
    Child? child,
    String? className,
    String? teacherName,
    String? teacherId,
    String? teacherPhone,
    String? roomNumber,
    List<ChildOverview>? allChildren,
  }) {
    return ChildOverview(
      child: child ?? this.child,
      className: className ?? this.className,
      teacherName: teacherName ?? this.teacherName,
      teacherId: teacherId ?? this.teacherId,
      teacherPhone: teacherPhone ?? this.teacherPhone,
      roomNumber: roomNumber ?? this.roomNumber,
      allChildren: allChildren ?? this.allChildren,
    );
  }
}
