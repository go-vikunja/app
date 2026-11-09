import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/overview/application/open_tasks_provider.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/application/foreground_sync_scheduler_providers.dart';
import 'package:vikunja_mobile/features/sync/application/sync_status_queries.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/fake_sync_client.dart';
import '../../../helpers/fake_write_client.dart';
import '../../../helpers/recording_sync_engine.dart';
import '../../../helpers/server_connections.dart';
import '../../../helpers/sync_fakes.dart';
import '../../../helpers/trash_fakes.dart';

// Removing an account goes through the same SignOut as signing out, for
// the active account and for any other one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 11, 12);

  Future<RegisteredAccount> seed(
    AuthFakes auth,
    ServerConnection connection,
    int userId, {
    bool activate = false,
  }) => auth.seedAccount(
    connection,
    // Valid now, so the sign-out's server logout is part of the run.
    tokens: issueTokens(
      issuedAt: DateTime.now().toUtc(),
      userId: userId,
      username: 'user$userId',
    ),
    displayName: 'User $userId',
    activate: activate,
  );

  test('removing an inactive account stops its sender and engine and '
      'deletes its database; the active account keeps its engine, sender, '
      'database and screens, and its scheduler is back afterwards', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    final auth = AuthFakes();
    final files = FakeAccountDatabaseFiles();
    final databases = <String, AppDatabase>{};
    final engines = <String, RecordingSyncEngine>{};
    final container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (accountId, _) =>
                databases[accountId] = AppDatabase(NativeDatabase.memory()),
          ),
        ),
        syncEngineProvider.overrideWith(
          (ref, accountId) => engines[accountId] = RecordingSyncEngine(
            SyncIdle(lastSyncedAt: now),
          ),
        ),
        writeClientProvider.overrideWith(
          (ref, _) => FakeWriteClient(clock: () => now),
        ),
        readClientProvider.overrideWith((ref, _) => FakeSyncClient()),
        trashPortProvider.overrideWith((ref, _) => FakeTrashPort()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    final alice = await seed(auth, fullServer270(), 7, activate: true);
    final bob = await seed(auth, oauthServer230(), 8);
    await container.read(accountsProvider.future);
    // What the shell and its screens hold.
    container
      ..listen(openTasksProvider, (_, _) {})
      ..listen(projectsProvider, (_, _) {})
      ..listen(syncStatusProvider, (_, _) {});
    final scheduler = container.listen(
      foregroundSyncSchedulerProvider,
      (_, _) {},
    );
    await pumpEventQueue();
    final aliceScheduler = scheduler.read();
    expect(aliceScheduler, isNotNull);
    final aliceTasks = container.read(taskRepositoryProvider);
    final aliceProjects = container.read(projectRepositoryProvider);
    final aliceSender = container.read(outboxSenderProvider(alice.id));
    // Built by the inactive-outbox drain.
    final bobSender = container.read(outboxSenderProvider(bob.id));
    final bobDatabase = databases[bob.id]!;
    await pumpEventQueue();

    final logout = Completer<void>();
    auth.accountGateway.onLogout = (_) => logout.future;

    final signingOut = container
        .read(signOutControllerProvider.notifier)
        .signOut(bob.id);
    await pumpEventQueue();
    expect(auth.accountGateway.logoutTokens, hasLength(1));
    expect(scheduler.read(), isNull);
    logout.complete();
    await signingOut;
    await pumpEventQueue();

    expect(container.read(activeAccountIdProvider), alice.id);
    expect(container.read(taskRepositoryProvider), same(aliceTasks));
    expect(container.read(projectRepositoryProvider), same(aliceProjects));
    expect(container.read(outboxSenderProvider(alice.id)), same(aliceSender));
    expect(engines[alice.id]!.disposed, isFalse);
    expect(await databases[alice.id]!.outboxDao.count(), 0);
    expect(container.read(syncStatusProvider).value, isA<SyncIdle>());

    expect(engines[bob.id]!.disposed, isTrue);
    await expectLater(bobDatabase.outboxDao.count(), throwsA(anything));
    // Disposed: it no longer touches the closed database.
    await expectLater(bobSender.sendNow(), completion(isNull));
    expect(files.deleted, [bob.id]);

    // At rest while the sign-out ran, a new one for Alice afterwards.
    expect(scheduler.read(), isNotNull);
    expect(scheduler.read(), isNot(same(aliceScheduler)));
  });

  testWidgets("the active account's scheduler syncs again on its timer once "
      'an inactive account is removed', (tester) async {
    final auth = AuthFakes();
    final sync = SyncFakes(now: now);
    final alice = await seed(auth, fullServer270(), 7, activate: true);
    final bob = await seed(auth, oauthServer230(), 8);
    sync.accounts[bob.id] = AccountDataFakes(now: now);
    final container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        ...sync.overrides,
        clockProvider.overrideWithValue(() => now),
      ],
    );
    final shell = container.listen(foregroundSyncSchedulerProvider, (_, _) {});
    while (shell.read() == null) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    container.read(syncEngineProvider(bob.id));

    await container.read(signOutControllerProvider.notifier).signOut(bob.id);
    await tester.pump();
    expect(shell.read(), isNotNull);
    expect(container.read(activeAccountIdProvider), alice.id);
    expect(sync.accounts[bob.id]!.engine.disposed, isTrue);
    expect(sync.engine.disposed, isFalse);

    await tester.pump(const Duration(seconds: 61));
    expect(sync.engine.refreshCalls, 1);

    // Before the test ends: a timer still pending there would fail it.
    shell.close();
    container.dispose();
  });

  test('removing the active account activates the most recently active '
      'other one, never passing through a state without an active account '
      'or one that needs a first sync', () async {
    final auth = AuthFakes();
    final sync = SyncFakes(now: now);
    final container = ProviderContainer(
      overrides: [...auth.overrides, ...sync.overrides],
    );
    addTearDown(container.dispose);
    final alice = await seed(auth, fullServer270(), 7, activate: true);
    final bob = await seed(auth, oauthServer230(), 8);
    final carol = await seed(auth, insecureServer(), 9);
    for (final entry in [alice, bob]) {
      sync.accounts[entry.id] = AccountDataFakes(now: now);
    }
    // Synced at another time than Bob, so the switch shows in the status.
    sync.accounts[carol.id] = AccountDataFakes(
      now: now,
      status: SyncIdle(lastSyncedAt: now.subtract(const Duration(hours: 1))),
    );
    await container.read(accountsProvider.future);
    final registry = container.read(accountRegistryProvider);
    await registry.setActive(carol.id);
    await registry.setActive(bob.id);
    // Delivered before anything listens, so Carol's status is not built yet.
    await pumpEventQueue();
    container
      ..listen(openTasksProvider, (_, _) {})
      ..listen(projectsProvider, (_, _) {});
    final actives = <String?>[];
    container.listen(
      accountsProvider,
      (_, next) => actives.add(next.value?.activeAccountId),
    );
    final statuses = <SyncStatus?>[];
    container.listen(syncStatusProvider, (_, next) => statuses.add(next.value));
    await pumpEventQueue();
    statuses.clear();

    await container.read(signOutControllerProvider.notifier).signOut(bob.id);
    await pumpEventQueue();

    expect(container.read(activeAccountIdProvider), carol.id);
    expect(actives, isNotEmpty);
    expect(actives, everyElement(isNotNull));
    expect(statuses, isNotEmpty);
    expect(statuses.where(needsFirstSync), isEmpty);
    expect(
      container.read(taskRepositoryProvider),
      same(sync.accounts[carol.id]!.tasks),
    );
    expect(sync.accounts[bob.id]!.engine.disposed, isTrue);
    expect(sync.accounts[alice.id]!.engine.disposed, isFalse);
    expect(sync.accounts[carol.id]!.engine.disposed, isFalse);
    expect(sync.files.deleted, [bob.id]);
  });
}
