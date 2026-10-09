import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/browser_sign_in.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');

void main() {
  late DateTime now;
  late AuthFakes fakes;
  late SessionManagers sessions;
  late BrowserSignIn signIn;
  final connection = fullServer270();
  final accountId = accountIdFor(connection.rootUri, _alice.id);

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    fakes = AuthFakes()..serveUser(_alice, now: now);
    sessions = SessionManagers(
      tokenStore: fakes.tokenStore,
      clockOffsets: fakes.clockOffsets,
      tokenGateway: fakes.tokenGateway,
      connectionFor: (_) async => connection,
      markNeedsReauth: fakes.registry.markNeedsReauth,
      clock: () => now,
    );
    signIn = BrowserSignIn(
      authenticator: fakes.webAuthenticator,
      tokenGateway: fakes.tokenGateway,
      accountGateway: fakes.accountGateway,
      tokenStore: fakes.tokenStore,
      registry: fakes.registry,
      sessions: sessions,
      clock: () => now,
    );
  });

  test('signs in through the browser and activates the account', () async {
    final tokens = issueTokens(issuedAt: now, userId: _alice.id);
    fakes.tokenGateway.onExchange = (_) async => tokens;

    final entry = await signIn.signIn(connection);

    final url = fakes.webAuthenticator.urls.single;
    expect(url.path, '/vikunja/oauth/authorize');
    expect(url.queryParameters, {
      'response_type': 'code',
      'client_id': 'dev.coderoftime.vikunja',
      'redirect_uri': 'vikunja-dev.coderoftime.vikunja://oauth/callback',
      'state': isNotEmpty,
      'code_challenge': isNotEmpty,
      'code_challenge_method': 'S256',
    });
    expect(fakes.webAuthenticator.schemes, ['vikunja-dev.coderoftime.vikunja']);
    expect(fakes.tokenGateway.exchangedCodes, ['auth-code']);
    expect(
      fakes.tokenGateway.exchangeRequests.single.state,
      url.queryParameters['state'],
    );
    expect(fakes.accountGateway.currentUserTokens, [tokens.accessToken]);

    expect(entry?.id, accountId);
    expect(entry?.account.username, 'alice');
    expect(entry?.account.displayName, 'Alice Example');
    expect(entry?.account.serverRoot, connection.rootUri);
    expect(entry?.account.addedAt, now);
    final registry = await fakes.registry.load();
    expect(registry.activeAccountId, accountId);
    expect(registry.activeAccount?.connection.rootUri, connection.rootUri);
    final stored = await fakes.tokenStore.read(accountId);
    expect(stored?.refreshToken, tokens.refreshToken);
    expect(stored?.accessToken, tokens.accessToken);
    expect(
      await sessions.forAccount(accountId).validAccessToken(),
      tokens.accessToken,
    );
  });

  test('closing the browser returns quietly', () async {
    fakes.webAuthenticator.handler = (_, _) async => null;

    expect(await signIn.signIn(connection), isNull);
    expect(fakes.tokenGateway.exchangedCodes, isEmpty);
    expect((await fakes.registry.load()).accounts, isEmpty);
  });

  test('a browser failure is passed on', () async {
    fakes.webAuthenticator.handler = (_, _) async =>
        throw const WebAuthenticationFailed(WebAuthenticationProblem.noBrowser);

    await expectLater(
      signIn.signIn(connection),
      throwsA(isA<WebAuthenticationFailed>()),
    );
  });

  for (final (name, callback, problem) in [
    (
      'a foreign state',
      (Uri url) => appOAuthClient.redirectUri.replace(
        queryParameters: {'code': 'auth-code', 'state': 'forged'},
      ),
      AuthorizationCallbackProblem.stateMismatch,
    ),
    (
      'an error parameter',
      (Uri url) => appOAuthClient.redirectUri.replace(
        queryParameters: {
          'error': 'access_denied',
          'state': url.queryParameters['state'],
        },
      ),
      AuthorizationCallbackProblem.errorResponse,
    ),
    (
      'no code',
      (Uri url) => appOAuthClient.redirectUri.replace(
        queryParameters: {'state': url.queryParameters['state']},
      ),
      AuthorizationCallbackProblem.missingCode,
    ),
    (
      'another redirect target',
      (Uri url) => Uri.parse(
        'vikunja-dev.coderoftime.vikunja://elsewhere?code=c&'
        'state=${url.queryParameters['state']}',
      ),
      AuthorizationCallbackProblem.wrongRedirect,
    ),
  ]) {
    test('rejects a callback with $name without exchanging it', () async {
      fakes.webAuthenticator.handler = (url, _) async => callback(url);

      await expectLater(
        signIn.signIn(connection),
        throwsA(
          isA<AuthorizationCallbackException>().having(
            (e) => e.problem,
            'problem',
            problem,
          ),
        ),
      );
      expect(fakes.tokenGateway.exchangedCodes, isEmpty);
      expect((await fakes.registry.load()).accounts, isEmpty);
    });
  }

  test('a failed code exchange stores nothing', () async {
    fakes.tokenGateway.onExchange = (_) async =>
        throw const OAuthFailure(OAuthProblem.codeExpired, code: 17005);

    await expectLater(signIn.signIn(connection), throwsA(isA<OAuthFailure>()));
    expect(fakes.secureStore.values, isEmpty);
    expect((await fakes.registry.load()).accounts, isEmpty);
  });

  test(
    'when GET /user fails, the new session is logged out and dropped',
    () async {
      final tokens = issueTokens(issuedAt: now, userId: _alice.id);
      fakes.tokenGateway.onExchange = (_) async => tokens;
      fakes.accountGateway.onCurrentUser = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await expectLater(
        signIn.signIn(connection),
        throwsA(isA<NetworkFailure>()),
      );
      await pumpEventQueue();

      expect(fakes.secureStore.values, isEmpty);
      expect((await fakes.registry.load()).accounts, isEmpty);
      expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
    },
  );

  test('a user that does not match the token is refused', () async {
    fakes.accountGateway.onCurrentUser = (_) async =>
        const User(id: 99, username: 'mallory');

    await expectLater(
      signIn.signIn(connection),
      throwsA(isA<UnexpectedResponse>()),
    );
    expect((await fakes.registry.load()).accounts, isEmpty);
  });

  test(
    'signing in again replaces the session and logs out the old one',
    () async {
      final old = issueTokens(
        issuedAt: now.subtract(const Duration(minutes: 3)),
        userId: _alice.id,
        sessionId: 'old-session',
      );
      final seeded = await fakes.seedAccount(
        connection,
        tokens: old,
        needsReauth: true,
      );
      final oldManager = sessions.forAccount(seeded.id);
      final fresh = issueTokens(
        issuedAt: now,
        userId: _alice.id,
        sessionId: 'new-session',
      );
      fakes.tokenGateway.onExchange = (_) async => fresh;

      final entry = await signIn.signIn(connection);
      await pumpEventQueue();

      expect(entry?.id, seeded.id);
      expect(entry?.account.needsReauth, isFalse);
      expect(entry?.account.addedAt, seeded.account.addedAt);
      expect((await fakes.registry.load()).accounts, hasLength(1));
      expect(
        (await fakes.tokenStore.read(seeded.id))?.refreshToken,
        fresh.refreshToken,
      );
      expect(fakes.accountGateway.logoutTokens, [old.accessToken]);
      await expectLater(
        oldManager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(
        await sessions.forAccount(seeded.id).validAccessToken(),
        fresh.accessToken,
      );
    },
  );

  test(
    'an expired replaced session is refreshed in memory to log it out',
    () async {
      final old = issueTokens(
        issuedAt: now.subtract(const Duration(hours: 1)),
        userId: _alice.id,
      );
      await fakes.seedAccount(connection, tokens: old);
      final oldRefreshed = issueTokens(issuedAt: now, userId: _alice.id);
      fakes.tokenGateway.onRefresh = (_) async => oldRefreshed;
      final fresh = issueTokens(issuedAt: now, userId: _alice.id);
      fakes.tokenGateway.onExchange = (_) async => fresh;

      await signIn.signIn(connection);
      await pumpEventQueue();

      expect(fakes.tokenGateway.refreshedTokens, [old.refreshToken]);
      expect(fakes.accountGateway.logoutTokens, [oldRefreshed.accessToken]);
      expect(
        (await fakes.tokenStore.read(accountIdFor(connection.rootUri, 7)))
            ?.refreshToken,
        fresh.refreshToken,
      );
    },
  );

  test('another user on the same server becomes a second account', () async {
    await signIn.signIn(connection);
    fakes.serveUser(const User(id: 8, username: 'bob'), now: now);

    final bob = await signIn.signIn(connection);

    final registry = await fakes.registry.load();
    expect(registry.accounts, hasLength(2));
    expect(registry.activeAccountId, bob?.id);
    expect(bob?.account.displayName, 'bob');
  });

  group('signing in again as a given account', () {
    test(
      'refuses another user, stores nothing and ends that session',
      () async {
        final seeded = await fakes.seedAccount(
          connection,
          tokens: issueTokens(issuedAt: now, userId: _alice.id),
          needsReauth: true,
        );
        final storedBefore = Map.of(fakes.secureStore.values);
        final bobTokens = issueTokens(
          issuedAt: now,
          userId: 8,
          username: 'bob',
        );
        fakes.tokenGateway.onExchange = (_) async => bobTokens;
        fakes.accountGateway.onCurrentUser = (_) async =>
            const User(id: 8, username: 'bob');

        await expectLater(
          signIn.signIn(connection, expectedAccount: seeded.account),
          throwsA(
            isA<SignedInAsDifferentUser>()
                .having((e) => e.signedInUsername, 'signedIn', 'bob')
                .having((e) => e.expectedUsername, 'expected', 'alice'),
          ),
        );
        await pumpEventQueue();

        expect(fakes.secureStore.values, storedBefore);
        expect(fakes.accountGateway.logoutTokens, [bobTokens.accessToken]);
        final registry = await fakes.registry.load();
        expect(registry.accounts.map((entry) => entry.id), [seeded.id]);
        expect(registry.activeAccount?.account.needsReauth, isTrue);
      },
    );

    test('accepts the same user', () async {
      final seeded = await fakes.seedAccount(
        connection,
        tokens: issueTokens(issuedAt: now, userId: _alice.id),
        needsReauth: true,
      );

      final entry = await signIn.signIn(
        connection,
        expectedAccount: seeded.account,
      );

      expect(entry?.id, seeded.id);
      expect(entry?.account.needsReauth, isFalse);
    });
  });

  test('stores the server clock offset of the sign-in', () async {
    const skew = Duration(minutes: 3);
    fakes.tokenGateway.onExchange = (_) async =>
        issueTokens(issuedAt: now.add(skew), userId: _alice.id);

    final entry = await signIn.signIn(connection);

    expect(await fakes.clockOffsets.read(entry!.id), skew);
  });
}
