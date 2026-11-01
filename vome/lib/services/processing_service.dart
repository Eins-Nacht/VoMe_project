import 'dart:async';
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
  final Map<String, Future<RemoteSummary>> _processingRequests =
      <String, Future<RemoteSummary>>{};
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
        unawaited(processRecording(recording));
      }
    }
  }

  Future<RemoteSummary?> fetchResult(Recording recording) async {
    final jobId = recording.processingJobId;
    final api = _api;
    if (jobId == null || api == null) return null;
    return api.processingResult(int.parse(jobId));
  }

  Future<RemoteSummary> processRecording(
    Recording recording, {
    void Function(String stage)? onStage,
  }) {
    final existing = _processingRequests[recording.id];
    if (existing != null) return existing;
    final request = _processRecording(recording, onStage: onStage);
    _processingRequests[recording.id] = request;
    request
        .whenComplete(() => _processingRequests.remove(recording.id))
        .ignore();
    return request;
  }

  Future<RemoteSummary> _processRecording(
    Recording recording, {
    void Function(String stage)? onStage,
  }) async {
    onStage?.call('Uploading audio...');
    final enqueued = await enqueue(recording);
    if (!enqueued.succeeded) {
      throw StateError(enqueued.error ?? 'Unable to start processing.');
    }

    final current = await RecordingRepository.instance.getRecordingById(
      recording.id,
    );
    final jobId = current?.processingJobId ?? recording.processingJobId;
    if (jobId == null) {
      throw StateError('The processing job was not created.');
    }
    final summary = await _pollUntilTranscribed(
      recording.id,
      int.parse(jobId),
      onStage: onStage,
    );
    onStage?.call('Transcription complete.');
    await RecordingRepository.instance.updateProcessing(
      recording.id,
      status: 'Completed',
      transcript: summary.transcriptText,
      error: null,
    );
    return summary;
  }

  Future<RemoteSummary> _pollUntilTranscribed(
    String recordingId,
    int jobId, {
    void Function(String stage)? onStage,
  }) async {
    try {
      final api = _api;
      if (api == null) {
        throw StateError('Sign in to start processing.');
      }
      onStage?.call('Transcribing audio...');
      for (var attempt = 0; attempt < 120; attempt++) {
        final job = await api.processingStatus(jobId);
        final recording = await RecordingRepository.instance.getRecordingById(
          recordingId,
        );
        if (recording == null) {
          throw StateError('The local recording is unavailable.');
        }
        await _saveJob(recordingId, job);
        onStage?.call(_stageLabel(job.processingStage, job.status));
        if (job.status == 'cancelled') {
          throw StateError('Processing was cancelled.');
        }
        if (job.status == 'completed') {
          final transcription = await api.processingResult(jobId);
          if (transcription.transcriptionStatus != null &&
              transcription.transcriptionStatus != 'success') {
            await RecordingRepository.instance.updateProcessing(
              recordingId,
              status: 'Failed',
              error: _outcomeError(
                transcription.transcriptionStatus!,
                transcription.message,
              ),
            );
            throw StateError(
              _outcomeError(
                transcription.transcriptionStatus!,
                transcription.message,
              ),
            );
          }

          await RecordingRepository.instance.updateProcessing(
            recordingId,
            status: 'Completed',
            transcript: transcription.transcriptText,
            error: null,
          );
          return transcription;
        }
        if (job.status == 'failed') {
          throw StateError(job.errorMessage ?? 'Transcription failed.');
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      await RecordingRepository.instance.updateProcessing(
        recordingId,
        status: 'Failed',
        error: 'Processing timed out. Try again.',
      );
      throw StateError('Transcription timed out. Try again.');
    } on AudioApiException catch (error) {
      final recording = await RecordingRepository.instance.getRecordingById(
        recordingId,
      );
      if (recording != null) {
        await _markUnavailable(recording, error.toString());
      }
      rethrow;
    } catch (error) {
      final recording = await RecordingRepository.instance.getRecordingById(
        recordingId,
      );
      if (recording != null) {
        if (error is StateError) {
          await RecordingRepository.instance.updateProcessing(
            recordingId,
            status: 'Failed',
            error: error.toString(),
          );
        } else {
          await _markUnavailable(recording, error.toString());
        }
      }
      rethrow;
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

  String _stageLabel(String? stage, String status) => switch (stage) {
    'transcribing' => 'Transcribing audio...',
    'correcting' => 'Correcting transcript...',
    'summarizing' => 'Generating summary...',
    'completed' => 'Completed.',
    'failed' => 'Processing failed.',
    _ => status == 'processing' ? 'Processing audio...' : 'Uploading audio...',
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
