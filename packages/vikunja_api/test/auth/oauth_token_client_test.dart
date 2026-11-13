import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/jwt.dart';

const _v2Endpoint = 'https://tasks.example.com/vikunja/api/v2/oauth/token';
const _v1Endpoint = 'https://tasks.example.com/vikunja/api/v1/oauth/token';

ServerConnection _connection({required bool hasV2}) {
  final info = ServerInfo(
    version: hasV2
        ? const ServerVersion(2, 7, 0)
        : const ServerVersion(2, 3, 0),
  );
  final apiVersions = {ApiVersion.v1, if (hasV2) ApiVersion.v2};
  return ServerConnection(
    rootUri: Uri.parse('https://tasks.example.com/vikunja'),
    apiVersions: apiVersions,
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: apiVersions,
    ),
  );
}

final _client = OAuthClientConfig(
  clientId: 'vikunja-io.vikunja.app',
  redirectUri: Uri.parse('vikunja-io.vikunja.app://oauth/callback'),
);

final _request = AuthorizationRequest(
  url: Uri.parse('https://tasks.example.com/vikunja/oauth/authorize'),
  state: 'state',
  codeVerifier: 'verifier-verifier-verifier-verifier-verifie',
  client: _client,
);

final _issuedAt = DateTime.utc(2026, 10, 9, 8);
final _expiresAt = DateTime.utc(2026, 10, 9, 8, 5);
final String _refreshToken = 'f' * 256;

FakeRoute _tokens({
  String? accessToken,
  Object? refreshToken,
  Object? expiresIn = 600,
  Object? tokenType = 'bearer',
}) => json({
  r'$schema': 'https://tasks.example.com/api/v2/schemas/TokenResponse.json',
  'access_token':
      accessToken ??
      fakeJwt(sid: 'sid-1', issuedAt: _issuedAt, expiresAt: _expiresAt),
  'token_type': tokenType,
  'expires_in': expiresIn,
  'refresh_token': refreshToken ?? _refreshToken,
});

void main() {
  group('endpoint and body', () {
    test('exchanges the code at /api/v2 as JSON', () async {
      final dio = fakeDio({_v2Endpoint: _tokens()});
      final client = OAuthTokenClient(dio, _connection(hasV2: true));

      final tokens = await client.exchangeCode(code: 'c0de', request: _request);

      final sent = adapterOf(dio).requests.single;
      expect(sent.method, 'POST');
      expect(sent.contentType, startsWith('application/json'));
      expect(sent.data, {
        'grant_type': 'authorization_code',
        'code': 'c0de',
        'client_id': 'vikunja-io.vikunja.app',
        'redirect_uri': 'vikunja-io.vikunja.app://oauth/callback',
        'code_verifier': _request.codeVerifier,
      });
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(
        tokens,
        TokenSet(
          accessToken: tokens.accessToken,
          refreshToken: _refreshToken,
          accessTokenExpiry: _expiresAt,
          issuedAt: _issuedAt,
          sessionId: 'sid-1',
          userId: 7,
          username: 'alice',
        ),
      );
    });

    test('refreshes at /api/v1 on a server without /api/v2', () async {
      final dio = fakeDio({_v1Endpoint: _tokens()});
      final client = OAuthTokenClient(dio, _connection(hasV2: false));

      await client.refresh('old-refresh-token');

      expect(adapterOf(dio).requests.single.data, {
        'grant_type': 'refresh_token',
        'refresh_token': 'old-refresh-token',
      });
    });

    test('token requests get the configured timeout', () async {
      final dio = fakeDio({_v2Endpoint: _tokens()});
      final client = OAuthTokenClient(
        dio,
        _connection(hasV2: true),
        timeout: const Duration(seconds: 90),
      );

      await client.refresh('r');

      final sent = adapterOf(dio).requests.single;
      expect(sent.receiveTimeout, const Duration(seconds: 90));
      expect(sent.sendTimeout, const Duration(seconds: 90));
      expect(sent.cancelToken, isNull);
    });
  });

  group('token response', () {
    test('expiry comes from the JWT, not from expires_in', () async {
      final dio = fakeDio({_v2Endpoint: _tokens(expiresIn: 3600)});

      final tokens = await OAuthTokenClient(
        dio,
        _connection(hasV2: true),
      ).refresh('r');

      expect(tokens.accessTokenExpiry, _expiresAt);
      expect(tokens.issuedAt, _issuedAt);
    });

    test('without iat, issuedAt is exp minus expires_in', () async {
      final dio = fakeDio({
        _v1Endpoint: _tokens(
          accessToken: fakeJwt(expiresAt: _expiresAt, withIssuedAt: false),
        ),
      });

      final tokens = await OAuthTokenClient(
        dio,
        _connection(hasV2: false),
      ).refresh('r');

      expect(tokens.issuedAt, _expiresAt.subtract(const Duration(minutes: 10)));
    });

    test(
      'without iat and expires_in, the default lifetime is assumed',
      () async {
        final dio = fakeDio({
          _v1Endpoint: _tokens(
            accessToken: fakeJwt(expiresAt: _expiresAt, withIssuedAt: false),
            expiresIn: null,
          ),
        });

        final tokens = await OAuthTokenClient(
          dio,
          _connection(hasV2: false),
        ).refresh('r');

        expect(
          tokens.issuedAt,
          _expiresAt.subtract(const Duration(minutes: 10)),
        );
      },
    );

    for (final (description, route) in [
      ('no refresh token', _tokens(refreshToken: 42)),
      ('an empty refresh token', _tokens(refreshToken: '')),
      ('another token type', _tokens(tokenType: 'mac')),
      ('a link share access token', _tokens(accessToken: fakeJwt(type: 2))),
      ('an API token', _tokens(accessToken: 'tk_0123')),
      ('a JSON array', json([1, 2])),
      ('an HTML page', html('<html></html>')),
    ]) {
      test('$description is an unexpected response', () async {
        final dio = fakeDio({_v2Endpoint: route});

        await expectLater(
          OAuthTokenClient(dio, _connection(hasV2: true)).refresh('r'),
          throwsA(
            isA<UnexpectedResponse>()
                .having((f) => f.statusCode, 'status', 200)
                .having((f) => f.message, 'message', isNot(contains('tk_'))),
          ),
        );
      });
    }
  });

  group('code exchange failures', () {
    for (final (fixture, problem) in [
      ('v2_oauth_17001_client_mismatch_2.7.0', OAuthProblem.clientMismatch),
      (
        'v2_oauth_17002_redirect_mismatch_2.4.0',
        OAuthProblem.invalidRedirectUri,
      ),
      ('v2_oauth_17004_code_used_2.7.0', OAuthProblem.codeInvalid),
      ('v2_oauth_17006_pkce_mismatch_2.4.0', OAuthProblem.pkceMismatch),
      ('v2_oauth_17007_grant_2.7.0', OAuthProblem.unsupportedGrant),
    ]) {
      test(fixture, () async {
        final dio = fakeDio({_v2Endpoint: errorFixture(fixture)});

        await expectLater(
          OAuthTokenClient(
            dio,
            _connection(hasV2: true),
          ).exchangeCode(code: 'c', request: _request),
          throwsA(
            isA<OAuthFailure>().having((f) => f.problem, 'problem', problem),
          ),
        );
      });
    }

    for (final (fixture, problem) in [
      ('v1_oauth_17004_code_used_2.3.0', OAuthProblem.codeInvalid),
      ('v1_oauth_17006_pkce_mismatch_2.3.0', OAuthProblem.pkceMismatch),
    ]) {
      test(fixture, () async {
        final dio = fakeDio({_v1Endpoint: errorFixture(fixture)});

        await expectLater(
          OAuthTokenClient(
            dio,
            _connection(hasV2: false),
          ).exchangeCode(code: 'c', request: _request),
          throwsA(
            isA<OAuthFailure>().having((f) => f.problem, 'problem', problem),
          ),
        );
      });
    }

    test('a base Dio that accepts every status still fails', () async {
      final dio = fakeDio({
        _v2Endpoint: errorFixture('v2_oauth_17004_code_used_2.7.0'),
      })..options.validateStatus = (_) => true;

      await expectLater(
        OAuthTokenClient(
          dio,
          _connection(hasV2: true),
        ).exchangeCode(code: 'c', request: _request),
        throwsA(isA<OAuthFailure>()),
      );
    });

    test('a redirect is not followed', () async {
      final dio = fakeDio({
        _v2Endpoint: redirect(
          'http://tasks.example.com/vikunja/api/v2/oauth/token',
          status: 308,
        ),
      });

      await expectLater(
        OAuthTokenClient(
          dio,
          _connection(hasV2: true),
        ).exchangeCode(code: 'c', request: _request),
        throwsA(
          isA<UnexpectedResponse>().having((f) => f.statusCode, 'status', 308),
        ),
      );
      expect(adapterOf(dio).requests.single.followRedirects, isFalse);
    });

    test('the network failing is a network failure', () async {
      final dio = fakeDio({});

      await expectLater(
        OAuthTokenClient(
          dio,
          _connection(hasV2: true),
        ).exchangeCode(code: 'c', request: _request),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('refresh failures', () {
    Future<void> expectRefreshFailure(
      FakeRoute route,
      Matcher matcher, {
      bool hasV2 = true,
    }) async {
      final dio = fakeDio({hasV2 ? _v2Endpoint : _v1Endpoint: route});
      await expectLater(
        OAuthTokenClient(dio, _connection(hasV2: hasV2)).refresh('r'),
        throwsA(matcher),
      );
    }

    TypeMatcher<SessionEnded> sessionEnded(
      SessionEndReason reason, {
      int? code,
    }) => isA<SessionEnded>()
        .having((f) => f.reason, 'reason', reason)
        .having((f) => f.code, 'code', code);

    test('2.7.0 says 16002 for an unknown or rotated token', () async {
      await expectRefreshFailure(
        errorFixture('v2_refresh_invalid_2.7.0'),
        sessionEnded(SessionEndReason.invalidRefreshToken, code: 16002),
      );
    });

    for (final (fixture, hasV2) in [
      ('v1_refresh_invalid_2.3.0', false),
      ('v1_refresh_race_401_2.3.0', false),
      ('v2_refresh_invalid_2.4.0', true),
    ]) {
      test('$fixture: an uncoded 401 ends the session', () async {
        await expectRefreshFailure(
          errorFixture(fixture),
          sessionEnded(SessionEndReason.invalidRefreshToken).having(
            (f) => f.message,
            'message',
            'Invalid or expired refresh token.',
          ),
          hasV2: hasV2,
        );
      });
    }

    test('a rotation race lost on SQLite is a server failure', () async {
      await expectRefreshFailure(
        errorFixture('v2_refresh_race_500_2.7.0'),
        isA<ServerFailure>().having((f) => f.statusCode, 'status', 500),
      );
    });

    test('the 2.3.0 limiter is rate limiting with its reset time', () async {
      await expectRefreshFailure(
        errorFixture('v1_429_oauth_token_2.3.0'),
        isA<RateLimited>().having(
          (f) => f.retryAfter,
          'retryAfter',
          const Duration(seconds: 60),
        ),
        hasV2: false,
      );
    });

    test('a redirect is not followed and does not end the session', () async {
      final dio = fakeDio({
        _v2Endpoint: redirect(
          'http://tasks.example.com/vikunja/api/v2/oauth/token',
          status: 308,
        ),
      });

      await expectLater(
        OAuthTokenClient(dio, _connection(hasV2: true)).refresh('r'),
        throwsA(
          isA<UnexpectedResponse>().having((f) => f.statusCode, 'status', 308),
        ),
      );
      expect(adapterOf(dio).requests.single.followRedirects, isFalse);
    });

    test('16003 is an expired session', () async {
      await expectRefreshFailure(
        json({'code': 16003, 'message': 'Session expired.'}, status: 401),
        sessionEnded(SessionEndReason.expired, code: 16003),
      );
    });

    test('16004 lost the rotation race', () async {
      await expectRefreshFailure(
        json({
          'code': 16004,
          'message': 'Refresh token already used.',
        }, status: 401),
        isA<RefreshRaceLost>(),
      );
    });

    for (final (code, reason) in [
      (1020, SessionEndReason.accountDisabled),
      (1040, SessionEndReason.accountLocked),
      (1026, SessionEndReason.accountLocked),
    ]) {
      test('412 code $code ends the session', () async {
        await expectRefreshFailure(
          json({'code': code, 'message': 'x'}, status: 412),
          sessionEnded(reason, code: code),
        );
      });
    }

    test('a 401 with an unknown code ends the session', () async {
      await expectRefreshFailure(
        json({'code': 16099, 'message': 'x'}, status: 401),
        sessionEnded(SessionEndReason.invalidRefreshToken, code: 16099),
      );
    });

    test('an uncoded 401 at the code exchange is not a session end', () async {
      final dio = fakeDio({
        _v2Endpoint: json({'message': 'nope'}, status: 401),
      });

      await expectLater(
        OAuthTokenClient(
          dio,
          _connection(hasV2: true),
        ).exchangeCode(code: 'c', request: _request),
        throwsA(isA<UnexpectedResponse>()),
      );
    });
  });
}
