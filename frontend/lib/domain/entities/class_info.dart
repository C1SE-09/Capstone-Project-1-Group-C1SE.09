// frontend/lib/domain/entities/class_info.dart
// =========================================================
// Entity ClassInfo — MIRROR backend app/models/user.py (Class_)

import 'package:adark_frontend/domain/entities/base_entity.dart';

class ClassInfo extends BaseEntity {
  const ClassInfo({
    required this.classId,
    required this.schoolId,
    required this.name,
    this.gradeLabel,
    this.roomNumber,
    this.capacity,
    this.isActive = true,
  });

  final String classId;
  final String schoolId;
  final String name;
  final String? gradeLabel; // Mầm | Chồi | Lá
  final String? roomNumber;
  final int? capacity;
  final bool isActive;

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    return ClassInfo(
      classId: json['class_id'] as String,
      schoolId: json['school_id'] as String,
      name: json['name'] as String,
      gradeLabel: json['grade_label'] as String?,
      roomNumber: json['room_number'] as String?,
      capacity: json['capacity'] as int?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
