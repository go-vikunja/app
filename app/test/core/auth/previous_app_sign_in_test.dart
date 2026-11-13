import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/previous_app_sign_in.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';

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
