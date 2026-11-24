import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_user_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_providers.dart';
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
  late List<FakeWriteClient> writes;
  late List<FakeSyncClient> reads;
  late List<RecordingSyncEngine> engines;
  late RecordingSyncEngine engine;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late ProviderContainer container;

  setUp(() {
    auth = AuthFakes();
    files = FakeAccountDatabaseFiles();
    opened = [];
    writes = [];
    reads = [];
    engines = [];
    // The clients and the engine are built anew for each stored server
    // version, as the real ports key rebuilds them.
    String serverVersionOf(Ref ref, String accountId) {
      final version = ref.watch(
        accountsProvider.select((accounts) {
          final info = accounts.value?.find(accountId)?.connection.info;
          return info == null ? null : info.version?.raw ?? info.rawVersion;
        }),
      );
      if (version == null) {
        throw StateError('Account $accountId is not registered');
      }
      return version;
    }

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
        syncEngineProvider.overrideWith((ref, accountId) {
          serverVersionOf(ref, accountId);
          ref.watch(appDatabaseProvider(accountId));
          final built = RecordingSyncEngine(SyncIdle(lastSyncedAt: now));
          ref.onDispose(() => unawaited(built.dispose()));
          engines.add(built);
          return engine = built;
        }),
        writeClientProvider.overrideWith((ref, accountId) {
          serverVersionOf(ref, accountId);
          final built = FakeWriteClient(clock: () => now);
          if (writes.lastOrNull case final previous?) {
            built.serverTasks.addAll(previous.serverTasks);
          }
          writes.add(built);
          return write = built;
        }),
        readClientProvider.overrideWith((ref, accountId) {
          serverVersionOf(ref, accountId);
          final built = FakeSyncClient()..allTasks = [task];
          reads.add(built);
          return read = built;
        }),
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
    expect(engine.refreshAfterWriteCalls, 1);
  });

  test("the pickers' label create and people search reach the account's "
      'database; the label is stored at once, created by the signed-in user, '
      'and sent with the update that attaches it', () async {
    final (accountId, repository) = await signedIn();
    final labels = container.read(labelRepositoryProvider);
    final users = container.read(userRepositoryProvider);
    expect(labels, isA<LocalLabelRepository>());
    expect(users, isA<LocalUserRepository>());
    const bob = User(id: 8, username: 'bob', name: 'Bob');
    read.projectUsers[task.projectId] = [bob];
    write.serverUsers[bob.id] = bob;
    final gate = Completer<void>();
    write.beforeRequest = (request) async {
      if (request.startsWith('create label')) await gate.future;
    };

    final label = await labels!.create(
      const NewLabel(title: 'Garden', hexColor: '0ead69'),
    );
    final found = await users!.searchAssignees(task.projectId, ' bo ');

    expect(label.id, isNegative);
    expect(label.createdBy?.id, 7);
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

    gate.complete();
    await container.read(outboxSenderProvider(accountId)).drain();

    expect(write.requests, ['create label Garden', 'update 1']);
    final stored = write.serverTasks[task.id]!;
    expect(stored.labels.map((l) => l.id), [900]);
    expect(stored.assignees.map((u) => u.id), [bob.id]);
    expect(
      (await opened.single.tasksDao.find(task.id))!.labels.map((l) => l.id),
      [900],
    );
    expect((await labels.watchLabel(label.id).first)!.id, 900);
  });

  test("a lost label create adopts the signed-in user's own label, not "
      "another member's of that title", () async {
    final (accountId, _) = await signedIn();
    final labels = container.read(labelRepositoryProvider)!;
    const alice = User(id: 7, username: 'alice');
    const ana = User(id: 6, username: 'ana');
    read.allLabels = [
      Label(id: 30, title: 'errand', created: now, createdBy: ana),
      Label(
        id: 29,
        title: 'errand',
        created: now.subtract(const Duration(minutes: 5)),
        createdBy: alice,
      ),
    ];
    write.beforeRequest = (_) =>
        throw const NetworkFailure(NetworkProblem.timeout);

    final local = await labels.create(const NewLabel(title: 'errand'));
    final sender = container.read(outboxSenderProvider(accountId));
    await sender.drain();
    write.beforeRequest = null;
    await sender.sendNow();

    expect(write.requests, ['create label errand']);
    expect((await labels.watchLabel(local.id).first)!.id, 29);
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
    expect(engine.refreshAfterWriteCalls, 0);
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

  group('a stored server upgrade', () {
    Future<void> upgrade(String accountId) async {
      await container
          .read(accountRegistryProvider)
          .updateConnection(accountId, (_) => fullServer280());
      await pumpEventQueue();
    }

    test("while a change is on its way keeps the account's sender: it "
        'stores the answer, and the next change goes at once through the '
        'rebuilt clients and engine', () async {
      final (accountId, repository) = await signedIn();
      final other = sampleTask(id: 2, title: 'Call the plumber', projectId: 7);
      await opened.single.tasksDao.upsertAll([other], syncRunId: 'run');
      write.serverTasks[other.id] = other;
      final sender = container.read(outboxSenderProvider(accountId));
      final gate = Completer<void>();
      writes.single.beforeRequest = (_) => gate.future;
      await repository.setDone(task.id, done: true);
      await pumpEventQueue();
      expect(writes.single.requests, ['update 1']);

      await upgrade(accountId);

      expect(writes, hasLength(2));
      expect(engines.first.disposed, isTrue);
      expect(container.read(outboxSenderProvider(accountId)), same(sender));
      await container
          .read(taskRepositoryProvider)!
          .setFavorite(other.id, favorite: true);
      await pumpEventQueue();
      expect(writes.last.requests, isEmpty);

      gate.complete();
      await pumpEventQueue();

      expect(writes.first.updates, [(1, const TaskChanges(done: true))]);
      expect(writes.last.updates, [(2, const TaskChanges(isFavorite: true))]);
      final db = opened.single;
      expect((await db.tasksDao.find(task.id))!.done, isTrue);
      expect((await db.tasksDao.find(other.id))!.isFavorite, isTrue);
      expect(await db.outboxDao.count(), 0);
      expect(sender.state, OutboxSenderState.idle);
      expect(engines.first.refreshAfterWriteCalls, 0);
      expect(engines.last.refreshAfterWriteCalls, 1);
    });

    test('a new task whose create is on its way during it is stored once '
        'under its server id: not sent again, not looked up, not shown '
        'twice', () async {
      final (accountId, repository) = await signedIn();
      final gate = Completer<void>();
      writes.single.beforeRequest = (_) => gate.future;
      final id = await repository.createTask(
        const NewTask(projectId: 7, title: 'Buy milk'),
      );
      await pumpEventQueue();
      expect(writes.single.requests, ['create Buy milk']);

      await upgrade(accountId);
      gate.complete();
      await pumpEventQueue();

      expect(writes.first.creates, hasLength(1));
      expect(writes.last.requests, isEmpty);
      expect([
        for (final client in reads) ...client.requests,
      ], everyElement(isNot(startsWith('project 7 tasks'))));
      final db = opened.single;
      expect(await db.tasksDao.resolveId(id), 100);
      expect(await db.tasksDao.findRow(id), isNull);
      expect((await db.tasksDao.find(100))!.title, 'Buy milk');
      expect(await db.outboxDao.count(), 0);
    });

    test('after it, a sync that gets through on the rebuilt engine sends a '
        'change waiting out a network failure at once; what the rebuilt '
        'engine replays does not', () async {
      final (accountId, repository) = await signedIn();
      final sender = container.read(outboxSenderProvider(accountId));
      writes.single.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await repository.setDone(task.id, done: true);
      await pumpEventQueue();
      expect(sender.state, OutboxSenderState.waiting);
      expect(sender.blockedBy, isA<NetworkFailure>());

      await upgrade(accountId);

      expect(engines, hasLength(2));
      expect(engines.first.disposed, isTrue);
      expect(writes.last.requests, isEmpty);

      engines.last.emit(SyncIdle(lastSyncedAt: now));
      await pumpEventQueue();

      expect(writes.last.updates, [(1, const TaskChanges(done: true))]);
      expect(await opened.single.outboxDao.count(), 0);
    });
  });

  test('signed out and in again, the account gets a new sender over its new '
      'database, and it sends', () async {
    final (accountId, _) = await signedIn();
    final first = container.read(outboxSenderProvider(accountId));

    await container.read(signOutProvider).call(accountId);
    await pumpEventQueue();
    await auth.seedAccount(fullServer270(), tokens: issueTokens(issuedAt: now));
    container.invalidate(accountsProvider);
    await container.read(accountsProvider.future);
    await pumpEventQueue();

    expect(opened, hasLength(2));
    await opened.last.tasksDao.upsertAll([task], syncRunId: 'run');
    writes.last.serverTasks[task.id] = task;
    expect(container.read(outboxSenderProvider(accountId)), isNot(same(first)));

    await container.read(taskRepositoryProvider)!.setDone(task.id, done: true);
    await pumpEventQueue();

    expect(writes.last.updates, [(1, const TaskChanges(done: true))]);
    expect(await opened.last.outboxDao.count(), 0);
    expect(engines.last.refreshAfterWriteCalls, 1);
    expect(files.deleted, [accountId]);
    final requests = [for (final client in writes) ...client.requests];
    await first.drain();
    expect([for (final client in writes) ...client.requests], requests);
  });

  test('removing the account disposes its sender with its database: the '
      'change queued behind the one on its way is not sent', () async {
    final (accountId, repository) = await signedIn();
    final sender = container.read(outboxSenderProvider(accountId));
    final gate = Completer<void>();
    writes.single.beforeRequest = (_) => gate.future;
    await repository.setDone(task.id, done: true);
    await pumpEventQueue();
    await repository.updateTask(task.id, const TaskChanges(priority: 3));
    expect(await opened.single.outboxDao.count(), 2);

    await container.read(accountRegistryProvider).remove(accountId);
    await pumpEventQueue();
    gate.complete();
    await pumpEventQueue();

    expect(writes.single.requests, ['update 1']);
    expect(
      () => container.read(outboxSenderProvider(accountId)),
      throwsA(anything),
    );
    await expectLater(sender.sendNow(), completion(isNull));
  });
}
