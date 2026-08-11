import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AudioStorageService {
  AudioStorageService._();

  static final AudioStorageService instance = AudioStorageService._();

  static const String audioDirName = 'audio';
  static const Set<String> allowedUploadExtensions = {'mp3', 'm4a', 'wav'};

  Directory? _audioDirectory;

  Future<void> init() async {
    if (_audioDirectory != null) {
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    _audioDirectory = Directory(p.join(appDir.path, audioDirName));

    if (!await _audioDirectory!.exists()) {
      await _audioDirectory!.create(recursive: true);
    }
  }

  Directory get audioDirectory {
    final dir = _audioDirectory;
    if (dir == null) {
      throw StateError('AudioStorageService.init() must be called first');
    }
    return dir;
  }

  String generateFilename(String eventType, String extension, int sequence) {
    final prefix = _sanitizeEventType(eventType);
    final padded = sequence.toString().padLeft(3, '0');
    return '${prefix}_$padded.$extension';
  }

  String _sanitizeEventType(String eventType) {
    final normalized = eventType
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (normalized.isEmpty) {
      return 'recording';
    }
    return normalized;
  }

  String relativePath(String filename) {
    return p.join(audioDirName, filename);
  }

  String absolutePath(String relativeAudioPath) {
    final appDir = p.dirname(audioDirectory.path);
    return p.normalize(p.join(appDir, relativeAudioPath));
  }

  Future<String> saveRecordedFile({
    required String tempFilePath,
    required String eventType,
    required int sequence,
  }) async {
    final filename = generateFilename(eventType, 'm4a', sequence);
    final destPath = p.join(audioDirectory.path, filename);
    final tempFile = File(tempFilePath);

    if (!await tempFile.exists()) {
      throw FileSystemException('Recorded file not found', tempFilePath);
    }

    await tempFile.copy(destPath);
    await tempFile.delete();

    return relativePath(filename);
  }

  Future<String> saveUploadedFile({
    required String sourcePath,
    required String originalFilename,
    required String eventType,
    required int sequence,
  }) async {
    final extension = p.extension(originalFilename).replaceFirst('.', '').toLowerCase();

    if (!allowedUploadExtensions.contains(extension)) {
      throw ArgumentError(
        'Unsupported audio format: .$extension. Allowed: ${allowedUploadExtensions.join(', ')}',
      );
    }

    final filename = generateFilename(eventType, extension, sequence);
    final destPath = p.join(audioDirectory.path, filename);
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw FileSystemException('Source file not found', sourcePath);
    }

    await sourceFile.copy(destPath);
    return relativePath(filename);
  }

  Future<int> getFileSize(String relativeAudioPath) async {
    final file = File(absolutePath(relativeAudioPath));
    if (!await file.exists()) {
      return 0;
    }
    return file.length();
  }

  Future<bool> fileExists(String relativeAudioPath) async {
    return File(absolutePath(relativeAudioPath)).exists();
  }

  Future<void> deleteAudioFile(String relativeAudioPath) async {
    final file = File(absolutePath(relativeAudioPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String mimeTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'audio/*';
    }
  }
}
