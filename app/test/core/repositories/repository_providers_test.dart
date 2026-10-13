import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/overview/application/open_tasks_provider.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 10, 12);
  late AuthFakes auth;
  late SyncFakes sync;
  late ProviderContainer container;

  setUp(() {
    auth = AuthFakes();
    sync = SyncFakes(now: now);
    container = ProviderContainer(
      overrides: [...auth.overrides, ...sync.overrides],
    );
    addTearDown(container.dispose);
  });

  AccountDataFakes dataFor(String accountId) =>
      sync.accounts.putIfAbsent(accountId, () => AccountDataFakes(now: now));

  test('without an account there are no repositories and no status', () async {
    await container.read(accountsProvider.future);

    expect(container.read(activeAccountIdProvider), isNull);
    expect(container.read(projectRepositoryProvider), isNull);
    expect(container.read(taskRepositoryProvider), isNull);
    expect(container.read(labelRepositoryProvider), isNull);
    expect(container.read(userRepositoryProvider), isNull);
    expect(container.read(subscriptionRepositoryProvider), isNull);
    final projects = container.listen(projectsProvider, (_, _) {});
    expect(projects.read(), const AsyncLoading<List<Project>>());
    final status = container.listen(syncStatusProvider, (_, _) {});
    await pumpEventQueue();
    expect(status.read().isLoading, isTrue);
  });

  test(
    'switching the account replaces the repositories and clears the data',
    () async {
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
      dataFor(alice.id).projects.all = [
        sampleProject(id: 1, title: 'Alice project'),
      ];
      dataFor(bob.id).projects.all = [
        sampleProject(id: 2, title: 'Bob project'),
      ];
      final projectStates = <AsyncValue<List<Project>>>[];
      container
        ..listen(projectsProvider, (_, next) => projectStates.add(next))
        ..listen(openTasksProvider, (_, _) {});
      await pumpEventQueue();
      expect(
        container.read(projectRepositoryProvider),
        same(dataFor(alice.id).projects),
      );
      expect(
        container.read(taskRepositoryProvider),
        same(dataFor(alice.id).tasks),
      );
      expect(projectStates.last.value?.single.title, 'Alice project');

      await container.read(accountRegistryProvider).setActive(bob.id);
      await pumpEventQueue();

      expect(container.read(activeAccountIdProvider), bob.id);
      expect(
        container.read(projectRepositoryProvider),
        same(dataFor(bob.id).projects),
      );
      expect(
        container.read(taskRepositoryProvider),
        same(dataFor(bob.id).tasks),
      );
      expect(
        container.read(subscriptionRepositoryProvider),
        same(dataFor(bob.id).subscriptions),
      );
      // The old account's data must not linger while the new one loads.
      expect(
        projectStates.map(
          (s) => s.isLoading ? 'loading' : s.value?.singleOrNull?.title,
        ),
        ['Alice project', 'loading', 'Bob project'],
      );
    },
  );

  test('the sync status follows the active account', () async {
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
    sync.accounts[bob.id] = AccountDataFakes(
      now: now,
      status: const SyncNeverRun(),
    );
    final statuses = <AsyncValue<SyncStatus>>[];
    container.listen(syncStatusProvider, (_, next) => statuses.add(next));
    await pumpEventQueue();
    expect(statuses.last.value, isA<SyncIdle>());

    await container.read(accountRegistryProvider).setActive(bob.id);
    await pumpEventQueue();

    expect(statuses.last, isA<AsyncData<SyncStatus>>());
    expect(statuses.last.value, isA<SyncNeverRun>());
    expect(statuses.any((s) => s.isLoading), isTrue);
    expect(dataFor(alice.id).engine.disposed, isFalse);
  });

  test(
    'flagging an account for re-authentication keeps its repositories',
    () async {
      final alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      await container.read(accountsProvider.future);
      container.listen(projectsProvider, (_, _) {});
      await pumpEventQueue();
      final before = container.read(projectRepositoryProvider);

      await container.read(accountRegistryProvider).markNeedsReauth(alice.id);
      await pumpEventQueue();

      expect(container.read(projectRepositoryProvider), same(before));
    },
  );

  test('signing out stops the engine and deletes the database files, '
      'without errors on the screens', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    await container.read(accountsProvider.future);
    final errors = <Object>[];
    container
      ..listen(projectsProvider, (_, next) {
        if (next case AsyncError(:final error)) errors.add(error);
      }, onError: (error, _) => errors.add(error))
      ..listen(openTasksProvider, (_, _) {})
      ..listen(syncStatusProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(syncStatusProvider).value, isA<SyncIdle>());

    await container.read(signOutProvider).call(alice.id);
    await pumpEventQueue();

    expect(container.read(activeAccountIdProvider), isNull);
    expect(container.read(projectRepositoryProvider), isNull);
    expect(container.read(taskRepositoryProvider), isNull);
    expect(sync.engine.disposed, isTrue);
    expect(sync.files.deleted, [alice.id]);
    expect(errors, isEmpty);
  });

  test('signing out an account whose engine was never built only deletes '
      'the files', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    await container.read(accountsProvider.future);

    await container.read(signOutProvider).call(alice.id);

    expect(sync.engine.disposed, isFalse);
    expect(sync.files.deleted, [alice.id]);
  });
}
