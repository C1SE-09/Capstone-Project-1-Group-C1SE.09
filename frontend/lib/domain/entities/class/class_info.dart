// frontend/lib/domain/entities/class/class_info.dart
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

  factory ClassInfo.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    String? firstStringValue(List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return null;
    }

    final classId = firstStringValue(const ['class_id', 'classId', 'id']) ?? '';
    final schoolId = firstStringValue(const ['school_id', 'schoolId']) ?? '';

    return ClassInfo(
      classId: classId,
      schoolId: schoolId,
      name: firstStringValue(const ['name', 'class_name']) ?? 'Lớp',
      gradeLabel: firstStringValue(const ['grade_label', 'gradeLabel']),
      roomNumber: firstStringValue(const ['room_number', 'roomNumber']),
      capacity: data['capacity'] is int ? data['capacity'] as int : null,
      isActive: data['is_active'] is bool ? data['is_active'] as bool : true,
    );
  }
}
