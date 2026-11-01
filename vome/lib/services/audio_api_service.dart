import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AudioApiException implements Exception {
  final int statusCode;
  final String message;

  const AudioApiException(this.statusCode, this.message);

  @override
  String toString() => 'AudioApiException($statusCode): $message';
}

class RemoteAudioRecord {
  final int id;
  final int eventId;
  final String filename;
  final String format;
  final int size;
  final double? duration;
  final String? audioPath;
  final String? clientRecordingId;

  const RemoteAudioRecord({
    required this.id,
    required this.eventId,
    required this.filename,
    required this.format,
    required this.size,
    required this.duration,
    required this.audioPath,
    this.clientRecordingId,
  });

  factory RemoteAudioRecord.fromJson(Map<String, dynamic> json) =>
      RemoteAudioRecord(
        id: json['id'] as int,
        eventId: json['event_id'] as int,
        filename: json['filename'] as String,
        format: json['format'] as String,
        size: json['size'] as int,
        duration: (json['duration'] as num?)?.toDouble(),
        audioPath: json['audio_path'] as String?,
        clientRecordingId: json['client_recording_id'] as String?,
      );
}

class RemoteEvent {
  final int id;
  final String title;
  final String? category;

  const RemoteEvent({required this.id, required this.title, this.category});

  factory RemoteEvent.fromJson(Map<String, dynamic> json) => RemoteEvent(
    id: json['id'] as int,
    title: json['title'] as String,
    category: json['category'] as String?,
  );
}

class RemoteProcessingJob {
  final int id;
  final int audioRecordId;
  final String status;
  final String? errorMessage;
  final String? transcriptionStatus;

  const RemoteProcessingJob({
    required this.id,
    required this.audioRecordId,
    required this.status,
    this.errorMessage,
    this.transcriptionStatus,
  });

  factory RemoteProcessingJob.fromJson(Map<String, dynamic> json) =>
      RemoteProcessingJob(
        id: json['id'] as int,
        audioRecordId: json['audio_record_id'] as int,
        status: json['status'] as String,
        errorMessage: json['error_message'] as String?,
        transcriptionStatus: json['transcription_status'] as String?,
      );
}

class RemoteSummary {
  final int id;
  final int audioRecordId;
  final String? clientRecordingId;
  final int eventId;
  final String eventTitle;
  final String audioFilename;
  final String summary;
  final List<String> keyPoints;
  final List<String> actionItems;
  final List<String> keywords;
  final String? category;
  final String? mood;
  final String? actionStatus;
  final String? transcriptionStatus;
  final String? message;
  final String? transcriptText;
  final String? transcriptLanguage;

  const RemoteSummary({
    required this.id,
    required this.audioRecordId,
    this.clientRecordingId,
    required this.eventId,
    required this.eventTitle,
    required this.audioFilename,
    required this.summary,
    required this.keyPoints,
    required this.actionItems,
    required this.keywords,
    this.category,
    this.mood,
    this.actionStatus,
    this.transcriptionStatus,
    this.message,
    this.transcriptText,
    this.transcriptLanguage,
  });

  factory RemoteSummary.fromJson(Map<String, dynamic> json) => RemoteSummary(
    id: json['id'] as int,
    audioRecordId: json['audio_record_id'] as int,
    clientRecordingId: json['client_recording_id'] as String?,
    eventId: json['event_id'] as int,
    eventTitle: json['event_title'] as String,
    audioFilename: json['audio_filename'] as String,
    summary: json['summary'] as String,
    keyPoints: _strings(json['key_points']),
    actionItems: _strings(json['action_items']),
    keywords: _strings(json['keywords']),
    category: json['category'] as String?,
    mood: json['mood'] as String?,
    actionStatus: json['action_status'] as String?,
    transcriptionStatus: json['transcription_status'] as String?,
    message: json['message'] as String?,
    transcriptText: json['transcript_text'] as String?,
    transcriptLanguage: json['transcript_language'] as String?,
  );

  factory RemoteSummary.fromProcessingResult(Map<String, dynamic> json) {
    final audio = json['audio'] as Map<String, dynamic>;
    return RemoteSummary(
      id: json['id'] as int,
      audioRecordId: json['audio_record_id'] as int,
      clientRecordingId: audio['client_recording_id'] as String?,
      eventId: audio['event_id'] as int,
      eventTitle: json['event_title'] as String,
      audioFilename: audio['filename'] as String,
      summary: json['summary'] as String? ?? '',
      keyPoints: _strings(json['key_points']),
      actionItems: _strings(json['action_items']),
      keywords: _strings(json['keywords']),
      category:
          json['event_category'] as String? ?? json['category'] as String?,
      mood: json['mood'] as String?,
      actionStatus: json['action_status'] as String?,
      transcriptionStatus: json['transcription_status'] as String?,
      message: json['message'] as String?,
      transcriptText: json['transcript_text'] as String?,
      transcriptLanguage: json['transcript_language'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'audio_record_id': audioRecordId,
    'client_recording_id': clientRecordingId,
    'event_id': eventId,
    'event_title': eventTitle,
    'audio_filename': audioFilename,
    'summary': summary,
    'key_points': keyPoints,
    'action_items': actionItems,
    'keywords': keywords,
    'category': category,
    'mood': mood,
    'action_status': actionStatus,
    'transcription_status': transcriptionStatus,
    'message': message,
    'transcript_text': transcriptText,
    'transcript_language': transcriptLanguage,
  };
}

List<String> _strings(dynamic value) => (value as List<dynamic>? ?? const [])
    .map((item) => item.toString())
    .toList();

class AudioApiService {
  final Uri baseUri;
  final String accessToken;
  final http.Client _client;

  AudioApiService({
    required String baseUrl,
    required this.accessToken,
    http.Client? client,
  }) : baseUri = Uri.parse(baseUrl),
       _client = client ?? http.Client() {
    debugPrint('[VoMe API DEBUG] configured base URL: $baseUrl');
  }

  Map<String, String> get _headers => {'Authorization': 'Bearer $accessToken'};
  Uri _uri(String path) => baseUri.resolve('/api/v1$path');

  Future<http.Response> _get(String path) =>
      _client.get(_uri(path), headers: _headers);

  Future<RemoteAudioRecord> upload({
    required int eventId,
    required String filePath,
    String? clientRecordingId,
  }) async {
    final uri = _uri('/audio');
    debugPrint(
      '[VoMe API DEBUG] request POST $uri '
      'fields={event_id: $eventId, client_recording_id: $clientRecordingId}',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers)
      ..fields['event_id'] = eventId.toString()
      ..fields.addAll({
        if (clientRecordingId != null) 'client_recording_id': clientRecordingId,
      })
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    _checkResponse(response);
    return RemoteAudioRecord.fromJson(_decodeJson(response));
  }

  Future<List<RemoteAudioRecord>> list() async {
    final response = await _get('/audio');
    _checkResponse(response);
    return (_decodeJson(response) as List<dynamic>)
        .map((item) => RemoteAudioRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Uint8List> download(int id) async {
    final response = await _get('/audio/$id/file');
    _checkResponse(response);
    return response.bodyBytes;
  }

  Future<void> delete(int id) async {
    final response = await _client.delete(
      _uri('/audio/$id'),
      headers: _headers,
    );
    _checkResponse(response);
  }

  Future<RemoteEvent> createEvent({
    required String title,
    required String category,
  }) async {
    final uri = _uri('/events');
    debugPrint(
      '[VoMe API DEBUG] request POST $uri '
      'body=${jsonEncode({'title': title, 'category': category})}',
    );
    final response = await _client.post(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'category': category}),
    );
    _checkResponse(response);
    return RemoteEvent.fromJson(_decodeJson(response));
  }

  Future<RemoteProcessingJob> startProcessing(int audioId) async {
    final uri = _uri('/processing/audio/$audioId');
    debugPrint('[VoMe API DEBUG] request POST $uri body=<empty>');
    final response = await _client.post(uri, headers: _headers);
    _checkResponse(response);
    return RemoteProcessingJob.fromJson(_decodeJson(response));
  }

  Future<RemoteProcessingJob> processingStatus(int jobId) async {
    final uri = _uri('/processing/$jobId');
    debugPrint('[VoMe API DEBUG] request GET $uri');
    final response = await _get('/processing/$jobId');
    _checkResponse(response);
    return RemoteProcessingJob.fromJson(_decodeJson(response));
  }

  Future<RemoteProcessingJob> cancelProcessing(int jobId) async {
    final response = await _client.delete(
      _uri('/processing/$jobId'),
      headers: _headers,
    );
    _checkResponse(response);
    return RemoteProcessingJob.fromJson(_decodeJson(response));
  }

  Future<RemoteSummary> processingResult(int jobId) async {
    final uri = _uri('/processing/$jobId/result');
    debugPrint('[VoMe API DEBUG] request GET $uri');
    final response = await _get('/processing/$jobId/result');
    _checkResponse(response);
    return RemoteSummary.fromProcessingResult(_decodeJson(response));
  }

  Future<RemoteSummary> generateSummary(int jobId) async {
    final uri = _uri('/processing/$jobId/summary');
    debugPrint('[VoMe API DEBUG] request POST $uri body=<empty>');
    final response = await _client.post(uri, headers: _headers);
    _checkResponse(response);
    return RemoteSummary.fromProcessingResult(_decodeJson(response));
  }

  Future<List<RemoteSummary>> listSummaries({
    String? search,
    String? category,
    String? mood,
    String? actionStatus,
    int limit = 20,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (category != null && category.isNotEmpty) 'category': category,
      if (mood != null && mood.isNotEmpty) 'mood': mood,
      if (actionStatus != null && actionStatus.isNotEmpty)
        'action_status': actionStatus,
    };
    final response = await _client.get(
      _uri('/summaries').replace(queryParameters: query),
      headers: _headers,
    );
    _checkResponse(response);
    final body = _decodeJson(response) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>)
        .map((item) => RemoteSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<RemoteSummary> getSummary(int id) async {
    final response = await _get('/summaries/$id');
    _checkResponse(response);
    return RemoteSummary.fromJson(_decodeJson(response));
  }

  Future<RemoteSummary> updateSummary(
    int id, {
    String? summary,
    List<String>? keyPoints,
    List<String>? actionItems,
    List<String>? keywords,
    String? category,
    String? mood,
    String? actionStatus,
  }) async {
    final response = await _client.patch(
      _uri('/summaries/$id'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        if (summary != null) 'summary': summary,
        if (keyPoints != null) 'key_points': keyPoints,
        if (actionItems != null) 'action_items': actionItems,
        if (keywords != null) 'keywords': keywords,
        if (category != null) 'category': category,
        if (mood != null) 'mood': mood,
        if (actionStatus != null) 'action_status': actionStatus,
      }),
    );
    _checkResponse(response);
    return RemoteSummary.fromJson(_decodeJson(response));
  }

  Future<void> deleteSummary(int id) async {
    final response = await _client.delete(
      _uri('/summaries/$id'),
      headers: _headers,
    );
    _checkResponse(response);
  }

  void _checkResponse(http.Response response) {
    debugPrint(
      '[VoMe API DEBUG] response ${response.request?.method ?? '<unknown>'} '
      '${response.request?.url ?? '<unknown URL>'} '
      'status=${response.statusCode} body=${response.body}',
    );
    if (response.statusCode == 401) {
      AuthService.instance.logout();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AudioApiException(response.statusCode, response.body);
    }
  }

  dynamic _decodeJson(http.Response response) => jsonDecode(response.body);
}
