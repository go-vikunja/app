import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/application/inactive_outboxes.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/fake_sync_client.dart';
import '../../../helpers/fake_write_client.dart';
import '../../../helpers/recording_sync_engine.dart';
import '../../../helpers/sample_data.dart';
import '../../../helpers/server_connections.dart';
import '../../../helpers/sync_fakes.dart';

RegisteredAccount _account(String id, {bool needsReauth = false}) =>
    RegisteredAccount(
      account: Account(
        id: id,
        serverRoot: Uri.parse('https://tasks.example.org/vikunja'),
        userId: id.codeUnitAt(0),
        username: id,
        displayName: id,
        addedAt: DateTime.utc(2026, 10),
        needsReauth: needsReauth,
      ),
      connection: fullServer270(),
    );

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 11, 12);

  void resume() => [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ].forEach(binding.handleAppLifecycleStateChanged);

  group('InactiveOutboxes', () {
    late Map<String, int> queued;
    late FakeAccountOutboxes outboxes;
    late AccountRegistryState? state;
    late InactiveOutboxes inactive;

    setUp(() {
      queued = {};
      outboxes = FakeAccountOutboxes((accountId) => queued[accountId] ?? 0);
      state = AccountRegistryState(
        accounts: [
          _account('alice'),
          _account('bob'),
          _account('carol'),
          _account('dave', needsReauth: true),
        ],
        activeAccountId: 'alice',
      );
      inactive = InactiveOutboxes(outboxes: outboxes, accounts: () => state);
    });

    test('drains only the inactive accounts with queued ops and leaves out '
        'those that need a new sign-in', () async {
      queued = {'alice': 3, 'bob': 2, 'dave': 5};

      await inactive.check();

      expect(outboxes.counted, ['bob', 'carol']);
      expect(outboxes.drained, ['bob']);
    });

    test('an account that became active, needs a new sign-in or is gone by '
        'the time its ops are counted is not drained', () async {
      state = AccountRegistryState(
        accounts: [
          _account('alice'),
          _account('bob'),
          _account('carol'),
          _account('erin'),
        ],
        activeAccountId: 'alice',
      );
      queued = {'bob': 1, 'carol': 1, 'erin': 1};
      outboxes.beforeCount = (accountId) async {
        if (accountId != 'bob') return;
        state = AccountRegistryState(
          accounts: [
            _account('alice'),
            _account('bob'),
            _account('carol', needsReauth: true),
          ],
          activeAccountId: 'bob',
        );
      };

      await inactive.check();

      expect(outboxes.counted, ['bob', 'carol', 'erin']);
      expect(outboxes.drained, isEmpty);
    });

    test('a check asked for during a check looks once more, not once per '
        'call', () async {
      queued = {'bob': 1};
      final gate = Completer<void>();
      outboxes.beforeCount = (accountId) =>
          outboxes.counted.length == 1 ? gate.future : Future.value();

      final first = inactive.check();
      await pumpEventQueue();
      final second = inactive.check();
      final third = inactive.check();
      gate.complete();
      await Future.wait([first, second, third]);

      expect(outboxes.counted, ['bob', 'carol', 'bob', 'carol']);
      expect(outboxes.drained, ['bob', 'bob']);
    });

    test(
      'a failed count or drain neither stops the others nor escapes',
      () async {
        queued = {'bob': 1, 'carol': 1};
        outboxes
          ..beforeCount = (accountId) async {
            if (accountId == 'bob') throw StateError('database');
          }
          ..onDrain = (_) async => throw StateError('sender');

        await inactive.check();
        await pumpEventQueue();

        expect(outboxes.drained, ['carol']);
      },
    );

    test('once disposed it checks nothing, and a running check stops before '
        'it drains', () async {
      queued = {'bob': 1, 'carol': 1};
      final gate = Completer<void>();
      outboxes.beforeCount = (_) => gate.future;

      final running = inactive.check();
      await pumpEventQueue();
      inactive.dispose();
      gate.complete();
      await running;
      await inactive.check();

      expect(outboxes.counted, ['bob']);
      expect(outboxes.drained, isEmpty);
    });

    test('nothing is drained without a loaded registry', () async {
      state = null;

      await inactive.check();

      expect(outboxes.counted, isEmpty);
    });
  });

  group('inactiveOutboxesProvider', () {
    late AuthFakes auth;
    late SyncFakes sync;
    late ProviderContainer container;
    late RegisteredAccount alice;
    late RegisteredAccount bob;
    late RegisteredAccount carol;

    setUp(() async {
      auth = AuthFakes();
      sync = SyncFakes(now: now);
      alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      bob = await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        activate: false,
      );
      // Signed out below; a session that is valid now reaches the logout.
      carol = await auth.seedAccount(
        insecureServer(),
        tokens: issueTokens(
          issuedAt: DateTime.now().toUtc(),
          userId: 9,
          username: 'carol',
        ),
        activate: false,
      );
      sync.accounts[alice.id] = AccountDataFakes(now: now)
        ..tasks.pendingChanges = 1;
      sync.accounts[bob.id] = AccountDataFakes(now: now)
        ..tasks.pendingChanges = 2;
      container = ProviderContainer(
        overrides: [...auth.overrides, ...sync.overrides],
      );
      addTearDown(container.dispose);
      await container.read(accountsProvider.future);
    });

    test('checks when the shell starts listening, when the app comes back '
        'to the front and when the accounts change', () async {
      final shell = container.listen(inactiveOutboxesProvider, (_, _) {});
      await pumpEventQueue();
      expect(sync.outboxes.counted, [bob.id, carol.id]);
      expect(sync.outboxes.drained, [bob.id]);

      resume();
      await pumpEventQueue();
      expect(sync.outboxes.drained, [bob.id, bob.id]);

      await container.read(accountRegistryProvider).setActive(bob.id);
      await pumpEventQueue();
      expect(sync.outboxes.drained, [bob.id, bob.id, alice.id]);
      shell.close();
    });

    test(
      'rests while the shell is gone and checks again when it is back',
      () async {
        final shell = container.listen(inactiveOutboxesProvider, (_, _) {});
        await pumpEventQueue();
        shell.close();
        sync.outboxes.counted.clear();

        resume();
        await container.read(accountRegistryProvider).markNeedsReauth(carol.id);
        await pumpEventQueue();
        expect(sync.outboxes.counted, isEmpty);

        final again = container.listen(inactiveOutboxesProvider, (_, _) {});
        await pumpEventQueue();
        expect(sync.outboxes.counted, [bob.id]);
        again.close();
      },
    );

    test('rests during a sign-out and checks again once it is over', () async {
      final shell = container.listen(inactiveOutboxesProvider, (_, _) {});
      await pumpEventQueue();
      sync.outboxes.counted.clear();
      final logout = Completer<void>();
      auth.accountGateway.onLogout = (_) => logout.future;

      final signingOut = container
          .read(signOutControllerProvider.notifier)
          .signOut(carol.id);
      await pumpEventQueue();
      expect(auth.accountGateway.logoutTokens, hasLength(1));
      expect(shell.read(), isNull);
      resume();
      await container.read(accountRegistryProvider).setActive(bob.id);
      await pumpEventQueue();
      expect(sync.outboxes.counted, isEmpty);

      logout.complete();
      await signingOut;
      await pumpEventQueue();

      expect(shell.read(), isNotNull);
      expect(sync.outboxes.counted, [alice.id]);
      expect(sync.outboxes.drained.last, alice.id);
      shell.close();
    });

    test('a check counting when a sign-out starts drains nothing', () async {
      final counting = Completer<void>();
      final release = Completer<void>();
      final drainedWhileSigningOut = <String>[];
      sync.outboxes
        ..beforeCount = (accountId) async {
          if (accountId != bob.id || counting.isCompleted) return;
          counting.complete();
          await release.future;
        }
        ..onDrain = (accountId) async {
          if (container.read(signOutControllerProvider)) {
            drainedWhileSigningOut.add(accountId);
          }
        };
      final shell = container.listen(inactiveOutboxesProvider, (_, _) {});
      await counting.future;

      final signingOut = container
          .read(signOutControllerProvider.notifier)
          .signOut(carol.id);
      release.complete();
      await signingOut;
      await pumpEventQueue();

      expect(drainedWhileSigningOut, isEmpty);
      // The check after the sign-out.
      expect(sync.outboxes.drained, [bob.id]);
      shell.close();
    });

    test('stops when the container goes', () async {
      final shell = container.listen(inactiveOutboxesProvider, (_, _) {});
      await pumpEventQueue();
      final outboxes = shell.read()!;
      sync.outboxes.counted.clear();

      container.dispose();
      resume();
      await outboxes.check();

      expect(sync.outboxes.counted, isEmpty);
    });
  });

  test('over the real databases and senders, only an inactive account with '
      'queued ops gets a sender, and it sends them', () async {
    // One in-memory database per account.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    final auth = AuthFakes();
    final files = FakeAccountDatabaseFiles();
    final databases = <String, AppDatabase>{};
    final write = FakeWriteClient(clock: () => now);
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
          (ref, _) => RecordingSyncEngine(SyncIdle(lastSyncedAt: now)),
        ),
        writeClientProvider.overrideWith((ref, _) => write),
        readClientProvider.overrideWith((ref, _) => FakeSyncClient()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    Future<RegisteredAccount> seed(
      ServerConnection connection,
      int userId, {
      bool needsReauth = false,
    }) => auth.seedAccount(
      connection,
      tokens: issueTokens(issuedAt: now, userId: userId, username: 'u$userId'),
      needsReauth: needsReauth,
      activate: false,
    );
    final alice = await seed(fullServer270(), 7);
    final bob = await seed(oauthServer230(), 8);
    final carol = await seed(insecureServer(), 9, needsReauth: true);
    final dave = await seed(v1OnlyServer270(), 10);
    await container.read(accountsProvider.future);
    for (final (accountId, taskId) in [
      (alice.id, 1),
      (bob.id, 2),
      (carol.id, 3),
    ]) {
      final task = sampleTask(id: taskId, title: 'Task $taskId');
      write.serverTasks[taskId] = task;
      final db = container.read(appDatabaseProvider(accountId));
      await db.tasksDao.upsertAll([task], syncRunId: 'run');
      await db.outboxDao.queueUpdate(
        taskId,
        const TaskChanges(done: true),
        now: now,
      );
    }
    expect(container.read(activeAccountIdProvider), alice.id);

    final shell = container.listen(inactiveOutboxesProvider, (_, _) {});
    await pumpEventQueue();

    expect(write.requests, ['update 2']);
    expect(await databases[bob.id]!.outboxDao.count(), 0);
    expect(container.exists(outboxSenderProvider(alice.id)), isFalse);
    expect(container.exists(outboxSenderProvider(carol.id)), isFalse);
    expect(container.exists(outboxSenderProvider(dave.id)), isFalse);
    expect(databases.keys, contains(dave.id));
    shell.close();
  });
}
