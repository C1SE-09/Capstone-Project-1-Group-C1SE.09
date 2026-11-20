import 'package:adark_frontend/core/localization/locale_controller.dart';

/// Bộ chuẩn hóa song ngữ cho dữ liệu Thời khóa biểu Mầm Non (Vietnamese <-> English).
///
/// Hỗ trợ tự động ánh xạ các tên hoạt động, địa điểm phòng học theo khung chuẩn
/// giáo dục mầm non sang tiếng Anh khi ngôn ngữ ứng dụng là English (`isEnglish == true`).
class TimetableLocalizer {
  TimetableLocalizer._();

  /// Từ điển hoạt động mầm non chuẩn (Vietnamese -> English)
  static final Map<String, String> _activityDictionary = {
    'đón trẻ': 'Arrival & Free Play',
    'đón trẻ & chơi tự do': 'Arrival & Free Play',
    'đón trẻ - chơi tự do': 'Arrival & Free Play',
    'tập thể dục - ăn sáng': 'Morning Exercise & Breakfast',
    'thể dục - ăn sáng': 'Morning Exercise & Breakfast',
    'thể dục buổi sáng': 'Morning Exercise',
    'thể dục sáng': 'Morning Exercise',
    'ăn sáng': 'Breakfast',
    'hoạt động có chủ đích': 'Guided Learning Activity',
    'hoạt động có chủ đích (mỹ thuật)': 'Art & Craft Activity',
    'hoạt động có chủ đích (âm nhạc)': 'Music & Movement Activity',
    'hoạt động có chủ đích (kỹ năng)': 'Life Skills Activity',
    'hoạt động có chủ đích (tiếng việt)': 'Language & Storytelling Activity',
    'hoạt động có chủ đích (toán)': 'Early Math Activity',
    'hoạt động có chủ đích (khám phá)': 'Science & Exploration Activity',
    'hoạt động học': 'Learning Activity',
    'ăn giữa giờ - vệ sinh': 'Mid-morning Snack & Hygiene',
    'ăn giữa giờ': 'Mid-morning Snack',
    'uống sữa': 'Milk Break',
    'hoạt động vui chơi': 'Free Play & Corner Activities',
    'vui chơi tự do': 'Free Play',
    'hoạt động góc': 'Corner Activities',
    'hoạt động ngoài trời': 'Outdoor Activities',
    'ăn trưa': 'Lunch Time',
    'vệ sinh - ăn trưa': 'Hygiene & Lunch',
    'ngủ trưa': 'Nap Time',
    'vệ sinh & ngủ trưa': 'Hygiene & Nap Time',
    'hoạt động nhẹ': 'Gentle Awakening & Movement',
    'vận động nhẹ': 'Gentle Movement',
    'thức dậy': 'Wake-up Time',
    'ăn xế': 'Afternoon Snack',
    'ăn phụ chiều': 'Afternoon Snack',
    'ăn chiều': 'Afternoon Meal',
    'sinh hoạt ngoại khóa - hoạt động vui chơi': 'Extracurricular & Play Activities',
    'sinh hoạt ngoại khóa': 'Extracurricular Activities',
    'hoạt động chiều': 'Afternoon Activities',
    'trả trẻ': 'Pick-up & Dismissal',
    'vệ sinh & trả trẻ': 'Hygiene & Dismissal',
    'vệ sinh': 'Hygiene & Clean up',
  };

  /// Từ điển địa điểm / phòng học chuẩn
  static final Map<String, String> _roomDictionary = {
    'phòng học mầm a': 'Classroom Nursery A',
    'phòng học mầm b': 'Classroom Nursery B',
    'phòng học mầm c': 'Classroom Nursery C',
    'phòng mầm a': 'Classroom Nursery A',
    'phòng mầm b': 'Classroom Nursery B',
    'phòng mầm c': 'Classroom Nursery C',
    'phòng mỹ thuật & tạo hình': 'Art & Craft Studio',
    'phòng mỹ thuật': 'Art Studio',
    'phòng tạo hình': 'Craft Studio',
    'phòng âm nhạc & vận động': 'Music & Movement Room',
    'phòng âm nhạc': 'Music Room',
    'phòng thể chất': 'Gymnasium',
    'sân trường': 'School Yard',
    'sân cỏ': 'Playground / Grass Field',
    'sân chơi': 'Playground',
    'hồ bơi': 'Swimming Pool',
    'nhà ăn': 'Dining Hall',
    'thư viện': 'Library',
    'vườn trường': 'School Garden',
    'phòng y tế': 'Health Office',
  };

  /// Chuyển đổi tên hoạt động sang tiếng Anh nếu locale hiện tại là tiếng Anh
  static String localizeActivity(String activityName, {bool? isEn}) {
    final effectiveIsEn = isEn ?? LocaleController.instance.isEnglish;
    if (!effectiveIsEn) return activityName;

    final trimmed = activityName.trim();
    if (trimmed.isEmpty) return trimmed;

    final lower = trimmed.toLowerCase();

    // 1. Khớp chính xác từ điển
    if (_activityDictionary.containsKey(lower)) {
      return _activityDictionary[lower]!;
    }

    // 2. Khớp tiền tố hoặc biểu thức chứa cụm từ chuẩn
    for (final entry in _activityDictionary.entries) {
      if (lower.startsWith(entry.key) || lower.contains(entry.key)) {
        // Thay thế cụm từ khóa tiếng Việt bằng tiếng Anh
        final reg = RegExp(RegExp.escape(entry.key), caseSensitive: false);
        return trimmed.replaceFirst(reg, entry.value);
      }
    }

    // 3. Fallback: Nếu không nằm trong từ điển, giữ nguyên
    return trimmed;
  }

  /// Chuyển đổi tên phòng học / khuôn viên sang tiếng Anh nếu locale là tiếng Anh
  static String localizeRoom(String roomName, {bool? isEn}) {
    final effectiveIsEn = isEn ?? LocaleController.instance.isEnglish;
    if (!effectiveIsEn) return roomName;

    final trimmed = roomName.trim();
    if (trimmed.isEmpty) return trimmed;

    final lower = trimmed.toLowerCase();

    // 1. Khớp chính xác
    if (_roomDictionary.containsKey(lower)) {
      return _roomDictionary[lower]!;
    }

    // 2. Khớp theo mẫu "Phòng học ..." hoặc "Phòng ..."
    for (final entry in _roomDictionary.entries) {
      if (lower.contains(entry.key)) {
        final reg = RegExp(RegExp.escape(entry.key), caseSensitive: false);
        return trimmed.replaceFirst(reg, entry.value);
      }
    }

    if (lower.startsWith('phòng học ')) {
      return trimmed.replaceFirst(RegExp(r'^phòng học\s+', caseSensitive: false), 'Classroom ');
    }
    if (lower.startsWith('phòng ')) {
      return trimmed.replaceFirst(RegExp(r'^phòng\s+', caseSensitive: false), 'Room ');
    }

    return trimmed;
  }
}
