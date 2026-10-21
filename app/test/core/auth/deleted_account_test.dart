import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/deleted_account.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

import '../../helpers/account_settings_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

const _userGone = NotFound(code: userDoesNotExistCode);

void main() {
  group('a read of the user', () {
    final now = DateTime.utc(2026, 10, 21, 12);
    late AuthFakes auth;
    late SessionManager session;
    late RegisteredAccount entry;

    setUp(() async {
      auth = AuthFakes();
      entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      session = SessionManagers(
        tokenStore: auth.tokenStore,
        clockOffsets: auth.clockOffsets,
        tokenGateway: auth.tokenGateway,
        connectionFor: (id) async => (await auth.registry.find(id))?.connection,
        markNeedsReauth: auth.registry.markNeedsReauth,
        clock: () => now,
        sleep: (_) async {},
      ).forAccount(entry.id);
    });

    Future<bool> needsReauth() async =>
        (await auth.registry.find(entry.id))!.account.needsReauth;

    test(
      'for a deleted account ends the session, as the refresh fails',
      () async {
        auth.tokenGateway.onRefresh = (_) async => throw const SessionEnded(
          SessionEndReason.invalidRefreshToken,
          code: 16002,
        );

        await expectLater(
          endingSessionOfDeletedAccount<User>(session, () => throw _userGone),
          throwsA(isA<SessionEnded>()),
        );
        expect(await needsReauth(), isTrue);
      },
    );

    test('keeps the 404 when the refresh cannot tell', () async {
      auth.tokenGateway.onRefresh = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await expectLater(
        endingSessionOfDeletedAccount<User>(session, () => throw _userGone),
        throwsA(_userGone),
      );
      expect(await needsReauth(), isFalse);
    });

    test('keeps the 404 when the session lives on', () async {
      auth.tokenGateway.onRefresh = (_) async => issueTokens(issuedAt: now);

      await expectLater(
        endingSessionOfDeletedAccount<User>(session, () => throw _userGone),
        throwsA(_userGone),
      );
      expect(auth.tokenGateway.refreshedTokens, hasLength(1));
      expect(await needsReauth(), isFalse);
    });

    test('passes the user and other failures through untouched', () async {
      const alice = User(id: 7, username: 'alice');

      expect(
        await endingSessionOfDeletedAccount(session, () async => alice),
        alice,
      );
      await expectLater(
        endingSessionOfDeletedAccount<User>(
          session,
          () => throw const NotFound(),
        ),
        throwsA(const NotFound()),
      );
      expect(auth.tokenGateway.refreshedTokens, isEmpty);
    });
  });

  group('the app', () {
    // The session managers run on the real clock.
    final noon = DateTime.now().toUtc();
    late AuthFakes auth;
    late ProviderContainer container;
    late RegisteredAccount alice;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      auth = AuthFakes();
      final files = FakeAccountDatabaseFiles();
      container = ProviderContainer(
        overrides: [
          ...auth.overrides,
          accountDatabaseFilesProvider.overrideWithValue(files),
          openDatabasesProvider.overrideWithValue(
            OpenDatabases(
              files,
              open: (_, _) => AppDatabase(NativeDatabase.memory()),
            ),
          ),
          readClientProvider.overrideWith((ref, _) => FakeSyncClient()),
          userSettingsWritePortProvider.overrideWith(
            (ref, _) => FakeUserSettingsWritePort(),
          ),
        ],
      );
      addTearDown(container.dispose);
      alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: noon),
      );
      await container.read(accountsProvider.future);
      auth.accountGateway.onCurrentUser = (_) async => throw _userGone;
      // 16003 rather than 16002, which waits seconds for a sibling isolate
      // that might have won the rotation.
      auth.tokenGateway.onRefresh = (_) async =>
          throw const SessionEnded(SessionEndReason.expired, code: 16003);
    });

    Future<bool> needsReauth() async =>
        (await auth.registry.find(alice.id))!.account.needsReauth;

    test(
      'asks for a new sign-in when a sync finds the account deleted',
      () async {
        await expectLater(
          container.read(syncEngineProvider(alice.id)).ensureInitialSync(),
          throwsA(isA<SessionEnded>()),
        );

        expect(await needsReauth(), isTrue);
      },
    );

    test('asks for a new sign-in when the account settings find the account '
        'deleted', () async {
      final repository = container
          .listen(accountSettingsRepositoryForProvider(alice.id), (_, _) {})
          .read();

      await expectLater(repository.refresh(), throwsA(isA<SessionEnded>()));

      expect(await needsReauth(), isTrue);
    });
  });
}
