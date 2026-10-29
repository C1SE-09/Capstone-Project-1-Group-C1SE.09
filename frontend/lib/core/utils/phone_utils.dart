/// Chỉ mở số điện thoại, không cho URI/số điều khiển cuộc gọi đi vào tel:.
Uri? phoneCallUri(String phone) {
  final raw = phone.trim();
  if (!RegExp(r'^\+?[0-9\s().-]+$').hasMatch(raw)) return null;
  final clean = raw.replaceAll(RegExp(r'[\s().-]'), '');
  return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(clean)
      ? Uri(scheme: 'tel', path: clean)
      : null;
}

String maskedPhone(String phone) {
  final value = phoneCallUri(phone)?.path;
  return value == null
      ? 'Chưa có số điện thoại hợp lệ'
      : '${value.substring(0, 4)} ••• ${value.substring(value.length - 3)}';
}
