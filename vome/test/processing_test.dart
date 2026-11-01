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

  test('maps a real Thai transcript without requiring summary fields', () {
    final result = RemoteSummary.fromProcessingResult({
      'id': 8,
      'audio_record_id': 4,
      'status': 'completed',
      'transcription_status': 'success',
      'error_message': null,
      'event_title': 'Thai meeting',
      'event_category': 'Meeting',
      'audio': {
        'id': 4,
        'event_id': 3,
        'filename': 'meeting.mp3',
        'format': 'mp3',
        'size': 100,
        'duration': 35.1,
        'audio_path': null,
        'created_at': '2026-10-31T00:00:00Z',
        'updated_at': '2026-10-31T00:00:00Z',
        'client_recording_id': 'local-4',
      },
      'transcript_text': 'สวัสดีครับ\nปิดประชุมครับ',
      'transcript_language': 'th',
      'summary': null,
      'key_points': null,
      'action_items': null,
      'keywords': null,
      'category': null,
      'mood': null,
      'action_status': null,
      'message': null,
    });

    expect(result.transcriptText, 'สวัสดีครับ\nปิดประชุมครับ');
    expect(result.transcriptLanguage, 'th');
    expect(result.summary, isEmpty);
    expect(result.keyPoints, isEmpty);
  });

  test('maps an empty transcript safely', () {
    final result = RemoteSummary.fromProcessingResult({
      'id': 9,
      'audio_record_id': 5,
      'status': 'completed',
      'transcription_status': 'no_speech',
      'error_message': 'No speech detected',
      'event_title': 'Silent recording',
      'event_category': null,
      'audio': {
        'id': 5,
        'event_id': 3,
        'filename': 'silent.mp3',
        'format': 'mp3',
        'size': 100,
        'duration': null,
        'audio_path': null,
        'created_at': '2026-10-31T00:00:00Z',
        'updated_at': '2026-10-31T00:00:00Z',
      },
      'transcript_text': null,
      'transcript_language': null,
      'summary': null,
      'key_points': null,
      'action_items': null,
      'keywords': null,
      'category': null,
      'mood': null,
      'action_status': null,
      'message': 'No speech detected',
    });

    expect(result.transcriptText, isNull);
    expect(result.transcriptLanguage, isNull);
    expect(result.transcriptionStatus, 'no_speech');
    expect(result.message, 'No speech detected');
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

  testWidgets('renders no-speech outcome without retry action', (tester) async {
    final recording = _Recording(
      id: 'no-speech-id',
      title: 'Silent recording',
      eventType: 'Meeting',
      durationMs: 1000,
      audioPath: 'audio/silent.m4a',
      source: 'recorded',
      processingJobId: '5',
      status: 'Failed',
      processingError: 'no_speech|No speech was found in this audio file.',
    );
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

    expect(find.textContaining('No speech detected'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(retried, isFalse);
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
    super.processingError,
  }) : super(createdAt: DateTime(2026, 10, 31));
}
