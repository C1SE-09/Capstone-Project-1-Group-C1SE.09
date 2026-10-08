// frontend/lib/domain/entities/timetable/subject.dart
// =========================================================
// Entity Subject — MIRROR backend app/schemas/schedule.py (SubjectResponse)

import 'package:adark_frontend/domain/entities/base_entity.dart';

class Subject extends BaseEntity {
  const Subject({
    required this.subjectId,
    required this.name,
    this.code,
    this.colorCode,
    this.description,
  });

  final String subjectId;
  final String name;
  final String? code;
  final String? colorCode; // HEX, e.g. "#4CAF50"
  final String? description;

  factory Subject.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return Subject(
      subjectId: (data['subject_id'] ?? data['subjectId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      code: data['code']?.toString(),
      colorCode: data['color_code']?.toString() ?? data['colorCode']?.toString(),
      description: data['description']?.toString(),
    );
  }
}
