import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vome/screens/login_screen.dart';
import 'package:vome/services/auth_service.dart';

import 'package:vome/main.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this.responses);

  final List<http.Response> responses;
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = responses[requestCount++];
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

class _FakeTokenStore implements AuthTokenStore {
  String? token;

  @override
  Future<String?> read({required String key}) async => token;

  @override
  Future<void> write({required String key, required String value}) async {
    token = value;
  }

  @override
  Future<void> delete({required String key}) async {
    token = null;
  }
}

Widget _loginApp(AuthService authService, {VoidCallback? onAuthenticated}) {
  return MaterialApp(
    home: LoginScreen(
      authService: authService,
      onAuthenticated: onAuthenticated,
    ),
  );
}

void main() {
  testWidgets('Audiary app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const AudiaryApp());
    await tester.pump();

    expect(find.text('Audiary'), findsOneWidget);
  });

  testWidgets('registration dialog opens and closes safely', (tester) async {
    await tester.pumpWidget(
      _loginApp(
        AuthService.forTesting(_FakeClient([]), tokenStore: _FakeTokenStore()),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('successful registration authenticates once', (tester) async {
    final client = _FakeClient([
      http.Response('{}', 201),
      http.Response('{"access_token":"token"}', 200),
    ]);
    var authenticated = 0;
    await tester.pumpWidget(
      _loginApp(
        AuthService.forTesting(client, tokenStore: _FakeTokenStore()),
        onAuthenticated: () => authenticated++,
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Test User');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(authenticated, 1);
    expect(client.requestCount, 2);
  });

  testWidgets('registration failure leaves the form usable', (tester) async {
    final client = _FakeClient([
      http.Response('{"detail":"Email exists"}', 409),
    ]);
    await tester.pumpWidget(
      _loginApp(AuthService.forTesting(client, tokenStore: _FakeTokenStore())),
    );
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Test User');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Email exists'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('invalid input prevents registration request', (tester) async {
    final client = _FakeClient([]);
    await tester.pumpWidget(
      _loginApp(AuthService.forTesting(client, tokenStore: _FakeTokenStore())),
    );
    await tester.enterText(find.byType(TextField).at(0), 'invalid');
    await tester.enterText(find.byType(TextField).at(1), 'short');
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(client.requestCount, 0);
  });

  testWidgets('repeated registration presses submit once', (tester) async {
    final client = _FakeClient([
      http.Response('{}', 201),
      http.Response('{"access_token":"token"}', 200),
    ]);
    await tester.pumpWidget(
      _loginApp(AuthService.forTesting(client, tokenStore: _FakeTokenStore())),
    );
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Test User');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(client.requestCount, 2);
  });
}
