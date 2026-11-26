import 'dart:async';
import 'dart:io' show SocketException;

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart'
    show ClientClosed, ConnectTimedOut, VikunjaWriteClient;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/outbox/task_deletion.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/task_edits.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

void main() {
  late AppDatabase db;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late RecordingSyncEngine sync;
  late FakeTimers timers;
  late DateTime now;
  final monday = DateTime.utc(2026, 10, 12, 9);
  const done = TaskChanges(done: true);
  const favorite = TaskChanges(isFavorite: true);
  final tasks = [
    sampleTask(id: 1, title: 'One', projectId: 7, due: monday),
    sampleTask(id: 2, title: 'Two', projectId: 7),
    sampleTask(
      id: 3,
      title: 'Daily',
      projectId: 7,
      due: monday,
      repeatAfter: const Duration(days: 1),
    ),
  ];

  OutboxSender sender({
    DateTime Function()? clock,
    int? userId,
    int? processId,
    VikunjaWriteClient Function()? writeClient,
  }) {
    final sender = writeClient == null
        ? OutboxSender(
            db: db,
            writeClient: write,
            readClient: read,
            sync: sync,
            now: clock ?? () => now,
            createTimer: timers.create,
            random: ZeroRandom(),
            currentUserId: () => userId,
            processId: processId,
          )
        : OutboxSender.following(
            db: db,
            writeClient: writeClient,
            readClient: () => read,
            sync: () => sync,
            syncStatus: sync.status,
            now: clock ?? () => now,
            createTimer: timers.create,
            random: ZeroRandom(),
            currentUserId: () => userId,
            processId: processId,
          );
    addTearDown(sender.dispose);
    return sender;
  }

  Future<void> queue(int id, TaskChanges changes) async {
    expect(await db.outboxDao.queueUpdate(id, changes, now: now), isTrue);
  }

  Future<void> queueDelete(int id) async {
    expect(await db.outboxDao.queueDelete(id, now: now), TaskDeletion.queued);
  }

  Future<List<OutboxRow>> ops() => db.outboxDao.all();

  List<OutboxSenderState> record(OutboxSender sender) {
    final seen = <OutboxSenderState>[];
    final subscription = sender.states.listen(seen.add);
    addTearDown(subscription.cancel);
    return seen;
  }

  Never fail(VikunjaFailure failure) => throw failure;

  setUp(() async {
    db = testDatabase();
    now = DateTime.utc(2026, 10, 10, 12);
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient()
      ..allProjects = [sampleProject(id: 7, title: 'Work')]
      ..allTasks = tasks;
    sync = RecordingSyncEngine();
    timers = FakeTimers();
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
    write.serverTasks.addEntries(tasks.map((t) => MapEntry(t.id, t)));
  });

  test('with the real engine, a run that read a task before its send '
      'cannot leave that stale row: the refresh after the drain runs after '
      'it', () async {
    final before = now.subtract(const Duration(minutes: 10));
    read.allTasks = [for (final task in tasks) task.copyWith(updated: before)];
    write.serverTasks.addEntries(read.allTasks.map((t) => MapEntry(t.id, t)));
    final engine = DefaultSyncEngine(
      db: db,
      client: read,
      perPage: 50,
      now: () => now,
    );
    addTearDown(engine.dispose);
    await engine.ensureInitialSync();
    await queue(1, done);
    // The server answers the run's first task read as it was before the
    // send, every later one as it is after it.
    final reached = Completer<void>();
    final held = Completer<void>();
    var taskReads = 0;
    read.beforeRequest = (request) async {
      if (!request.startsWith('tasks ')) return;
      if (++taskReads == 1) {
        reached.complete();
        await held.future;
      } else {
        read.allTasks = [
          for (final task in read.allTasks) write.serverTasks[task.id] ?? task,
        ];
      }
    };
    final running = engine.refresh();
    await reached.future;
    final outbox = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: engine,
      now: () => now,
      createTimer: timers.create,
      random: ZeroRandom(),
      currentUserId: () => null,
    );
    addTearDown(outbox.dispose);

    final draining = outbox.drain();
    while (await db.outboxDao.count() > 0) {
      await pumpEventQueue();
    }
    expect((await db.tasksDao.find(1))!.done, isTrue);
    held.complete();
    await running;
    await draining;

    expect((await db.tasksDao.find(1))!.done, isTrue);
    expect(taskReads, greaterThan(2));
  });

  group('sending', () {
    test(
      "sends the queued ops in order and applies the server's answers",
      () async {
        await queue(1, done);
        await queue(2, favorite);
        final outbox = sender();
        final states = record(outbox);

        await outbox.drain();

        expect(write.requests, ['update 1', 'update 2']);
        expect(write.updates, [(1, done), (2, favorite)]);
        expect(await db.outboxDao.count(), 0);
        final one = (await db.tasksDao.find(1))!;
        expect(one.done, isTrue);
        expect(one.updated, now);
        expect((await db.tasksDao.findRow(1))!.pendingChanges, isNull);
        expect((await db.tasksDao.find(2))!.isFavorite, isTrue);
        expect(sync.refreshAfterWriteCalls, 1);
        expect(states, [
          OutboxSenderState.idle,
          OutboxSenderState.draining,
          OutboxSenderState.idle,
        ]);
      },
    );

    test('a repeating task comes back open with the next date', () async {
      await queue(3, done);
      expect((await db.tasksDao.find(3))!.done, isTrue);

      await sender().drain();

      final daily = (await db.tasksDao.find(3))!;
      expect(daily.done, isFalse);
      expect(daily.dueDate, monday.add(const Duration(days: 1)));
      expect(daily.doneAt, now);
    });

    test('a delete removes the row once the server confirms', () async {
      await queueDelete(1);

      await sender().drain();

      expect(write.deletes, [1]);
      expect(await db.tasksDao.findRow(1), isNull);
      expect(await db.outboxDao.count(), 0);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    for (final (what, code) in [
      ('deleted', 4002),
      ('put in the trash', 4040),
      ('put in the trash with its project, on a delete', 3001),
      ('put in the trash with its project, on a read', 3018),
    ]) {
      test('a task the server already $what ($code) counts as '
          'deleted', () async {
        await queueDelete(2);
        write.beforeRequest = (_) => fail(NotFound(code: code));

        await sender().drain();

        expect(await db.tasksDao.findRow(2), isNull);
        expect(await db.outboxDao.count(), 0);
        expect(await db.outboxDao.loadProblems(), isEmpty);
      });
    }

    test("the fields of a later op survive the server's answer", () async {
      await queue(1, done);
      final gate = RequestGate()..pattern = 'update 1';
      write.beforeRequest = gate.call;
      final outbox = sender();
      final drain = outbox.drain();
      await pumpEventQueue();
      expect((await ops()).single.state, OutboxState.sending.name);
      // Queued while the first op is in flight: an op of its own.
      await queue(1, favorite);
      expect(await ops(), hasLength(2));

      gate.release();
      await pumpEventQueue();

      // The server answered done without the favourite; the row keeps it.
      final one = (await db.tasksDao.find(1))!;
      expect(one.done, isTrue);
      expect(one.isFavorite, isTrue);
      expect(
        decodeTaskChanges((await db.tasksDao.findRow(1))!.pendingChanges!),
        favorite,
      );
      expect(write.serverTasks[1]!.isFavorite, isFalse);

      gate.release();
      await drain;

      expect(write.updates, [(1, done), (1, favorite)]);
      expect(write.serverTasks[1]!.isFavorite, isTrue);
      expect((await db.tasksDao.findRow(1))!.pendingChanges, isNull);
    });

    test(
      'a delete queued behind an update in flight keeps the row hidden',
      () async {
        await queue(1, done);
        final gate = RequestGate()..pattern = 'update 1';
        write.beforeRequest = gate.call;
        final outbox = sender();
        final drain = outbox.drain();
        await pumpEventQueue();
        await queueDelete(1);

        gate.release();
        await drain;

        expect(write.requests, ['update 1', 'delete 1']);
        expect(await db.tasksDao.findRow(1), isNull);
      },
    );

    test('updates queued before a delete go first, in order, and the row '
        'stays hidden through their answers', () async {
      await queue(1, done);
      await queue(2, favorite);
      await queue(1, const TaskChanges(title: 'Renamed'));
      await queueDelete(1);
      final gate = RequestGate()..pattern = 'delete 1';
      write.beforeRequest = gate.call;
      final outbox = sender();
      final drain = outbox.drain();
      await pumpEventQueue();

      expect(write.requests, ['update 1', 'update 2', 'delete 1']);
      expect(write.updates, [
        (1, const TaskChanges(done: true, title: 'Renamed')),
        (2, favorite),
      ]);
      expect(write.serverTasks[1]!.title, 'Renamed');
      expect(await db.tasksDao.find(1), isNull);
      expect((await db.tasksDao.findRow(1))!.pendingDelete, isTrue);
      expect((await ops()).single.kind, 'deleteTask');

      gate.release();
      await drain;

      expect(await db.tasksDao.findRow(1), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('never sends two ops at once', () async {
      await queue(1, done);
      final gate = RequestGate()..pattern = 'update 1';
      write.beforeRequest = gate.call;
      final outbox = sender();
      final first = outbox.drain();
      await pumpEventQueue();
      await queue(2, done);
      final second = outbox.drain();
      await pumpEventQueue();
      expect(write.requests, ['update 1']);

      gate.release();
      await first;
      await second;

      expect(write.requests, ['update 1', 'update 2']);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test(
      'a drain asked for during the refresh looks at the queue again',
      () async {
        await queue(1, done);
        sync.gate = Completer<void>();
        final outbox = sender();
        final first = outbox.drain();
        await pumpEventQueue();
        expect(write.requests, ['update 1']);
        expect(sync.refreshAfterWriteCalls, 1);

        await queue(2, done);
        final second = outbox.drain();
        sync.gate!.complete();
        sync.gate = null;
        await first;
        await second;

        expect(write.requests, ['update 1', 'update 2']);
        expect(sync.refreshAfterWriteCalls, 2);
        expect(await db.outboxDao.count(), 0);
      },
    );

    test(
      'an edit merged in between the queue read and the claim is sent',
      () async {
        await queue(1, done);
        // The clock is read right before the claim: the undo lands there.
        var undone = false;
        final outbox = sender(
          clock: () {
            if (!undone) {
              undone = true;
              unawaited(
                db.outboxDao.queueUpdate(
                  1,
                  const TaskChanges(done: false),
                  now: now,
                ),
              );
            }
            return now;
          },
        );

        await outbox.drain();

        expect(write.updates, [(1, const TaskChanges(done: false))]);
        expect(write.serverTasks[1]!.done, isFalse);
        expect((await db.tasksDao.find(1))!.done, isFalse);
        expect(await db.outboxDao.count(), 0);
      },
    );

    test('an op that fails for good behind a newer edit folds into it, so the '
        'newer intent wins and a later edit cannot be reverted', () async {
      // Done in flight and rejected; the undo queued meanwhile then hits
      // a network failure; done again; Send now.
      await queue(1, done);
      final held = Completer<void>();
      write.beforeRequest = (request) =>
          request == 'update 1' ? held.future : Future.value();
      final outbox = sender();
      final drain = outbox.drain();
      await pumpEventQueue();
      await queue(1, const TaskChanges(done: false));
      expect(await ops(), hasLength(2));
      write.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.unreachable));
      held.completeError(const Forbidden(code: 7003));
      await drain;

      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(outbox.state, OutboxSenderState.waiting);
      final waiting = (await ops()).single;
      expect(
        decodeTaskChanges(waiting.payload),
        const TaskChanges(done: false),
      );

      await queue(1, done);
      write.beforeRequest = null;
      await outbox.sendNow();

      expect(write.updates, [(1, done)]);
      expect(write.serverTasks[1]!.done, isTrue);
      expect((await db.tasksDao.find(1))!.done, isTrue);
      expect(await db.outboxDao.count(), 0);
    });

    test('an accepted write whose local apply fails is left in flight, not '
        're-sent on the spot, and goes again once it is stale', () async {
      await queue(1, done);
      await db.customStatement(
        'CREATE TRIGGER apply_fails BEFORE DELETE ON outbox '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );

      await expectLater(sender().drain(), throwsA(anything));

      expect(write.updates, [(1, done)]);
      final op = (await ops()).single;
      expect(op.state, OutboxState.sending.name);
      expect(op.lastError, isNull);
      expect(await db.outboxDao.loadProblems(), isEmpty);

      await db.customStatement('DROP TRIGGER apply_fails');
      await sender().drain();
      expect(write.updates, [(1, done)]);

      now = now.add(OutboxSender.staleSendingAfter);
      await sender().drain();

      // At least once: the server stored it twice.
      expect(write.updates, [(1, done), (1, done)]);
      expect(await db.outboxDao.count(), 0);
    });

    test('a database error fails the drain and leaves the sender idle; the '
        'same sender drains again', () async {
      await queue(1, done);
      await db.customStatement(
        'CREATE TRIGGER apply_fails BEFORE DELETE ON outbox '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      final outbox = sender();
      final states = record(outbox);

      await expectLater(outbox.drain(), throwsA(anything));

      expect(outbox.state, OutboxSenderState.idle);
      await db.customStatement('DROP TRIGGER apply_fails');
      now = now.add(OutboxSender.staleSendingAfter);
      await outbox.drain();

      expect(write.updates, [(1, done), (1, done)]);
      expect(await db.outboxDao.count(), 0);
      expect(states, [
        OutboxSenderState.idle,
        OutboxSenderState.draining,
        OutboxSenderState.idle,
        OutboxSenderState.draining,
        OutboxSenderState.idle,
      ]);
    });

    test('a delete takes a rejected update of the same task with it', () async {
      await queue(1, done);
      final gate = RequestGate()..pattern = 'update 1';
      write.beforeRequest = gate.call;
      final outbox = sender();
      final drain = outbox.drain();
      await pumpEventQueue();
      await queueDelete(1);
      write.beforeRequest = (request) => request == 'update 1'
          ? fail(const Forbidden(code: 7003))
          : Future.value();

      gate.release();
      await drain;

      expect(write.requests, ['update 1', 'delete 1']);
      expect(await db.tasksDao.findRow(1), isNull);
      expect(await db.outboxDao.count(), 0);
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test('ops a killed app left in flight are sent again once stale', () async {
      await queue(1, done);
      await db.outboxDao.markSending((await ops()).single.id, at: now);
      now = now.add(OutboxSender.staleSendingAfter);

      await sender().drain();

      expect(write.updates, [(1, done)]);
      expect(await db.outboxDao.count(), 0);
    });

    test('ops a dead process left in flight go at the first drain after the '
        'restart; those of the same process wait', () async {
      // The process before: its sender ran, then it claimed them all and
      // died, one create after its request left, the other before.
      await sender(processId: 1).drain();
      await queue(1, done);
      final unsent = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'Buy milk'),
        now: now,
      );
      final posted = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'Buy bread'),
        now: now,
      );
      for (final op in await ops()) {
        await db.outboxDao.markSending(op.id, at: now);
      }
      final postedOp = (await ops()).singleWhere((o) => o.taskId == posted);
      expect(await db.outboxDao.markCreatePosted(postedOp, at: now), isTrue);
      final sameProcess = sender(processId: 1);
      await sameProcess.drain();
      expect(sameProcess.state, OutboxSenderState.waiting);
      expect(write.requests, isEmpty);

      await sender(processId: 2).drain();

      expect(write.requests, ['update 1', 'create Buy milk']);
      expect(await db.tasksDao.resolveId(unsent), isNot(unsent));
      expect(await db.tasksDao.resolveId(posted), posted);
      expect((await db.outboxDao.loadProblems()).single.taskId, posted);
    });

    test('a create whose claim was reset during its project read is not '
        'sent by that claim', () async {
      await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'Buy milk'),
        now: now,
      );
      final held = Completer<void>();
      var projectReads = 0;
      read.beforeRequest = (request) async {
        if (request == 'project 7' && ++projectReads == 1) await held.future;
      };
      final first = sender();
      final drain = first.drain();
      await pumpEventQueue();
      expect(read.requests, ['project 7']);

      now = now.add(OutboxSender.staleSendingAfter);
      await sender().drain();
      expect(write.requests, ['create Buy milk']);

      held.complete();
      await drain;

      expect(write.requests, ['create Buy milk']);
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test(
      'a database without a process stored keeps the age rule once',
      () async {
        await queue(1, done);
        await db.outboxDao.markSending((await ops()).single.id, at: now);

        final outbox = sender(processId: 2);
        await outbox.drain();

        expect(write.requests, isEmpty);
        expect(outbox.state, OutboxSenderState.waiting);
        expect(
          (await db.syncStateDao.readAll())[OutboxDao.sendingProcessKey],
          '2',
        );
      },
    );

    test('a second sender leaves a create the first has in flight alone '
        'and waits for it', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'Buy milk'),
        now: now,
      );
      final gate = RequestGate()..pattern = 'create Buy milk';
      write.beforeRequest = gate.call;
      final first = sender();
      final drain = first.drain();
      await pumpEventQueue();
      expect(write.requests, ['create Buy milk']);

      final second = sender();
      await second.drain();

      expect(second.state, OutboxSenderState.waiting);
      expect(second.blockedBy, isNull);
      expect(timers.pendingWait, OutboxSender.inFlightRecheck);
      expect(read.requests, [
        'project 7',
      ], reason: 'the first one checked the server');
      expect(write.requests, ['create Buy milk']);
      expect((await ops()).single.sentAt, isNull);

      gate.release();
      await drain;
      timers.fireNext();
      await pumpEventQueue();

      expect(write.creates, hasLength(1));
      expect(await db.tasksDao.resolveId(id), 100);
      expect(await db.outboxDao.count(), 0);
      expect(second.state, OutboxSenderState.idle);
    });

    test(
      'a second sender does not overtake an op the first has in flight',
      () async {
        await queue(1, done);
        final gate = RequestGate()..pattern = 'update 1';
        write.beforeRequest = gate.call;
        final first = sender();
        final drain = first.drain();
        await pumpEventQueue();
        await queue(1, favorite);
        expect((await ops()).map((op) => op.state), ['sending', 'pending']);

        final second = sender();
        await second.drain();

        expect(second.state, OutboxSenderState.waiting);
        expect(write.requests, ['update 1']);

        gate
          ..pattern = null
          ..release();
        await drain;
        timers.fireNext();
        await pumpEventQueue();

        expect(write.updates, [(1, done), (1, favorite)]);
        expect(await db.outboxDao.count(), 0);
      },
    );

    test(
      'an op in flight elsewhere is reset and sent once it is stale',
      () async {
        await queue(1, done);
        await db.outboxDao.markSending((await ops()).single.id, at: now);
        now = now.add(const Duration(minutes: 4, seconds: 50));

        final outbox = sender();
        await outbox.drain();

        expect(write.requests, isEmpty);
        expect(timers.pendingWait, const Duration(seconds: 10));

        now = now.add(const Duration(seconds: 10));
        timers.fireNext();
        await pumpEventQueue();

        expect(write.updates, [(1, done)]);
        expect(await db.outboxDao.count(), 0);
      },
    );

    test('nothing to send means no refresh', () async {
      await sender().drain();

      expect(sync.refreshAfterWriteCalls, 0);
      expect(write.requests, isEmpty);
    });

    test('a failed refresh does not fail the drain', () async {
      await queue(1, done);
      sync.error = const NetworkFailure(NetworkProblem.unreachable);

      await sender().drain();

      expect(await db.outboxDao.count(), 0);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('after dispose nothing is sent', () async {
      await queue(1, done);
      final outbox = sender();
      await outbox.dispose();

      await outbox.drain();

      expect(write.requests, isEmpty);
    });
  });

  group('retries', () {
    test('a network failure is retried with a doubling backoff', () async {
      write.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.timeout));
      await queue(1, done);
      final outbox = sender();
      final states = record(outbox);

      await outbox.drain();

      expect(outbox.state, OutboxSenderState.waiting);
      expect(timers.pendingWait, const Duration(seconds: 2));
      var op = (await ops()).single;
      expect(op.state, OutboxState.pending.name);
      expect(op.attempts, 1);
      expect(op.nextAttemptAt, now.add(const Duration(seconds: 2)));
      expect(decodeFailure(op.lastError!), isA<NetworkFailure>());
      expect(sync.refreshAfterWriteCalls, 0);
      expect(await db.outboxDao.loadProblems(), isEmpty);

      for (final wait in const [4, 8, 16]) {
        now = now.add(timers.pendingWait);
        timers.fireNext();
        await pumpEventQueue();
        expect(timers.pendingWait, Duration(seconds: wait));
      }
      op = (await ops()).single;
      expect(op.attempts, 4);

      write.beforeRequest = null;
      now = now.add(timers.pendingWait);
      timers.fireNext();
      await pumpEventQueue();

      expect(await db.outboxDao.count(), 0);
      expect(write.serverTasks[1]!.done, isTrue);
      expect(sync.refreshAfterWriteCalls, 1);
      expect(states.last, OutboxSenderState.idle);
      expect(timers.active, isEmpty);
    });

    test('a change whose clients are rebuilt while it is on its way goes '
        'again at once over the new ones when the replaced client refuses '
        'its request as offline, nothing counted', () async {
      final rebuilt = FakeWriteClient(clock: () => now);
      rebuilt.serverTasks.addAll(write.serverTasks);
      VikunjaWriteClient current = write;
      write.beforeRequest = (_) {
        current = rebuilt;
        fail(const NetworkFailure(NetworkProblem.unreachable));
      };
      await queue(1, done);
      await queue(2, favorite);
      final outbox = sender(writeClient: () => current);

      await outbox.drain();

      expect(write.requests, ['update 1']);
      expect(rebuilt.updates, [(1, done), (2, favorite)]);
      expect(await db.outboxDao.count(), 0);
      expect(timers.active, isEmpty);
      expect(outbox.state, OutboxSenderState.idle);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('the backoff tops out at 15 minutes', () async {
      write.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.unreachable));
      await queue(1, done);
      final op = (await ops()).single;
      await db.outboxDao.scheduleRetry(
        op.id,
        attempts: 20,
        failure: const NetworkFailure(NetworkProblem.unreachable),
        nextAttemptAt: now,
      );

      await sender().drain();

      expect(timers.pendingWait, OutboxSender.maxBackoff);
      expect((await ops()).single.attempts, 21);
    });

    test('a 429 waits as long as Retry-After says, at most 15 '
        'minutes', () async {
      write.beforeRequest = (_) =>
          fail(const RateLimited(retryAfter: Duration(seconds: 45)));
      await queue(1, done);
      final outbox = sender();

      await outbox.drain();
      expect(timers.pendingWait, const Duration(seconds: 45));

      write.beforeRequest = (_) =>
          fail(const RateLimited(retryAfter: Duration(hours: 1)));
      now = now.add(const Duration(seconds: 45));
      timers.fireNext();
      await pumpEventQueue();
      expect(timers.pendingWait, OutboxSender.maxBackoff);

      write.beforeRequest = (_) => fail(const RateLimited());
      now = now.add(OutboxSender.maxBackoff);
      timers.fireNext();
      await pumpEventQueue();
      // Without a Retry-After the backoff applies: the third attempt waits 8 s.
      expect(timers.pendingWait, const Duration(seconds: 8));
    });

    test(
      'a drain before the backoff ends waits the rest; Send now skips it',
      () async {
        write.beforeRequest = (_) =>
            fail(const NetworkFailure(NetworkProblem.unreachable));
        await queue(1, done);
        await queue(2, done);
        final outbox = sender();
        await outbox.drain();
        expect(write.requests, ['update 1']);

        now = now.add(const Duration(milliseconds: 500));
        await outbox.drain();

        // The oldest op blocks the queue; the second never overtakes it.
        expect(write.requests, ['update 1']);
        expect(timers.pendingWait, const Duration(milliseconds: 1500));
        expect(timers.active, hasLength(1));

        write.beforeRequest = null;
        await outbox.sendNow();

        expect(write.requests, ['update 1', 'update 1', 'update 2']);
        expect(await db.outboxDao.count(), 0);
        expect(timers.active, isEmpty);
      },
    );

    test('a session that ended pauses the sender until it resumes', () async {
      write.beforeRequest = (_) =>
          fail(const SessionEnded(SessionEndReason.expired, code: 16003));
      await queue(1, done);
      final outbox = sender();
      final states = record(outbox);

      await outbox.drain();

      expect(outbox.state, OutboxSenderState.paused);
      final op = (await ops()).single;
      expect(op.state, OutboxState.pending.name);
      expect(op.attempts, 0);
      expect(decodeFailure(op.lastError!), isA<SessionEnded>());
      expect(timers.active, isEmpty);
      expect(await db.outboxDao.loadProblems(), isEmpty);

      await outbox.drain();
      expect(write.requests, ['update 1']);

      write.beforeRequest = null;
      await outbox.resume();

      expect(write.requests, ['update 1', 'update 1']);
      expect(await db.outboxDao.count(), 0);
      expect(states, [
        OutboxSenderState.idle,
        OutboxSenderState.draining,
        OutboxSenderState.paused,
        OutboxSenderState.idle,
        OutboxSenderState.draining,
        OutboxSenderState.idle,
      ]);
    });

    test('a rejected token after the interceptor gave up is retried: the '
        'session that ended for good arrives as SessionEnded', () async {
      write.beforeRequest = (_) => fail(const TokenRejected());
      await queue(1, done);
      final outbox = sender();

      await outbox.drain();

      expect(outbox.state, OutboxSenderState.waiting);
      final op = (await ops()).single;
      expect(op.state, OutboxState.pending.name);
      expect(op.attempts, 1);
      expect(decodeFailure(op.lastError!), isA<TokenRejected>());

      write.beforeRequest = null;
      expect(await outbox.sendNow(), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    for (final failure in <VikunjaFailure>[
      const UnexpectedResponse(302),
      const UnexpectedResponse(401),
      const UnexpectedResponse(407),
      const NotFound(),
    ]) {
      test('$failure is not a Vikunja answer: retried with backoff', () async {
        write.beforeRequest = (_) => fail(failure);
        await queue(1, done);
        final outbox = sender();

        await outbox.drain();

        expect(outbox.state, OutboxSenderState.waiting);
        expect(timers.pendingWait, const Duration(seconds: 2));
        expect((await ops()).single.attempts, 1);
        expect(await db.outboxDao.loadProblems(), isEmpty);
      });
    }

    Future<void> retryWhenDue() async {
      now = now.add(timers.pendingWait);
      timers.fireNext();
      await pumpEventQueue();
    }

    for (final (what, failure) in <(String, VikunjaFailure)>[
      ('a 5xx', const ServerFailure(502)),
      ("an access gate's 401", const UnexpectedResponse(401)),
    ]) {
      test('an answer that keeps being $what becomes a problem after the '
          'limit, one to two hours on, and the queue goes on', () async {
        write.beforeRequest = (request) =>
            request == 'update 1' ? fail(failure) : Future.value();
        await queue(1, done);
        await queue(2, favorite);
        final start = now;
        final outbox = sender();
        await outbox.drain();

        for (
          var failed = 1;
          failed < OutboxSender.maxFailedAnswersInARow;
          failed++
        ) {
          expect((await ops()).first.attempts, failed);
          expect(outbox.state, OutboxSenderState.waiting);
          await retryWhenDue();
        }

        expect(write.requests, [
          ...List.filled(OutboxSender.maxFailedAnswersInARow, 'update 1'),
          'update 2',
        ]);
        // The waits before the 16th attempt, none shortened (ZeroRandom).
        expect(now.difference(start), const Duration(seconds: 6422));
        final problem = (await db.outboxDao.loadProblems()).single;
        expect(problem.taskId, 1);
        expect('${problem.failure}', '$failure');
        expect((await db.tasksDao.find(1))!.done, isTrue);
        expect(write.serverTasks[2]!.isFavorite, isTrue);
        expect(await db.outboxDao.count(), 1);
        expect(outbox.state, OutboxSenderState.idle);
        expect(timers.active, isEmpty);

        write.beforeRequest = null;
        await outbox.retry(problem.operationId);

        expect(write.serverTasks[1]!.done, isTrue);
        expect(await db.outboxDao.count(), 0);
      });
    }

    test('only answers in a row count: a day offline before a 5xx uses up '
        'none of them, and a 429 or a network failure never does', () async {
      await queue(1, done);
      final op = (await ops()).single;
      await db.outboxDao.scheduleRetry(
        op.id,
        attempts: 200,
        failure: const NetworkFailure(NetworkProblem.unreachable),
        nextAttemptAt: now,
      );
      write.beforeRequest = (_) => fail(const ServerFailure(503));
      final outbox = sender();

      await outbox.drain();

      expect((await ops()).single.attempts, 1);
      expect(timers.pendingWait, OutboxSender.initialBackoff);
      expect(await db.outboxDao.loadProblems(), isEmpty);

      for (final failure in const <VikunjaFailure>[
        RateLimited(),
        NetworkFailure(NetworkProblem.timeout),
      ]) {
        await db.outboxDao.scheduleRetry(
          op.id,
          attempts: 200,
          failure: failure,
          nextAttemptAt: now,
        );
        write.beforeRequest = (_) => fail(failure);
        await outbox.sendNow();

        expect((await ops()).single.attempts, 201);
        expect(await db.outboxDao.loadProblems(), isEmpty);
      }
    });

    for (final (what, failure) in [
      (
        'a 2xx whose body cannot be read',
        const UnexpectedResponse(200, message: 'task without id'),
      ),
      (
        'a 2xx whose JSON cannot be parsed',
        const UnexpectedResponse(null, message: 'FormatException'),
      ),
    ]) {
      test('$what is final for an update: a problem at once, and the queue '
          'goes on', () async {
        write.afterRequest = (request) =>
            request == 'update 1' ? fail(failure) : Future.value();
        await queue(1, done);
        await queue(2, favorite);
        final outbox = sender();

        await outbox.drain();

        expect(write.requests, ['update 1', 'update 2']);
        final problem = (await db.outboxDao.loadProblems()).single;
        expect(problem.taskId, 1);
        expect(problem.failure, isA<UnexpectedResponse>());
        expect(problem.failure.message, failure.message);
        expect(timers.active, isEmpty);
        expect(outbox.state, OutboxSenderState.idle);
      });
    }

    test("a captive portal's page in the server's place waits like being "
        'offline: no update becomes a problem and no delete counts as '
        'sent', () async {
      const portal = NotJsonResponse(200, message: 'text/html');
      write.beforeRequest = (_) => fail(portal);
      await queue(1, done);
      await queueDelete(2);
      final outbox = sender();

      await outbox.drain();

      expect(write.requests, ['update 1']);
      expect(outbox.state, OutboxSenderState.waiting);
      expect(outbox.blockedBy, isA<NotJsonResponse>());
      expect(await db.outboxDao.loadProblems(), isEmpty);
      final first = (await ops()).first;
      expect(first.state, OutboxState.pending.name);
      expect(decodeFailure(first.lastError!), isA<NotJsonResponse>());

      // The delete meets the portal once the update got through.
      write.beforeRequest = (request) =>
          request == 'delete 2' ? fail(portal) : Future.value();
      now = now.add(timers.pendingWait);
      timers.fireNext();
      await pumpEventQueue();

      expect(write.requests, ['update 1', 'update 1', 'delete 2']);
      expect(write.deletes, isEmpty);
      expect(await db.tasksDao.findRow(2), isNotNull);
      expect((await ops()).single.kind, OutboxOperationKind.deleteTask.name);
      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(outbox.state, OutboxSenderState.waiting);

      // A sync that gets through means the portal is gone.
      write.beforeRequest = null;
      sync.emit(SyncIdle(lastSyncedAt: now));
      await pumpEventQueue();

      expect(write.deletes, [2]);
      expect(await db.tasksDao.findRow(2), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('an exception without an answer is final for an update and a '
        'delete', () async {
      write.beforeRequest = (request) => request == 'update 2'
          ? Future.value()
          : Future.error(StateError('a bug'));
      await queue(1, done);
      await queueDelete(3);
      await queue(2, favorite);
      final outbox = sender();

      await outbox.drain();

      expect(write.requests, ['update 1', 'delete 3', 'update 2']);
      final problems = await db.outboxDao.loadProblems();
      expect(problems.map((p) => p.kind), [
        OutboxOperationKind.updateTask,
        OutboxOperationKind.deleteTask,
      ]);
      expect(
        problems.map((p) => p.failure),
        everyElement(
          isA<UnexpectedResponse>()
              .having((f) => f.statusCode, 'statusCode', isNull)
              .having((f) => f.message, 'message', 'StateError'),
        ),
      );
      expect(timers.active, isEmpty);
    });

    test('a Retry-After of 0 falls back to the backoff', () async {
      write.beforeRequest = (_) =>
          fail(const RateLimited(retryAfter: Duration.zero));
      await queue(1, done);

      await sender().drain();

      expect(timers.pendingWait, const Duration(seconds: 2));
    });

    test('a sync that gets through while an op waits out a network failure '
        'sends it at once', () async {
      write.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.unreachable));
      await queue(1, done);
      final outbox = sender();
      await outbox.drain();
      expect(outbox.state, OutboxSenderState.waiting);

      write.beforeRequest = null;
      sync.emit(SyncIdle(lastSyncedAt: now));
      await pumpEventQueue();

      expect(write.requests, ['update 1', 'update 1']);
      expect(await db.outboxDao.count(), 0);
      expect(outbox.state, OutboxSenderState.idle);
      expect(timers.active, isEmpty);
    });

    test('a sync does not cut a Retry-After short', () async {
      write.beforeRequest = (_) =>
          fail(const RateLimited(retryAfter: Duration(seconds: 45)));
      await queue(1, done);
      final outbox = sender();
      await outbox.drain();

      write.beforeRequest = null;
      sync.emit(SyncIdle(lastSyncedAt: now));
      await pumpEventQueue();

      expect(write.requests, ['update 1']);
      expect(timers.pendingWait, const Duration(seconds: 45));
    });

    test('Send now reports what still blocks the queue', () async {
      write.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.timeout));
      await queue(1, done);
      final outbox = sender();

      expect(await outbox.sendNow(), isA<NetworkFailure>());
      expect(write.requests, ['update 1']);

      write.beforeRequest = null;
      expect(await outbox.sendNow(), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('Send now refreshes after sending, unless its caller syncs itself: '
        'then neither it nor a drain after it does', () async {
      await queue(1, done);
      final outbox = sender();
      expect(await outbox.sendNow(), isNull);
      expect(sync.refreshAfterWriteCalls, 1);

      await queue(2, done);
      final quiet = sender();
      expect(await quiet.sendNow(refreshAfter: false), isNull);
      expect(write.requests, ['update 1', 'update 2']);
      expect(sync.refreshAfterWriteCalls, 1);

      write.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.unreachable));
      await queue(1, favorite);
      expect(await quiet.sendNow(), isA<NetworkFailure>());
      write.beforeRequest = null;
      now = now.add(timers.pendingWait);
      timers.fireNext();
      await pumpEventQueue();

      expect(write.updates.last, (1, favorite));
      expect(await db.outboxDao.count(), 0);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('pause stops the drain between ops', () async {
      await queue(1, done);
      await queue(2, done);
      final gate = RequestGate()..pattern = 'update 1';
      write.beforeRequest = gate.call;
      final outbox = sender();
      final drain = outbox.drain();
      await pumpEventQueue();

      outbox.pause();
      gate.release();
      await drain;

      expect(write.requests, ['update 1']);
      expect(await db.outboxDao.count(), 1);
      expect(outbox.state, OutboxSenderState.paused);
    });
  });

  group("a repeating task's Done", () {
    final tuesday = monday.add(const Duration(days: 1));

    setUp(() {
      // A read shows what the server holds at that moment.
      read.beforeRequest = (_) async =>
          read.allTasks = [...write.serverTasks.values];
    });

    void loseAnswers() =>
        write.afterRequest = (_) =>
            fail(const NetworkFailure(NetworkProblem.timeout));

    Future<void> retry() async {
      now = now.add(timers.pendingWait);
      timers.fireNext();
      await pumpEventQueue();
    }

    test('whose answer was lost after the server applied it is not applied '
        'again', () async {
      await queue(3, done);
      loseAnswers();
      final outbox = sender();

      await outbox.drain();

      expect(write.serverTasks[3]!.dueDate, tuesday);
      final op = (await ops()).single;
      expect(op.state, OutboxState.pending.name);
      expect(op.sentAt, now);
      expect(decodeTaskChanges(op.payload).doneBase, DoneBase(dueDate: monday));

      write.afterRequest = null;
      await retry();

      expect(write.requests, ['update 3']);
      expect(read.requests, ['task 3', 'task 3']);
      final server = write.serverTasks[3]!;
      expect(server.dueDate, tuesday);
      expect(server.done, isFalse);
      final daily = (await db.tasksDao.find(3))!;
      expect(daily.dueDate, tuesday);
      expect(daily.done, isFalse);
      expect(daily.doneAt, server.doneAt);
      expect(await db.outboxDao.count(), 0);
      expect(outbox.state, OutboxSenderState.idle);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('a lost Done whose schedule advanced back to the old date keeps '
        'the server date, retries the label and saves the date edit', () async {
      final before = copyTask(
        write.serverTasks[3]!,
        doneAt: now.subtract(const Duration(days: 1)),
      );
      await db.tasksDao.upsertAll([before]);
      write.serverTasks[3] = before;
      write.serverLabels[5] = sampleLabel(id: 5, title: 'urgent');
      const label = TaskChanges(labels: IdSetChange(added: {5}));
      final schedule = TaskChanges(
        dueDate: DateChange.set(monday.subtract(const Duration(days: 1))),
      );
      await queue(3, schedule.merge(done).merge(label));
      write.afterRequest = (_) {
        // The body landed (moving Sunday's due date back to Monday), but
        // the label request did not.
        write.serverTasks[3] = write.serverTasks[3]!.copyWith(labels: []);
        fail(const NetworkFailure(NetworkProblem.timeout));
      };
      final outbox = sender();
      await outbox.drain();
      final completedAt = now;
      expect(write.serverTasks[3]!.dueDate, monday);
      expect(write.serverTasks[3]!.doneAt, completedAt);
      write.afterRequest = null;
      await retry();

      expect(write.updates, hasLength(2));
      expect(write.updates.first.$2.done, isTrue);
      expect(write.updates.last, (3, label));
      final server = write.serverTasks[3]!;
      expect(server.dueDate, monday);
      expect(server.doneAt, completedAt);
      expect(server.labels.map((label) => label.id), [5]);
      final local = (await db.tasksDao.find(3))!;
      expect(local.dueDate, monday);
      expect(local.done, isFalse);
      final notice = (await db.outboxDao.loadProblems()).single;
      expect(isRecurringScheduleConflict(notice.failure), isTrue);
      expect(notice.changes, schedule);
      expect(await db.outboxDao.hasQueuedOps(3), isFalse);
    });

    test('a lost answer to Done with dates and reminders keeps the '
        'server schedule and retains unmatched edits as a notice', () async {
      const day = Duration(days: 1);
      const hour = Duration(hours: 1);
      final before = copyTask(
        write.serverTasks[3]!,
        startDate: monday.subtract(hour),
        endDate: monday.add(hour),
        reminders: [TaskReminder(reminder: monday.subtract(hour * 2))],
      );
      await db.tasksDao.upsertAll([before]);
      write.serverTasks[3] = before;
      final schedule = TaskChanges(
        dueDate: DateChange.set(monday.subtract(hour)),
        startDate: DateChange.set(monday.subtract(hour * 2)),
        endDate: const DateChange.clear(),
        reminders: const [],
      );
      await queue(
        3,
        schedule.merge(const TaskChanges(done: true, title: 'New')),
      );
      write.afterRequest = (_) {
        // The server can advance from the original schedule, not the
        // companion schedule in the accepted request.
        write.serverTasks[3] = reopenRepeating(
          before.copyWith(title: 'New'),
          now: now,
        );
        fail(const NetworkFailure(NetworkProblem.timeout));
      };
      final outbox = sender();
      await outbox.drain();
      write.afterRequest = null;
      await retry();

      final server = write.serverTasks[3]!;
      expect(server.dueDate, tuesday);
      expect(server.startDate, before.startDate!.add(day));
      expect(server.endDate, before.endDate!.add(day));
      expect(
        server.reminders.single.reminder,
        before.reminders.single.reminder!.add(day),
      );
      expect(server.title, 'New');
      // The title landed with the Done.
      expect(write.updates, hasLength(1));
      final local = (await db.tasksDao.find(3))!;
      expect(local.dueDate, server.dueDate);
      expect(local.startDate, server.startDate);
      expect(local.endDate, server.endDate);
      expect(local.reminders, server.reminders);
      expect(local.done, isFalse);
      final notice = (await db.outboxDao.loadProblems()).single;
      expect(isRecurringScheduleConflict(notice.failure), isTrue);
      expect(notice.changes, schedule);
      expect(await db.outboxDao.hasQueuedOps(3), isFalse);
      expect(await db.outboxDao.loadPendingTaskIds(), isEmpty);

      // Neither manual retry nor a later edit can pick up the old dates.
      await outbox.retry(notice.operationId);
      await outbox.retryAll([notice.operationId]);
      expect(write.requests, ['update 3']);
      await queue(3, favorite);
      await outbox.drain();
      expect(write.updates.last, (3, favorite));
      expect(write.serverTasks[3]!.dueDate, tuesday);
      expect(
        (await db.outboxDao.loadProblems()).single.operationId,
        notice.operationId,
      );
      final readsBeforeDiscard = read.requests.length;
      await outbox.discard(notice.operationId);
      expect(read.requests, hasLength(readsBeforeDiscard));
      expect(await db.outboxDao.count(), 0);
      expect((await db.tasksDao.find(3))!.dueDate, tuesday);
    });

    test('an already reflected schedule does not get replayed or leave a '
        'notice after a lost answer', () async {
      await queue(
        3,
        const TaskChanges(
          done: true,
          startDate: DateChange.clear(),
          reminders: [],
        ),
      );
      loseAnswers();
      final outbox = sender();
      await outbox.drain();
      write.afterRequest = null;
      await retry();

      expect(write.requests, ['update 3']);
      expect((await db.tasksDao.find(3))!.dueDate, tuesday);
      expect(await db.outboxDao.count(), 0);
    });

    for (final renamedOnWeb in [false, true]) {
      final outcome = renamedOnWeb
          ? 'renamed on the web since keeps the web title and leaves a notice'
          : 'that landed sends nothing more';
      test('a lost answer to Done with a title $outcome', () async {
        await queue(3, done.merge(const TaskChanges(title: 'Mine')));
        write.afterRequest = (_) {
          if (renamedOnWeb) {
            write.serverTasks[3] = write.serverTasks[3]!.copyWith(title: 'Web');
          }
          fail(const NetworkFailure(NetworkProblem.timeout));
        };
        final outbox = sender();
        await outbox.drain();
        write.afterRequest = null;
        await retry();

        expect(write.requests, ['update 3']);
        final title = renamedOnWeb ? 'Web' : 'Mine';
        expect(write.serverTasks[3]!.title, title);
        expect((await db.tasksDao.find(3))!.title, title);
        final problems = await db.outboxDao.loadProblems();
        if (renamedOnWeb) {
          expect(isRecurringScheduleConflict(problems.single.failure), isTrue);
          expect(problems.single.changes, const TaskChanges(title: 'Mine'));
        } else {
          expect(problems, isEmpty);
        }
        expect(await db.outboxDao.hasQueuedOps(3), isFalse);
      });
    }

    for (final renamedHere in [false, true]) {
      final what = renamedHere
          ? 'leaves a title renamed here since'
          : 'sends a held title as a new edit';
      test('Keep my version $what, and never the dates held for the previous '
          'occurrence', () async {
        await queue(
          3,
          done.merge(
            TaskChanges(
              title: 'Mine',
              dueDate: DateChange.set(monday.add(const Duration(hours: 9))),
            ),
          ),
        );
        write.afterRequest = (_) {
          write.serverTasks[3] = write.serverTasks[3]!.copyWith(title: 'Web');
          fail(const NetworkFailure(NetworkProblem.timeout));
        };
        final outbox = sender();
        await outbox.drain();
        write.afterRequest = null;
        await retry();
        final notice = (await db.outboxDao.loadProblems()).single;
        expect(notice.changes!.title, 'Mine');
        expect(notice.changes!.dueDate, isNotNull);
        if (renamedHere) {
          await db.outboxDao.queueUpdate(
            3,
            const TaskChanges(title: 'Phone'),
            now: now,
          );
          await outbox.drain();
        }
        final advanced = write.serverTasks[3]!.dueDate;
        final sent = write.updates.length;

        await outbox.keepHeldChanges(notice.operationId);

        if (renamedHere) {
          expect(write.updates, hasLength(sent));
        } else {
          expect(write.updates.skip(sent), [
            (3, const TaskChanges(title: 'Mine')),
          ]);
        }
        final title = renamedHere ? 'Phone' : 'Mine';
        final server = write.serverTasks[3]!;
        expect(server.title, title);
        expect(server.done, isFalse);
        expect(server.dueDate, advanced);
        expect((await db.tasksDao.find(3))!.title, title);
        expect(await db.outboxDao.count(), 0);
      });
    }

    test('Keep my version sends a held cover when this device stores no '
        "details of the task, comparing with the server's", () async {
      write.serverAttachments[3] = [
        sampleAttachment(id: 7, taskId: 3),
        sampleAttachment(id: 8, taskId: 3),
      ];
      await queue(3, done.merge(const TaskChanges(coverImageAttachmentId: 7)));
      write.afterRequest = (_) {
        // Changed on the web after the request landed.
        write.covers[3] = 8;
        read.taskDetails[3] = const TaskDetails(coverImageAttachmentId: 8);
        fail(const NetworkFailure(NetworkProblem.timeout));
      };
      final outbox = sender();
      await outbox.drain();
      write.afterRequest = null;
      await retry();
      final notice = (await db.outboxDao.loadProblems()).single;
      expect(notice.changes!.coverImageAttachmentId, 7);
      expect(await db.outboxDao.localCover(3), isNull);
      final sent = write.updates.length;

      await outbox.keepHeldChanges(notice.operationId);

      expect(write.updates.skip(sent), [
        (3, const TaskChanges(coverImageAttachmentId: 7)),
      ]);
      expect(write.covers[3], 7);
      expect(await db.outboxDao.count(), 0);
    });

    test('sent with a label whose request failed after the body goes again '
        'with only the label', () async {
      write.serverLabels[5] = sampleLabel(id: 5, title: 'urgent');
      await queue(
        3,
        done.merge(const TaskChanges(labels: IdSetChange(added: {5}))),
      );
      // The body is stored, the label request fails.
      write.afterRequest = (_) async {
        write.serverTasks[3] = write.serverTasks[3]!.copyWith(labels: []);
        throw const ServerFailure(502);
      };
      final outbox = sender();
      await outbox.drain();
      expect(write.serverTasks[3]!.dueDate, tuesday);
      expect(write.serverTasks[3]!.labels, isEmpty);

      write.afterRequest = null;
      await retry();

      expect(write.requests, ['update 3', 'update 3']);
      expect(write.updates.last, (
        3,
        const TaskChanges(labels: IdSetChange(added: {5})),
      ));
      final server = write.serverTasks[3]!;
      expect(server.dueDate, tuesday);
      expect(server.labels.map((label) => label.id), [5]);
      expect((await db.tasksDao.find(3))!.dueDate, tuesday);
      expect(await db.outboxDao.count(), 0);
    });

    test('whose first attempt never reached the server is sent on the '
        'retry', () async {
      await queue(3, done);
      write.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.timeout));
      final outbox = sender();
      await outbox.drain();
      expect(write.serverTasks[3]!.dueDate, monday);
      expect((await ops()).single.sentAt, now);

      write.beforeRequest = null;
      await retry();

      expect(write.requests, ['update 3', 'update 3']);
      expect(write.updates, [
        (3, TaskChanges(done: true, doneBase: DoneBase(dueDate: monday))),
      ]);
      expect(write.serverTasks[3]!.dueDate, tuesday);
      expect((await db.tasksDao.find(3))!.dueDate, tuesday);
      expect(await db.outboxDao.count(), 0);
    });

    for (final conflict in [false, true]) {
      test('completed elsewhere between attempts preserves a based '
          'description edit with${conflict ? ' a' : 'out a'} conflict and '
          'holds back an unmatched favorite', () async {
        final base = write.serverTasks[3]!.description;
        await queue(
          3,
          TaskChanges(
            done: true,
            isFavorite: true,
            description: '<p>Mine</p>',
            descriptionBase: base,
          ),
        );
        write.beforeRequest = (_) =>
            fail(const NetworkFailure(NetworkProblem.timeout));
        final outbox = sender();
        await outbox.drain();
        write.beforeRequest = null;
        write.serverTasks[3] = copyTask(
          write.serverTasks[3]!,
          dueDate: tuesday,
          doneAt: now,
        ).copyWith(description: conflict ? '<p>Web</p>' : base);

        await outbox.sendNow();

        expect(write.serverTasks[3]!.dueDate, tuesday);
        final notice = (await db.outboxDao.loadProblems()).singleWhere(
          (problem) => isRecurringScheduleConflict(problem.failure),
        );
        expect(notice.changes, favorite);
        if (conflict) {
          final problem = (await db.outboxDao.loadProblems()).singleWhere(
            (problem) => problem.failure is DescriptionConflict,
          );
          expect(problem.changes?.done, isNull);
          expect(write.serverTasks[3]!.description, '<p>Web</p>');
          await outbox.keepMyDescription(
            problem.operationId,
            webDescription: '<p>Web</p>',
          );
        }
        expect(write.updates.single.$2.done, isNull);
        expect(write.serverTasks[3]!.dueDate, tuesday);
        expect(write.updates.single.$2.isFavorite, isNull);
        expect(write.serverTasks[3]!.description, '<p>Mine</p>');
        expect(write.serverTasks[3]!.isFavorite, isFalse);
        expect(await db.outboxDao.hasQueuedOps(3), isFalse);
      });
    }

    test('completion elsewhere between attempts preserves the new schedule '
        'through description conflict resolution', () async {
      final before = write.serverTasks[3]!;
      final schedule = TaskChanges(
        dueDate: DateChange.set(monday.add(const Duration(hours: 2))),
      );
      await queue(
        3,
        schedule.merge(
          TaskChanges(
            done: true,
            title: 'Mine',
            description: '<p>Mine</p>',
            descriptionBase: before.description,
          ),
        ),
      );
      write.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.timeout));
      final outbox = sender();
      await outbox.drain();
      write.beforeRequest = null;
      write.serverTasks[3] = reopenRepeating(
        before.copyWith(description: '<p>Web</p>'),
        now: now,
      );
      await outbox.sendNow();

      final problems = await db.outboxDao.loadProblems();
      final description = problems.singleWhere(
        (problem) => problem.failure is DescriptionConflict,
      );
      expect(description.changes?.dueDate, isNull);
      expect(description.changes?.done, isNull);
      expect(description.changes?.descriptionBase, before.description);
      final notice = problems.singleWhere(
        (problem) => isRecurringScheduleConflict(problem.failure),
      );
      expect(notice.changes, schedule.merge(const TaskChanges(title: 'Mine')));
      expect((await db.tasksDao.find(3))!.dueDate, tuesday);
      expect(write.serverTasks[3]!.description, '<p>Web</p>');

      await outbox.keepMyDescription(
        description.operationId,
        webDescription: '<p>Web</p>',
      );

      final server = write.serverTasks[3]!;
      expect(server.title, before.title);
      expect(server.description, '<p>Mine</p>');
      expect(server.dueDate, tuesday);
      expect(write.updates.single.$2.dueDate, isNull);
      expect(write.updates.single.$2.done, isNull);
      expect(
        (await db.outboxDao.loadProblems()).single.operationId,
        notice.operationId,
      );
    });

    test('left in flight by a sender disposed after the request is not '
        'applied again once it is stale', () async {
      await queue(3, done);
      final first = sender();
      write.afterRequest = (_) => first.dispose();

      await first.drain();

      final left = (await ops()).single;
      expect(left.state, OutboxState.sending.name);
      expect(left.sentAt, now);
      expect(write.serverTasks[3]!.dueDate, tuesday);

      write.afterRequest = null;
      now = now.add(OutboxSender.staleSendingAfter);
      await sender().drain();

      expect(write.requests, ['update 3']);
      expect(write.serverTasks[3]!.dueDate, tuesday);
      expect((await db.tasksDao.find(3))!.dueDate, tuesday);
      expect(await db.outboxDao.count(), 0);
    });

    group('of a task without dates, which only its reminders and done time '
        'tell', () {
      final reminder = DateTime.utc(2026, 10, 20, 9);
      final next = reminder.add(const Duration(days: 1));

      setUp(() async {
        final undated = sampleTask(
          id: 4,
          title: 'Water the plants',
          projectId: 7,
          repeatAfter: const Duration(days: 1),
          reminders: [TaskReminder(reminder: reminder)],
        );
        await db.tasksDao.upsertAll([undated], syncRunId: 'run');
        write.serverTasks[4] = undated;
      });

      test('whose answer was lost is not applied again', () async {
        await queue(4, done);
        loseAnswers();
        final outbox = sender();
        await outbox.drain();
        expect(
          decodeTaskChanges((await ops()).single.payload).doneBase,
          const DoneBase(),
        );

        write.afterRequest = null;
        await retry();

        expect(write.requests, ['update 4']);
        final server = write.serverTasks[4]!;
        expect(server.reminders.single.reminder, next);
        expect(server.done, isFalse);
        final local = (await db.tasksDao.find(4))!;
        expect(local.reminders.single.reminder, next);
        expect(local.doneAt, server.doneAt);
        expect(await db.outboxDao.count(), 0);
      });

      test('whose first attempt never reached the server is sent on the '
          'retry', () async {
        await queue(4, done);
        write.beforeRequest = (_) =>
            fail(const NetworkFailure(NetworkProblem.timeout));
        final outbox = sender();
        await outbox.drain();

        write.beforeRequest = null;
        await retry();

        expect(write.requests, ['update 4', 'update 4']);
        expect(write.serverTasks[4]!.reminders.single.reminder, next);
        expect(await db.outboxDao.count(), 0);
      });
    });

    group('made on the web for the occurrence shown here, before the device '
        'synced it', () {
      final webDone = DateTime.utc(2026, 10, 10, 8);

      setUp(() {
        write.serverTasks[3] = copyTask(
          write.serverTasks[3]!,
          dueDate: tuesday,
          doneAt: webDone,
        );
      });

      test('is not applied again: the device takes the next '
          'occurrence', () async {
        await queue(3, done);
        expect(
          decodeTaskChanges((await ops()).single.payload).doneBase,
          DoneBase(dueDate: monday),
        );

        await sender().drain();

        expect(read.requests, ['task 3']);
        expect(write.requests, isEmpty);
        expect(write.serverTasks[3]!.dueDate, tuesday);
        final daily = (await db.tasksDao.find(3))!;
        expect(daily.dueDate, tuesday);
        expect(daily.done, isFalse);
        expect(daily.doneAt, webDone);
        expect(await db.outboxDao.count(), 0);
      });

      test('leaves out only the Done: an edit queued with it goes', () async {
        const edit = TaskChanges(isFavorite: true, title: 'Mine');
        await queue(3, done);
        await queue(3, edit);
        expect(await ops(), hasLength(1));

        await sender().drain();

        expect(write.updates, [(3, edit)]);
        final server = write.serverTasks[3]!;
        expect(server.dueDate, tuesday);
        expect(server.isFavorite, isTrue);
        expect(server.title, 'Mine');
        final daily = (await db.tasksDao.find(3))!;
        expect(daily.dueDate, tuesday);
        expect(daily.isFavorite, isTrue);
        expect(await db.outboxDao.count(), 0);
      });

      test(
        'holds back a stale schedule even before the first request',
        () async {
          final schedule = TaskChanges(dueDate: DateChange.set(monday));
          await queue(3, schedule.merge(done));

          await sender().drain();

          expect(write.requests, isEmpty);
          expect((await db.tasksDao.find(3))!.dueDate, tuesday);
          final notice = (await db.outboxDao.loadProblems()).single;
          expect(isRecurringScheduleConflict(notice.failure), isTrue);
          expect(notice.changes, schedule);
        },
      );

      test('Done, Undo and Done again keep it: the Undo takes the shown '
          'occurrence back with its Done', () async {
        await queue(3, done);
        await queue(
          3,
          TaskChanges(done: false, dueDate: DateChange.set(monday)),
        );
        expect(
          decodeTaskChanges((await ops()).single.payload).doneBase,
          isNull,
        );
        await queue(3, done);

        await sender().drain();

        expect(write.serverTasks[3]!.dueDate, tuesday);
        expect((await db.tasksDao.find(3))!.dueDate, tuesday);
        expect(await db.outboxDao.count(), 0);
      });

      test('is sent when the row showed a change of its own: the shown '
          "occurrence was not the server's", () async {
        await queue(3, favorite);
        await queue(3, done);
        expect(
          decodeTaskChanges((await ops()).single.payload).doneBase,
          isNull,
        );

        await sender().drain();

        expect(write.updates.single.$2.done, isTrue);
        expect(
          write.serverTasks[3]!.dueDate,
          tuesday.add(const Duration(days: 1)),
        );
      });
    });

    test('is sent when only a date was edited on the web before the device '
        'synced it', () async {
      final thursday = monday.add(const Duration(days: 3));
      write.serverTasks[3] = copyTask(write.serverTasks[3]!, dueDate: thursday);
      await queue(3, done);

      await sender().drain();

      expect(write.requests, ['update 3']);
      expect(
        write.serverTasks[3]!.dueDate,
        thursday.add(const Duration(days: 1)),
      );
      expect(await db.outboxDao.count(), 0);
    });

    test('of a task that does not repeat costs no read', () async {
      await queue(1, done);

      await sender().drain();

      expect(read.requests, isEmpty);
      expect(write.updates, [(1, done)]);
      expect(await db.outboxDao.count(), 0);
    });

    test('is sent when only a date was edited on the server between the '
        'attempts', () async {
      final thursday = monday.add(const Duration(days: 3));
      final previousDone = now.subtract(const Duration(days: 1));
      final task = copyTask(
        write.serverTasks[3]!,
        doneAt: previousDone.add(const Duration(milliseconds: 123)),
      );
      await db.tasksDao.upsertAll([task]);
      write.serverTasks[3] = task;
      await queue(3, done);
      write.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.timeout));
      final outbox = sender();
      await outbox.drain();
      // Losing fractional precision on a read is not another completion.
      write.serverTasks[3] = copyTask(
        task,
        dueDate: thursday,
        doneAt: previousDone,
      );

      write.beforeRequest = null;
      await retry();

      expect(write.requests, ['update 3', 'update 3']);
      expect(
        write.serverTasks[3]!.dueDate,
        thursday.add(const Duration(days: 1)),
      );
      expect(await db.outboxDao.count(), 0);
    });

    test('an edit queued after the lost answer is an op of its own and goes '
        'after it, so it is not dropped with the body', () async {
      await queue(3, done);
      loseAnswers();
      final outbox = sender();
      await outbox.drain();
      write.afterRequest = null;

      await queue(3, favorite);

      expect(await ops(), hasLength(2));
      await outbox.sendNow();

      expect(write.requests, ['update 3', 'update 3']);
      expect(write.updates.last, (3, favorite));
      final server = write.serverTasks[3]!;
      expect(server.dueDate, tuesday);
      expect(server.isFavorite, isTrue);
      final daily = (await db.tasksDao.find(3))!;
      expect(daily.dueDate, tuesday);
      expect(daily.isFavorite, isTrue);
      expect(await db.outboxDao.count(), 0);
    });

    test('an Undo queued after the lost answer goes after it', () async {
      await queue(3, done);
      loseAnswers();
      final outbox = sender();
      await outbox.drain();
      write.afterRequest = null;

      await queue(3, const TaskChanges(done: false));
      await outbox.sendNow();

      expect(write.requests, ['update 3', 'update 3']);
      expect(write.updates.last, (3, const TaskChanges(done: false)));
      expect(write.serverTasks[3]!.dueDate, tuesday);
      expect(write.serverTasks[3]!.done, isFalse);
      expect((await db.tasksDao.find(3))!.done, isFalse);
      expect(await db.outboxDao.count(), 0);
    });
  });

  group('problems', () {
    for (final failure in <VikunjaFailure>[
      const NotFound(code: 3001),
      const NotFound(code: 3018),
      const NotFound(code: 4002),
      const NotFound(code: 4040),
      const Forbidden(code: 7003),
      const DomainError(412, code: 3008),
      const ValidationFailed(
        fieldErrors: {
          'title': ['empty'],
        },
      ),
      const UnexpectedResponse(400),
      const UnexpectedResponse(500),
    ]) {
      test('$failure is final: a problem, and the queue moves on', () async {
        write.beforeRequest = (request) {
          if (request == 'update 1') fail(failure);
          return Future.value();
        };
        await queue(1, done);
        await queue(2, done);
        final outbox = sender();

        await outbox.drain();

        expect(write.requests, ['update 1', 'update 2']);
        final problem = (await db.outboxDao.loadProblems()).single;
        expect(problem.taskId, 1);
        expect(problem.taskTitle, 'One');
        expect(problem.failure.runtimeType, failure.runtimeType);
        expect(problem.failure.code, failure.code);
        expect(problem.failedAt, now);
        expect(await db.outboxDao.count(), 1);
        expect(outbox.state, OutboxSenderState.idle);
        expect(timers.active, isEmpty);
        expect(sync.refreshAfterWriteCalls, 1);
        // The local edit stays until the user decides.
        expect((await db.tasksDao.find(1))!.done, isTrue);
      });
    }

    test('Retry all puts every failed op of the list back and sends them in '
        'one drain; an op no longer failed is left alone', () async {
      write.beforeRequest = (request) => request == 'update 3'
          ? fail(const NetworkFailure(NetworkProblem.unreachable))
          : fail(const Forbidden(code: 7003));
      await queue(1, done);
      await queue(2, favorite);
      final outbox = sender();
      await outbox.drain();
      final problems = await db.outboxDao.loadProblems();
      expect(problems, hasLength(2));
      await queue(3, favorite);
      await outbox.drain();
      final waiting = (await ops()).last;
      expect(waiting.state, OutboxState.pending.name);
      write.beforeRequest = (request) => request == 'update 3'
          ? fail(const NetworkFailure(NetworkProblem.unreachable))
          : Future.value();

      await outbox.retryAll([
        for (final problem in problems) problem.operationId,
        waiting.id,
      ]);

      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(write.requests, [
        'update 1',
        'update 2',
        'update 3',
        'update 1',
        'update 2',
      ]);
      expect(write.serverTasks[1]!.done, isTrue);
      expect(write.serverTasks[2]!.isFavorite, isTrue);
      final left = (await ops()).single;
      expect(left.id, waiting.id);
      expect(left.attempts, waiting.attempts);
      expect(left.nextAttemptAt, waiting.nextAttemptAt);
    });

    test('retry puts the op back in the queue and sends it', () async {
      write.beforeRequest = (_) => fail(const Forbidden(code: 7003));
      await queue(1, done);
      final outbox = sender();
      await outbox.drain();
      final problem = (await db.outboxDao.loadProblems()).single;

      write.beforeRequest = null;
      await outbox.retry(problem.operationId);

      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(await db.outboxDao.count(), 0);
      expect(write.serverTasks[1]!.done, isTrue);
    });

    test(
      'discard drops the op and restores the task from the server',
      () async {
        write.beforeRequest = (_) => fail(const Forbidden(code: 7003));
        await queue(1, const TaskChanges(done: true, isFavorite: true));
        final outbox = sender();
        await outbox.drain();
        final problem = (await db.outboxDao.loadProblems()).single;
        read.allTasks = [
          copyTask(tasks[0], title: 'One, renamed on the web'),
          ...tasks.skip(1),
        ];

        await outbox.discard(problem.operationId);

        final one = (await db.tasksDao.find(1))!;
        expect(one.title, 'One, renamed on the web');
        expect(one.done, isFalse);
        expect(one.isFavorite, isFalse);
        expect((await db.tasksDao.findRow(1))!.pendingChanges, isNull);
        expect(await db.outboxDao.count(), 0);
        expect(read.requests, ['task 1']);
      },
    );

    test('discarding a delete shows the task again', () async {
      write.beforeRequest = (_) => fail(const Forbidden(code: 7003));
      await queueDelete(2);
      final outbox = sender();
      await outbox.drain();
      expect(await db.tasksDao.find(2), isNull);
      final problem = (await db.outboxDao.loadProblems()).single;

      await outbox.discard(problem.operationId);

      final two = (await db.tasksDao.find(2))!;
      expect(two.title, 'Two');
      expect((await db.tasksDao.findRow(2))!.pendingDelete, isFalse);
      expect(await db.outboxDao.count(), 0);
    });

    test(
      'discarding an op of a task the server no longer has removes it',
      () async {
        write.beforeRequest = (_) => fail(const NotFound(code: 3001));
        await queue(1, done);
        final outbox = sender();
        await outbox.drain();
        final problem = (await db.outboxDao.loadProblems()).single;
        read.allTasks = tasks.skip(1).toList();

        await outbox.discard(problem.operationId);

        expect(await db.tasksDao.findRow(1), isNull);
        expect(await db.outboxDao.count(), 0);
      },
    );

    test('discarding an op of a task the server no longer has takes its '
        'other ops with it', () async {
      write.beforeRequest = (_) => fail(const NotFound(code: 4002));
      await queue(1, done);
      final outbox = sender();
      await outbox.drain();
      final problem = (await db.outboxDao.loadProblems()).single;
      await queueDelete(1);
      read.allTasks = tasks.skip(1).toList();

      await outbox.discard(problem.operationId);
      await pumpEventQueue();

      expect(await db.tasksDao.findRow(1), isNull);
      expect(await db.outboxDao.count(), 0);
      expect(write.requests, ['update 1']);
    });

    test('discarding an op the server forbids removes the task: its '
        'project left the user', () async {
      write.beforeRequest = (_) => fail(const Forbidden(code: 0));
      await queue(1, done);
      final outbox = sender();
      await outbox.drain();
      final problem = (await db.outboxDao.loadProblems()).single;
      read.beforeRequest = (_) => fail(const Forbidden(code: 0));

      await outbox.discard(problem.operationId);

      expect(await db.tasksDao.findRow(1), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('discarding a forbidden delete removes the row too', () async {
      write.beforeRequest = (_) => fail(const Forbidden(code: 0));
      await queueDelete(2);
      final outbox = sender();
      await outbox.drain();
      final problem = (await db.outboxDao.loadProblems()).single;
      read.beforeRequest = (_) => fail(const Forbidden(code: 0));

      await outbox.discard(problem.operationId);

      expect(await db.tasksDao.findRow(2), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('a discard whose op went meanwhile leaves the row alone', () async {
      write.beforeRequest = (_) => fail(const Forbidden(code: 7003));
      await queue(1, done);
      final outbox = sender();
      await outbox.drain();
      final problem = (await db.outboxDao.loadProblems()).single;
      // The read is slow; a Retry gets through before it answers with the
      // task as it was before.
      final gate = RequestGate()..pattern = 'task 1';
      read.beforeRequest = gate.call;
      final discard = outbox.discard(problem.operationId);
      await pumpEventQueue();
      write.beforeRequest = null;
      await outbox.retry(problem.operationId);
      expect(write.serverTasks[1]!.done, isTrue);

      gate.release();
      await discard;

      expect((await db.tasksDao.find(1))!.done, isTrue);
      expect(await db.outboxDao.count(), 0);
    });

    test('a discard that cannot reach the server changes nothing', () async {
      write.beforeRequest = (_) => fail(const Forbidden(code: 7003));
      await queue(1, done);
      final outbox = sender();
      await outbox.drain();
      final problem = (await db.outboxDao.loadProblems()).single;
      read.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.unreachable));

      await expectLater(
        outbox.discard(problem.operationId),
        throwsA(isA<NetworkFailure>()),
      );

      expect(await db.outboxDao.loadProblems(), hasLength(1));
      expect((await db.tasksDao.find(1))!.done, isTrue);
    });

    test('an op that is gone is nothing to retry or discard', () async {
      final outbox = sender();

      await outbox.retry('missing');
      await outbox.discard('missing');

      expect(read.requests, isEmpty);
    });
  });

  group('creates', () {
    const draft = NewTask(
      projectId: 7,
      title: 'Buy milk',
      priority: TaskPriority.high,
      isFavorite: true,
    );

    Future<int> create([NewTask task = draft]) =>
        db.outboxDao.queueCreate(task, now: now);

    test('a create is sent, the row moves to the server id with the response '
        'applied, and watchers follow', () async {
      final id = await create();
      final seen = <Task?>[];
      final subscription = db.tasksDao.watchTask(id).listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen.single!.id, id);

      await sender().drain();

      expect(write.requests, ['create Buy milk']);
      expect(write.creates, [draft]);
      expect(await db.tasksDao.findRow(id), isNull);
      final created = (await db.tasksDao.find(100))!;
      expect(created.title, 'Buy milk');
      expect(created.priority, TaskPriority.high);
      expect(created.isFavorite, isTrue);
      expect(created.identifier, '-100');
      expect(created.updated, now);
      expect(await db.tasksDao.resolveId(id), 100);
      await pumpEventQueue();
      expect(seen.last!.id, 100);
      expect(await db.outboxDao.count(), 0);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test(
      'ops go in order: a create, an update and a delete of other tasks, '
      'and an edit queued behind the create is sent under the server id',
      () async {
        final id = await create();
        await queue(1, done);
        await queueDelete(2);
        final gate = RequestGate()..pattern = 'create';
        write.beforeRequest = gate.call;
        final outbox = sender();
        final drain = outbox.drain();
        await pumpEventQueue();
        await queue(id, const TaskChanges(done: true, title: 'Bought'));
        expect(await db.outboxDao.all(), hasLength(4));

        gate.release();
        await drain;

        expect(write.requests, [
          'create Buy milk',
          'update 1',
          'delete 2',
          'update 100',
        ]);
        expect(write.updates.last, (
          100,
          const TaskChanges(done: true, title: 'Bought'),
        ));
        final created = (await db.tasksDao.find(100))!;
        expect(created.title, 'Bought');
        expect(created.done, isTrue);
        expect(write.serverTasks[100]!.done, isTrue);
        expect(await db.outboxDao.count(), 0);
      },
    );

    test('a lost create answer is not resent over a rebuilt client', () async {
      final rebuilt = FakeWriteClient(clock: () => now);
      VikunjaWriteClient current = write;
      write.afterRequest = (_) {
        current = rebuilt;
        fail(const NetworkFailure(NetworkProblem.timeout));
      };
      final id = await create();
      final outbox = sender(writeClient: () => current);

      await outbox.drain();

      expect(write.requests, ['create Buy milk']);
      expect(rebuilt.requests, isEmpty);
      expect(await db.tasksDao.resolveId(id), id);
      expect((await ops()).single.state, OutboxState.failed.name);
      expect(timers.active, isEmpty);
    });

    test('a create the replaced client refused goes at once over the rebuilt '
        'one, not blocked as unconfirmed', () async {
      final rebuilt = FakeWriteClient(clock: () => now);
      VikunjaWriteClient current = write;
      write.beforeRequest = (_) {
        current = rebuilt;
        fail(
          const NetworkFailure(
            NetworkProblem.unreachable,
            cause: ClientClosed(),
          ),
        );
      };
      await create();
      final outbox = sender(writeClient: () => current);

      await outbox.drain();

      expect(write.requests, ['create Buy milk']);
      expect(rebuilt.requests, ['create Buy milk']);
      expect(await db.outboxDao.count(), 0);
      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(timers.active, isEmpty);
    });

    for (final (what, answer) in [
      ('a timeout', () => fail(const NetworkFailure(NetworkProblem.timeout))),
      ('a 5xx', () => fail(const ServerFailure(504))),
      (
        'a 2xx whose body cannot be read',
        () => fail(const UnexpectedResponse(201, message: 'task without id')),
      ),
      ('an exception after the request', () => throw StateError('a bug')),
    ]) {
      test('$what leaves a possibly committed create blocked', () async {
        final id = await create();
        write.afterRequest = (_) async => answer();
        final outbox = sender();

        await outbox.drain();

        final op = (await ops()).single;
        expect(op.state, OutboxState.failed.name);
        expect(op.sentAt, now);
        expect(write.serverTasks[100]!.title, draft.title);
        expect(
          isUnconfirmedWrite(
            (await db.outboxDao.loadProblems()).single.failure,
          ),
          isTrue,
        );

        write.afterRequest = null;
        now = now.add(const Duration(minutes: 1));
        await outbox.retry(op.id);
        await outbox.retryAll([op.id]);

        // Neither Retry nor "Try all again" picks it up again.
        expect(await ops(), [op]);
        expect(write.requests, ['create Buy milk']);
        expect(read.requests, ['project 7']);
        expect(await db.tasksDao.resolveId(id), id);
        expect((await db.tasksDao.find(id))!.title, draft.title);
        expect(await db.outboxDao.count(), 1);
      });
    }

    for (final (what, failure) in const [
      (
        'could not connect',
        NetworkFailure(
          NetworkProblem.unreachable,
          cause: SocketException('Connection refused'),
        ),
      ),
      (
        'timed out while connecting',
        NetworkFailure(NetworkProblem.timeout, cause: ConnectTimedOut()),
      ),
    ]) {
      test('a create that $what is retried without blocking', () async {
        final id = await create();
        write.beforeRequest = (_) => fail(failure);
        final outbox = sender();
        await outbox.drain();
        expect((await ops()).single.sentAt, isNull);
        expect(outbox.state, OutboxSenderState.waiting);

        write.beforeRequest = null;
        await outbox.sendNow();

        expect(write.requests, ['create Buy milk', 'create Buy milk']);
        expect(await db.tasksDao.resolveId(id), 100);
        expect(await db.outboxDao.count(), 0);
      });
    }

    test("a captive portal's page in the server's place stopped the create: "
        'it waits and goes once the portal is gone', () async {
      final id = await create();
      write.beforeRequest = (_) =>
          fail(const NotJsonResponse(200, message: 'text/html'));
      final outbox = sender();
      await outbox.drain();
      final op = (await ops()).single;
      expect(op.sentAt, isNull);
      expect(op.state, OutboxState.pending.name);
      expect(await db.outboxDao.loadProblems(), isEmpty);

      write.beforeRequest = null;
      await outbox.sendNow();

      expect(write.requests, ['create Buy milk', 'create Buy milk']);
      expect(await db.tasksDao.resolveId(id), 100);
      expect(await db.outboxDao.count(), 0);
    });

    // Android's and iOS's HTTP clients report a timeout while connecting as
    // a bare one, which proves nothing (decision log: Creates).
    for (final (what, failure) in const <(String, VikunjaFailure)>[
      ('a timeout', NetworkFailure(NetworkProblem.timeout)),
      ('a 5xx', ServerFailure(502)),
      ("a captive portal's page", NotJsonResponse(200, message: 'text/html')),
    ]) {
      test('$what on the read of its project before a create holds the '
          'create back unsent', () async {
        final id = await create();
        read.beforeRequest = (_) => fail(failure);
        final outbox = sender();

        await outbox.drain();

        expect(read.requests, ['project 7']);
        expect(write.requests, isEmpty);
        final op = (await ops()).single;
        expect(op.sentAt, isNull);
        expect(op.state, OutboxState.pending.name);
        expect(outbox.state, OutboxSenderState.waiting);
        expect(await db.outboxDao.loadProblems(), isEmpty);

        read.beforeRequest = null;
        await outbox.sendNow();

        expect(read.requests, ['project 7', 'project 7']);
        expect(write.requests, ['create Buy milk']);
        expect(await db.tasksDao.resolveId(id), 100);
      });
    }

    test('a create whose sender is disposed during the read before it is '
        'sent by the next start, not blocked', () async {
      final id = await create();
      final reading = Completer<void>();
      final finishRead = Completer<void>();
      addTearDown(() {
        if (!finishRead.isCompleted) finishRead.complete();
      });
      read.beforeRequest = (_) async {
        if (reading.isCompleted) return;
        reading.complete();
        await finishRead.future;
      };
      final first = sender();
      final draining = first.drain();
      await reading.future;
      await first.dispose();
      finishRead.complete();
      await draining;
      expect(write.requests, isEmpty);
      final op = (await ops()).single;
      expect(op.sentAt, isNull);
      expect(op.state, OutboxState.pending.name);

      await sender().drain();

      expect(write.requests, ['create Buy milk']);
      expect(await db.tasksDao.resolveId(id), 100);
    });

    test('an answer of the server within the last 30 s spares the read '
        'before a create; an older answer or a failure since does '
        'not', () async {
      await create();
      await create(const NewTask(projectId: 7, title: 'Bread'));
      final outbox = sender();

      await outbox.drain();

      expect(read.requests, ['project 7']);
      expect(write.requests, ['create Buy milk', 'create Bread']);

      now = now.add(OutboxSender.answeredRecently);
      await create(const NewTask(projectId: 7, title: 'Eggs'));
      await outbox.sendNow();

      expect(read.requests, hasLength(2));

      // A sync that got through is an answer too.
      now = now.add(OutboxSender.answeredRecently);
      sync.emit(SyncIdle(lastSyncedAt: now));
      await pumpEventQueue();
      write.beforeRequest = (_) => fail(
        const NetworkFailure(
          NetworkProblem.unreachable,
          cause: SocketException('Connection refused'),
        ),
      );
      await create(const NewTask(projectId: 7, title: 'Jam'));
      await outbox.sendNow();

      expect(read.requests, hasLength(2));
      expect(write.requests.last, 'create Jam');

      write.beforeRequest = null;
      now = now.add(OutboxSender.initialBackoff);
      await outbox.sendNow();

      expect(read.requests, hasLength(3));
      expect(write.requests.last, 'create Jam');
      expect(await db.outboxDao.count(), 0);
    });

    test(
      'a 429 or a rejected token is certain: no lookup afterwards',
      () async {
        await create();
        write.beforeRequest = (_) =>
            fail(const RateLimited(retryAfter: Duration(seconds: 5)));
        final outbox = sender();
        await outbox.drain();
        expect((await ops()).single.sentAt, isNull);

        write.beforeRequest = null;
        await outbox.sendNow();

        expect(read.requests, ['project 7']);
        expect(write.requests, ['create Buy milk', 'create Buy milk']);
      },
    );

    // Such a request never left the device, though it fails as a network
    // failure (decision log: Sessions).
    for (final failure in const [
      NetworkFailure(NetworkProblem.timeout, cause: RefreshDeferred.race),
      NetworkFailure(
        NetworkProblem.unreachable,
        cause: SecureStorageUnreadable(PlatformException),
      ),
    ]) {
      test('a create whose request got no token (${failure.cause}) is '
          'certain: no lookup afterwards', () async {
        await create();
        write.beforeRequest = (_) => fail(failure);
        final outbox = sender();
        await outbox.drain();
        final op = (await ops()).single;
        expect(op.sentAt, isNull);
        expect(op.state, OutboxState.pending.name);

        write.beforeRequest = null;
        await outbox.sendNow();

        expect(read.requests, ['project 7']);
        expect(write.requests, ['create Buy milk', 'create Buy milk']);
      });
    }

    test('a rejected create is a problem under its title; the row stays '
        'until the user decides', () async {
      final id = await create();
      await queue(1, done);
      write.beforeRequest = (request) => request.startsWith('create')
          ? fail(const DomainError(412, code: 3008, message: 'archived'))
          : Future.value();
      final outbox = sender();

      await outbox.drain();

      expect(write.requests, ['create Buy milk', 'update 1']);
      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.kind, OutboxOperationKind.createTask);
      expect(problem.taskId, id);
      expect(problem.taskTitle, 'Buy milk');
      expect(problem.failure, isA<DomainError>());
      expect((await db.tasksDao.find(id))!.title, 'Buy milk');
      expect(outbox.state, OutboxSenderState.idle);

      // Moved to another project and retried.
      await db.outboxDao.queueUpdate(
        id,
        const TaskChanges(projectId: 8),
        now: now,
      );
      write.beforeRequest = null;
      await outbox.drain();

      expect(write.creates.last.projectId, 8);
      expect(await db.tasksDao.resolveId(id), 100);
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test('discarding a rejected create drops the task without asking the '
        'server', () async {
      final id = await create();
      write.beforeRequest = (_) =>
          fail(const ValidationFailed(code: 4001, message: 'title'));
      final outbox = sender();
      await outbox.drain();
      final problem = (await db.outboxDao.loadProblems()).single;
      read.requests.clear();

      await outbox.discard(problem.operationId);

      expect(read.requests, isEmpty);
      expect(await db.tasksDao.findRow(id), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('discarding a rejected create sends at once what of another task '
        'waited for it', () async {
      final id = await create();
      write.beforeRequest = (request) => request.startsWith('create')
          ? fail(const ValidationFailed(code: 4001, message: 'title'))
          : Future.value();
      final outbox = sender();
      await outbox.drain();
      await queue(
        1,
        TaskChanges(
          isFavorite: true,
          relations: RelationChange(
            added: {TaskRelationRef(TaskRelationKind.related, id)},
          ),
        ),
      );
      await outbox.drain();
      expect(write.requests, ['create Buy milk']);
      final problem = (await db.outboxDao.loadProblems()).single;

      await outbox.discard(problem.operationId);
      await pumpEventQueue();

      expect(write.requests, ['create Buy milk', 'update 1']);
      expect(write.updates.single, (1, favorite));
      expect(await db.outboxDao.count(), 0);
    });

    test('a create and its delete before the send cost no request', () async {
      final id = await create();
      await queue(id, done);
      await queueDelete(id);
      expect(await ops(), hasLength(3));

      await sender().drain();

      expect(write.requests, isEmpty);
      expect(read.requests, isEmpty);
      expect(sync.refreshAfterWriteCalls, 0);
      expect(await db.outboxDao.count(), 0);
      expect(await db.tasksDao.findRow(id), isNull);
    });

    test('a delete taken back between the claim of the create and its drop '
        'lets the create go', () async {
      final interceptor = _OnStatement();
      db = AppDatabase(NativeDatabase.memory().interceptWith(interceptor));
      addTearDown(db.close);
      final id = await create();
      await queueDelete(id);
      final createId = (await ops()).first.id;
      late Future<DeleteUnqueue> undo;
      interceptor.onUpdate = (args) {
        if (!args.contains(createId) ||
            !args.contains(OutboxState.sending.name)) {
          return;
        }
        interceptor.onUpdate = null;
        // Outside the claim's transaction, so it queues behind it and ahead
        // of the sender's next one.
        Zone.root.run<void>(() {
          undo = db.outboxDao.unqueueDelete(id);
        });
      };

      await sender().drain();

      expect(await undo, DeleteUnqueue.cancelled);
      expect(write.requests, ['create Buy milk']);
      expect((await db.tasksDao.find(100))!.title, 'Buy milk');
      expect(await db.outboxDao.count(), 0);
    });

    test('a delete queued while the create is in flight is sent under the '
        'server id', () async {
      final id = await create();
      final gate = RequestGate()..pattern = 'create';
      write.beforeRequest = gate.call;
      final outbox = sender();
      final drain = outbox.drain();
      await pumpEventQueue();
      await queueDelete(id);
      expect(await db.tasksDao.find(id), isNull);

      gate.release();
      await drain;

      expect(write.requests, ['create Buy milk', 'delete 100']);
      expect(write.serverTasks.containsKey(100), isFalse);
      expect(await db.tasksDao.findRow(100), isNull);
      expect(await db.tasksDao.findRow(id), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('an op queued behind a rejected create waits for it', () async {
      final id = await create();
      final held = Completer<void>();
      write.beforeRequest = (request) =>
          request.startsWith('create') ? held.future : Future.value();
      final outbox = sender();
      final drain = outbox.drain();
      await pumpEventQueue();
      await queue(id, done);
      held.completeError(const Forbidden(code: 7003));
      await drain;

      expect(write.requests, ['create Buy milk']);
      expect(await db.outboxDao.count(), 2);
      expect(await db.outboxDao.loadProblems(), hasLength(1));
      expect(outbox.state, OutboxSenderState.idle);

      write.beforeRequest = null;
      await outbox.retry(
        (await db.outboxDao.loadProblems()).single.operationId,
      );

      expect(write.requests, [
        'create Buy milk',
        'create Buy milk',
        'update 100',
      ]);
      expect((await db.tasksDao.find(100))!.done, isTrue);
      expect(await db.outboxDao.count(), 0);
    });

    for (final hasLookalike in [true, false]) {
      test('a stale create with ${hasLookalike ? 'a' : 'no'} lookalike keeps '
          'its draft, edit and delete under the temporary ID', () async {
        const me = User(id: 5, username: 'me');
        final id = await create();
        final op = (await ops()).single;
        await db.outboxDao.markSending(op.id, at: now);
        await db.outboxDao.markCreatePosted((await ops()).single, at: now);
        await queue(id, const TaskChanges(title: 'Buy oat milk'));
        await queueDelete(id);
        if (hasLookalike) {
          final other = taskFromNewTask(
            draft,
            id: 50,
            now: now,
          ).copyWith(createdBy: me);
          read.allTasks = [...tasks, other];
          write.serverTasks[50] = other;
        }
        now = now.add(OutboxSender.staleSendingAfter);
        final outbox = sender(userId: me.id);

        await outbox.drain();
        await outbox.retry(op.id);

        final rows = await ops();
        expect(rows.map((row) => row.taskId), [id, id, id]);
        expect(rows.first.state, OutboxState.failed.name);
        expect(decodeTaskChanges(rows[1].payload).title, 'Buy oat milk');
        expect(rows[2].kind, OutboxOperationKind.deleteTask.name);
        expect(await db.tasksDao.resolveId(id), id);
        expect((await db.tasksDao.findRow(id))!.pendingDelete, isTrue);
        expect(write.requests, isEmpty);
        expect(read.requests, isEmpty);
        if (hasLookalike) expect(write.serverTasks[50]!.title, draft.title);
      });
    }

    test('the create payload the sender sends is the merged one', () async {
      final id = await create();
      await queue(id, TaskChanges(dueDate: DateChange.set(monday)));

      await sender().drain();

      expect(write.creates.single.dueDate, monday);
      expect(
        decodeNewTask(encodeNewTask(write.creates.single)).title,
        'Buy milk',
      );
    });
  });

  group('labels, assignees and reminders', () {
    final urgent = sampleLabel(id: 10, title: 'urgent');
    final home = sampleLabel(id: 11, title: 'home');
    const ana = User(id: 20, username: 'ana', name: 'Ana');
    const hourBeforeDue = TaskReminder(
      relativePeriod: Duration(hours: -1),
      relativeTo: ReminderRelativeTo.dueDate,
    );
    final beforeMonday = monday.subtract(const Duration(hours: 1));

    setUp(() async {
      await db.labelsDao.upsertAll([urgent, home]);
      await db.usersDao.upsertAll([ana]);
      write.serverLabels[10] = urgent;
      write.serverUsers[20] = ana;
    });

    test('reach the server, and the answer lands in the child rows', () async {
      const changes = TaskChanges(
        labels: IdSetChange(added: {10}),
        assignees: IdSetChange(added: {20}),
        reminders: [hourBeforeDue],
      );
      await queue(1, changes);

      await sender().drain();

      expect(write.requests, ['update 1']);
      expect(write.updates.single, (1, changes));
      final server = write.serverTasks[1]!;
      expect(server.labels, [urgent]);
      expect(server.assignees, [ana]);
      expect(server.reminders.single.reminder, beforeMonday);
      final local = (await db.tasksDao.find(1))!;
      expect(local.labels, [urgent]);
      expect(local.assignees, [ana]);
      expect(local.reminders, server.reminders);
      expect((await db.tasksDao.findRow(1))!.pendingChanges, isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('a task created with a reminder, then labelled and assigned before '
        'the send: the create carries the reminder, the labels and the '
        'assignee follow under the server id, and the local rows survive '
        'the remap', () async {
      final id = await db.outboxDao.queueCreate(
        NewTask(
          projectId: 7,
          title: 'Call back',
          dueDate: monday,
          reminders: const [hourBeforeDue],
        ),
        now: now,
      );
      await queue(
        id,
        const TaskChanges(
          labels: IdSetChange(added: {10}),
          assignees: IdSetChange(added: {20}),
        ),
      );
      final local = (await db.tasksDao.find(id))!;
      expect(local.labels, [urgent]);
      expect(local.assignees, [ana]);
      expect(local.reminders.single.reminder, beforeMonday);

      await sender().drain();

      expect(write.requests, ['create Call back', 'update 100']);
      expect(write.creates.single.reminders, [hourBeforeDue]);
      expect(write.updates.single, (
        100,
        const TaskChanges(
          labels: IdSetChange(added: {10}),
          assignees: IdSetChange(added: {20}),
        ),
      ));
      final server = write.serverTasks[100]!;
      expect(server.labels, [urgent]);
      expect(server.assignees, [ana]);
      expect(server.reminders.single.reminder, beforeMonday);
      expect(await db.tasksDao.resolveId(id), 100);
      final created = (await db.tasksDao.find(100))!;
      expect(created.labels, [urgent]);
      expect(created.assignees, [ana]);
      expect(created.reminders, server.reminders);
      expect(await db.outboxDao.count(), 0);
    });

    test('labels picked while the create is in flight are still shown after '
        'the remap, before their own update is sent', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'Call back'),
        now: now,
      );
      final gate = RequestGate()..pattern = RegExp('create|update');
      write.beforeRequest = gate.call;
      final outbox = sender();
      final drain = outbox.drain();
      await pumpEventQueue();
      await queue(id, const TaskChanges(labels: IdSetChange(added: {10})));
      expect((await db.tasksDao.find(id))!.labels, [urgent]);

      gate.release();
      await pumpEventQueue();

      expect(write.requests, ['create Call back', 'update 100']);
      expect((await db.tasksDao.find(100))!.labels, [urgent]);
      expect(write.serverTasks[100]!.labels, isEmpty);

      gate.release();
      await drain;

      expect(write.serverTasks[100]!.labels, [urgent]);
      expect((await db.tasksDao.find(100))!.labels, [urgent]);
    });

    test('a label the server no longer has is a sync problem under the task '
        'title; discard brings back what the server has', () async {
      await queue(1, const TaskChanges(labels: IdSetChange(added: {11})));
      final outbox = sender();

      await outbox.drain();

      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.kind, OutboxOperationKind.updateTask);
      expect(problem.taskTitle, 'One');
      expect(problem.failure, isA<NotFound>());
      expect(problem.failure.code, 8002);
      expect((await db.tasksDao.find(1))!.labels, [home]);
      expect(write.serverTasks[1]!.labels, isEmpty);

      await outbox.discard(problem.operationId);

      expect(await db.outboxDao.count(), 0);
      final restored = (await db.tasksDao.find(1))!;
      expect(restored.labels, isEmpty);
      expect((await db.tasksDao.findRow(1))!.pendingChanges, isNull);
    });

    for (final failure in <VikunjaFailure>[
      const NotFound(code: 8002),
      const NotFound(code: 1005),
      const Forbidden(code: 7003),
      const Forbidden(),
    ]) {
      test('$failure on a label or assignee change is final and keeps the '
          'task and the change', () async {
        write.beforeRequest = (request) {
          if (request == 'update 1') fail(failure);
          return Future.value();
        };
        await queue(
          1,
          const TaskChanges(
            labels: IdSetChange(added: {10}),
            assignees: IdSetChange(added: {20}),
          ),
        );
        final outbox = sender();

        await outbox.drain();

        final problem = (await db.outboxDao.loadProblems()).single;
        expect(problem.taskId, 1);
        expect(problem.failure.runtimeType, failure.runtimeType);
        expect(problem.failure.code, failure.code);
        expect(timers.active, isEmpty);
        final local = (await db.tasksDao.find(1))!;
        expect(local.labels, [urgent]);
        expect(local.assignees, [ana]);
        expect(await db.outboxDao.count(), 1);
      });
    }
  });
}

/// Calls [onUpdate] with the arguments of every update statement, after it
/// ran.
final class _OnStatement extends QueryInterceptor {
  void Function(List<Object?> args)? onUpdate;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final changed = await super.runUpdate(executor, statement, args);
    onUpdate?.call(args);
    return changed;
  }
}
