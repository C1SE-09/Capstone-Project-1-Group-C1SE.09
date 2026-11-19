import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adark_frontend/data/repositories/http_report_response_repository.dart';
import 'package:adark_frontend/domain/entities/report/report_response.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/voice_message_bubble.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/voice_record_bar.dart';

class MockReportResponseRepository extends HttpReportResponseRepository {
  MockReportResponseRepository() : super(baseUrl: 'http://mock');

  @override
  Future<Uint8List> getAudioBytes(String audioUrl) async {
    return Uint8List.fromList([0, 1, 2, 3, 4]);
  }
}

void main() {
  group('ReportResponse Entity Audio Support', () {
    test('fromJson and toJson round-trip preserves audio fields', () {
      final json = {
        'response_id': 'resp-123',
        'daily_report_id': 'rep-456',
        'author_role': 'parent',
        'author_name': 'Mẹ bé An',
        'content': 'Tin nhắn thoại (15 giây)',
        'audio_url': '/api/report-responses/audio/child-1/audio-1',
        'audio_duration': 15,
        'has_audio': true,
        'is_read': false,
        'is_resolved': false,
        'created_at': '2026-11-19T10:00:00.000Z',
      };

      final response = ReportResponse.fromJson(json);
      expect(response.responseId, 'resp-123');
      expect(response.hasAudio, isTrue);
      expect(response.audioUrl, '/api/report-responses/audio/child-1/audio-1');
      expect(response.audioDuration, 15);

      final encoded = response.toJson();
      expect(encoded['audio_url'], '/api/report-responses/audio/child-1/audio-1');
      expect(encoded['audio_duration'], 15);
      expect(encoded['has_audio'], isTrue);
    });
  });

  group('VoiceMessageBubbleWidget', () {
    testWidgets('renders play button, waveform and duration label', (tester) async {
      final repo = MockReportResponseRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceMessageBubbleWidget(
              audioUrl: '/api/report-responses/audio/child-1/audio-1',
              durationSeconds: 15,
              repository: repo,
              isMe: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('0:15'), findsOneWidget);
    });
  });

  group('VoiceRecordBar Widget', () {
    testWidgets('renders mic icon button when idle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceRecordBar(
              onVoiceRecorded: ({
                required Uint8List bytes,
                required int durationSeconds,
                required String fileName,
              }) async {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });
  });
}
