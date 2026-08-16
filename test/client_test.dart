import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/token_lock.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/server_data_source.dart';
import 'package:vikunja_app/main.dart' show globalNavigatorKey;

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

class CloseTrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
  }

  @override
  void close() {
    closed = true;
  }
}

// -- Tests --

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildOkHttpConfiguration', () {
    test('returns a plain configuration when alias is null', () async {
      var loaderCalled = false;
      final config = await buildOkHttpConfiguration(
        null,
        loadFromAlias: (alias) async {
          loaderCalled = true;
          throw StateError('should not be called');
        },
      );

      expect(loaderCalled, isFalse);
      expect(config.clientPrivateKey, isNull);
      expect(config.clientCertificateChain, isNull);
      expect(config.validateServerCertificates, isTrue);
    });

    test('can disable server certificate validation', () async {
      final config = await buildOkHttpConfiguration(
        null,
        validateServerCertificates: false,
      );

      expect(config.validateServerCertificates, isFalse);
    });

    test(
      'falls back to a plain configuration when the alias fails to load',
      () async {
        final config = await buildOkHttpConfiguration(
          'missing-alias',
          loadFromAlias: (alias) async {
            throw Exception('alias not found in Keystore');
          },
        );

        expect(config.clientPrivateKey, isNull);
        expect(config.clientCertificateChain, isNull);
      },
    );

    // Regression test: this catch used to report only via `developer.log`,
    // which never reaches logcat, so a certificate that failed to load looked
    // exactly like one that loaded fine. Recovering from an error is allowed;
    // recovering silently is not.
    test('logs the error when the alias fails to load', () async {
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) =>
          printed.add(message ?? '');
      addTearDown(() => debugPrint = original);

      await buildOkHttpConfiguration(
        'missing-alias',
        loadFromAlias: (alias) async {
          throw Exception('alias not found in Keystore');
        },
      );

      expect(printed, isNotEmpty);
      expect(printed.single, contains('missing-alias'));
      expect(printed.single, contains('alias not found in Keystore'));
    });

    // Regression test: the loader used to be synchronous, which forced the
    // Keystore read onto the platform thread, where `KeyChain.getPrivateKey`
    // throws "calling this from your main thread can lead to deadlock". The
    // failure was swallowed by the fallback above, so a selected certificate
    // silently never got presented. An async loader is what lets the read run
    // on another isolate — and therefore another thread.
    test('awaits a loader that completes asynchronously', () async {
      var loaded = false;
      await buildOkHttpConfiguration(
        'slow-alias',
        loadFromAlias: (alias) async {
          await Future<void>.delayed(Duration.zero);
          loaded = true;
          throw Exception('no Keystore in a unit test');
        },
      );

      expect(loaded, isTrue);
    });
  });

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
    late Directory tempDir;

    setUp(() async {
      settings = MockSettingsDatasource();
      requestCount = 0;
      tempDir = await Directory.systemTemp.createTemp('refresh_retry_test_');
      TokenLock.setLockDirectory(tempDir);
    });

    tearDown(() async {
      TokenLock.setLockDirectory(null);
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
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

      final client = _createClient(
        settings,
        http_testing.MockClient((request) async {
          if (request.url.path.endsWith('/oauth/token')) {
            expect(request.method, 'POST');
            expect(request.body, contains('valid-refresh'));
            return http.Response(
              jsonEncode({
                'access_token': 'new-token',
                'refresh_token': 'new-refresh',
              }),
              200,
            );
          }

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
    late Directory tempDir;

    setUp(() async {
      settings = MockSettingsDatasource();
      tempDir = await Directory.systemTemp.createTemp('client_test_');
      TokenLock.setLockDirectory(tempDir);
    });

    tearDown(() async {
      TokenLock.setLockDirectory(null);
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('returns false when refresh token is null', () async {
      settings.refreshToken = null;
      final client = _createClient(
        settings,
        http_testing.MockClient((_) async => http.Response('', 500)),
      );
      expect(await client.tryRefreshToken(), isFalse);
    });

    test('returns false when refresh token is empty', () async {
      settings.refreshToken = '';
      final client = _createClient(
        settings,
        http_testing.MockClient((_) async => http.Response('', 500)),
      );
      expect(await client.tryRefreshToken(), isFalse);
    });

    test('uses the configured client and saves tokens on refresh', () async {
      settings.refreshToken = 'old-refresh';

      final client = _createClient(
        settings,
        http_testing.MockClient((request) async {
          expect(request.url.path, contains('/oauth/token'));
          return http.Response(
            jsonEncode({
              'access_token': 'fresh-access',
              'refresh_token': 'fresh-refresh',
            }),
            200,
          );
        }),
      );

      final result = await client.tryRefreshToken();

      expect(result, isTrue);
      expect(settings.token, 'fresh-access');
      expect(settings.refreshToken, 'fresh-refresh');
    });

    test('returns false on non-200 response', () async {
      settings.refreshToken = 'old-refresh';

      final client = _createClient(
        settings,
        http_testing.MockClient((request) async {
          return http.Response(
            jsonEncode({'code': 17004, 'message': 'invalid token'}),
            400,
          );
        }),
      );

      final result = await client.tryRefreshToken();

      expect(result, isFalse);
      // Tokens should not be updated
      expect(settings.token, isNull);
    });

    test('returns false when response has empty access_token', () async {
      settings.refreshToken = 'old-refresh';

      final client = _createClient(
        settings,
        http_testing.MockClient((request) async {
          return http.Response(
            jsonEncode({'access_token': '', 'refresh_token': 'new-refresh'}),
            200,
          );
        }),
      );

      final result = await client.tryRefreshToken();

      expect(result, isFalse);
    });

    test('sends correct JSON body with grant_type and refresh_token', () async {
      settings.refreshToken = 'my-refresh-token';
      String? capturedBody;

      final client = _createClient(
        settings,
        http_testing.MockClient((request) async {
          capturedBody = request.body;
          return http.Response(
            jsonEncode({'access_token': 'new', 'refresh_token': 'new-refresh'}),
            200,
          );
        }),
      );

      await client.tryRefreshToken();

      expect(capturedBody, isNotNull);
      final parsed = jsonDecode(capturedBody!);
      expect(parsed['grant_type'], 'refresh_token');
      expect(parsed['refresh_token'], 'my-refresh-token');
    });
  });

  group('Client.getRaw', () {
    test(
      'uses the configured client with authentication for binary data',
      () async {
        final settings = MockSettingsDatasource()..token = 'binary-token';
        final expectedBytes = <int>[0, 1, 2, 255];
        final client = _createClient(
          settings,
          http_testing.MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/v1/tasks/1/attachments/2');
            expect(request.headers['Authorization'], 'Bearer binary-token');
            return http.Response.bytes(expectedBytes, 200);
          }),
        );

        final response = await client.getRaw(url: '/tasks/1/attachments/2');

        expect(response.bodyBytes, expectedBytes);
      },
    );
  });

  testWidgets('server info 401 does not push another login route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: globalNavigatorKey,
        home: const SizedBox(),
        routes: {'/login': (_) => const SizedBox(key: ValueKey('login-route'))},
      ),
    );
    final client = _createClient(
      MockSettingsDatasource(),
      http_testing.MockClient((_) async => http.Response('Unauthorized', 401)),
    );

    final response = await ServerDataSource(client).getInfo();
    await tester.pumpAndSettle();

    expect(response.toError().statusCode, 401);
    expect(response.toError().error, {'message': 'Unauthorized'});
    expect(find.byKey(const ValueKey('login-route')), findsNothing);
  });

  test('Client.close closes its configured transport', () {
    final transport = CloseTrackingClient();
    final client = _createClient(MockSettingsDatasource(), transport);

    client.close();

    expect(transport.closed, isTrue);
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
