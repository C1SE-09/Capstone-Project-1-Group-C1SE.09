// frontend/lib/domain/entities/teacher.dart
// =========================================================
// Entity Teacher — MIRROR backend app/models/user.py (Teacher)
//
// Tên field đã convert sang camelCase (chuẩn Dart), nhưng
// fromJson() vẫn đọc đúng key snake_case của API.

import 'package:adark_frontend/domain/entities/base_entity.dart';

class Teacher extends BaseEntity {
  const Teacher({
    required this.teacherId,
    required this.fullName,
    required this.email,
    this.schoolId,
    this.classId,
    this.phone,
    this.avatarUrl,
    this.isVerified = false,
  });

  final String teacherId;
  final String? schoolId;
  final String? classId;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final bool isVerified;

  /// Parse từ JSON API. Key khớp với schema backend.
  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      teacherId: json['teacher_id'] as String,
      schoolId: json['school_id'] as String?,
      classId: json['class_id'] as String?,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}