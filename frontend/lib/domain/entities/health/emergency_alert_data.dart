// frontend/lib/domain/entities/health/emergency_alert_data.dart
// =========================================================
// Entity lưu trữ thông tin cảnh báo sự cố khẩn cấp (Task #294).

import 'package:equatable/equatable.dart';

class EmergencyAlertData extends Equatable {
  const EmergencyAlertData({
    required this.incidentId,
    required this.childId,
    required this.childName,
    required this.incidentType,
    required this.teacherName,
    required this.teacherPhone,
    this.description,
    this.temperature,
    this.createdAt,
  });

  final String incidentId;
  final String childId;
  final String childName;
  final String incidentType;
  final String teacherName;
  final String teacherPhone;
  final String? description;
  final String? temperature;
  final DateTime? createdAt;

  factory EmergencyAlertData.fromMap(Map<String, dynamic> map) {
    String? text(String key) {
      final val = map[key];
      if (val is String && val.trim().isNotEmpty) return val.trim();
      return null;
    }

    final createdAtStr = text('created_at');
    DateTime? parsedDate;
    if (createdAtStr != null) {
      parsedDate = DateTime.tryParse(createdAtStr);
    }

    return EmergencyAlertData(
      incidentId: text('incident_id') ?? '',
      childId: text('child_id') ?? '',
      childName: text('child_name') ?? 'Bé',
      incidentType: text('incident_type') ?? 'Sự cố sức khỏe',
      teacherName: text('teacher_name') ?? 'Cô giáo phụ trách',
      teacherPhone: text('teacher_phone') ?? '',
      description: text('description'),
      temperature: text('temperature'),
      createdAt: parsedDate ?? DateTime.now(),
    );
  }

  Map<String, String> toQueryParameters() {
    return {
      'incident_id': incidentId,
      'child_id': childId,
      'child_name': childName,
      'incident_type': incidentType,
      'teacher_name': teacherName,
      'teacher_phone': teacherPhone,
      if (description != null && description!.isNotEmpty) 'description': description!,
      if (temperature != null && temperature!.isNotEmpty) 'temperature': temperature!,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        incidentId,
        childId,
        childName,
        incidentType,
        teacherName,
        teacherPhone,
        description,
        temperature,
        createdAt,
      ];
}
