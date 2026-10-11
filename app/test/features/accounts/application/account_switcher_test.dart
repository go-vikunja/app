import 'dart:async';

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
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/sample_data.dart';
import '../../../helpers/server_connections.dart';
import '../../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 12);
  late AuthFakes auth;
  late ProviderContainer container;

  setUp(() {
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
      ],
    );
    addTearDown(container.dispose);
  });

  test('switching activates the account and puts it first by recency; the '
      'active account and an unknown id change nothing', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      activate: false,
    );
    await container.read(accountsProvider.future);
    final switcher = container.read(accountSwitcherProvider);
    final writes = <Object>[];
    container.read(accountRegistryProvider).changes.listen(writes.add);

    await switcher.switchTo(alice.id);
    await switcher.switchTo('unknown');
    await pumpEventQueue();
    expect(writes, isEmpty);

    await switcher.switchTo(bob.id);
    await pumpEventQueue();

    final state = container.read(accountsProvider).value!;
    expect(state.activeAccountId, bob.id);
    expect(state.accountsByRecency.map((entry) => entry.id), [
      bob.id,
      alice.id,
    ]);
    expect(container.read(activeAccountIdProvider), bob.id);
  });

  test('the account becomes active once its engine has reported, so its '
      'status is there at once', () async {
    final sync = SyncFakes(now: now);
    final container = ProviderContainer(
      overrides: [...auth.overrides, ...sync.overrides],
    );
    addTearDown(container.dispose);
    await auth.seedAccount(fullServer270(), tokens: issueTokens(issuedAt: now));
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      activate: false,
    );
    final bobData = sync.accounts[bob.id] = AccountDataFakes(
      now: now,
      restored: false,
    );
    await container.read(accountsProvider.future);

    var switched = false;
    unawaited(
      container
          .read(accountSwitcherProvider)
          .switchTo(bob.id)
          .then((_) => switched = true),
    );
    await pumpEventQueue();
    expect(switched, isFalse);
    expect(container.read(activeAccountIdProvider), isNot(bob.id));

    bobData.engine.emit(SyncIdle(lastSyncedAt: now));
    await pumpEventQueue();

    expect(switched, isTrue);
    expect(container.read(activeAccountIdProvider), bob.id);
    expect(container.read(syncStatusProvider).value, isA<SyncIdle>());
  });

  test('nothing switches while a sign-in runs, which activates its account '
      'when it ends', () async {
    await auth.seedAccount(fullServer270(), tokens: issueTokens(issuedAt: now));
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      activate: false,
    );
    await container.read(accountsProvider.future);
    container.listen(signInControllerProvider, (_, _) {});
    final browser = Completer<Uri?>();
    auth.webAuthenticator.handler = (_, _) => browser.future;
    unawaited(
      container.read(signInControllerProvider.notifier).signIn(fullServer270()),
    );
    await pumpEventQueue();
    expect(container.read(signInControllerProvider), isA<SignInInProgress>());

    final switched = await container
        .read(accountSwitcherProvider)
        .switchTo(bob.id);

    expect(switched, isFalse);
    expect(container.read(activeAccountIdProvider), isNot(bob.id));
    browser.complete(null);
  });

  group('AccountSwitcher', () {
    late RegisteredAccount bob;
    late AccountRegistry registry;
    var busy = false;
    final prepared = <String>[];
    Future<void> Function(String accountId)? onPrepare;

    AccountSwitcher switcher() => AccountSwitcher(
      registry: registry,
      prepare: (accountId) async {
        prepared.add(accountId);
        await onPrepare?.call(accountId);
      },
      busy: () => busy,
    );

    setUp(() async {
      busy = false;
      prepared.clear();
      onPrepare = null;
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      bob = await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        activate: false,
      );
      registry = container.read(accountRegistryProvider);
    });

    Future<String?> active() async => (await registry.load()).activeAccountId;

    test('activates the account only once it is prepared', () async {
      final ready = Completer<void>();
      onPrepare = (_) => ready.future;
      final switching = switcher().switchTo(bob.id);
      await pumpEventQueue();
      expect(prepared, [bob.id]);
      expect(await active(), isNot(bob.id));

      ready.complete();

      expect(await switching, isTrue);
      expect(await active(), bob.id);
    });

    test('refuses during a sign-in or sign-out, also one that starts while '
        'the account is prepared', () async {
      busy = true;
      expect(await switcher().switchTo(bob.id), isFalse);
      expect(prepared, isEmpty);

      busy = false;
      onPrepare = (_) async => busy = true;
      expect(await switcher().switchTo(bob.id), isFalse);
      expect(await active(), isNot(bob.id));
    });

    test('ignores another switch while one is under way', () async {
      final ready = Completer<void>();
      onPrepare = (_) => ready.future;
      final accounts = switcher();
      final first = accounts.switchTo(bob.id);
      await pumpEventQueue();

      expect(await accounts.switchTo(bob.id), isFalse);
      ready.complete();
      expect(await first, isTrue);
      expect(prepared, [bob.id]);
    });
  });

  test(
    'the pending changes of an inactive account follow its outbox',
    () async {
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      final bob = await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        activate: false,
      );
      await container.read(accountsProvider.future);
      final pending = container.listen(
        accountPendingChangesProvider(bob.id),
        (_, _) {},
      );
      await pumpEventQueue();
      expect(pending.read().value, 0);

      final db = container.read(appDatabaseProvider(bob.id));
      final task = sampleTask(id: 2, title: 'Call the plumber');
      await db.tasksDao.upsertAll([task], syncRunId: 'run');
      await db.outboxDao.queueUpdate(
        task.id,
        const TaskChanges(done: true),
        now: now,
      );
      await pumpEventQueue();

      expect(pending.read().value, 1);
      expect(container.exists(outboxSenderProvider(bob.id)), isFalse);
      pending.close();
    },
  );
}
