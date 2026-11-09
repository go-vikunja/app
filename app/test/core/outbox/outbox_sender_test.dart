import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
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
    read = FakeSyncClient()
      ..allProjects = [sampleProject(id: 7, title: 'Work')]
      ..allTasks = tasks;
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
      expect(read.requests, isEmpty);
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

  group('creates', () {
    const draft = NewTask(
      projectId: 7,
      title: 'Buy milk',
      priority: TaskPriority.high,
      isFavorite: true,
    );

    Future<int> create([NewTask task = draft]) =>
        db.outboxDao.queueCreate(task, now: now);

    /// The server as the sync engine reads it: what the write client holds.
    void mirrorServer() => read.allTasks = write.serverTasks.values.toList();

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
      expect(sync.refreshCalls, 1);
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

    test('a create whose answer was lost is recovered by its title instead '
        'of being sent twice', () async {
      final id = await create();
      write.afterRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.timeout));
      final outbox = sender();

      await outbox.drain();

      expect(outbox.state, OutboxSenderState.waiting);
      final op = (await ops()).single;
      expect(op.state, OutboxState.pending.name);
      expect(op.sentAt, now);
      expect(op.attempts, 1);
      expect(write.serverTasks[100]!.title, 'Buy milk');
      expect((await db.tasksDao.find(id))!.title, 'Buy milk');

      // The server has it; the next attempt looks before it sends.
      mirrorServer();
      write.afterRequest = null;
      now = now.add(timers.pendingWait);
      timers.fireNext();
      await pumpEventQueue();

      expect(write.requests, ['create Buy milk']);
      expect(
        read.requests.single,
        startsWith(
          "project 7 tasks created >= '2026-10-10T11:00:00Z' sort=created desc",
        ),
      );
      expect(await db.tasksDao.findRow(id), isNull);
      expect((await db.tasksDao.find(100))!.title, 'Buy milk');
      expect(await db.tasksDao.resolveId(id), 100);
      expect(await db.outboxDao.count(), 0);
      expect(outbox.state, OutboxSenderState.idle);
    });

    test('a lost create whose title had a U+0000 is adopted under the title '
        'the server stored, not sent again', () async {
      final id = await create(
        const NewTask(projectId: 7, title: 'Buy\u0000 milk'),
      );
      write.afterRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.timeout));
      final outbox = sender();
      await outbox.drain();
      // The transport leaves the NUL out, so the server stores the title
      // without it.
      write.serverTasks[100] = write.serverTasks[100]!.copyWith(
        title: 'Buy milk',
      );
      mirrorServer();

      write.afterRequest = null;
      await outbox.sendNow();

      expect(write.requests, ['create Buy\u0000 milk']);
      expect(read.requests, hasLength(1));
      expect(await db.tasksDao.resolveId(id), 100);
      expect((await db.tasksDao.find(100))!.title, 'Buy milk');
      expect(await db.outboxDao.count(), 0);
    });

    test('the lookup matches the title as sent, not the newer one, and '
        'ignores other tasks created meanwhile', () async {
      final id = await create();
      write.afterRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.unreachable));
      final outbox = sender();
      await outbox.drain();
      await queue(id, const TaskChanges(title: 'Buy oat milk'));
      read.allTasks = [
        ...tasks,
        sampleTask(
          id: 99,
          title: 'Something else',
          projectId: 7,
        ).copyWith(created: now),
        write.serverTasks[100]!,
      ];

      write.afterRequest = null;
      await outbox.sendNow();

      expect(write.requests, ['create Buy milk', 'update 100']);
      expect(write.updates, [(100, const TaskChanges(title: 'Buy oat milk'))]);
      expect(write.serverTasks[100]!.title, 'Buy oat milk');
      expect((await db.tasksDao.find(100))!.title, 'Buy oat milk');
      expect(await db.outboxDao.count(), 0);
    });

    test(
      'an unanswered create the server does not have is sent again',
      () async {
        final id = await create();
        write.beforeRequest = (_) =>
            fail(const NetworkFailure(NetworkProblem.timeout));
        final outbox = sender();
        await outbox.drain();
        expect((await ops()).single.sentAt, now);
        expect(write.serverTasks.containsKey(100), isFalse);

        write.beforeRequest = null;
        await outbox.sendNow();

        expect(write.requests, ['create Buy milk', 'create Buy milk']);
        expect(read.requests, hasLength(1));
        expect(await db.tasksDao.resolveId(id), 100);
        expect(await db.outboxDao.count(), 0);
      },
    );

    test('a 5xx may have come from a proxy after the server stored the '
        'task: the next attempt looks first', () async {
      await create();
      write.afterRequest = (_) => fail(const ServerFailure(504));
      final outbox = sender();
      await outbox.drain();
      expect((await ops()).single.sentAt, now);
      mirrorServer();

      write.afterRequest = null;
      await outbox.sendNow();

      expect(write.requests, ['create Buy milk']);
      expect(await db.outboxDao.count(), 0);
    });

    test('a lookup that cannot reach the server leaves the create uncertain '
        'and waiting', () async {
      await create();
      write.afterRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.timeout));
      final outbox = sender();
      await outbox.drain();
      read.beforeRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.unreachable));

      await outbox.sendNow();

      expect(write.requests, ['create Buy milk']);
      final op = (await ops()).single;
      expect(op.sentAt, now);
      expect(op.attempts, 2);
      expect(outbox.state, OutboxSenderState.waiting);
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

        expect(read.requests, isEmpty);
        expect(write.requests, ['create Buy milk', 'create Buy milk']);
      },
    );

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

      await outbox.discard(problem.operationId);

      expect(read.requests, isEmpty);
      expect(await db.tasksDao.findRow(id), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('a create and its delete before the send cost no request', () async {
      final id = await create();
      await queueDelete(id);

      await sender().drain();

      expect(write.requests, isEmpty);
      expect(sync.refreshCalls, 0);
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

    test('a create a killed app left in flight is looked up at the next start '
        'and adopted, not sent again', () async {
      final id = await create();
      final op = (await ops()).single;
      await db.outboxDao.markSending(op.id, at: now);
      now = now.add(OutboxSender.staleSendingAfter);
      // The request had reached the server before the kill.
      write.serverTasks[100] = taskFromNewTask(draft, id: 100, now: now);
      write.nextId = 101;
      mirrorServer();

      await sender().drain();

      expect(write.requests, isEmpty);
      expect(
        read.requests.single,
        startsWith("project 7 tasks created >= '2026-10-10T11:00:00Z'"),
      );
      expect(await db.tasksDao.findRow(id), isNull);
      expect((await db.tasksDao.find(100))!.title, 'Buy milk');
      expect(await db.tasksDao.resolveId(id), 100);
      expect(await db.outboxDao.count(), 0);
    });

    test('a create a killed app left in flight that never reached the server '
        'is sent once', () async {
      final id = await create();
      final op = (await ops()).single;
      await db.outboxDao.markSending(op.id, at: now);
      now = now.add(OutboxSender.staleSendingAfter);

      await sender().drain();

      expect(read.requests, hasLength(1));
      expect(write.requests, ['create Buy milk']);
      expect(await db.tasksDao.resolveId(id), 100);
      expect(await db.outboxDao.count(), 0);
    });

    test('a server clock minutes behind the phone still lands the stored '
        'task in the lookup window', () async {
      write = FakeWriteClient(
        clock: () => now.subtract(const Duration(minutes: 3)),
      );
      final id = await create();
      write.afterRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.timeout));
      final outbox = sender();
      await outbox.drain();
      expect(
        write.serverTasks[100]!.created,
        now.subtract(const Duration(minutes: 3)),
      );
      mirrorServer();

      write.afterRequest = null;
      await outbox.sendNow();

      expect(write.requests, ['create Buy milk']);
      expect(await db.tasksDao.resolveId(id), 100);
      expect(await db.outboxDao.count(), 0);
    });

    test('two lost creates with the same title adopt two different server '
        'tasks', () async {
      const callBack = NewTask(projectId: 7, title: 'Call back');
      final first = await create(callBack);
      final second = await create(callBack);
      write.afterRequest = (_) =>
          fail(const NetworkFailure(NetworkProblem.timeout));
      final outbox = sender();
      // The first reaches the server (100), its answer is lost.
      await outbox.drain();
      mirrorServer();
      // The first is adopted; the second reaches the server (101) in the
      // same second, its answer is lost too.
      await outbox.sendNow();
      expect(await db.tasksDao.resolveId(first), 100);
      expect(write.serverTasks[101]!.created, write.serverTasks[100]!.created);
      mirrorServer();

      write.afterRequest = null;
      await outbox.sendNow();

      expect(write.requests, ['create Call back', 'create Call back']);
      expect(await db.tasksDao.resolveId(second), 101);
      expect(await db.tasksDao.findRow(first), isNull);
      expect(await db.tasksDao.findRow(second), isNull);
      expect(await db.outboxDao.count(), 0);
    });

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
