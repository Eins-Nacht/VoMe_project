import 'audio_api_service.dart';
import 'auth_service.dart';

class RemoteSummaryService {
  RemoteSummaryService._();

  static final instance = RemoteSummaryService._();

  AudioApiService? get api {
    final token = AuthService.instance.token;
    return token == null
        ? null
        : AudioApiService(
            baseUrl: AuthService.defaultBaseUrl,
            accessToken: token,
          );
  }
}
