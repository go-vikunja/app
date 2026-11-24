import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/browser_sign_in.dart';
import 'package:vikunja_mobile/core/auth/failed_without_token.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/sign_in_tokens.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/db/open_account_database.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');

final Matcher _noTokenYet = isA<NetworkFailure>().having(
  (f) => f.cause,
  'cause',
  RefreshDeferred.signIn,
);

/// Memory storage whose reads fail while [failReads] is set.
final class _FlakyStore implements SecureStore {
  new(this._inner);

  final MemorySecureStore _inner;
  bool failReads = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('the Keystore refused');
    return await _inner.read(key);
  }

  @override
  Future<void> write(String key, String value, {bool recoverLostKey = false}) =>
      _inner.write(key, value, recoverLostKey: recoverLostKey);

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<void> deleteAll() => _inner.deleteAll();

  @override
  Future<void> flush() => _inner.flush();
}

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
      'client_id': 'vikunja-io.vikunja.app',
      'redirect_uri': 'vikunja-io.vikunja.app://oauth/callback',
      'state': isNotEmpty,
      'code_challenge': isNotEmpty,
      'code_challenge_method': 'S256',
    });
    expect(fakes.webAuthenticator.schemes, ['vikunja-io.vikunja.app']);
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
        'vikunja-io.vikunja.app://elsewhere?code=c&'
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
      await expectLater(oldManager.validAccessToken(), throwsA(_noTokenYet));
      expect(
        await sessions.forAccount(seeded.id).validAccessToken(),
        fresh.accessToken,
      );
    },
  );

  test('a request while the new tokens are stored gets no token yet without '
      'marking the account, and the new session once they are', () async {
    await fakes.seedAccount(
      connection,
      tokens: issueTokens(
        issuedAt: now.subtract(const Duration(minutes: 3)),
        userId: _alice.id,
        sessionId: 'old-session',
      ),
    );
    final fresh = issueTokens(
      issuedAt: now,
      userId: _alice.id,
      sessionId: 'new-session',
    );
    fakes.tokenGateway.onExchange = (_) async => fresh;
    final writing = Completer<void>();
    final gate = Completer<void>();
    fakes.secureStore.beforeWrite = (_) {
      if (!writing.isCompleted) writing.complete();
      return gate.future;
    };

    final signingIn = signIn.signIn(connection);
    await writing.future;

    Object? failure;
    try {
      await sessions.forAccount(accountId).validAccessToken();
    } on Object catch (error) {
      failure = error;
    }
    expect(failure, _noTokenYet);
    expect(failedWithoutToken(failure), isTrue);
    expect(
      (await fakes.registry.find(accountId))!.account.needsReauth,
      isFalse,
    );

    gate.complete();
    await signingIn;

    expect(
      await sessions.forAccount(accountId).validAccessToken(),
      fresh.accessToken,
    );
  });

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

  test('an account already here is prepared before it becomes active '
      'again; a new one is not', () async {
    final prepared = <(String, String?)>[];
    Future<void> prepare(String id) async =>
        prepared.add((id, (await fakes.registry.load()).activeAccountId));
    await signIn.signIn(connection, beforeActivatingExisting: prepare);
    expect(prepared, isEmpty);
    fakes.serveUser(const User(id: 8, username: 'bob'), now: now);
    final bob = await signIn.signIn(connection);
    fakes.serveUser(_alice, now: now);

    await signIn.signIn(connection, beforeActivatingExisting: prepare);

    expect(prepared, [(accountId, bob!.id)]);
    expect((await fakes.registry.load()).activeAccountId, accountId);
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

  group('before anything of the new session is stored', () {
    late TokenSet old;
    late TokenSet fresh;

    setUp(() async {
      old = issueTokens(
        issuedAt: now.subtract(const Duration(minutes: 3)),
        userId: _alice.id,
      );
      await fakes.seedAccount(connection, tokens: old);
      fresh = issueTokens(issuedAt: now, userId: _alice.id);
      fakes.tokenGateway.onExchange = (_) async => fresh;
    });

    test('the sign-in waits there for the account the browser told', () async {
      final waited = <String>[];
      String? storedMeanwhile;

      await signIn.signIn(
        connection,
        beforeStoring: (id) async {
          waited.add(id);
          storedMeanwhile = (await fakes.tokenStore.read(id))?.refreshToken;
        },
      );

      expect(waited, [accountId]);
      expect(storedMeanwhile, old.refreshToken);
      expect(
        (await fakes.tokenStore.read(accountId))?.refreshToken,
        fresh.refreshToken,
      );
    });

    test('a throw there ends the sign-in: nothing is stored, the old session '
        'goes on, and the new one is logged out', () async {
      await expectLater(
        signIn.signIn(
          connection,
          beforeStoring: (_) async => throw const SignOutStillFinishing(),
        ),
        throwsA(isA<SignOutStillFinishing>()),
      );
      await pumpEventQueue();

      expect(
        (await fakes.tokenStore.read(accountId))?.refreshToken,
        old.refreshToken,
      );
      expect(
        await sessions.forAccount(accountId).validAccessToken(),
        old.accessToken,
      );
      expect(fakes.accountGateway.logoutTokens, [fresh.accessToken]);
    });
  });

  test('a live account whose new tokens cannot be stored goes on with the '
      'session storage still holds, and is not marked', () async {
    final old = issueTokens(
      issuedAt: now.subtract(const Duration(minutes: 3)),
      userId: _alice.id,
    );
    await fakes.seedAccount(connection, tokens: old);
    final before = sessions.forAccount(accountId);
    expect(await before.validAccessToken(), old.accessToken);
    fakes.secureStore.beforeWrite = (_) async =>
        throw StateError('the key is gone');
    final failingStorage = BrowserSignIn(
      authenticator: fakes.webAuthenticator,
      tokenGateway: fakes.tokenGateway,
      accountGateway: fakes.accountGateway,
      tokenStore: fakes.tokenStore,
      registry: fakes.registry,
      sessions: sessions,
      clock: () => now,
      sleep: (_) async {},
    );

    await expectLater(
      failingStorage.signIn(connection),
      throwsA(isA<StateError>()),
    );

    await expectLater(before.validAccessToken(), throwsA(_noTokenYet));
    expect(sessions.forAccount(accountId), isNot(same(before)));
    expect(
      await sessions.forAccount(accountId).validAccessToken(),
      old.accessToken,
    );
    final stored = (await fakes.registry.find(accountId))!;
    expect(stored.account.needsReauth, isFalse);
  });

  group('when the account cannot be registered (decision log: Sessions)', () {
    late TokenSet fresh;

    setUp(() {
      fresh = issueTokens(issuedAt: now, userId: _alice.id);
      fakes.tokenGateway.onExchange = (_) async => fresh;
    });

    test('a new account takes back its tokens, retires its manager and logs '
        'the new session out', () async {
      fakes.preferences.failWrites.add(AccountRegistry.storageKey);

      await expectLater(signIn.signIn(connection), throwsA(isA<Exception>()));
      await pumpEventQueue();

      expect(fakes.secureStore.values, isEmpty);
      expect(
        fakes.preferences.values.keys,
        everyElement(isNot(contains(accountId))),
      );
      expect((await fakes.registry.load()).accounts, isEmpty);
      expect(fakes.accountGateway.logoutTokens, [fresh.accessToken]);
      await expectLater(
        sessions.forAccount(accountId).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
    });

    test('an account already here keeps the new tokens and session', () async {
      await fakes.seedAccount(
        connection,
        tokens: issueTokens(
          issuedAt: now.subtract(const Duration(minutes: 3)),
          userId: _alice.id,
        ),
      );
      fakes.preferences.failWrites.add(AccountRegistry.storageKey);

      await expectLater(signIn.signIn(connection), throwsA(isA<Exception>()));
      await pumpEventQueue();

      expect(
        (await fakes.tokenStore.read(accountId))?.refreshToken,
        fresh.refreshToken,
      );
      expect(
        await sessions.forAccount(accountId).validAccessToken(),
        fresh.accessToken,
      );
      expect(
        fakes.accountGateway.logoutTokens,
        isNot(contains(fresh.accessToken)),
      );
      expect(await fakes.registry.find(accountId), isNotNull);
    });

    test('tokens storage held for an account it does not list stay: an entry '
        'this build cannot read may name them', () async {
      await fakes.tokenStore.write(
        accountId,
        issueTokens(
          issuedAt: now.subtract(const Duration(minutes: 3)),
          userId: _alice.id,
        ),
      );
      fakes.preferences.failWrites.add(AccountRegistry.storageKey);

      await expectLater(signIn.signIn(connection), throwsA(isA<Exception>()));
      await pumpEventQueue();

      expect(
        (await fakes.tokenStore.read(accountId))?.refreshToken,
        fresh.refreshToken,
      );
      expect(
        fakes.accountGateway.logoutTokens,
        isNot(contains(fresh.accessToken)),
      );
    });

    test('a registry that cannot be read before storing stores nothing and '
        'logs the new session out', () async {
      fakes.preferences.failNextRead.add(AccountRegistry.storageKey);

      await expectLater(signIn.signIn(connection), throwsA(isA<Exception>()));
      await pumpEventQueue();

      expect(fakes.secureStore.values, isEmpty);
      expect(fakes.accountGateway.logoutTokens, [fresh.accessToken]);
    });
  });

  test('stores the server clock offset of the sign-in', () async {
    const skew = Duration(minutes: 3);
    fakes.tokenGateway.onExchange = (_) async =>
        issueTokens(issuedAt: now.add(skew), userId: _alice.id);

    final entry = await signIn.signIn(connection);

    expect(await fakes.clockOffsets.read(entry!.id), skew);
  });

  group('after an ended session (decision log: Sessions)', () {
    late SessionDiagnostics diagnostics;
    late List<Duration> sleeps;
    late TokenSet old;
    late TokenSet fresh;

    BrowserSignIn signInWith(TokenStore tokenStore) => BrowserSignIn(
      authenticator: fakes.webAuthenticator,
      tokenGateway: fakes.tokenGateway,
      accountGateway: fakes.accountGateway,
      tokenStore: tokenStore,
      registry: fakes.registry,
      sessions: sessions,
      diagnostics: diagnostics,
      clock: () => now,
      sleep: (duration) async => sleeps.add(duration),
    );

    setUp(() async {
      diagnostics = SessionDiagnostics(fakes.preferences);
      sleeps = [];
      old = issueTokens(
        issuedAt: now.subtract(const Duration(hours: 5)),
        userId: _alice.id,
        sessionId: 'old-session',
      );
      fresh = issueTokens(
        issuedAt: now,
        userId: _alice.id,
        sessionId: 'new-session',
      );
      await fakes.seedAccount(connection, tokens: old, needsReauth: true);
      await diagnostics.recordEnd(
        accountId,
        SessionEndDiagnosis(
          at: now.subtract(const Duration(hours: 1)),
          cause: SessionEndCause.refreshRejected,
          part: AppPart.backgroundRun,
          code: 16002,
          failedToken: tokenFingerprint(old.refreshToken),
        ),
      );
      fakes.tokenGateway.onExchange = (_) async => fresh;
    });

    Future<SessionEndResolution?> resolution() async =>
        (await diagnostics.lastEnd(accountId))?.resolution;

    test('an old session the server refuses but still lists is revoked: the '
        'answer to a refresh was lost', () async {
      fakes.tokenGateway.onRefresh = (_) async => throw const SessionEnded(
        SessionEndReason.invalidRefreshToken,
        code: 16002,
      );
      fakes.accountGateway.serverSessions = [
        const UserSession(id: 'old-session'),
        const UserSession(id: 'new-session'),
      ];

      await signInWith(fakes.tokenStore).signIn(connection);
      await pumpEventQueue();

      expect(fakes.accountGateway.revokedSessions, ['old-session']);
      expect(await resolution(), SessionEndResolution.orphanRevoked);
      final record = (await diagnostics.lastEnd(accountId))!;
      expect(record.code, 16002);
      expect(record.part, AppPart.backgroundRun);
    });

    test('an old session the server no longer has was deleted there', () async {
      fakes.tokenGateway.onRefresh = (_) async => throw const SessionEnded(
        SessionEndReason.invalidRefreshToken,
        code: 16002,
      );
      fakes.accountGateway.serverSessions = [
        const UserSession(id: 'new-session'),
      ];

      await signInWith(fakes.tokenStore).signIn(connection);
      await pumpEventQueue();

      expect(fakes.accountGateway.revokedSessions, isEmpty);
      expect(await resolution(), SessionEndResolution.goneOnServer);
    });

    test('old tokens that still work show the app ended a live session; it '
        'is logged out', () async {
      final oldRefreshed = issueTokens(issuedAt: now, userId: _alice.id);
      fakes.tokenGateway.onRefresh = (_) async => oldRefreshed;

      await signInWith(fakes.tokenStore).signIn(connection);
      await pumpEventQueue();

      expect(fakes.accountGateway.logoutTokens, [oldRefreshed.accessToken]);
      expect(await resolution(), SessionEndResolution.wasAlive);
    });

    test('no old tokens left on the device are noted', () async {
      await fakes.tokenStore.delete(accountId);

      await signInWith(fakes.tokenStore).signIn(connection);
      await pumpEventQueue();

      expect(await resolution(), SessionEndResolution.noTokens);
      expect(fakes.accountGateway.logoutTokens, isEmpty);
    });

    test('old tokens that cannot be read do not stop the sign-in', () async {
      final flaky = _FlakyStore(fakes.secureStore)..failReads = true;

      final entry = await signInWith(TokenStore(flaky)).signIn(connection);
      await pumpEventQueue();
      flaky.failReads = false;

      expect(entry?.account.needsReauth, isFalse);
      expect(
        (await fakes.tokenStore.read(accountId))?.refreshToken,
        fresh.refreshToken,
      );
      // The tokens were there, only unreadable: no verdict on the old
      // session.
      expect(await resolution(), SessionEndResolution.unknown);
    });

    test('a write that fails twice is tried once more, letting the platform '
        'reset storage whose key is lost for good, and leaves the other '
        "accounts' tokens alone", () async {
      final bob = await fakes.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        activate: false,
      );
      var refusals = 2;
      fakes.secureStore.beforeWrite = (key) async {
        if (key.contains(accountId) && refusals-- > 0) {
          throw StateError('the Keystore failed');
        }
      };

      final entry = await signInWith(fakes.tokenStore).signIn(connection);

      expect(entry, isNotNull);
      expect(sleeps, [
        SignInTokens.storageRetryDelay,
        SignInTokens.storageRetryDelay,
      ]);
      expect(fakes.secureStore.operations, isNot(contains('deleteAll')));
      expect(fakes.secureStore.recoveringWrites, [
        TokenStore.refreshTokenKey(accountId),
      ]);
      expect(
        (await fakes.tokenStore.read(accountId))?.refreshToken,
        fresh.refreshToken,
      );
      expect(await fakes.tokenStore.read(bob.id), isNotNull);
    });

    test('a key lost for good is recovered by the write that asks for it, '
        'where nothing else works', () async {
      fakes.secureStore.beforeWrite = (key) async {
        if (fakes.secureStore.recoveringWrites.isEmpty) {
          throw StateError('the key cannot be unwrapped');
        }
      };

      final entry = await signInWith(fakes.tokenStore).signIn(connection);

      expect(entry, isNotNull);
      expect(
        (await fakes.tokenStore.read(accountId))?.refreshToken,
        fresh.refreshToken,
      );
    });

    test('a write that keeps failing fails the sign-in', () async {
      fakes.secureStore.beforeWrite = (_) async =>
          throw StateError('the key is gone');

      await expectLater(
        signInWith(fakes.tokenStore).signIn(connection),
        throwsA(isA<StateError>()),
      );
      final stored = (await fakes.registry.find(accountId))!;
      expect(stored.account.needsReauth, isTrue);
    });
  });
}
