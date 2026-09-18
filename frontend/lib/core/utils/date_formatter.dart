// frontend/lib/core/utils/date_formatter.dart
// =========================================================
// Tiện ích định dạng ngày/giờ tiếng Việt (không cần gói intl).

/// "Thứ Năm, 17 tháng 9" — dùng cho dòng ngày trên header.
String formatVNWeekdayDate(DateTime d) {
  const weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  final weekday = weekdays[d.weekday - 1]; // weekday: 1=Mon ... 7=Sun
  return '$weekday, ${d.day} tháng ${d.month}';
}

/// "17/09/2026" — dùng cho danh sách báo cáo.
String formatDDMMYYYY(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

/// "15:40" — dùng cho thời gian cập nhật.
String formatHHMM(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// "vừa xong" / "15 phút trước" / "1 giờ trước" — dùng cho timeline.
String formatTimeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  return '${diff.inDays} ngày trước';
}