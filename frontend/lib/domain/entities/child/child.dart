// frontend/lib/domain/entities/child/child.dart
// =========================================================
// Entity Child — MIRROR backend app/models/child.py (Child)

import 'package:adark_frontend/domain/entities/base_entity.dart';

class Child extends BaseEntity {
  const Child({
    required this.childId,
    required this.fullName,
    this.parentId,
    this.classId,
    this.nickname,
    this.dateOfBirth,
    this.gender,
    this.avatarUrl,
    this.medicalAllergies,
  });

  final String childId;
  final String? parentId;
  final String? classId;
  final String fullName;
  final String? nickname; // tên gọi thân mật trong báo cáo
  final DateTime? dateOfBirth;
  final String? gender;
  final String? avatarUrl;
  final String? medicalAllergies;

  /// Tên hiển thị: ưu tiên nickname, không có thì dùng tên đầy đủ.
  String get displayName =>
      (nickname?.isNotEmpty ?? false) ? nickname! : fullName;

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      childId: json['child_id'] as String,
      parentId: json['parent_id'] as String?,
      classId: json['class_id'] as String?,
      fullName: json['full_name'] as String,
      nickname: json['nickname'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'] as String)
          : null,
      gender: json['gender'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      medicalAllergies: json['medical_allergies'] as String?,
    );
  }
}
