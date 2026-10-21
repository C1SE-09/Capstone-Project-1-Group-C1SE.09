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
    this.allergyStatus = 'unknown',
    this.careNotes,
    this.healthUpdatedAt,
    this.healthUpdatedByUserId,
    this.healthUpdateSource,
    this.healthVersion = 1,
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
  final String allergyStatus; // unknown | none | present
  final String? careNotes;
  final DateTime? healthUpdatedAt;
  final String? healthUpdatedByUserId;
  final String? healthUpdateSource; // parent | admin | legacy
  final int healthVersion;

  /// Tên hiển thị: ưu tiên nickname, không có thì dùng tên đầy đủ.
  String get displayName =>
      (nickname?.isNotEmpty ?? false) ? nickname! : fullName;

  /// Chuỗi seed/kế thừa ghi "Không có" thay vì để trống khi bé không bị dị ứng.
  static const _noAllergy = {'', 'không', 'không có', 'none'};

  /// Dị ứng cần lưu ý (null nếu chưa ghi nhận) — trả null cho "Không có" để
  /// UI không hiện banner/sheet vô nghĩa. Bỏ tiền tố "Dị ứng" trùng label.
  static const _allergyPrefixes = ['dị ứng:', 'dị ứng'];

  String? get allergy {
    final raw = medicalAllergies?.trim();
    if (raw == null || _noAllergy.contains(raw.toLowerCase())) return null;
    final lower = raw.toLowerCase();
    for (final prefix in _allergyPrefixes) {
      if (lower.startsWith(prefix)) return raw.substring(prefix.length).trim();
    }
    return raw;
  }

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
      allergyStatus: json['allergy_status'] as String? ?? 'unknown',
      careNotes: json['care_notes'] as String?,
      healthUpdatedAt: json['health_updated_at'] != null
          ? DateTime.tryParse(json['health_updated_at'] as String)
          : null,
      healthUpdatedByUserId: json['health_updated_by_user_id'] as String?,
      healthUpdateSource: json['health_update_source'] as String?,
      healthVersion: json['health_version'] as int? ?? 1,
    );
  }
}
