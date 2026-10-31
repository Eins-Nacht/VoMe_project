import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

abstract interface class AuthTokenStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class _SecureAuthTokenStore implements AuthTokenStore {
  const _SecureAuthTokenStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class AuthService {
  AuthService._({http.Client? client, AuthTokenStore? tokenStore})
    : _client = client ?? http.Client(),
      _tokenStore = tokenStore ?? const _SecureAuthTokenStore();

  static final AuthService instance = AuthService._();
  static const _tokenKey = 'audiary_access_token';
  static const defaultBaseUrl = String.fromEnvironment(
    'AUDIARY_API_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  AuthService.forTesting(
    http.Client client, {
    required AuthTokenStore tokenStore,
  }) : this._(client: client, tokenStore: tokenStore);

  final http.Client _client;
  final AuthTokenStore _tokenStore;
  String? _token;
  String? _displayName;

  String? get token => _token;
  String? get displayName => _displayName;
  bool get isAuthenticated => _token != null;

  Future<bool> restoreSession() async {
    _token = await _tokenStore.read(key: _tokenKey);
    return _token != null;
  }

  Future<void> login({
    required String email,
    required String password,
    String baseUrl = defaultBaseUrl,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw AuthException(_message(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final responseDisplayName = body['display_name'] as String?;
    if (responseDisplayName != null && responseDisplayName.trim().isNotEmpty) {
      _displayName = responseDisplayName.trim();
    }
    await _saveToken(body['access_token'] as String);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String baseUrl = defaultBaseUrl,
  }) async {
    final response = await _client.post(
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
    _displayName = displayName.trim();
    await login(email: email, password: password, baseUrl: baseUrl);
  }

  Future<void> logout() async {
    _token = null;
    _displayName = null;
    await _tokenStore.delete(key: _tokenKey);
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    await _tokenStore.write(key: _tokenKey, value: token);
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
