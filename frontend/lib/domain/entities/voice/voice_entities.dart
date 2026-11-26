// frontend/lib/domain/entities/voice/voice_entities.dart
// =========================================================
// Các Domain Entities cho luồng ghi âm giọng nói, phiên ghi âm nhiều clip
// và dữ liệu trích xuất AI của giáo viên.

// ---------------------------------------------------------------------------
// Entity: VoiceRecord
// ---------------------------------------------------------------------------

// Lightweight entity returned after a successful upload.
//
// Fields mirror the backend response schema:
//   { "id": "uuid", "status": "pending" }
class VoiceRecord {
  const VoiceRecord({
    required this.id,
    required this.status,
    this.rawTranscript,
    this.editedTranscript,
    this.transcription,
    this.errorMessage,
  });

  final String id;
  final String status;
  final String? rawTranscript;
  final String? editedTranscript;
  final String? transcription;
  final String? errorMessage;

  /// Returns the effective transcript text (edited > raw > transcription).
  String get effectiveTranscript =>
      editedTranscript ?? rawTranscript ?? transcription ?? '';

  factory VoiceRecord.fromJson(Map<String, dynamic> json) {
    return VoiceRecord(
      id: json['id'] as String,
      status: json['status'] as String,
      rawTranscript: json['raw_transcript'] as String?,
      editedTranscript: json['edited_transcript'] as String?,
      transcription: json['transcription'] as String?,
      errorMessage: json['error_message'] as String?,
    );
  }

  @override
  String toString() =>
      'VoiceRecord(id: $id, status: $status, edited: ${editedTranscript != null})';
}

// ---------------------------------------------------------------------------
// Entities: Multi-Clip Voice Recording Session (User Story #78)
// ---------------------------------------------------------------------------

class VoiceClip {
  const VoiceClip({
    required this.voiceRecordId,
    required this.status,
    this.audioUrl,
    this.audioDuration,
    this.fileSizeBytes,
    this.transcript,
    this.errorMessage,
    this.isRepresentative = false,
    this.createdAt,
  });

  final String voiceRecordId;
  final String status;
  final String? audioUrl;
  final double? audioDuration;
  final int? fileSizeBytes;
  final String? transcript;
  final String? errorMessage;
  final bool isRepresentative;
  final DateTime? createdAt;

  bool get isPendingOrProcessing =>
      status == 'pending' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  VoiceClip copyWith({
    String? status,
    String? audioUrl,
    double? audioDuration,
    int? fileSizeBytes,
    String? transcript,
    String? errorMessage,
    bool? isRepresentative,
    DateTime? createdAt,
  }) {
    return VoiceClip(
      voiceRecordId: voiceRecordId,
      status: status ?? this.status,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      transcript: transcript ?? this.transcript,
      errorMessage: errorMessage ?? this.errorMessage,
      isRepresentative: isRepresentative ?? this.isRepresentative,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory VoiceClip.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'] as String?;
    return VoiceClip(
      voiceRecordId: (json['voice_record_id'] ?? json['id'] ?? '') as String,
      status: (json['status'] as String?) ?? 'pending',
      audioUrl: json['audio_url'] as String?,
      audioDuration: (json['audio_duration'] as num?)?.toDouble(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
      transcript: json['transcript'] as String?,
      errorMessage: json['error_message'] as String?,
      isRepresentative: json['is_representative'] as bool? ?? false,
      createdAt: createdRaw != null ? DateTime.tryParse(createdRaw) : null,
    );
  }
}

class VoiceRecordingSession {
  const VoiceRecordingSession({
    required this.sessionId,
    required this.scope,
    required this.status,
    this.teacherId,
    this.classId,
    this.childId,
    this.recordedAt,
    this.mergedTranscript,
    this.representativeVoiceRecordId,
    this.clips = const [],
    this.pendingCount = 0,
    this.completedCount = 0,
  });

  final String sessionId;
  final String scope;
  final String status;
  final String? teacherId;
  final String? classId;
  final String? childId;
  final String? recordedAt;
  final String? mergedTranscript;
  final String? representativeVoiceRecordId;
  final List<VoiceClip> clips;
  final int pendingCount;
  final int completedCount;

  factory VoiceRecordingSession.fromJson(Map<String, dynamic> json) {
    final rawClips = json['clips'] as List<dynamic>? ?? const [];
    final clips = rawClips
        .whereType<Map<String, dynamic>>()
        .map(VoiceClip.fromJson)
        .toList();
    return VoiceRecordingSession(
      sessionId: json['session_id'] as String,
      teacherId: json['teacher_id'] as String?,
      classId: json['class_id'] as String?,
      childId: json['child_id'] as String?,
      scope: (json['scope'] as String?) ?? 'whole_class',
      status: (json['status'] as String?) ?? 'active',
      recordedAt: json['recorded_at'] as String?,
      mergedTranscript: json['merged_transcript'] as String?,
      representativeVoiceRecordId:
          json['representative_voice_record_id'] as String?,
      clips: clips,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class MergeVoiceSessionResult {
  const MergeVoiceSessionResult({
    required this.sessionId,
    required this.mergedTranscript,
    this.clipCount = 0,
    this.skippedClips = 0,
    this.representativeVoiceRecordId,
  });

  final String sessionId;
  final String mergedTranscript;
  final int clipCount;
  final int skippedClips;
  final String? representativeVoiceRecordId;

  factory MergeVoiceSessionResult.fromJson(Map<String, dynamic> json) {
    return MergeVoiceSessionResult(
      sessionId: json['session_id'] as String,
      mergedTranscript: (json['merged_transcript'] as String?) ?? '',
      clipCount: (json['clip_count'] as num?)?.toInt() ?? 0,
      skippedClips: (json['skipped_clips'] as num?)?.toInt() ?? 0,
      representativeVoiceRecordId:
          json['representative_voice_record_id'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Entity: ExtractionData
// ---------------------------------------------------------------------------

class ExtractionData {
  const ExtractionData({
    this.transcript,
    this.meals,
    this.sleeping,
    this.health,
    this.activities,
    this.mood,
    this.rawJson,
    this.segments,
    this.classWideExtraction,
    this.childExtractions,
  });

  final String? transcript;
  final String? meals;
  final String? sleeping;
  final String? health;
  final String? activities;
  final String? mood;
  final Map<String, dynamic>? rawJson;
  final List<dynamic>? segments;

  /// Default content cho cả lớp (vd: "Cả lớp ăn ngon").
  /// Backend trả về trong key `class_wide_extraction`.
  /// Chỉ thực sự có nội dung khi giáo viên nói "cả lớp...".
  final Map<String, dynamic>? classWideExtraction;

  /// Override content cho từng bé (vd: "Lan ho nhẹ").
  /// Backend trả về trong key `child_extractions`.
  /// Chỉ chứa các bé CÓ override (không phải cả lớp).
  final Map<String, dynamic>? childExtractions;

  factory ExtractionData.fromJson(Map<String, dynamic> json) {
    return ExtractionData(
      transcript: json['transcript'] as String?,
      meals: json['meals'] as String?,
      sleeping: json['sleeping'] as String?,
      health: json['health'] as String?,
      activities: json['activities'] as String?,
      mood: json['mood'] as String?,
      rawJson: json,
      segments: json['segments'] as List<dynamic>?,
      classWideExtraction: json['class_wide_extraction'] is Map
          ? (json['class_wide_extraction'] as Map).cast<String, dynamic>()
          : null,
      childExtractions: json['child_extractions'] is Map
          ? (json['child_extractions'] as Map).cast<String, dynamic>()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'transcript': transcript,
        'meals': meals,
        'sleeping': sleeping,
        'health': health,
        'activities': activities,
        'mood': mood,
        if (segments != null) 'segments': segments,
        if (classWideExtraction != null)
          'class_wide_extraction': classWideExtraction,
        if (childExtractions != null) 'child_extractions': childExtractions,
      };

  ExtractionData copyWith({
    String? transcript,
    String? meals,
    String? sleeping,
    String? health,
    String? activities,
    String? mood,
    Map<String, dynamic>? rawJson,
    List<dynamic>? segments,
    Map<String, dynamic>? classWideExtraction,
    Map<String, dynamic>? childExtractions,
  }) {
    return ExtractionData(
      transcript: transcript ?? this.transcript,
      meals: meals ?? this.meals,
      sleeping: sleeping ?? this.sleeping,
      health: health ?? this.health,
      activities: activities ?? this.activities,
      mood: mood ?? this.mood,
      rawJson: rawJson ?? this.rawJson,
      segments: segments ?? this.segments,
      classWideExtraction: classWideExtraction ?? this.classWideExtraction,
      childExtractions: childExtractions ?? this.childExtractions,
    );
  }

  /// Classwide có nội dung thật (ít nhất 1 field không null/rỗng).
  bool get hasClassWideContent {
    final cw = classWideExtraction;
    if (cw == null || cw.isEmpty) return false;
    return cw.values.any((v) {
      if (v == null) return false;
      final s = v.toString().trim();
      return s.isNotEmpty;
    });
  }
}
