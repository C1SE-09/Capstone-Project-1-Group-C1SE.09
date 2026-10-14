// frontend/lib/domain/entities/auth/parent.dart
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
    this.relationship,
    this.createdAt,
  });

  final String parentId;
  final String fullName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final bool isVerified;

  /// Quan hệ với bé ("Bố", "Mẹ", …) — null nếu nhà trường chưa ghi.
  final String? relationship;

  /// Mốc tạo tài khoản — màn Tài khoản tính "N ngày cùng con ở KinderLog".
  final DateTime? createdAt;

  /// Chỉ dùng để cập nhật SĐT tại chỗ sau khi PUT thành công.
  Parent copyWith({String? phone}) => Parent(
    parentId: parentId,
    fullName: fullName,
    phone: phone ?? this.phone,
    email: email,
    avatarUrl: avatarUrl,
    isVerified: isVerified,
    relationship: relationship,
    createdAt: createdAt,
  );

  factory Parent.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['created_at'];
    return Parent(
      parentId: json['parent_id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      relationship: json['relationship'] as String?,
      createdAt: rawCreatedAt == null ? null : DateTime.tryParse('$rawCreatedAt'),
    );
  }
}