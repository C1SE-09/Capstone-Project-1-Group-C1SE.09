// frontend/lib/domain/entities/parent.dart
// =========================================================
// Entity Parent — MIRROR backend app/models/child.py (Parent)
// (một tài khoản phụ huynh đại diện cả gia đình; có thể có
//  nhiều con)

import 'package:adark_frontend/domain/entities/base_entity.dart';

class Parent extends BaseEntity {
  const Parent({
    required this.parentId,
    required this.fullName,
    this.phone,
    this.email,
    this.avatarUrl,
    this.isVerified = false,
  });

  final String parentId;
  final String fullName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final bool isVerified;

  factory Parent.fromJson(Map<String, dynamic> json) {
    return Parent(
      parentId: json['parent_id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}