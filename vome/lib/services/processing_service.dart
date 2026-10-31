import 'dart:async';
import 'dart:convert';

import '../models/recording.dart';
import 'audio_storage_service.dart';
import 'processing_api_client.dart';
import 'recording_repository.dart';

class ProcessingService {
  ProcessingService._();
  static final instance = ProcessingService._();

  final _api = ProcessingApiClient();
  static const _maxUploadBytes = 25 * 1024 * 1024;

  Future<void> enqueue(Recording recording) async {
    final fileSize = await AudioStorageService.instance.getFileSize(recording.audioPath);
    if (fileSize == 0) {
      await RecordingRepository.instance.updateProcessing(recording.id, status: 'Failed', error: 'Audio file is unavailable.');
      return;
    }
    if (fileSize > _maxUploadBytes) {
      await RecordingRepository.instance.updateProcessing(
        recording.id,
        status: 'Failed',
        error: 'Audio files must be 25 MB or smaller.',
      );
      return;
    }
    await RecordingRepository.instance.updateProcessing(recording.id, status: 'Uploading');
    try {
      final jobId = await _api.createJob(
        recordingId: recording.id,
        audioPath: AudioStorageService.instance.absolutePath(recording.audioPath),
        title: recording.title,
        eventType: recording.eventType,
      );
      await RecordingRepository.instance.updateProcessing(recording.id, status: 'Queued', jobId: jobId);
      unawaited(_poll(recording.id, jobId));
    } catch (error) {
      await RecordingRepository.instance.updateProcessing(recording.id, status: 'Failed', error: error.toString());
    }
  }

  Future<void> retry(Recording recording) => enqueue(recording);

  Future<void> resumePendingJobs() async {
    final recordings = await RecordingRepository.instance.getAllRecordings();
    for (final recording in recordings) {
      final jobId = recording.processingJobId;
      if (jobId != null && recording.status != 'Completed' && recording.status != 'Failed') {
        unawaited(_poll(recording.id, jobId));
      }
    }
  }

  Future<void> _poll(String recordingId, String jobId) async {
    for (var attempt = 0; attempt < 120; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        final job = await _api.getJob(jobId);
        if (job.status == 'completed') {
          await RecordingRepository.instance.updateProcessing(
            recordingId,
            status: 'Completed',
            transcript: job.transcript,
            summaryJson: jsonEncode(job.summary),
            error: null,
          );
          final recording = await RecordingRepository.instance.getRecordingById(recordingId);
          if (recording != null && !recording.audioRetained) {
            await RecordingRepository.instance.removeLocalAudio(recording);
          }
          return;
        }
        if (job.status == 'failed') {
          await RecordingRepository.instance.updateProcessing(recordingId, status: 'Failed', error: job.error);
          return;
        }
        await RecordingRepository.instance.updateProcessing(recordingId, status: _titleCase(job.status));
      } catch (error) {
        await RecordingRepository.instance.updateProcessing(recordingId, status: 'Failed', error: error.toString());
        return;
      }
    }
    await RecordingRepository.instance.updateProcessing(recordingId, status: 'Failed', error: 'Processing timed out. Try again.');
  }

  String _titleCase(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
