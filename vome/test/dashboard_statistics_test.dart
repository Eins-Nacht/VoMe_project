import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vome/models/recording.dart';
import 'package:vome/services/database_service.dart';

void main() {
  const testIds = [
    'dashboard-statistics-retained',
    'dashboard-statistics-uploaded',
    'dashboard-statistics-removed',
  ];

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseService.instance.init();
  });

  tearDown(() async {
    for (final id in testIds) {
      await DatabaseService.instance.deleteRecording(id);
    }
  });

  test('statistics count local rows and only retained local audio', () async {
    final beforeCount = await _countThisWeek();
    final beforeDuration = await _durationThisWeek();

    await _insertRecording(
      id: testIds[0],
      durationMs: 1000,
      source: 'recorded',
      audioRetained: true,
    );
    await _insertRecording(
      id: testIds[1],
      durationMs: 2000,
      source: 'uploaded',
      audioRetained: true,
    );
    await _insertRecording(
      id: testIds[2],
      durationMs: 500,
      source: 'uploaded',
      audioRetained: false,
    );

    expect(await _countThisWeek(), beforeCount + 3);
    expect(await _durationThisWeek(), beforeDuration + 3000);
  });
}

Future<int> _countThisWeek() {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  return DatabaseService.instance.countRecordingsSince(
    DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
  );
}

Future<int> _durationThisWeek() async {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  return DatabaseService.instance.sumDurationSince(
    DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
  );
}

Future<void> _insertRecording({
  required String id,
  required int durationMs,
  required String source,
  required bool audioRetained,
}) {
  return DatabaseService.instance.insertRecording(
    Recording(
      id: id,
      title: 'Dashboard test',
      eventType: 'Meeting',
      durationMs: durationMs,
      createdAt: DateTime.now(),
      audioPath: 'audio/$id.m4a',
      fileSize: audioRetained ? 100 : null,
      mimeType: 'audio/mp4',
      source: source,
      audioRetained: audioRetained,
      status: 'Completed',
      transcript: 'Completed transcript',
    ),
  );
}
