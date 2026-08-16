import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/oauth/oauth_service.dart';

const _server = 'https://mtls.example.com';

/// A [Client] whose transport is a mock, so the authorize leg can be exercised
/// without a real mTLS edge.
class _TestableClient extends Client {
  final http.Client mock;

  _TestableClient({required super.base, required this.mock});

  @override
  http.Client createClient() => mock;
}

_TestableClient _client(http_testing.MockClient mock) =>
    _TestableClient(base: _server, mock: mock);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'uses the browser flow when no client certificate is selected',
    () async {
      final callbacks = StreamController<Uri>();
      late Uri launchedUrl;
      final service = OAuthService(
        launchAuthorizeUrl: (uri) async {
          launchedUrl = uri;
          return true;
        },
        callbackUris: () => callbacks.stream,
      );
      final client = _client(
        http_testing.MockClient((_) async {
          fail('browser authorization must not use the HTTP client');
        }),
      );

      final authorization = service.authorize(client, _server);
      await Future<void>.delayed(Duration.zero);
      callbacks.add(
        Uri.parse(
          'vikunja-flutter://callback?code=browser-code&state='
          '${launchedUrl.queryParameters['state']}',
        ),
      );

      expect(await authorization, 'browser-code');
      expect(launchedUrl.path, '/oauth/authorize');
      await callbacks.close();
    },
  );

  test('reports a browser launch failure', () async {
    final callbacks = StreamController<Uri>();
    final service = OAuthService(
      launchAuthorizeUrl: (_) async => false,
      callbackUris: () => callbacks.stream,
    );

    await expectLater(
      service.authorize(
        _client(http_testing.MockClient((_) async => http.Response('', 500))),
        _server,
      ),
      throwsA(
        isA<OAuthException>().having(
          (error) => error.error,
          'error',
          OAuthError.browserLaunchFailed,
        ),
      ),
    );
    await callbacks.close();
  });

  group('OAuthService.authorize (mTLS, no browser)', () {
    test('returns the code from the 302 callback redirect', () async {
      late Uri requested;
      final client = _client(
        http_testing.MockClient((req) async {
          requested = req.url;
          // Echo the state back, as the federator does.
          final state = req.url.queryParameters['state'];
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'vikunja-flutter://callback?code=the-code&state=$state',
            },
          );
        }),
      );

      final code = await OAuthService().authorize(
        client,
        _server,
        useClientTransport: true,
      );

      expect(code, 'the-code');
      // The authorize leg is issued over the app's transport, to the root
      // /oauth/authorize endpoint (not under /api/v1), with PKCE.
      expect(requested.path, '/oauth/authorize');
      expect(requested.queryParameters['client_id'], 'vikunja-flutter');
      expect(requested.queryParameters['response_type'], 'code');
      expect(requested.queryParameters['code_challenge_method'], 'S256');
      expect(requested.queryParameters['code_challenge'], isNotEmpty);
    });

    test(
      'throws stateMismatch when the callback state does not match',
      () async {
        final client = _client(
          http_testing.MockClient(
            (req) async => http.Response(
              '',
              302,
              headers: {
                'location': 'vikunja-flutter://callback?code=x&state=TAMPERED',
              },
            ),
          ),
        );

        await expectLater(
          OAuthService().authorize(client, _server, useClientTransport: true),
          throwsA(
            isA<OAuthException>().having(
              (e) => e.error,
              'error',
              OAuthError.stateMismatch,
            ),
          ),
        );
      },
    );

    // The certificate-gated authorize leg answered without a redirect: the
    // ext_authz Unauthorized deny of a missing/rejected client certificate.
    test(
      'throws noAuthorizationCode when the edge denies (no redirect)',
      () async {
        final client = _client(
          http_testing.MockClient(
            (req) async => http.Response('{"error":"Unauthorized"}', 403),
          ),
        );

        await expectLater(
          OAuthService().authorize(client, _server, useClientTransport: true),
          throwsA(
            isA<OAuthException>().having(
              (e) => e.error,
              'error',
              OAuthError.noAuthorizationCode,
            ),
          ),
        );
      },
    );

    test(
      'throws noAuthorizationCode when the redirect carries no code',
      () async {
        final client = _client(
          http_testing.MockClient(
            (req) async => http.Response(
              '',
              302,
              headers: {
                'location':
                    'vikunja-flutter://callback?state=${req.url.queryParameters['state']}',
              },
            ),
          ),
        );

        await expectLater(
          OAuthService().authorize(client, _server, useClientTransport: true),
          throwsA(
            isA<OAuthException>().having(
              (e) => e.error,
              'error',
              OAuthError.noAuthorizationCode,
            ),
          ),
        );
      },
    );

    test('preserves transport failures from the mTLS client', () async {
      final client = _client(
        http_testing.MockClient((_) async {
          throw StateError('TLS client certificate rejected');
        }),
      );

      await expectLater(
        OAuthService().authorize(client, _server, useClientTransport: true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'TLS client certificate rejected',
          ),
        ),
      );
    });
  });
}
