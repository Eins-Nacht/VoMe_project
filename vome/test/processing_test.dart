import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vome/models/recording.dart';
import 'package:vome/services/audio_api_service.dart';
import 'package:vome/widgets/processing_status_card.dart';

void main() {
  test('maps the processing result response shape', () {
    final summary = RemoteSummary.fromProcessingResult({
      'id': 7,
      'audio_record_id': 3,
      'status': 'completed',
      'error_message': null,
      'event_title': 'Weekly Sync',
      'event_category': 'Meeting',
      'audio': {
        'id': 3,
        'event_id': 2,
        'filename': 'sync.mp3',
        'format': 'mp3',
        'size': 10,
        'duration': null,
        'audio_path': 'audio/sync.mp3',
        'created_at': '2026-10-31T00:00:00Z',
        'updated_at': '2026-10-31T00:00:00Z',
      },
      'transcript_text': 'Transcript',
      'transcript_language': 'en',
      'summary': 'Summary',
      'key_points': ['Point'],
      'action_items': ['Action'],
      'keywords': ['sync'],
      'category': null,
      'mood': 'Neutral',
      'action_status': 'No Action',
    });

    expect(summary.eventTitle, 'Weekly Sync');
    expect(summary.audioFilename, 'sync.mp3');
    expect(summary.audioRecordId, 3);
    expect(summary.summary, 'Summary');
  });

  testWidgets('renders failed processing status and retry action', (
    tester,
  ) async {
    final recording = RecordingFixture.failed;
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProcessingStatusCard(
            recording: recording,
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Processing failed'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}

class RecordingFixture {
  static final failed = _Recording(
    id: 'recording-id',
    title: 'Failed upload',
    eventType: 'Meeting',
    durationMs: 1000,
    audioPath: 'audio/failed.m4a',
    source: 'recorded',
    processingJobId: '4',
    status: 'Failed',
  );
}

class _Recording extends Recording {
  _Recording({
    required super.id,
    required super.title,
    required super.eventType,
    required super.durationMs,
    required super.audioPath,
    required super.source,
    required super.processingJobId,
    required super.status,
  }) : super(createdAt: DateTime(2026, 10, 31));
}
