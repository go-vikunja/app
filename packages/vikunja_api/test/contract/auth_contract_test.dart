@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/auth/pkce.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

final _client = OAuthClientConfig(
  clientId: 'vikunja-io.vikunja.app',
  redirectUri: Uri.parse('vikunja-io.vikunja.app://oauth/callback'),
);

/// What the web app's /oauth/authorize page does once the user is signed in:
/// POST /oauth/authorize with the page's query, then redirect to
/// `redirect_uri?code=…&state=…`.
Future<Uri> _browserLeg(
  Dio dio,
  ServerConnection connection,
  TestUser user,
  AuthorizationRequest request,
) async {
  final query = request.url.queryParameters;
  final api = connection.apiBaseUri(connection.preferredApiVersion);
  final response = await dio.postUri<Map<String, Object?>>(
    api.replace(path: '${api.path}/oauth/authorize'),
    data: {
      for (final key in const [
        'response_type',
        'client_id',
        'redirect_uri',
        'state',
        'code_challenge',
        'code_challenge_method',
      ])
        key: query[key],
    },
    options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
  );
  final body = response.data!;
  expect(body['redirect_uri'], query['redirect_uri']);
  expect(body['state'], request.state);
  final redirect = Uri.parse(body['redirect_uri']! as String);
  return redirect.replace(
    queryParameters: {
      ...redirect.queryParameters,
      'code': body['code']! as String,
      'state': body['state']! as String,
    },
  );
}

/// A minimal stand-in for the app's session manager.
final class _SessionTokens implements AccessTokenSource {
  new(this._tokenClient, this.tokens);

  final OAuthTokenClient _tokenClient;
  TokenSet tokens;
  String? accessTokenOverride;
  String? Function(String rejectedToken)? onRejection;
  final rejectedTokens = <String>[];

  @override
  Future<String> validAccessToken() async =>
      accessTokenOverride ?? tokens.accessToken;

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async {
    rejectedTokens.add(rejectedToken);
    if (onRejection case final onRejection?) return onRejection(rejectedToken);
    accessTokenOverride = null;
    tokens = await patiently(() => _tokenClient.refresh(tokens.refreshToken));
    return tokens.accessToken;
  }
}

void main() {
  group('browser sign-in on local Docker servers', skip: contractSkip, () {
    for (final (port, version) in [(34527, contractServerVersion.display)]) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late OAuthTokenClient tokenClient;
        late TestUser user;

        setUpAll(() async {
          dio = Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'User-Agent': 'Rurana contract tests'},
            ),
          );
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          tokenClient = OAuthTokenClient(dio, connection);
          user = await registerAndLogin(dio, connection);
        });

        tearDownAll(() => dio.close(force: true));

        Future<(AuthorizationRequest, String)> authorize() async {
          final request = AuthorizationRequest.create(connection, _client);
          final callback = await _browserLeg(dio, connection, user, request);
          return (request, request.codeFromCallback(callback));
        }

        Future<TokenSet> signIn() async {
          final (request, code) = await authorize();
          return await patiently(
            () => tokenClient.exchangeCode(code: code, request: request),
          );
        }

        test('the authorize URL opens the web app', () async {
          final request = AuthorizationRequest.create(connection, _client);
          final page = await dio.getUri<String>(
            request.url,
            options: Options(responseType: ResponseType.plain),
          );

          expect(request.url.origin, 'http://localhost:$port');
          expect(request.url.path, '/oauth/authorize');
          expect(page.statusCode, 200);
          expect(page.data, contains('<html'));
        });

        test('sign-in, current user, rotation, reuse, logout', () async {
          final first = await signIn();

          expect(first.userId, user.id);
          expect(first.username, user.username);
          expect(first.sessionId, isNotEmpty);
          expect(first.refreshToken, matches(RegExp(r'^[0-9a-f]{256}$')));
          expect(
            first.accessTokenExpiry.difference(first.issuedAt),
            const Duration(minutes: 10),
          );
          expect(
            first.issuedAt.difference(DateTime.now().toUtc()).abs(),
            lessThan(const Duration(minutes: 5)),
          );

          final tokens = _SessionTokens(tokenClient, first);
          final api = AccountApi(
            createAuthenticatedDio(
              base: dio,
              connection: connection,
              tokens: tokens,
            ),
            connection,
          );
          final me = await api.currentUser();
          expect(me.id, user.id);
          expect(me.username, user.username);

          var current = first;
          final seenRefreshTokens = {first.refreshToken};
          for (var i = 0; i < 3; i++) {
            final previous = current;
            current = await patiently(
              () => tokenClient.refresh(previous.refreshToken),
            );
            expect(seenRefreshTokens, isNot(contains(current.refreshToken)));
            seenRefreshTokens.add(current.refreshToken);
            expect(current.accessToken, isNot(previous.accessToken));
            expect(current.sessionId, first.sessionId);
            expect(current.userId, user.id);
          }

          await expectLater(
            patiently(() => tokenClient.refresh(first.refreshToken)),
            throwsA(
              isA<SessionEnded>().having(
                (f) => f.reason,
                'reason',
                SessionEndReason.invalidRefreshToken,
              ),
            ),
          );

          // No reuse detection: replaying an old token leaves the session.
          current = await patiently(
            () => tokenClient.refresh(current.refreshToken),
          );

          tokens.tokens = current;
          await api.logout();

          await expectLater(
            patiently(() => tokenClient.refresh(current.refreshToken)),
            throwsA(isA<SessionEnded>()),
          );
        });

        test('a wrong verifier is a PKCE mismatch', () async {
          final (request, code) = await authorize();
          final forged = AuthorizationRequest(
            url: request.url,
            state: request.state,
            codeVerifier: generateCodeVerifier(),
            client: request.client,
          );

          await expectLater(
            patiently(
              () => tokenClient.exchangeCode(code: code, request: forged),
            ),
            throwsA(
              isA<OAuthFailure>()
                  .having(
                    (f) => f.problem,
                    'problem',
                    OAuthProblem.pkceMismatch,
                  )
                  .having((f) => f.code, 'code', 17006),
            ),
          );
        });

        test('a code works once', () async {
          final (request, code) = await authorize();
          await patiently(
            () => tokenClient.exchangeCode(code: code, request: request),
          );

          await expectLater(
            patiently(
              () => tokenClient.exchangeCode(code: code, request: request),
            ),
            throwsA(
              isA<OAuthFailure>()
                  .having((f) => f.problem, 'problem', OAuthProblem.codeInvalid)
                  .having((f) => f.code, 'code', 17004),
            ),
          );
        });

        test('the token step checks redirect URI and client id', () async {
          for (final (other, problem, errorCode) in [
            (
              OAuthClientConfig(
                clientId: _client.clientId,
                redirectUri: Uri.parse('vikunja-io.vikunja.app://oauth/other'),
              ),
              OAuthProblem.invalidRedirectUri,
              17002,
            ),
            (
              OAuthClientConfig(
                clientId: 'someone.else',
                redirectUri: _client.redirectUri,
              ),
              OAuthProblem.clientMismatch,
              17001,
            ),
          ]) {
            final (request, code) = await authorize();
            final forged = AuthorizationRequest(
              url: request.url,
              state: request.state,
              codeVerifier: request.codeVerifier,
              client: other,
            );

            await expectLater(
              patiently(
                () => tokenClient.exchangeCode(code: code, request: forged),
              ),
              throwsA(
                isA<OAuthFailure>()
                    .having((f) => f.problem, 'problem', problem)
                    .having((f) => f.code, 'code', errorCode),
              ),
            );
          }
        });

        test(
          'a rejected token is refreshed once and the request repeated',
          () async {
            final tokens = _SessionTokens(tokenClient, await signIn())
              ..accessTokenOverride = 'garbage';
            final api = AccountApi(
              createAuthenticatedDio(
                base: dio,
                connection: connection,
                tokens: tokens,
              ),
              connection,
            );

            expect((await api.currentUser()).id, user.id);
            expect(tokens.rejectedTokens, ['garbage']);

            tokens
              ..onRejection = ((_) => 'still-garbage')
              ..accessTokenOverride = 'garbage';
            await expectLater(api.currentUser(), throwsA(isA<TokenRejected>()));
            expect(tokens.rejectedTokens, ['garbage', 'garbage']);

            // The logout POST is repeated too, as the server did not run it.
            tokens
              ..onRejection = null
              ..accessTokenOverride = 'garbage';
            await api.logout();
            expect(tokens.rejectedTokens, ['garbage', 'garbage', 'garbage']);
            await expectLater(
              patiently(() => tokenClient.refresh(tokens.tokens.refreshToken)),
              throwsA(isA<SessionEnded>()),
            );
          },
        );
      });
    }
  });
}
