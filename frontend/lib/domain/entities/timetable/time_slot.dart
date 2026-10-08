// frontend/lib/domain/entities/timetable/time_slot.dart
// =========================================================
// Entity TimeSlot — MIRROR backend app/schemas/schedule.py (TimeSlotResponse)

import 'package:adark_frontend/domain/entities/base_entity.dart';

class TimeSlot extends BaseEntity {
  const TimeSlot({
    required this.slotId,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.orderIndex = 1,
  });

  final String slotId;
  final String name; // "07:00 - 07:30"
  final String startTime; // HH:MM
  final String endTime; // HH:MM
  final int orderIndex;

  factory TimeSlot.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return TimeSlot(
      slotId: (data['slot_id'] ?? data['slotId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      startTime: (data['start_time'] ?? data['startTime'] ?? '').toString(),
      endTime: (data['end_time'] ?? data['endTime'] ?? '').toString(),
      orderIndex: data['order_index'] is int ? data['order_index'] as int : 1,
    );
  }
}
