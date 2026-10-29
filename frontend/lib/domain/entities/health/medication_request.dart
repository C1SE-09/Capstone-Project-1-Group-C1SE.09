import 'package:equatable/equatable.dart';

/// Ngày lịch Việt Nam, không lấy múi giờ hoặc DST của máy phụ huynh.
DateTime medicationDateInVietnam(DateTime now) {
  final vn = now.toUtc().add(const Duration(hours: 7));
  return DateTime(vn.year, vn.month, vn.day);
}

class MedicationDose extends Equatable {
  const MedicationDose(
      {required this.id,
      required this.childId,
      required this.classId,
      required this.dosage,
      required this.status,
      this.batchId,
      this.name,
      this.category,
      this.notes,
      this.requestDate,
      this.timeSlot,
      this.startDate,
      this.endDate,
      this.sessions = const [],
      this.imageUrl,
      this.creatorUserId,
      this.creatorRole,
      this.creatorName,
      this.createdAt,
      this.updatedAt,
      this.givenAt,
      this.givenById,
      this.givenByName});

  final String id, childId, classId, dosage, status;
  final String? batchId, name, category, notes, timeSlot, imageUrl;
  final String? creatorUserId, creatorRole, creatorName, givenById, givenByName;
  final DateTime? requestDate,
      startDate,
      endDate,
      createdAt,
      updatedAt,
      givenAt;
  final List<String> sessions;

  bool get isLegacy => requestDate == null || timeSlot == null;
  bool get isGiven => status == 'given';
  bool get canCancel => !isLegacy && status == 'pending';

  factory MedicationDose.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Thiếu $key trong cữ thuốc');
      }
      return value;
    }

    DateTime? date(String key) =>
        json[key] is String ? DateTime.tryParse(json[key] as String) : null;
    String? text(String key) =>
        json[key] is String && (json[key] as String).isNotEmpty
            ? json[key] as String
            : null;
    final slot = text('time_slot');
    if (slot != null &&
        !RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(slot)) {
      throw const FormatException('Giờ cữ thuốc không hợp lệ');
    }
    return MedicationDose(
        id: requiredText('id'),
        childId: requiredText('child_id'),
        classId: requiredText('class_id'),
        dosage: requiredText('dosage'),
        status: requiredText('status'),
        batchId: text('batch_id'),
        name: text('medicine_name'),
        category: text('medicine_category'),
        notes: text('notes'),
        requestDate: date('request_date'),
        timeSlot: slot,
        startDate: date('start_date'),
        endDate: date('end_date'),
        sessions: json['sessions'] is List
            ? List<String>.unmodifiable(
                (json['sessions'] as List).whereType<String>())
            : const [],
        imageUrl: text('prescription_image_url'),
        creatorUserId: text('created_by_user_id'),
        creatorRole: text('created_by_role'),
        creatorName: text('creator_name'),
        createdAt: date('created_at'),
        updatedAt: date('updated_at'),
        givenAt: date('given_at'),
        givenById: text('given_by_id'),
        givenByName: text('given_by_name'));
  }

  @override
  List<Object?> get props => [
        id,
        childId,
        classId,
        dosage,
        status,
        batchId,
        name,
        category,
        notes,
        requestDate,
        timeSlot,
        startDate,
        endDate,
        sessions,
        imageUrl,
        creatorUserId,
        creatorRole,
        creatorName,
        createdAt,
        updatedAt,
        givenAt,
        givenById,
        givenByName
      ];
}

class MedicationBatch {
  MedicationBatch(this.id, Iterable<MedicationDose> items)
      : doses = List.unmodifiable(items.toList()
          ..sort((a, b) =>
              '${a.requestDate ?? a.startDate ?? ''} ${a.timeSlot ?? ''} ${a.id}'
                  .compareTo(
                      '${b.requestDate ?? b.startDate ?? ''} ${b.timeSlot ?? ''} ${b.id}')));
  final String id;
  final List<MedicationDose> doses;
  bool get isLegacy => doses.any((dose) => dose.isLegacy);
  DateTime? get fromDate {
    final dates = doses
        .map((d) => d.requestDate ?? d.startDate)
        .whereType<DateTime>()
        .toList()
      ..sort();
    return dates.isEmpty ? null : dates.first;
  }

  DateTime? get toDate {
    final dates = doses
        .map((d) => d.requestDate ?? d.endDate)
        .whereType<DateTime>()
        .toList()
      ..sort();
    return dates.isEmpty ? null : dates.last;
  }

  String statusLabel(DateTime today) {
    if (doses.every((d) => d.status == 'cancelled')) return 'Đã hủy';
    if (isLegacy) return 'Lịch theo buổi';
    if (doses
        .any((d) => !{'pending', 'given', 'cancelled'}.contains(d.status))) {
      return 'Chưa rõ trạng thái';
    }
    if (!doses.any((d) => d.status == 'pending')) return 'Đã xong';
    if (toDate != null && toDate!.isBefore(today)) return 'Chưa hoàn tất';
    if (fromDate != null && fromDate!.isAfter(today)) return 'Chờ bắt đầu';
    return 'Đang uống';
  }
}

class MedicationBatchCreateResult {
  const MedicationBatchCreateResult(this.batchId, this.items);
  final String batchId;
  final List<MedicationDose> items;
}
