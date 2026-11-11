// frontend/lib/domain/entities/timetable/class_schedule.dart
// =========================================================
// Entity ClassSchedule — MIRROR backend app/schemas/schedule.py
// (ClassScheduleResponse, flat list with nested time_slot/subject/teacher)

import 'package:adark_frontend/domain/entities/base_entity.dart';
import 'package:adark_frontend/domain/entities/timetable/subject.dart';
import 'package:adark_frontend/domain/entities/timetable/time_slot.dart';

class ClassSchedule extends BaseEntity {
  const ClassSchedule({
    required this.scheduleId,
    required this.classId,
    required this.subjectId,
    required this.slotId,
    this.customStartTime,
    this.customEndTime,
    this.teacherId,
    required this.dayOfWeek,
    this.activityName,
    this.content,
    this.roomName,
    this.isActive = true,
    this.timeSlot,
    this.subject,
    this.teacherName,
  });

  final String scheduleId;
  final String classId;
  final String subjectId;
  final String slotId;
  final String? customStartTime;
  final String? customEndTime;
  final String? teacherId;
  final int dayOfWeek; // backend: 2=Thứ 2 … 7=Thứ 7
  final String? activityName;
  final String? content;
  final String? roomName;
  final bool isActive;
  final TimeSlot? timeSlot;
  final Subject? subject;
  final String? teacherName;

  /// 0 = Thứ Hai … 5 = Thứ Bảy (backend day 2..7).
  int get dayIndex => dayOfWeek - 2;

  String get displayName =>
      (activityName?.trim().isNotEmpty ?? false) ? activityName!.trim() : (subject?.name ?? 'Hoạt động');

  bool get isCustomTime =>
      slotId.isEmpty &&
      (customStartTime?.isNotEmpty ?? false) &&
      (customEndTime?.isNotEmpty ?? false);

  String get startTime =>
      (customStartTime?.isNotEmpty ?? false) ? customStartTime! : (timeSlot?.startTime ?? '');

  String get endTime =>
      (customEndTime?.isNotEmpty ?? false) ? customEndTime! : (timeSlot?.endTime ?? '');

  String get timeKey => slotId.isNotEmpty ? slotId : 'custom:$startTime-$endTime';
  String get teacherLabel => (teacherName?.trim().isNotEmpty ?? false) ? teacherName!.trim() : '';
  String get roomLabel => (roomName?.trim().isNotEmpty ?? false) ? roomName!.trim() : '';

  factory ClassSchedule.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final slotRaw = data['time_slot'] ?? data['timeSlot'];
    final subjectRaw = data['subject'];
    final teacherRaw = data['teacher'];
    return ClassSchedule(
      scheduleId: (data['schedule_id'] ?? data['scheduleId'] ?? '').toString(),
      classId: (data['class_id'] ?? data['classId'] ?? '').toString(),
      subjectId: (data['subject_id'] ?? data['subjectId'] ?? '').toString(),
      slotId: (data['slot_id'] ?? data['slotId'] ?? '').toString(),
      customStartTime: data['custom_start_time']?.toString() ?? data['customStartTime']?.toString(),
      customEndTime: data['custom_end_time']?.toString() ?? data['customEndTime']?.toString(),
      teacherId: data['teacher_id']?.toString() ?? data['teacherId']?.toString(),
      dayOfWeek: data['day_of_week'] is int ? data['day_of_week'] as int : 2,
      activityName: data['activity_name']?.toString() ?? data['activityName']?.toString(),
      content: data['content']?.toString(),
      roomName: data['room_name']?.toString() ?? data['roomName']?.toString(),
      isActive: data['is_active'] is bool ? data['is_active'] as bool : true,
      timeSlot: slotRaw is Map ? TimeSlot.fromJson(Map<String, dynamic>.from(slotRaw)) : null,
      subject: subjectRaw is Map ? Subject.fromJson(Map<String, dynamic>.from(subjectRaw)) : null,
      teacherName: teacherRaw is Map ? (teacherRaw['full_name'] ?? teacherRaw['fullName'])?.toString() : null,
    );
  }
}
