import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const _tokenKey = 'audiary_access_token';
  static const _storage = FlutterSecureStorage();
  static const defaultBaseUrl = String.fromEnvironment(
    'AUDIARY_API_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  String? _token;

  String? get token => _token;
  bool get isAuthenticated => _token != null;

  Future<bool> restoreSession() async {
    _token = await _storage.read(key: _tokenKey);
    return _token != null;
  }

  Future<void> login({
    required String email,
    required String password,
    String baseUrl = defaultBaseUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw AuthException(_message(response));
    }
    await _saveToken(
      (jsonDecode(response.body) as Map<String, dynamic>)['access_token']
          as String,
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String baseUrl = defaultBaseUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
      }),
    );
    if (response.statusCode != 201) {
      throw AuthException(_message(response));
    }
    await login(email: email, password: password, baseUrl: baseUrl);
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  String _message(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['detail']?.toString() ?? 'Authentication failed';
    } catch (_) {
      return 'Unable to reach the backend';
    }
  }
}
