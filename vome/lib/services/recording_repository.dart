import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/recording.dart';
import 'audio_storage_service.dart';
import 'database_service.dart';

class RecordingRepository {
  RecordingRepository._();

  static final RecordingRepository instance = RecordingRepository._();

  final _uuid = const Uuid();

  Future<Recording> saveRecordedAudio({
    required String tempFilePath,
    required String title,
    required String eventType,
    required Duration duration,
    bool audioRetained = true,
  }) async {
    final prefix = _eventTypePrefix(eventType);
    final sequence =
        await DatabaseService.instance.countRecordingsWithPrefix(prefix) + 1;

    final audioPath = await AudioStorageService.instance.saveRecordedFile(
      tempFilePath: tempFilePath,
      eventType: eventType,
      sequence: sequence,
    );

    final fileSize = await AudioStorageService.instance.getFileSize(audioPath);

    final recording = Recording(
      id: _uuid.v4(),
      title: title.isEmpty ? 'Untitled Recording' : title,
      eventType: eventType,
      durationMs: duration.inMilliseconds,
      createdAt: DateTime.now(),
      audioPath: audioPath,
      fileSize: fileSize,
      mimeType: AudioStorageService.mimeTypeForExtension('m4a'),
      source: 'recorded',
      audioRetained: audioRetained,
    );

    await DatabaseService.instance.insertRecording(recording);
    return recording;
  }

  Future<Recording> saveUploadedAudio({
    required String sourcePath,
    required String originalFilename,
    required String title,
    required String eventType,
    required Duration duration,
    bool audioRetained = true,
  }) async {
    final prefix = _eventTypePrefix(eventType);
    final sequence =
        await DatabaseService.instance.countRecordingsWithPrefix(prefix) + 1;

    final audioPath = await AudioStorageService.instance.saveUploadedFile(
      sourcePath: sourcePath,
      originalFilename: originalFilename,
      eventType: eventType,
      sequence: sequence,
    );

    final extension = p.extension(originalFilename).replaceFirst('.', '');
    final fileSize = await AudioStorageService.instance.getFileSize(audioPath);

    final recording = Recording(
      id: _uuid.v4(),
      title: title,
      eventType: eventType,
      durationMs: duration.inMilliseconds,
      createdAt: DateTime.now(),
      audioPath: audioPath,
      fileSize: fileSize,
      mimeType: AudioStorageService.mimeTypeForExtension(extension),
      source: 'uploaded',
      audioRetained: audioRetained,
    );

    await DatabaseService.instance.insertRecording(recording);
    return recording;
  }

  Future<List<Recording>> getAllRecordings() {
    return DatabaseService.instance.getAllRecordings();
  }

  Future<List<Recording>> getRecentRecordings({int limit = 10}) {
    return DatabaseService.instance.getRecentRecordings(limit: limit);
  }

  Future<Recording?> getRecordingById(String id) {
    return DatabaseService.instance.getRecordingById(id);
  }

  Future<void> deleteRecording(String id) async {
    final recording = await DatabaseService.instance.getRecordingById(id);
    if (recording == null) {
      return;
    }

    if (recording.audioRetained) {
      await AudioStorageService.instance.deleteAudioFile(recording.audioPath);
    }
    await DatabaseService.instance.deleteRecording(id);
  }

  Future<void> deleteByClientRecordingId(String? id) async {
    if (id == null) {
      return;
    }
    await deleteRecording(id);
  }

  Future<void> deleteByAudioFilename(String filename) async {
    final target = p.basename(filename);
    final recordings = await getAllRecordings();
    for (final recording in recordings) {
      if (p.basename(recording.audioPath) == target) {
        await deleteRecording(recording.id);
      }
    }
  }

  Future<void> updateProcessing(
    String id, {
    required String status,
    String? jobId,
    String? transcript,
    String? summaryJson,
    String? error,
  }) {
    return DatabaseService.instance.updateRecording(id, {
      'status': status,
      if (jobId != null) 'processing_job_id': jobId,
      if (transcript != null) 'transcript': transcript,
      if (summaryJson != null) 'summary_json': summaryJson,
      'processing_error': error,
    });
  }

  Future<void> removeLocalAudio(Recording recording) async {
    await AudioStorageService.instance.deleteAudioFile(recording.audioPath);
    await DatabaseService.instance.updateRecording(recording.id, {
      'audio_retained': 0,
      'file_size': null,
    });
  }

  Future<void> retainLocalAudio(Recording recording) async {
    if (!await AudioStorageService.instance.fileExists(recording.audioPath)) {
      throw StateError('The local audio file is unavailable.');
    }
    await DatabaseService.instance.updateRecording(recording.id, {
      'audio_retained': 1,
    });
  }

  String toAbsoluteAudioPath(String relativePath) {
    return AudioStorageService.instance.absolutePath(relativePath);
  }

  Future<void> updateSummary(String id, String? summaryJson) {
    return DatabaseService.instance.updateRecording(id, {
      'summary_json': summaryJson,
      'status': summaryJson == null ? 'Pending' : 'Completed',
    });
  }

  Future<int> countRecordingsThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    return DatabaseService.instance.countRecordingsSince(weekStart);
  }

  Future<Duration> totalDurationThisWeek() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final totalMs = await DatabaseService.instance.sumDurationSince(weekStart);
    return Duration(milliseconds: totalMs);
  }

  String _eventTypePrefix(String eventType) {
    final normalized = eventType
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return normalized.isEmpty ? 'recording' : normalized;
  }
}
