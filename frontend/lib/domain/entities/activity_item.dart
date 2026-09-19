// frontend/lib/domain/entities/activity_item.dart
// =========================================================
// 1 sự kiện trong dòng "Hoạt động gần đây" (timeline) của lớp.
//
// VD: "Báo cáo của Nguyễn Thị Nhím đã được gửi · 15 phút trước"

import 'package:adark_frontend/domain/entities/base_entity.dart';

/// Loại hoạt động — quyết định icon hiển thị trên timeline.
enum ActivityType {
  reportSent, // ✈ đã gửi báo cáo
  reportReviewing, // 🕐 đang chờ xem lại
  audioRecorded, // 🎤 đã ghi âm
}

class ActivityItem extends BaseEntity {
  const ActivityItem({
    required this.type,
    required this.message,
    required this.occurredAt,
  });

  final ActivityType type;
  final String message;
  final DateTime occurredAt; // thời điểm xảy ra (để tính "15 phút trước")

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      type: ActivityType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ActivityType.audioRecorded,
      ),
      message: json['message'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
    );
  }
}