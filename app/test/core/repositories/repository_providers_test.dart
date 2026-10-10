import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/overview/application/open_tasks_provider.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_read_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';

void main() {
  late AuthFakes auth;
  late Map<String, FakeReadClient> clients;
  late ProviderContainer container;

  setUp(() {
    auth = AuthFakes();
    clients = {};
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        readClientProvider.overrideWith(
          (ref, accountId) =>
              clients.putIfAbsent(accountId, FakeReadClient.new),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('without an account there are no repositories', () async {
    await container.read(accountsProvider.future);

    expect(container.read(activeAccountIdProvider), isNull);
    expect(container.read(projectRepositoryProvider), isNull);
    expect(container.read(taskRepositoryProvider), isNull);
    final projects = container.listen(projectsProvider, (_, _) {});
    expect(projects.read(), const AsyncLoading<List<Project>>());
  });

  test(
    'switching the account replaces the repositories and clears the data',
    () async {
      final now = DateTime.now().toUtc();
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
      clients.putIfAbsent(alice.id, FakeReadClient.new).projects.all = [
        sampleProject(id: 1, title: 'Alice project'),
      ];
      clients.putIfAbsent(bob.id, FakeReadClient.new).projects.all = [
        sampleProject(id: 2, title: 'Bob project'),
      ];
      final projectStates = <AsyncValue<List<Project>>>[];
      container
        ..listen(projectsProvider, (_, next) => projectStates.add(next))
        ..listen(openTasksProvider, (_, _) {});
      await pumpEventQueue();
      final aliceProjects = container.read(projectRepositoryProvider);
      final aliceTasks = container.read(taskRepositoryProvider);
      expect(projectStates.last.value?.single.title, 'Alice project');

      await container.read(accountRegistryProvider).setActive(bob.id);
      await pumpEventQueue();

      expect(container.read(activeAccountIdProvider), bob.id);
      expect(
        container.read(projectRepositoryProvider),
        isNot(same(aliceProjects)),
      );
      expect(container.read(taskRepositoryProvider), isNot(same(aliceTasks)));
      // The old account's data must not linger while the new one loads.
      expect(
        projectStates.map(
          (s) => s.isLoading ? 'loading' : s.value?.singleOrNull?.title,
        ),
        ['Alice project', 'loading', 'Bob project'],
      );
      expect(clients[alice.id]!.projects.listAllCalls, 1);
      expect(clients[bob.id]!.projects.listAllCalls, 1);
      expect(clients[alice.id]!.tasks.listQueries, hasLength(1));
      expect(clients[bob.id]!.tasks.listQueries, hasLength(1));
    },
  );

  test(
    'flagging an account for re-authentication keeps its repositories',
    () async {
      final alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      await container.read(accountsProvider.future);
      container.listen(projectsProvider, (_, _) {});
      await pumpEventQueue();
      final before = container.read(projectRepositoryProvider);

      await container.read(accountRegistryProvider).markNeedsReauth(alice.id);
      await pumpEventQueue();

      expect(container.read(projectRepositoryProvider), same(before));
      expect(clients[alice.id]!.projects.listAllCalls, 1);
    },
  );
}
