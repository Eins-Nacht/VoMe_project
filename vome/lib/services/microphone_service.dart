import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'audio_storage_service.dart';

class MicrophoneService {
  MicrophoneService._();

  static final MicrophoneService instance = MicrophoneService._();

  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() async {
    return Permission.microphone.isGranted;
  }

  Future<void> startRecording() async {
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        throw Exception('Microphone permission denied');
      }
    }

    if (await _recorder.isRecording()) {
      return;
    }

    final tempPath = p.join(
      AudioStorageService.instance.audioDirectory.path,
      'temp_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: tempPath,
    );
  }

  Future<void> pauseRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.pause();
    }
  }

  Future<void> resumeRecording() async {
    if (await _recorder.isPaused()) {
      await _recorder.resume();
    }
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path;
  }

  Future<void> cancelRecording() async {
    final path = await _recorder.stop();

    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Future<bool> isPaused() => _recorder.isPaused();

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
