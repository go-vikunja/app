import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/online/online_account_security_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

import '../../helpers/account_security_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

UserSession _session(String id) => UserSession(id: id, deviceInfo: id);

void main() {
  final now = DateTime.utc(2026, 10, 21, 12);

  group('the online repository', () {
    late FakeAccountSecurityPort port;
    late String? currentSession;
    late OnlineAccountSecurityRepository repository;

    setUp(() {
      port = FakeAccountSecurityPort(now: () => now);
      currentSession = fakeCurrentSessionId;
      repository = OnlineAccountSecurityRepository(
        port: port,
        currentSessionId: () async => currentSession,
        now: () => now,
      );
    });

    test('reads everything from the server, every time', () async {
      port
        ..totp = TotpStatus.setupStarted
        ..export = UserDataExport(
          id: 3,
          size: 2372,
          expires: now.add(const Duration(days: 7)),
        );

      expect(await repository.totpStatus(), TotpStatus.setupStarted);
      expect(await repository.sessions(), fakeSessions(now));
      expect(await repository.sessions(), hasLength(3));
      expect(await repository.apiTokens(), isEmpty);
      expect(await repository.apiPermissions(), fakeApiPermissionGroups);
      expect(await repository.caldavTokens(), isEmpty);
      expect((await repository.dataExport())?.id, 3);
      expect(port.requests, [
        'totpStatus',
        'sessions',
        'sessions',
        'apiTokens',
        'apiPermissions',
        'caldavTokens',
        'dataExport',
      ]);
    });

    test("hands the server's failures on as they are", () async {
      port.failures['totpStatus'] = const NotFound();
      port.failures['sessions'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );

      await expectLater(repository.totpStatus(), throwsA(const NotFound()));
      await expectLater(repository.sessions(), throwsA(isA<NetworkFailure>()));
    });

    test(
      'ends the other sessions one after the other and keeps its own',
      () async {
        final ended = await repository.revokeOtherSessions();

        expect(ended, 2);
        expect(port.requests, [
          'sessions',
          'revokeSession $fakeWebSessionId',
          'revokeSession $fakeScriptSessionId',
        ]);
        expect(port.sessionList.map((session) => session.id), [
          fakeCurrentSessionId,
        ]);
      },
    );

    test('stops at the first failure and says how many ended', () async {
      port
        ..sessionList = [
          _session('a'),
          _session(fakeCurrentSessionId),
          _session('b'),
          _session('c'),
        ]
        ..revokeFailures['b'] = const NetworkFailure(NetworkProblem.timeout);

      final failure = await repository.revokeOtherSessions().then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );

      expect(
        failure,
        isA<OtherSessionsNotAllEnded>()
            .having((f) => f.ended, 'ended', 1)
            .having((f) => f.notEnded, 'notEnded', 2)
            .having((f) => f.failure, 'failure', isA<NetworkFailure>()),
      );
      expect(port.requests, ['sessions', 'revokeSession a', 'revokeSession b']);
      expect(port.sessionList.map((session) => session.id), [
        fakeCurrentSessionId,
        'b',
        'c',
      ]);
    });

    test('a session that ended meanwhile counts as ended', () async {
      port.beforeRequest = (request) async {
        if (request == 'revokeSession $fakeWebSessionId') {
          port.sessionList = [
            for (final session in port.sessionList)
              if (session.id != fakeWebSessionId) session,
          ];
        }
      };

      expect(await repository.revokeOtherSessions(), 2);
      await repository.revokeSession('long-gone');
    });

    test('another failure to end a session is not taken for success', () async {
      port.revokeFailures[fakeWebSessionId] = const Forbidden();

      await expectLater(
        repository.revokeSession(fakeWebSessionId),
        throwsA(const Forbidden()),
      );
      port.revokeFailures[fakeWebSessionId] = const NotFound(code: 3001);
      await expectLater(
        repository.revokeSession(fakeWebSessionId),
        throwsA(const NotFound(code: 3001)),
      );
    });

    test("never ends this app's own session", () async {
      await expectLater(
        repository.revokeSession(fakeCurrentSessionId),
        throwsArgumentError,
      );
      currentSession = null;
      await expectLater(
        repository.revokeOtherSessions(),
        throwsA(isA<SessionEnded>()),
      );

      expect(port.requests, isEmpty);
      expect(port.sessionList, hasLength(3));
    });

    test('creates a token and hands its value on once', () async {
      final created = await repository.createApiToken(
        NewApiToken(
          title: 'Home Assistant',
          permissions: const {
            'tasks': ['read_all'],
          },
          expiresAt: now.add(const Duration(days: 30)),
        ),
      );

      expect(created.secret, fakeApiTokenSecret(created.token.id));
      expect(created.toString(), isNot(contains(created.secret)));
      expect(await repository.apiTokens(), [created.token]);
    });

    test('refuses a token the server would take but that could never work, '
        'before any request', () async {
      NewApiToken token({
        String title = 'CI',
        Map<String, List<String>> permissions = const {
          'tasks': ['read_all'],
        },
        Duration expiresIn = const Duration(days: 1),
      }) => NewApiToken(
        title: title,
        permissions: permissions,
        expiresAt: now.add(expiresIn),
      );

      for (final refused in [
        token(title: '   '),
        token(permissions: const {}),
        token(permissions: const {'tasks': []}),
        token(expiresIn: Duration.zero),
        token(expiresIn: const Duration(days: -1)),
      ]) {
        await expectLater(
          repository.createApiToken(refused),
          throwsArgumentError,
          reason: '$refused',
        );
      }
      expect(port.requests, isEmpty);
    });

    test('deletes tokens as the server does', () async {
      final created = await repository.createCaldavToken();
      expect(created.secret, hasLength(64));

      await repository.deleteCaldavToken(created.token.id);
      await repository.deleteCaldavToken(99);
      await expectLater(
        repository.deleteApiToken(99),
        throwsA(const Forbidden()),
      );
      expect(await repository.caldavTokens(), isEmpty);
    });
  });

  group('the providers', () {
    // The session managers run on the real clock.
    final noon = DateTime.now().toUtc();
    late AuthFakes auth;
    late ProviderContainer container;

    setUp(() {
      auth = AuthFakes();
      container = ProviderContainer(
        overrides: [
          ...auth.overrides,
          accountSecurityPortProvider.overrideWith(
            (ref, _) => FakeAccountSecurityPort(),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    Future<AccountSecurityRepository> signIn(TokenSet tokens) async {
      final entry = await auth.seedAccount(fullServer270(), tokens: tokens);
      await container.read(accountsProvider.future);
      return container
          .listen(accountSecurityRepositoryForProvider(entry.id), (_, _) {})
          .read();
    }

    test("this app's session is the sid of its access token, without a "
        'request', () async {
      final repository = await signIn(
        issueTokens(issuedAt: noon, sessionId: fakeCurrentSessionId),
      );

      expect(await repository.currentSessionId(), fakeCurrentSessionId);
      expect(auth.tokenGateway.refreshedTokens, isEmpty);
    });

    test(
      'with only a refresh token stored, the next access token tells',
      () async {
        final tokens = issueTokens(issuedAt: noon, sessionId: 'session-7');
        final repository = await signIn(tokens);
        final accountId = container.read(activeAccountIdProvider)!;
        await auth.secureStore.delete(TokenStore.accessTokenKey(accountId));
        auth.tokenGateway.onRefresh = (_) async =>
            issueTokens(issuedAt: noon, sessionId: 'session-7');

        expect(await repository.currentSessionId(), 'session-7');
        expect(auth.tokenGateway.refreshedTokens, [tokens.refreshToken]);
      },
    );

    test('signed out, there is none', () async {
      final repository = await signIn(issueTokens(issuedAt: noon));
      await auth.tokenStore.delete(container.read(activeAccountIdProvider)!);

      expect(await repository.currentSessionId(), isNull);
    });

    test("the active account's follows the active account", () async {
      expect(container.read(accountSecurityRepositoryProvider), isNull);

      final repository = await signIn(issueTokens(issuedAt: noon));

      expect(container.read(accountSecurityRepositoryProvider), repository);
    });
  });
}
