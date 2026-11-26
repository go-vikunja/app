import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/previous_app_sign_in.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/sign_in_tokens.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/server_connections.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');
const _oldToken = 'previous-refresh-token';

void main() {
  late DateTime now;
  late AuthFakes fakes;
  late FakeServerConnector connector;
  late SessionManagers sessions;
  late PreviousAppSignIn signIn;
  final connection = fullServer270(root: 'https://vikunja.example.com');
  final accountId = accountIdFor(connection.rootUri, _alice.id);

  setUp(() {
    now = DateTime.utc(2026, 11, 13, 9);
    fakes = AuthFakes();
    connector = FakeServerConnector.succeeding(connection);
    sessions = SessionManagers(
      tokenStore: fakes.tokenStore,
      clockOffsets: fakes.clockOffsets,
      tokenGateway: fakes.tokenGateway,
      connectionFor: (_) async => connection,
      markNeedsReauth: fakes.registry.markNeedsReauth,
      clock: () => now,
    );
    signIn = PreviousAppSignIn(
      connector: connector,
      tokenGateway: fakes.tokenGateway,
      accountGateway: fakes.accountGateway,
      tokenStore: fakes.tokenStore,
      registry: fakes.registry,
      sessions: sessions,
      clock: () => now,
    );
  });

  Future<RegisteredAccount?> keep([
    PreviousAppSignInCancellation? cancellation,
  ]) => signIn.signIn(
    serverAddress: 'https://vikunja.example.com',
    refreshToken: _oldToken,
    cancellation: cancellation,
  );

  Future<void> expectNothingStored() async {
    expect((await fakes.registry.load()).accounts, isEmpty);
    expect(fakes.secureStore.values, isEmpty);
    expect(
      fakes.preferences.values.keys,
      everyElement(isNot(contains(accountId))),
    );
  }

  test("exchanges the previous app's refresh token and registers the "
      'account as active, like a browser sign-in', () async {
    final tokens = issueTokens(issuedAt: now, userId: _alice.id);
    fakes.tokenGateway.onRefresh = (_) async => tokens;
    fakes.accountGateway.onCurrentUser = (_) async => _alice;

    final entry = (await keep())!;

    expect(connector.inputs, ['https://vikunja.example.com']);
    expect(fakes.tokenGateway.refreshedTokens, [_oldToken]);
    expect(fakes.accountGateway.currentUserTokens, [tokens.accessToken]);
    expect(entry.id, accountId);
    expect(entry.account.username, 'alice');
    expect(entry.account.displayName, 'Alice Example');
    expect(entry.account.serverRoot, connection.rootUri);
    expect(entry.account.addedAt, now);
    expect(entry.account.isLinkShare, isFalse);
    final registry = await fakes.registry.load();
    expect(registry.activeAccountId, accountId);
    expect(registry.accounts.single.connection.rootUri, connection.rootUri);
    final stored = await fakes.tokenStore.read(accountId);
    expect(stored?.refreshToken, tokens.refreshToken);
    expect(stored?.accessToken, tokens.accessToken);
    expect(
      await sessions.forAccount(accountId).validAccessToken(),
      tokens.accessToken,
    );
    expect(fakes.tokenGateway.refreshedTokens, hasLength(1));
    expect(fakes.accountGateway.logoutTokens, isEmpty);
  });

  test('an http server is not tried: this app asks before http, the '
      'previous app never did', () async {
    connector.handler = (_) async => insecureServer();

    await expectLater(
      keep(),
      throwsA(
        isA<PreviousAppSessionNotKept>().having(
          (error) => error.reason,
          'reason',
          PreviousAppSessionSkip.insecure,
        ),
      ),
    );
    expect(fakes.tokenGateway.refreshedTokens, isEmpty);
    await expectNothingStored();
  });

  for (final address in ['http://vikunja.example.com', 'vikunja.example.com']) {
    test(
      'does not discover or refresh with a legacy address of $address',
      () async {
        await expectLater(
          signIn.signIn(serverAddress: address, refreshToken: _oldToken),
          throwsA(isA<PreviousAppSessionNotKept>()),
        );

        expect(connector.inputs, isEmpty);
        expect(fakes.tokenGateway.refreshedTokens, isEmpty);
      },
    );
  }

  for (final root in [
    'https://other.example.com',
    'https://vikunja.example.com:3456',
  ]) {
    test('does not refresh when discovery returns $root', () async {
      connector.handler = (_) async => fullServer270(root: root);

      await expectLater(
        keep(),
        throwsA(
          isA<PreviousAppSessionNotKept>().having(
            (error) => error.reason,
            'reason',
            PreviousAppSessionSkip.originChanged,
          ),
        ),
      );
      expect(fakes.tokenGateway.refreshedTokens, isEmpty);
      await expectNothingStored();
    });
  }

  test(
    'allows discovery at a different path on the same HTTPS origin',
    () async {
      connector.handler = (_) async =>
          fullServer270(root: 'https://vikunja.example.com:443/subpath');
      fakes.tokenGateway.onRefresh = (_) async =>
          issueTokens(issuedAt: now, userId: _alice.id);
      fakes.accountGateway.onCurrentUser = (_) async => _alice;

      final entry = await keep();

      expect(entry?.account.serverRoot.path, '/subpath');
      expect(fakes.tokenGateway.refreshedTokens, [_oldToken]);
    },
  );

  test('a server below the support floor is not tried', () async {
    connector.handler = (_) async => legacyServer200();

    await expectLater(
      keep(),
      throwsA(
        isA<PreviousAppSessionNotKept>().having(
          (error) => error.reason,
          'reason',
          PreviousAppSessionSkip.unsupported,
        ),
      ),
    );
    expect(fakes.tokenGateway.refreshedTokens, isEmpty);
    await expectNothingStored();
  });

  test(
    'a server that cannot be reached is passed on, before any refresh',
    () async {
      connector.handler = (_) =>
          Future.error(ServerTimeout(Uri.parse('https://vikunja.example.com')));

      await expectLater(keep(), throwsA(isA<ServerTimeout>()));
      expect(fakes.tokenGateway.refreshedTokens, isEmpty);
      await expectNothingStored();
    },
  );

  test('a refused refresh stores nothing', () async {
    fakes.tokenGateway.onRefresh = (_) async =>
        throw const SessionEnded(SessionEndReason.invalidRefreshToken);

    await expectLater(keep(), throwsA(isA<SessionEnded>()));
    expect(fakes.accountGateway.currentUserTokens, isEmpty);
    await expectNothingStored();
  });

  test('a token of another user is logged out and nothing is stored', () async {
    final tokens = issueTokens(issuedAt: now, userId: 8, username: 'bob');
    fakes.tokenGateway.onRefresh = (_) async => tokens;
    fakes.accountGateway.onCurrentUser = (_) async => _alice;

    await expectLater(keep(), throwsA(isA<UnexpectedResponse>()));
    await pumpEventQueue();

    expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
    await expectNothingStored();
  });

  test(
    'a failed GET /user logs the new session out and stores nothing',
    () async {
      final tokens = issueTokens(issuedAt: now, userId: _alice.id);
      fakes.tokenGateway.onRefresh = (_) async => tokens;
      fakes.accountGateway
        ..onCurrentUser = _unreachable
        ..onLogout = _unreachable;

      await expectLater(keep(), throwsA(isA<NetworkFailure>()));
      await pumpEventQueue();

      expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
      await expectNothingStored();
    },
  );

  test('a GET /user that does not answer in time ends the try and logs the '
      'new session out', () async {
    final tokens = issueTokens(issuedAt: now, userId: _alice.id);
    fakes.tokenGateway.onRefresh = (_) async => tokens;
    fakes.accountGateway.onCurrentUser = (_) => Completer<User>().future;
    signIn = PreviousAppSignIn(
      connector: connector,
      tokenGateway: fakes.tokenGateway,
      accountGateway: fakes.accountGateway,
      tokenStore: fakes.tokenStore,
      registry: fakes.registry,
      sessions: sessions,
      userTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      keep().timeout(const Duration(seconds: 5)),
      throwsA(
        isA<TimeoutException>().having(
          (error) => error.duration,
          'duration',
          const Duration(milliseconds: 10),
        ),
      ),
    );
    await pumpEventQueue();

    expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
    await expectNothingStored();
  });

  test('a logout that never answers is given up', () async {
    final tokens = issueTokens(issuedAt: now, userId: _alice.id);
    fakes.tokenGateway.onRefresh = (_) async => tokens;
    fakes.accountGateway
      ..onCurrentUser = _unreachable
      ..onLogout = (_) => Completer<void>().future;
    signIn = PreviousAppSignIn(
      connector: connector,
      tokenGateway: fakes.tokenGateway,
      accountGateway: fakes.accountGateway,
      tokenStore: fakes.tokenStore,
      registry: fakes.registry,
      sessions: sessions,
      logoutTimeout: const Duration(milliseconds: 10),
    );

    final records = <LogRecord>[];
    final level = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(() {
      Logger.root.level = level;
      return subscription.cancel();
    });

    await expectLater(keep(), throwsA(isA<NetworkFailure>()));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
    expect(
      records.map((record) => record.message),
      contains('Could not end an abandoned session: TimeoutException'),
    );
  });

  group('a cancel', () {
    late PreviousAppSignInCancellation cancellation;

    setUp(() => cancellation = PreviousAppSignInCancellation());

    test('while connecting stops the probe, and the token is never '
        'sent', () async {
      connector.handler = (_) => Completer<ServerConnection>().future;

      final result = keep(cancellation);
      await pumpEventQueue();
      expect(cancellation.cancel(), isTrue);

      expect(await result, isNull);
      expect(connector.cancelTokens.single?.isCancelled, isTrue);
      expect(fakes.tokenGateway.refreshedTokens, isEmpty);
      await expectNothingStored();
    });

    test('that the connector ignores sends no token', () async {
      signIn = PreviousAppSignIn(
        connector: _DeafConnector(() async {
          cancellation.cancel();
          return connection;
        }),
        tokenGateway: fakes.tokenGateway,
        accountGateway: fakes.accountGateway,
        tokenStore: fakes.tokenStore,
        registry: fakes.registry,
        sessions: sessions,
      );

      expect(await keep(cancellation), isNull);
      expect(fakes.tokenGateway.refreshedTokens, isEmpty);
      await expectNothingStored();
    });

    test('while the token is refreshed logs out the session a late answer '
        'brings, and stores nothing', () async {
      final refresh = Completer<TokenSet>();
      fakes.tokenGateway.onRefresh = (_) => refresh.future;
      fakes.accountGateway.onCurrentUser = (_) async => _alice;
      final tokens = issueTokens(issuedAt: now, userId: _alice.id);

      final result = keep(cancellation);
      await pumpEventQueue();
      expect(fakes.tokenGateway.refreshedTokens, [_oldToken]);
      expect(cancellation.cancel(), isTrue);
      refresh.complete(tokens);

      expect(await result, isNull);
      await pumpEventQueue();
      expect(fakes.accountGateway.currentUserTokens, isEmpty);
      expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
      await expectNothingStored();
    });

    test('while GET /user is asked logs out the session once it answers, '
        'and stores nothing', () async {
      final tokens = issueTokens(issuedAt: now, userId: _alice.id);
      final user = Completer<User>();
      fakes.tokenGateway.onRefresh = (_) async => tokens;
      fakes.accountGateway.onCurrentUser = (_) => user.future;

      final result = keep(cancellation);
      await pumpEventQueue();
      expect(fakes.accountGateway.currentUserTokens, [tokens.accessToken]);
      expect(cancellation.cancel(), isTrue);
      user.complete(_alice);

      expect(await result, isNull);
      await pumpEventQueue();
      expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
      await expectNothingStored();
    });

    test('once the server has confirmed the account comes too late: the '
        'account is registered', () async {
      final tokens = issueTokens(issuedAt: now, userId: _alice.id);
      fakes.tokenGateway.onRefresh = (_) async => tokens;
      fakes.accountGateway.onCurrentUser = (_) async => _alice;
      final write = Completer<void>();
      fakes.secureStore.beforeWrite = (_) => write.future;

      final result = keep(cancellation);
      await pumpEventQueue();
      expect(cancellation.cancel(), isFalse);
      write.complete();

      expect((await result)?.id, accountId);
      expect(cancellation.isCancelled, isFalse);
      expect((await fakes.registry.load()).activeAccountId, accountId);
      expect(fakes.accountGateway.logoutTokens, isEmpty);
    });

    test('ends the sign-in only once', () {
      expect(cancellation.cancel(), isTrue);
      expect(cancellation.cancel(), isFalse);
      expect(cancellation.isCancelled, isTrue);
    });
  });

  group('stores its tokens like a browser sign-in '
      '(decision log: Sessions)', () {
    late SessionDiagnostics diagnostics;
    late List<Duration> sleeps;
    late TokenSet tokens;

    setUp(() {
      diagnostics = SessionDiagnostics(fakes.preferences);
      sleeps = [];
      tokens = issueTokens(issuedAt: now, userId: _alice.id);
      fakes.tokenGateway.onRefresh = (_) async => tokens;
      fakes.accountGateway.onCurrentUser = (_) async => _alice;
      signIn = PreviousAppSignIn(
        connector: connector,
        tokenGateway: fakes.tokenGateway,
        accountGateway: fakes.accountGateway,
        tokenStore: fakes.tokenStore,
        registry: fakes.registry,
        sessions: sessions,
        diagnostics: diagnostics,
        clock: () => now,
        sleep: (duration) async => sleeps.add(duration),
      );
    });

    test('a write that fails twice is tried once more, letting the platform '
        'reset storage whose key is lost for good', () async {
      var refusals = 2;
      fakes.secureStore.beforeWrite = (_) async {
        if (refusals-- > 0) throw StateError('the Keystore failed');
      };

      final entry = await keep();

      expect(entry?.id, accountId);
      expect(sleeps, [
        SignInTokens.storageRetryDelay,
        SignInTokens.storageRetryDelay,
      ]);
      expect(fakes.secureStore.recoveringWrites, [
        TokenStore.refreshTokenKey(accountId),
      ]);
      expect(
        (await fakes.tokenStore.read(accountId))?.refreshToken,
        tokens.refreshToken,
      );
    });

    test('a write that keeps failing logs the new session out, registers '
        'nothing and leaves no manager of the account waiting', () async {
      final before = sessions.forAccount(accountId);
      fakes.secureStore.beforeWrite = (_) async =>
          throw StateError('the Keystore failed');

      await expectLater(keep(), throwsA(isA<StateError>()));
      await pumpEventQueue();

      expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
      await expectNothingStored();
      expect(sessions.forAccount(accountId), isNot(same(before)));
    });

    test('an account the registry cannot store is taken back and its new '
        'session logged out', () async {
      fakes.preferences.failWrites.add(AccountRegistry.storageKey);

      await expectLater(keep(), throwsA(isA<Exception>()));
      await pumpEventQueue();

      expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
      await expectNothingStored();
    });

    test('a registry that cannot be read stores nothing and logs the new '
        'session out', () async {
      fakes.preferences.failNextRead.add(AccountRegistry.storageKey);

      await expectLater(keep(), throwsA(isA<Exception>()));
      await pumpEventQueue();

      expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
      await expectNothingStored();
    });

    test('a stored sign-in ends a run of unreadable reads', () async {
      await diagnostics.noteUnreadable(accountId, now);

      await keep();

      expect(
        fakes.preferences.values,
        isNot(contains(SessionDiagnostics.unreadableSinceKey(accountId))),
      );
    });

    test('an ended session of the account is noted as replaced', () async {
      await diagnostics.recordEnd(
        accountId,
        SessionEndDiagnosis(
          at: now,
          cause: SessionEndCause.missingTokens,
          part: AppPart.app,
        ),
      );

      await keep();
      await pumpEventQueue();

      expect(
        (await diagnostics.lastEnd(accountId))?.resolution,
        SessionEndResolution.noTokens,
      );
    });
  });

  test('the kept account becomes the active one', () async {
    final other = await fakes.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
    );
    fakes.tokenGateway.onRefresh = (_) async =>
        issueTokens(issuedAt: now, userId: _alice.id);
    fakes.accountGateway.onCurrentUser = (_) async => _alice;
    expect((await fakes.registry.load()).activeAccountId, other.id);

    await keep();

    expect((await fakes.registry.load()).activeAccountId, accountId);
  });
}

Future<Never> _unreachable(String _) async =>
    throw const NetworkFailure(NetworkProblem.unreachable);

/// A connector that does not stop when cancelled.
final class _DeafConnector implements ServerConnector {
  const new(this._connect);

  final Future<ServerConnection> Function() _connect;

  @override
  Future<ServerConnection> connect(String input, {CancelToken? cancelToken}) =>
      _connect();
}
