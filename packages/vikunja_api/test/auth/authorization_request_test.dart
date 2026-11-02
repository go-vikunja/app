import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/auth/pkce.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final _client = OAuthClientConfig(
  clientId: 'dev.coderoftime.rurana',
  redirectUri: Uri.parse('vikunja-dev.coderoftime.rurana://oauth/callback'),
);

ServerConnection _connection({
  String root = 'https://tasks.example.com',
  String? frontendUrl,
}) {
  final info = ServerInfo(
    version: const ServerVersion(2, 7, 0),
    frontendUrl: frontendUrl == null ? null : Uri.parse(frontendUrl),
  );
  const apiVersions = {ApiVersion.v1, ApiVersion.v2};
  return ServerConnection(
    rootUri: Uri.parse(root),
    apiVersions: apiVersions,
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: apiVersions,
    ),
  );
}

void main() {
  group('AuthorizationRequest.create', () {
    test('opens the web app authorize page with PKCE S256', () {
      final request = AuthorizationRequest.create(
        _connection(frontendUrl: 'https://tasks.example.com/'),
        _client,
      );

      expect(request.url.scheme, 'https');
      expect(request.url.host, 'tasks.example.com');
      expect(request.url.path, '/oauth/authorize');
      expect(request.url.queryParameters, {
        'response_type': 'code',
        'client_id': 'dev.coderoftime.rurana',
        'redirect_uri': 'vikunja-dev.coderoftime.rurana://oauth/callback',
        'state': request.state,
        'code_challenge': codeChallengeS256(request.codeVerifier),
        'code_challenge_method': 'S256',
      });
      expect(
        request.url.query,
        contains(
          'redirect_uri=vikunja-dev.coderoftime.rurana'
          '%3A%2F%2Foauth%2Fcallback',
        ),
      );
      expect(request.codeVerifier, hasLength(43));
      expect(request.state, hasLength(22));
      expect(request.client, same(_client));
    });

    for (final (frontendUrl, root, expected) in [
      (
        'https://web.example.com/vikunja/',
        'https://api.example.com',
        'https://web.example.com/vikunja/oauth/authorize',
      ),
      (
        'http://localhost:34527/',
        'http://localhost:34527',
        'http://localhost:34527/oauth/authorize',
      ),
      (
        'https://tasks.example.com/sub',
        'https://tasks.example.com/sub',
        'https://tasks.example.com/sub/oauth/authorize',
      ),
      (
        null,
        'https://tasks.example.com/apps/todo',
        'https://tasks.example.com/apps/todo/oauth/authorize',
      ),
      (
        null,
        'http://192.168.1.5:3456',
        'http://192.168.1.5:3456/oauth/authorize',
      ),
      (
        'http://vikunja.example.com/',
        'https://vikunja.example.com',
        'https://vikunja.example.com/oauth/authorize',
      ),
      (
        'http://192.168.1.5:3456/',
        'https://vikunja.example.com',
        'https://vikunja.example.com/oauth/authorize',
      ),
      (
        'http://tasks.example.com/apps/todo/',
        'https://tasks.example.com/apps/todo',
        'https://tasks.example.com/apps/todo/oauth/authorize',
      ),
    ]) {
      test('frontend $frontendUrl at root $root', () {
        final request = AuthorizationRequest.create(
          _connection(root: root, frontendUrl: frontendUrl),
          _client,
        );

        expect(request.url.replace(query: '').toString(), '$expected?');
      });
    }

    test('every attempt has its own verifier and state', () {
      final connection = _connection();
      final first = AuthorizationRequest.create(connection, _client);
      final second = AuthorizationRequest.create(connection, _client);

      expect(second.codeVerifier, isNot(first.codeVerifier));
      expect(second.state, isNot(first.state));
    });

    test('a redirect scheme Vikunja would refuse is a programming error', () {
      expect(
        () => AuthorizationRequest.create(
          _connection(),
          OAuthClientConfig(
            clientId: 'x',
            redirectUri: Uri.parse('dev.coderoftime.rurana://oauth/callback'),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('toString shows neither verifier nor state', () {
      final request = AuthorizationRequest.create(_connection(), _client);

      expect('$request', isNot(contains(request.codeVerifier)));
      expect('$request', isNot(contains(request.state)));
    });
  });

  group('codeFromCallback', () {
    late AuthorizationRequest request;

    setUp(() => request = AuthorizationRequest.create(_connection(), _client));

    Uri callback(Map<String, String> parameters, {String? base}) =>
        Uri.parse(base ?? 'vikunja-dev.coderoftime.rurana://oauth/callback')
            .replace(queryParameters: parameters);

    Matcher throwsProblem(AuthorizationCallbackProblem problem) => throwsA(
      isA<AuthorizationCallbackException>().having(
        (e) => e.problem,
        'problem',
        problem,
      ),
    );

    test('returns the code of the redirect the web app builds', () {
      expect(
        request.codeFromCallback(
          callback({'code': 'the-code', 'state': request.state}),
        ),
        'the-code',
      );
    });

    test('the scheme and host compare case-insensitively', () {
      expect(
        request.codeFromCallback(
          callback({
            'code': 'c',
            'state': request.state,
          }, base: 'Vikunja-Dev.CoderOfTime.Rurana://OAUTH/callback'),
        ),
        'c',
      );
    });

    for (final base in [
      'vikunja-desktop://oauth/callback',
      'vikunja-dev.coderoftime.rurana://other/callback',
      'vikunja-dev.coderoftime.rurana://oauth/callback/extra',
      'vikunja-dev.coderoftime.rurana://oauth/',
      'https://oauth/callback',
    ]) {
      test('rejects another redirect: $base', () {
        expect(
          () => request.codeFromCallback(
            callback({'code': 'c', 'state': request.state}, base: base),
          ),
          throwsProblem(AuthorizationCallbackProblem.wrongRedirect),
        );
      });
    }

    test('rejects a foreign state', () {
      expect(
        () => request.codeFromCallback(
          callback({'code': 'c', 'state': '${request.state}x'}),
        ),
        throwsProblem(AuthorizationCallbackProblem.stateMismatch),
      );
    });

    test('rejects a missing state', () {
      expect(
        () => request.codeFromCallback(callback({'code': 'c'})),
        throwsProblem(AuthorizationCallbackProblem.stateMismatch),
      );
    });

    test('reports an error response', () {
      expect(
        () => request.codeFromCallback(
          callback({
            'error': 'access_denied',
            'error_description': 'The user said no',
            'state': request.state,
          }),
        ),
        throwsA(
          isA<AuthorizationCallbackException>()
              .having(
                (e) => e.problem,
                'problem',
                AuthorizationCallbackProblem.errorResponse,
              )
              .having((e) => e.error, 'error', 'access_denied')
              .having(
                (e) => e.errorDescription,
                'errorDescription',
                'The user said no',
              ),
        ),
      );
    });

    test('an error response without our state is a state mismatch', () {
      expect(
        () => request.codeFromCallback(callback({'error': 'access_denied'})),
        throwsProblem(AuthorizationCallbackProblem.stateMismatch),
      );
    });

    for (final parameters in [
      <String, String>{},
      {'code': ''},
    ]) {
      test('rejects a missing code: $parameters', () {
        expect(
          () => request.codeFromCallback(
            callback({...parameters, 'state': request.state}),
          ),
          throwsProblem(AuthorizationCallbackProblem.missingCode),
        );
      });
    }

    test('rejects an undecodable query', () {
      expect(
        () => request.codeFromCallback(
          Uri.parse(
            'vikunja-dev.coderoftime.rurana://oauth/callback?code=%E0%A4%A&state=x',
          ),
        ),
        throwsA(isA<AuthorizationCallbackException>()),
      );
    });
  });
}
