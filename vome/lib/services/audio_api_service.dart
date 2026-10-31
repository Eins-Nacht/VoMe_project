import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class RemoteAudioRecord {
  final int id;
  final int eventId;
  final String filename;
  final String format;
  final int size;
  final double? duration;
  final String audioPath;

  const RemoteAudioRecord({
    required this.id,
    required this.eventId,
    required this.filename,
    required this.format,
    required this.size,
    required this.duration,
    required this.audioPath,
  });

  factory RemoteAudioRecord.fromJson(Map<String, dynamic> json) {
    return RemoteAudioRecord(
      id: json['id'] as int,
      eventId: json['event_id'] as int,
      filename: json['filename'] as String,
      format: json['format'] as String,
      size: json['size'] as int,
      duration: (json['duration'] as num?)?.toDouble(),
      audioPath: json['audio_path'] as String,
    );
  }
}

class AudioApiException implements Exception {
  final int statusCode;
  final String message;

  const AudioApiException(this.statusCode, this.message);

  @override
  String toString() => 'AudioApiException($statusCode): $message';
}

class AudioApiService {
  final Uri baseUri;
  final String accessToken;
  final http.Client _client;

  AudioApiService({
    required String baseUrl,
    required this.accessToken,
    http.Client? client,
  }) : baseUri = Uri.parse(baseUrl),
       _client = client ?? http.Client();

  Map<String, String> get _headers => {'Authorization': 'Bearer $accessToken'};

  Future<RemoteAudioRecord> upload({
    required int eventId,
    required String filePath,
  }) async {
    final request =
        http.MultipartRequest('POST', baseUri.resolve('/api/v1/audio'))
          ..headers.addAll(_headers)
          ..fields['event_id'] = eventId.toString()
          ..files.add(await http.MultipartFile.fromPath('file', filePath));
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    _checkResponse(response);
    return RemoteAudioRecord.fromJson(_decodeJson(response));
  }

  Future<List<RemoteAudioRecord>> list() async {
    final response = await _client.get(
      baseUri.resolve('/api/v1/audio'),
      headers: _headers,
    );
    _checkResponse(response);
    return (_decodeJson(response) as List<dynamic>)
        .map((item) => RemoteAudioRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<RemoteAudioRecord> get(int id) async {
    final response = await _client.get(
      baseUri.resolve('/api/v1/audio/$id'),
      headers: _headers,
    );
    _checkResponse(response);
    return RemoteAudioRecord.fromJson(_decodeJson(response));
  }

  Future<Uint8List> download(int id) async {
    final response = await _client.get(
      baseUri.resolve('/api/v1/audio/$id/file'),
      headers: _headers,
    );
    _checkResponse(response);
    return response.bodyBytes;
  }

  Future<void> delete(int id) async {
    final response = await _client.delete(
      baseUri.resolve('/api/v1/audio/$id'),
      headers: _headers,
    );
    _checkResponse(response);
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AudioApiException(response.statusCode, response.body);
    }
  }

  dynamic _decodeJson(http.Response response) {
    return jsonDecode(response.body);
  }
}
