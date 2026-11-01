import 'dart:async';
import 'dart:convert';

import '../models/recording.dart';
import 'audio_api_service.dart';
import 'audio_storage_service.dart';
import 'auth_service.dart';
import 'recording_repository.dart';

class ProcessingResult {
  final bool succeeded;
  final String? error;

  const ProcessingResult.success() : succeeded = true, error = null;
  const ProcessingResult.failure(this.error) : succeeded = false;
}

class ProcessingService {
  ProcessingService._();

  static final instance = ProcessingService._();
  final Set<String> _trackedRecordings = <String>{};
  static const _maxUploadBytes = 25 * 1024 * 1024;

  AudioApiService? get _api {
    final token = AuthService.instance.token;
    return token == null
        ? null
        : AudioApiService(
            baseUrl: AuthService.defaultBaseUrl,
            accessToken: token,
          );
  }

  Future<ProcessingResult> enqueue(Recording recording) async {
    if (recording.status == 'Completed') {
      return const ProcessingResult.success();
    }
    if (!_trackedRecordings.add(recording.id)) {
      return const ProcessingResult.success();
    }

    try {
      final api = _api;
      if (api == null) {
        const error = 'Sign in to start processing.';
        await _markUnavailable(recording, error);
        return const ProcessingResult.failure(error);
      }

      RemoteProcessingJob job;
      if (recording.processingJobId != null) {
        job = await api.processingStatus(int.parse(recording.processingJobId!));
        if (job.status == 'failed') {
          job = await api.startProcessing(job.audioRecordId);
        }
      } else {
        final fileSize = await AudioStorageService.instance.getFileSize(
          recording.audioPath,
        );
        if (fileSize > _maxUploadBytes) {
          const error = 'Audio files must be 25 MB or smaller.';
          await _markFailed(recording, error);
          return const ProcessingResult.failure(error);
        }
        if (fileSize == 0) {
          await RecordingRepository.instance.updateProcessing(
            recording.id,
            status: 'Failed',
            error: 'Audio file is unavailable.',
          );
          return const ProcessingResult.failure('Audio file is unavailable.');
        }
        final event = await api.createEvent(
          title: recording.title,
          category: recording.eventType,
        );
        final audio = await api.upload(
          eventId: event.id,
          filePath: AudioStorageService.instance.absolutePath(
            recording.audioPath,
          ),
          clientRecordingId: recording.id,
        );
        job = await api.startProcessing(audio.id);
      }

      await _saveJob(recording.id, job);
      unawaited(_poll(recording.id, job.id));
      return const ProcessingResult.success();
    } on FormatException {
      const error = 'The saved processing job is invalid.';
      await _markFailed(recording, error);
      return const ProcessingResult.failure(error);
    } on AudioApiException catch (error) {
      await _markUnavailable(recording, error.toString());
      return ProcessingResult.failure(error.toString());
    } catch (error) {
      await _markUnavailable(recording, error.toString());
      return ProcessingResult.failure(error.toString());
    }
  }

  Future<ProcessingResult> retry(Recording recording) => enqueue(recording);

  Future<void> cancelAndDelete(Recording recording) async {
    final api = _api;
    final jobId = recording.processingJobId;
    if (api != null &&
        jobId != null &&
        (recording.status == 'Pending' || recording.status == 'Processing')) {
      await api.cancelProcessing(int.parse(jobId));
      if (recording.status == 'Pending' || recording.status == 'Processing') {
        _trackedRecordings.remove(recording.id);
      }
    }
    if (api != null && jobId != null) {
      final job = await api.processingStatus(int.parse(jobId));
      await api.delete(job.audioRecordId);
    }
    await RecordingRepository.instance.deleteRecording(recording.id);
  }

  Future<void> resumePendingJobs() async {
    final recordings = await RecordingRepository.instance.getAllRecordings();
    for (final recording in recordings) {
      if (recording.status == 'Pending' ||
          (recording.processingJobId != null && recording.status != 'Failed')) {
        unawaited(enqueue(recording));
      }
    }
  }

  Future<RemoteSummary?> fetchResult(Recording recording) async {
    final jobId = recording.processingJobId;
    final api = _api;
    if (jobId == null || api == null) return null;
    return api.processingResult(int.parse(jobId));
  }

  Future<void> _poll(String recordingId, int jobId) async {
    try {
      final api = _api;
      if (api == null) return;
      for (var attempt = 0; attempt < 120; attempt++) {
        final job = await api.processingStatus(jobId);
        final recording = await RecordingRepository.instance.getRecordingById(
          recordingId,
        );
        if (recording == null) return;
        await _saveJob(recordingId, job);
        if (job.status == 'cancelled') return;
        if (job.status == 'completed') {
          final summary = await api.processingResult(jobId);
          if (summary.transcriptionStatus != null &&
              summary.transcriptionStatus != 'success') {
            await RecordingRepository.instance.updateProcessing(
              recordingId,
              status: 'Failed',
              error: _outcomeError(
                summary.transcriptionStatus!,
                summary.message,
              ),
            );
            return;
          }
          await RecordingRepository.instance.updateProcessing(
            recordingId,
            status: 'Completed',
            summaryJson: jsonEncode(summary.toJson()),
            error: null,
          );
          return;
        }
        if (job.status == 'failed') return;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      await RecordingRepository.instance.updateProcessing(
        recordingId,
        status: 'Failed',
        error: 'Processing timed out. Try again.',
      );
    } on AudioApiException catch (error) {
      final recording = await RecordingRepository.instance.getRecordingById(
        recordingId,
      );
      if (recording != null) {
        await _markUnavailable(recording, error.toString());
      }
    } catch (error) {
      final recording = await RecordingRepository.instance.getRecordingById(
        recordingId,
      );
      if (recording != null) {
        await _markUnavailable(recording, error.toString());
      }
    } finally {
      _trackedRecordings.remove(recordingId);
    }
  }

  Future<void> _saveJob(String recordingId, RemoteProcessingJob job) {
    return RecordingRepository.instance.updateProcessing(
      recordingId,
      status: _localStatus(job.status),
      jobId: job.id.toString(),
      error: job.errorMessage,
    );
  }

  Future<void> _markFailed(Recording recording, String error) {
    _trackedRecordings.remove(recording.id);
    return RecordingRepository.instance.updateProcessing(
      recording.id,
      status: 'Failed',
      error: error,
    );
  }

  Future<void> _markUnavailable(Recording recording, String error) {
    _trackedRecordings.remove(recording.id);
    return RecordingRepository.instance.updateProcessing(
      recording.id,
      status: recording.processingJobId == null ? 'Pending' : recording.status,
      error: error,
    );
  }

  String _localStatus(String status) => switch (status) {
    'pending' => 'Pending',
    'processing' => 'Processing',
    'completed' => 'Completed',
    'failed' => 'Failed',
    'cancelled' => 'Cancelled',
    _ => 'Pending',
  };

  String _outcomeError(String status, String? message) =>
      '$status|${message ?? _defaultOutcomeMessage(status)}';

  String _defaultOutcomeMessage(String status) => switch (status) {
    'no_speech' => 'No speech was found in this audio file.',
    'invalid_audio' =>
      'This audio file is empty or cannot be opened. Please select another file.',
    'unclear_speech' =>
      'Speech was detected, but it could not be transcribed clearly.',
    _ => 'Something went wrong while processing your audio.',
  };
}
