// frontend/lib/domain/entities/health/medication_schedule.dart
// =========================================================
// Entity quản lý lịch dặn uống thuốc của học sinh trong ngày (Task #295).

import 'package:equatable/equatable.dart';

class MedicationItem extends Equatable {
  const MedicationItem({
    required this.requestId,
    required this.childId,
    required this.childName,
    this.childNickname,
    this.childAvatarUrl,
    required this.medicationName,
    required this.dosage,
    this.instructions,
    required this.session,
    this.isGiven = false,
    this.givenAt,
    this.givenById,
    this.givenByName,
    this.notes,
    this.parentName,
    this.parentPhone,
    this.timeSlot,
    this.requestDate,
    this.prescriptionImageUrl,
  });

  final String requestId;
  final String childId;
  final String childName;
  final String? childNickname;
  final String? childAvatarUrl;
  final String medicationName;
  final String dosage;
  final String? instructions;
  final String session;
  final bool isGiven;
  final DateTime? givenAt;
  final String? givenById;
  final String? givenByName;
  final String? notes;
  final String? parentName;
  final String? parentPhone;
  final String? timeSlot, prescriptionImageUrl;
  final DateTime? requestDate;

  MedicationItem copyWith({
    bool? isGiven,
    DateTime? givenAt,
    String? givenById,
    String? givenByName,
    String? notes,
  }) {
    return MedicationItem(
      requestId: requestId,
      childId: childId,
      childName: childName,
      childNickname: childNickname,
      childAvatarUrl: childAvatarUrl,
      medicationName: medicationName,
      dosage: dosage,
      instructions: instructions,
      session: session,
      isGiven: isGiven ?? this.isGiven,
      givenAt: givenAt ?? this.givenAt,
      givenById: givenById ?? this.givenById,
      givenByName: givenByName ?? this.givenByName,
      notes: notes ?? this.notes,
      parentName: parentName,
      parentPhone: parentPhone,
      timeSlot: timeSlot,
      requestDate: requestDate,
      prescriptionImageUrl: prescriptionImageUrl,
    );
  }

  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    return MedicationItem(
      requestId: json['request_id']?.toString() ?? '',
      childId: json['child_id']?.toString() ?? '',
      childName: json['child_name']?.toString() ?? '',
      childNickname: json['child_nickname']?.toString(),
      childAvatarUrl: json['child_avatar_url']?.toString(),
      medicationName: json['medication_name']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      instructions: json['instructions']?.toString(),
      session: json['session']?.toString() ?? 'morning',
      isGiven: json['is_given'] == true,
      givenAt: json['given_at'] != null
          ? DateTime.tryParse(json['given_at'].toString())
          : null,
      givenById: json['given_by_id']?.toString(),
      givenByName: json['given_by_name']?.toString(),
      notes: json['notes']?.toString(),
      parentName: json['parent_name']?.toString(),
      parentPhone: json['parent_phone']?.toString(),
      timeSlot: json['time_slot']?.toString(),
      requestDate: DateTime.tryParse(json['request_date']?.toString() ?? ''),
      prescriptionImageUrl: json['prescription_image_url']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        requestId,
        childId,
        childName,
        medicationName,
        dosage,
        session,
        isGiven,
        givenAt,
        givenByName,
        timeSlot,
        requestDate,
        prescriptionImageUrl,
      ];
}

class MedicationsTodayData extends Equatable {
  const MedicationsTodayData({
    required this.date,
    required this.classId,
    this.className,
    required this.totalRequests,
    required this.completedCount,
    required this.pendingCount,
    required this.morning,
    required this.noon,
    required this.afternoon,
  });

  final String date;
  final String classId;
  final String? className;
  final int totalRequests;
  final int completedCount;
  final int pendingCount;
  final List<MedicationItem> morning;
  final List<MedicationItem> noon;
  final List<MedicationItem> afternoon;

  List<MedicationItem> get allItems => [...morning, ...noon, ...afternoon];

  factory MedicationsTodayData.fromJson(Map<String, dynamic> json) {
    List<MedicationItem> parseList(dynamic raw) {
      if (raw is List) {
        return raw
            .map((e) => MedicationItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    return MedicationsTodayData(
      date: json['date']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      className: json['class_name']?.toString(),
      totalRequests: (json['total_requests'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      morning: parseList(json['morning']),
      noon: parseList(json['noon']),
      afternoon: parseList(json['afternoon']),
    );
  }

  @override
  List<Object?> get props => [
        date,
        classId,
        className,
        totalRequests,
        completedCount,
        pendingCount,
        morning,
        noon,
        afternoon,
      ];
}
