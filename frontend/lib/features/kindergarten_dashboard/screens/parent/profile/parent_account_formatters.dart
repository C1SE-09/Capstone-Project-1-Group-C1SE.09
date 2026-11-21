import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';

/// Khoá lưu lựa chọn nhận thông báo đẩy trên máy.
const kParentPushPrefsKey = 'kinderlog-parent-push';

/// Ngày gắn bó = số ngày kể từ lúc tạo tài khoản (createdAt).
int parentJourneyDays(DateTime? createdAt, {DateTime? now}) {
  if (createdAt == null) return 0;
  return (now ?? DateTime.now()).difference(createdAt).inDays.clamp(0, 100000);
}

/// Định dạng số tuổi của trẻ từ ngày sinh (ví dụ: "4 tuổi" hoặc "3 tuổi 8 tháng").
String formatChildAge(DateTime? dob, {DateTime? now}) {
  if (dob == null) return '';
  final current = now ?? DateTime.now();
  if (dob.isAfter(current)) return '';
  int years = current.year - dob.year;
  int months = current.month - dob.month;
  if (current.day < dob.day) {
    months--;
  }
  if (months < 0) {
    years--;
    months += 12;
  }
  final isEn = LocaleController.instance.isEnglish;
  if (years <= 0) {
    return isEn ? '$months months old' : '$months tháng tuổi';
  } else if (months == 0) {
    return isEn ? '$years years old' : '$years tuổi';
  } else {
    return isEn ? '$years years $months months' : '$years tuổi $months tháng';
  }
}

/// Chuyển đổi mã giới tính sang tiếng Việt thân thiện.
String formatGender(String? gender) {
  final isEn = LocaleController.instance.isEnglish;
  if (gender == null || gender.trim().isEmpty) {
    return isEn ? 'Not updated' : 'Chưa cập nhật';
  }
  final g = gender.trim().toLowerCase();
  if (g == 'male' || g == 'nam') return isEn ? 'Boy (Male)' : 'Bé trai (Nam)';
  if (g == 'female' || g == 'nữ' || g == 'nu') return isEn ? 'Girl (Female)' : 'Bé gái (Nữ)';
  return isEn ? 'Other' : 'Khác';
}

/// Định dạng danh sách tên trẻ cho phụ huynh (tối đa 3 trẻ liệt kê, quá 3 thì thêm "+X bé").
/// Lấy tên thật (fullName) của bé thay vì biệt danh.
String formatParentChildrenNames(ChildOverview overview) {
  final isEn = LocaleController.instance.isEnglish;
  final prefix = isEn ? "Parent of " : "Phụ huynh bé ";
  final childrenList = overview.allChildren.isNotEmpty
      ? overview.allChildren
      : [overview];
  final names = childrenList
      .map((c) => c.child.fullNameWithNickname.trim())
      .where((n) => n.isNotEmpty)
      .toSet()
      .toList();
  if (names.isEmpty) return '$prefix${overview.child.fullNameWithNickname}';
  if (names.length <= 3) {
    return '$prefix${names.join(', ')}';
  }
  final firstThree = names.take(3).join(', ');
  final remaining = names.length - 3;
  return isEn
      ? '$prefix$firstThree, +$remaining children'
      : '$prefix$firstThree, +$remaining bé';
}

/// Lấy 2 chữ cái viết tắt của tên trẻ (ví dụ: Lê Hoàng Nôm -> HN).
String childInitials(String name) {
  final words =
      name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  return words
      .toList()
      .reversed
      .take(2)
      .toList()
      .reversed
      .map((word) => String.fromCharCode(word.runes.first))
      .join()
      .toUpperCase();
}

