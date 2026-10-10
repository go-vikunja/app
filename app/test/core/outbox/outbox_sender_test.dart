import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
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

  OutboxSender sender({DateTime Function()? clock}) {
    final sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: sync,
      now: clock ?? () => now,
      createTimer: timers.create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    return sender;
  }

  Future<void> queue(int id, TaskChanges changes) async {
    expect(await db.outboxDao.queueUpdate(id, changes, now: now), isTrue);
  }

  Future<void> queueDelete(int id) async {
    expect(await db.outboxDao.queueDelete(id, now: now), isTrue);
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
    read = FakeSyncClient()..allTasks = tasks;
    sync = RecordingSyncEngine();
    timers = FakeTimers();
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
    write.serverTasks.addEntries(tasks.map((t) => MapEntry(t.id, t)));
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
        expect(sync.refreshCalls, 1);
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
      expect(sync.refreshCalls, 1);
    });

    test('a task the server already deleted counts as deleted', () async {
      await queueDelete(2);
      write.beforeRequest = (_) => fail(const NotFound(code: 4002));

      await sender().drain();

      expect(await db.tasksDao.findRow(2), isNull);
      expect(await db.outboxDao.count(), 0);
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

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
      expect(sync.refreshCalls, 1);
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
        expect(sync.refreshCalls, 1);

        await queue(2, done);
        final second = outbox.drain();
        sync.gate!.complete();
        sync.gate = null;
        await first;
        await second;

        expect(write.requests, ['update 1', 'update 2']);
        expect(sync.refreshCalls, 2);
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
        're-sent on the spot, and goes again at the next start', () async {
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

      // At least once: the server stored it twice.
      expect(write.updates, [(1, done), (1, done)]);
      expect(await db.outboxDao.count(), 0);
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

    test('ops a killed app left in flight are sent again', () async {
      await queue(1, done);
      await db.outboxDao.markSending((await ops()).single.id, at: now);

      await sender().drain();

      expect(write.updates, [(1, done)]);
      expect(await db.outboxDao.count(), 0);
    });

    test('nothing to send means no refresh', () async {
      await sender().drain();

      expect(sync.refreshCalls, 0);
      expect(write.requests, isEmpty);
    });

    test('a failed refresh does not fail the drain', () async {
      await queue(1, done);
      sync.error = const NetworkFailure(NetworkProblem.unreachable);

      await sender().drain();

      expect(await db.outboxDao.count(), 0);
      expect(sync.refreshCalls, 1);
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
      expect(sync.refreshCalls, 0);
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
      expect(sync.refreshCalls, 1);
      expect(states.last, OutboxSenderState.idle);
      expect(timers.active, isEmpty);
    });

    test('the backoff tops out at 15 minutes', () async {
      write.beforeRequest = (_) => fail(const ServerFailure(503));
      await queue(1, done);
      final op = (await ops()).single;
      await db.outboxDao.scheduleRetry(
        op.id,
        attempts: 20,
        failure: const ServerFailure(503),
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
      const UnexpectedResponse(200, message: 'captive portal'),
      const UnexpectedResponse(302),
      const UnexpectedResponse(null, message: 'empty body'),
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

  group('problems', () {
    for (final failure in <VikunjaFailure>[
      const NotFound(code: 3001),
      const NotFound(code: 4002),
      const Forbidden(code: 7003),
      const DomainError(412, code: 3008),
      const ValidationFailed(
        fieldErrors: {
          'title': ['empty'],
        },
      ),
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
        expect(sync.refreshCalls, 1);
        // The local edit stays until the user decides.
        expect((await db.tasksDao.find(1))!.done, isTrue);
      });
    }

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
}
