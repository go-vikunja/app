import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/token_lock.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';

import '../../helpers/mock_http_overrides.dart';

const _baseUrl = 'https://vikunja.example.com';

// -- Mocks --

class MockSettingsDatasource implements SettingsDatasource {
  String? token;
  String? refreshToken;

  @override
  Future<String?> getUserToken() async => token;
  @override
  Future<String?> getRefreshToken() async => refreshToken;
  @override
  Future<void> saveUserToken(String? t) async => token = t;
  @override
  Future<void> saveRefreshToken(String? t) async => refreshToken = t;
  @override
  Future<void> clearAuthData() async {
    token = null;
    refreshToken = null;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A Client subclass that accepts a mock http.Client.
class TestableClient extends Client {
  final http.Client mockHttpClient;

  TestableClient({required super.base, required this.mockHttpClient});

  @override
  http.Client createClient() => mockHttpClient;
}

TestableClient _createClient(
  MockSettingsDatasource settings,
  http.Client mockHttp,
) {
  final client = TestableClient(base: _baseUrl, mockHttpClient: mockHttp);
  client.settingsDatasource = settings;
  return client;
}

// -- Tests --

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Client.getHeaders', () {
    late MockSettingsDatasource settings;
    late TestableClient client;

    setUp(() {
      settings = MockSettingsDatasource();
      client = _createClient(
        settings,
        http_testing.MockClient((_) async => http.Response('', 200)),
      );
    });

    test('includes Bearer token when token is set', () async {
      settings.token = 'my-jwt-token';
      final headers = await client.getHeaders();
      expect(headers['Authorization'], 'Bearer my-jwt-token');
    });

    test('omits Authorization header when token is null', () async {
      settings.token = null;
      final headers = await client.getHeaders();
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('omits Authorization header when token is empty', () async {
      settings.token = '';
      final headers = await client.getHeaders();
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('always includes Content-Type and User-Agent', () async {
      settings.token = null;
      final headers = await client.getHeaders();
      expect(headers['Content-Type'], 'application/json');
      expect(headers['User-Agent'], isNotEmpty);
    });
  });

  group('Client._handleResponseWithRefresh', () {
    late MockSettingsDatasource settings;
    late int requestCount;

    setUp(() {
      settings = MockSettingsDatasource();
      requestCount = 0;
    });

    test('returns success response directly on 200', () async {
      final client = _createClient(
        settings,
        http_testing.MockClient((_) async {
          requestCount++;
          return http.Response('{"id": 1}', 200);
        }),
      );

      final response = await client.get(
        url: '/test',
        mapper: (body) => body['id'] as int,
      );

      expect(response.isSuccessful, isTrue);
      expect(response.toSuccess().body, 1);
      expect(requestCount, 1);
    });

    test('retries on 401 with code 11 after successful refresh', () async {
      settings.token = 'old-token';
      settings.refreshToken = 'valid-refresh';

      final tempDir = await Directory.systemTemp.createTemp('refresh_test_');
      TokenLock.setLockDirectory(tempDir);

      // Set up HttpOverrides so tryRefreshToken's _createIOClient works
      installMockHttpClient((_, _, _) {
        return http.Response(
          jsonEncode({
            'access_token': 'new-token',
            'refresh_token': 'new-refresh',
          }),
          200,
        );
      });

      final client = _createClient(
        settings,
        http_testing.MockClient((_) async {
          requestCount++;
          if (requestCount == 1) {
            return http.Response(
              jsonEncode({'code': 11, 'message': 'token expired'}),
              401,
            );
          }
          return http.Response('{"id": 42}', 200);
        }),
      );

      final response = await client.get(
        url: '/test',
        mapper: (body) => body['id'] as int,
      );

      expect(response.isSuccessful, isTrue);
      expect(response.toSuccess().body, 42);
      expect(requestCount, 2);
      expect(settings.token, 'new-token');
      expect(settings.refreshToken, 'new-refresh');

      TokenLock.setLockDirectory(null);
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('does not retry on 401 without code 11', () async {
      final client = _createClient(
        settings,
        http_testing.MockClient((_) async {
          requestCount++;
          return http.Response(
            jsonEncode({'code': 3, 'message': 'forbidden'}),
            401,
          );
        }),
      );

      final response = await client.get<void>(url: '/test');

      expect(response.isError, isTrue);
      expect(requestCount, 1);
    });

    test('returns error when refresh fails', () async {
      settings.refreshToken = null;

      final client = _createClient(
        settings,
        http_testing.MockClient((_) async {
          requestCount++;
          return http.Response(
            jsonEncode({'code': 11, 'message': 'token expired'}),
            401,
          );
        }),
      );

      final response = await client.get<void>(url: '/test');

      expect(response.isError, isTrue);
      expect(requestCount, 1);
    });
  });

  group('Client.tryRefreshToken', () {
    late MockSettingsDatasource settings;
    late TestableClient client;
    late Directory tempDir;

    setUp(() async {
      settings = MockSettingsDatasource();
      client = _createClient(
        settings,
        http_testing.MockClient((_) async => http.Response('', 200)),
      );
      tempDir = await Directory.systemTemp.createTemp('client_test_');
      TokenLock.setLockDirectory(tempDir);
    });

    tearDown(() async {
      TokenLock.setLockDirectory(null);
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('returns false when refresh token is null', () async {
      settings.refreshToken = null;
      expect(await client.tryRefreshToken(), isFalse);
    });

    test('returns false when refresh token is empty', () async {
      settings.refreshToken = '';
      expect(await client.tryRefreshToken(), isFalse);
    });

    test('saves new tokens on successful refresh', () async {
      settings.refreshToken = 'old-refresh';

      installMockHttpClient((url, _, _) {
        expect(url.path, contains('/oauth/token'));
        return http.Response(
          jsonEncode({
            'access_token': 'fresh-access',
            'refresh_token': 'fresh-refresh',
          }),
          200,
        );
      });

      final result = await client.tryRefreshToken();

      expect(result, isTrue);
      expect(settings.token, 'fresh-access');
      expect(settings.refreshToken, 'fresh-refresh');
    });

    test('returns false on non-200 response', () async {
      settings.refreshToken = 'old-refresh';

      installMockHttpClient((_, _, _) {
        return http.Response(
          jsonEncode({'code': 17004, 'message': 'invalid token'}),
          400,
        );
      });

      final result = await client.tryRefreshToken();

      expect(result, isFalse);
      // Tokens should not be updated
      expect(settings.token, isNull);
    });

    test('returns false when response has empty access_token', () async {
      settings.refreshToken = 'old-refresh';

      installMockHttpClient((_, _, _) {
        return http.Response(
          jsonEncode({'access_token': '', 'refresh_token': 'new-refresh'}),
          200,
        );
      });

      final result = await client.tryRefreshToken();

      expect(result, isFalse);
    });

    test('sends correct JSON body with grant_type and refresh_token', () async {
      settings.refreshToken = 'my-refresh-token';
      String? capturedBody;

      installMockHttpClient((_, _, body) {
        capturedBody = body;
        return http.Response(
          jsonEncode({'access_token': 'new', 'refresh_token': 'new-refresh'}),
          200,
        );
      });

      await client.tryRefreshToken();

      expect(capturedBody, isNotNull);
      final parsed = jsonDecode(capturedBody!);
      expect(parsed['grant_type'], 'refresh_token');
      expect(parsed['refresh_token'], 'my-refresh-token');
    });
  });

  group('Client.postUnauthenticated', () {
    test('sends request without Authorization header', () async {
      final mockSettings = MockSettingsDatasource()
        ..token = 'should-not-be-sent';

      final client = _createClient(
        mockSettings,
        http_testing.MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect(request.headers['Content-Type'], 'application/json');
          expect(request.headers['User-Agent'], isNotEmpty);
          return http.Response('{"ok": true}', 200);
        }),
      );

      final response = await client.postUnauthenticated(
        url: '/oauth/token',
        body: {'grant_type': 'authorization_code'},
      );

      expect(response.statusCode, 200);
    });
  });
}
