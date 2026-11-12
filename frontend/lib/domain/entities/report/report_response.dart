import 'package:equatable/equatable.dart';

class ReportResponse extends Equatable {
  const ReportResponse({
    required this.responseId,
    required this.dailyReportId,
    this.childId,
    this.authorUserId,
    required this.authorRole,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
    this.imageUrl,
    this.hasImage = false,
    this.isRead = false,
    this.isResolved = false,
    this.resolvedAt,
    required this.createdAt,
    this.updatedAt,
  });

  final String responseId;
  final String dailyReportId;
  final String? childId;
  final String? authorUserId;
  final String authorRole;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final String? imageUrl;
  final bool hasImage;
  final bool isRead;
  final bool isResolved;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isFromParent => authorRole == 'parent';
  bool get isFromTeacher => authorRole == 'teacher' || authorRole == 'admin';

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      responseId: json['response_id']?.toString() ?? '',
      dailyReportId: json['daily_report_id']?.toString() ?? '',
      childId: json['child_id']?.toString(),
      authorUserId: json['author_user_id']?.toString(),
      authorRole: json['author_role']?.toString() ?? 'parent',
      authorName: json['author_name']?.toString() ?? 'Phụ huynh',
      authorAvatarUrl: json['author_avatar_url']?.toString(),
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      hasImage: json['has_image'] == true,
      isRead: json['is_read'] == true,
      isResolved: json['is_resolved'] == true,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'response_id': responseId,
        'daily_report_id': dailyReportId,
        'child_id': childId,
        'author_user_id': authorUserId,
        'author_role': authorRole,
        'author_name': authorName,
        'author_avatar_url': authorAvatarUrl,
        'content': content,
        'image_url': imageUrl,
        'has_image': hasImage,
        'is_read': isRead,
        'is_resolved': isResolved,
        'resolved_at': resolvedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        responseId,
        dailyReportId,
        childId,
        authorUserId,
        authorRole,
        authorName,
        authorAvatarUrl,
        content,
        imageUrl,
        hasImage,
        isRead,
        isResolved,
        resolvedAt,
        createdAt,
        updatedAt,
      ];
}

