import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class ProcessingApiClient {
  ProcessingApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = String.fromEnvironment('VOME_API_BASE_URL');
  static const _token = String.fromEnvironment('VOME_API_TOKEN');
  final http.Client _client;

  bool get isConfigured => _baseUrl.isNotEmpty && _token.isNotEmpty;

  Future<String> createJob({
    required String recordingId,
    required String audioPath,
    required String title,
    required String eventType,
  }) async {
    _requireConfiguration();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/v1/processing-jobs'),
    )
      ..headers['Authorization'] = 'Bearer $_token'
      ..fields.addAll({
        'recording_id': recordingId,
        'title': title,
        'event_type': eventType,
      })
      ..files.add(await http.MultipartFile.fromPath('audio', audioPath, filename: p.basename(audioPath)));

    final response = await http.Response.fromStream(await request.send());
    final body = _decode(response);
    if (response.statusCode != 202) {
      throw ProcessingApiException(body['detail']?.toString() ?? 'Unable to create processing job');
    }
    return body['job_id'] as String;
  }

  Future<ProcessingJobStatus> getJob(String jobId) async {
    _requireConfiguration();
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/processing-jobs/$jobId'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ProcessingApiException(body['detail']?.toString() ?? 'Unable to check processing job');
    }
    return ProcessingJobStatus.fromJson(body);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void _requireConfiguration() {
    if (!isConfigured) {
      throw ProcessingApiException('Processing is not configured. Set VOME_API_BASE_URL and VOME_API_TOKEN.');
    }
  }
}

class ProcessingJobStatus {
  const ProcessingJobStatus({
    required this.status,
    this.transcript,
    this.summary,
    this.error,
  });

  final String status;
  final String? transcript;
  final Map<String, dynamic>? summary;
  final String? error;

  factory ProcessingJobStatus.fromJson(Map<String, dynamic> json) => ProcessingJobStatus(
        status: json['status'] as String,
        transcript: json['transcript'] as String?,
        summary: json['summary'] as Map<String, dynamic>?,
        error: json['error'] as String?,
      );

  bool get isTerminal => status == 'completed' || status == 'failed';
}

class ProcessingApiException implements Exception {
  const ProcessingApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
