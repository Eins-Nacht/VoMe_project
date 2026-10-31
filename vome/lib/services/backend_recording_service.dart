import 'dart:async';

import 'auth_service.dart';
import 'audio_api_service.dart';

class BackendRecordingService {
  BackendRecordingService._();

  static final BackendRecordingService instance = BackendRecordingService._();

  AudioApiService? get _api {
    final token = AuthService.instance.token;
    if (token == null) return null;
    return AudioApiService(
      baseUrl: AuthService.defaultBaseUrl,
      accessToken: token,
    );
  }

  Future<RemoteProcessingJob?> uploadAndProcess({
    required String title,
    required String category,
    required String filePath,
  }) async {
    final api = _api;
    if (api == null) return null;
    final event = await api.createEvent(title: title, category: category);
    final audio = await api.upload(eventId: event.id, filePath: filePath);
    final job = await api.startProcessing(audio.id);
    _poll(api, job.id);
    return job;
  }

  Future<void> _poll(AudioApiService api, int jobId) async {
    try {
      for (var attempt = 0; attempt < 30; attempt++) {
        final job = await api.processingStatus(jobId);
        if (job.status == 'completed' || job.status == 'failed') return;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } on AudioApiException {
      // The status remains available for the next foreground refresh.
    }
  }
}
