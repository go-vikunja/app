import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_user_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/trash_fakes.dart';

// The real repository and sender providers over an in-memory database, with
// the clients and the engine faked: what the screens get when they write.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 10, 12);
  final task = sampleTask(id: 1, title: 'Water the plants', projectId: 7);
  late AuthFakes auth;
  late FakeAccountDatabaseFiles files;
  late List<AppDatabase> opened;
  late RecordingSyncEngine engine;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late ProviderContainer container;

  setUp(() {
    auth = AuthFakes();
    files = FakeAccountDatabaseFiles();
    opened = [];
    engine = RecordingSyncEngine(SyncIdle(lastSyncedAt: now));
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient()..allTasks = [task];
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (_, _) {
              final db = AppDatabase(NativeDatabase.memory());
              opened.add(db);
              return db;
            },
          ),
        ),
        syncEngineProvider.overrideWith((ref, accountId) => engine),
        writeClientProvider.overrideWith((ref, accountId) => write),
        readClientProvider.overrideWith((ref, accountId) => read),
        trashPortProvider.overrideWith((ref, accountId) => FakeTrashPort()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Signs Alice in, builds her repository as the shell would and seeds her
  /// database with [task].
  Future<(String, TaskRepository)> signedIn() async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    await container.read(accountsProvider.future);
    final repository = container.listen(taskRepositoryProvider, (_, _) {});
    await pumpEventQueue();
    await opened.single.tasksDao.upsertAll([task], syncRunId: 'run');
    write.serverTasks[task.id] = task;
    return (alice.id, repository.read()!);
  }

  test("a local write goes through the account's sender, marks the row "
      'pending meanwhile and refreshes afterwards', () async {
    final (accountId, repository) = await signedIn();
    expect(container.exists(outboxSenderProvider(accountId)), isTrue);
    final pendingIds = container.listen(pendingTaskIdsProvider, (_, _) {});
    final pendingCount = container.listen(pendingChangesProvider, (_, _) {});
    await pumpEventQueue();
    final gate = Completer<void>();
    write.beforeRequest = (_) => gate.future;

    await repository.setDone(task.id, done: true);
    await pumpEventQueue();

    expect(write.requests, ['update 1']);
    expect(pendingIds.read().value, {task.id});
    expect(pendingCount.read().value, 1);
    expect((await opened.single.tasksDao.find(task.id))!.done, isTrue);

    gate.complete();
    await pumpEventQueue();

    expect(write.updates, [(1, const TaskChanges(done: true))]);
    expect(pendingIds.read().value, isEmpty);
    expect(pendingCount.read().value, 0);
    expect(engine.refreshCalls, 1);
  });

  test("the pickers' label create and people search reach the account's "
      'database, and what they return is attached locally and sent', () async {
    final (_, repository) = await signedIn();
    final labels = container.read(labelRepositoryProvider);
    final users = container.read(userRepositoryProvider);
    expect(labels, isA<LocalLabelRepository>());
    expect(users, isA<LocalUserRepository>());
    const bob = User(id: 8, username: 'bob', name: 'Bob');
    read.projectUsers[task.projectId] = [bob];
    write.serverUsers[bob.id] = bob;

    final label = await labels!.create(
      const NewLabel(title: 'Garden', hexColor: '0ead69'),
    );
    final found = await users!.searchAssignees(task.projectId, ' bo ');

    expect(found, [bob]);
    expect(read.requests, contains('users ${task.projectId} bo'));
    expect(await labels.watchAll().first, [label]);
    expect(await users.knownUsers(), contains(bob));

    await repository.updateTask(
      task.id,
      TaskChanges(
        labels: IdSetChange(added: {label.id}),
        assignees: const IdSetChange(added: {8}),
      ),
    );
    final local = (await opened.single.tasksDao.find(task.id))!;
    expect(local.labels, [label]);
    expect(local.assignees, [bob]);
    await pumpEventQueue();

    expect(write.requests, ['create label Garden', 'update 1']);
    final stored = write.serverTasks[task.id]!;
    expect(stored.labels.map((l) => l.id), [label.id]);
    expect(stored.assignees.map((u) => u.id), [bob.id]);
    expect((await opened.single.tasksDao.find(task.id))!.labels, [label]);
  });

  test('signing out with an op in flight disposes the sender and wipes the '
      'account without errors', () async {
    final (accountId, repository) = await signedIn();
    final gate = Completer<void>();
    write.beforeRequest = (_) => gate.future;
    await repository.setDone(task.id, done: true);
    await pumpEventQueue();
    expect(write.requests, ['update 1']);
    final sender = container.read(outboxSenderProvider(accountId));
    expect(sender.state, OutboxSenderState.draining);

    await container.read(signOutProvider).call(accountId);
    await pumpEventQueue();
    gate.complete();
    await pumpEventQueue();

    expect(container.read(taskRepositoryProvider), isNull);
    expect(files.deleted, [accountId]);
    expect(engine.disposed, isTrue);
    expect(engine.refreshCalls, 0);
    // Disposed: a drain sends nothing any more.
    await sender.drain();
    expect(write.requests, ['update 1']);
  });

  test('a token the server rejects without the session ending is retried, '
      'and Send now gets it through', () async {
    final (accountId, repository) = await signedIn();
    final sender = container.read(outboxSenderProvider(accountId));
    write.beforeRequest = (_) => throw const TokenRejected();

    await repository.setDone(task.id, done: true);
    await pumpEventQueue();

    expect(write.requests, ['update 1']);
    expect(sender.state, OutboxSenderState.waiting);

    write.beforeRequest = null;
    expect(await repository.sendPendingChanges(), isNull);

    expect(write.updates, [(1, const TaskChanges(done: true))]);
    expect(await opened.single.outboxDao.count(), 0);
  });

  test('a session that needs a new sign-in pauses the sender', () async {
    final (accountId, repository) = await signedIn();
    final sender = container.read(outboxSenderProvider(accountId));
    await container.read(accountRegistryProvider).markNeedsReauth(accountId);
    await pumpEventQueue();
    expect(sender.state, OutboxSenderState.paused);

    await repository.setDone(task.id, done: true);
    await pumpEventQueue();

    expect(write.requests, isEmpty);
    expect(await opened.single.outboxDao.count(), 1);
  });
}
