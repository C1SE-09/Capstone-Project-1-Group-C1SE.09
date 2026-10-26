// frontend/lib/features/kindergarten_dashboard/widgets/timetable_models_and_helpers.dart
// ====================================================================================
// Models và Helper functions dùng cho module Thời khóa biểu (Timetable).

import 'package:adark_frontend/domain/entities/timetable/class_schedule.dart';
import 'package:adark_frontend/domain/entities/timetable/subject.dart';
import 'package:adark_frontend/domain/entities/timetable/time_slot.dart';
import 'package:flutter/material.dart';

const kTimetableDayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
const kTimetableDayLong = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];

class TimetableData {
  const TimetableData({required this.items, required this.slots, required this.subjects});
  final List<ClassSchedule> items;
  final List<TimeSlot> slots;
  final List<Subject> subjects;
}

Color? timetableHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final value = hex.replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

IconData timetableIconForSubject(String? subject) {
  switch (subject) {
    case 'Toán':
      return Icons.calculate_outlined;
    case 'Văn':
      return Icons.menu_book_outlined;
    case 'Ngoại ngữ':
      return Icons.language_outlined;
    case 'Âm nhạc':
      return Icons.music_note_outlined;
    case 'Mỹ thuật':
      return Icons.palette_outlined;
    case 'Thể dục':
      return Icons.sports_soccer_outlined;
    default:
      return Icons.event_outlined;
  }
}

int? timetableTimeToMinutes(String time) {
  final parts = time.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}
