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
    this.audioUrl,
    this.audioDuration,
    this.hasAudio = false,
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
  final String? audioUrl;
  final int? audioDuration;
  final bool hasAudio;
  final bool isRead;
  final bool isResolved;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isFromParent => authorRole == 'parent';
  bool get isFromTeacher => authorRole == 'teacher' || authorRole == 'admin';

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    final audio = json['audio_url']?.toString();
    final dur = json['audio_duration'] is int
        ? json['audio_duration'] as int
        : int.tryParse(json['audio_duration']?.toString() ?? '');

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
      hasImage: json['has_image'] == true || (json['image_url'] != null && json['image_url'].toString().isNotEmpty),
      audioUrl: audio,
      audioDuration: dur,
      hasAudio: json['has_audio'] == true || (audio != null && audio.isNotEmpty),
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
        'audio_url': audioUrl,
        'audio_duration': audioDuration,
        'has_audio': hasAudio,
        'is_read': isRead,
        'is_resolved': isResolved,
        'resolved_at': resolvedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  ReportResponse copyWith({
    String? responseId,
    String? dailyReportId,
    String? childId,
    String? authorUserId,
    String? authorRole,
    String? authorName,
    String? authorAvatarUrl,
    String? content,
    String? imageUrl,
    bool? hasImage,
    String? audioUrl,
    int? audioDuration,
    bool? hasAudio,
    bool? isRead,
    bool? isResolved,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportResponse(
      responseId: responseId ?? this.responseId,
      dailyReportId: dailyReportId ?? this.dailyReportId,
      childId: childId ?? this.childId,
      authorUserId: authorUserId ?? this.authorUserId,
      authorRole: authorRole ?? this.authorRole,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      hasImage: hasImage ?? this.hasImage,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      hasAudio: hasAudio ?? this.hasAudio,
      isRead: isRead ?? this.isRead,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
        audioUrl,
        audioDuration,
        hasAudio,
        isRead,
        isResolved,
        resolvedAt,
        createdAt,
        updatedAt,
      ];
}
