import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/posted_at_json.dart';
import 'package:vikunja_mobile/core/outbox/set_aside_upload_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/outbox/upload_json.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 20, 12);
  const done = TaskChanges(done: true);

  setUp(() async {
    db = testDatabase();
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'One', projectId: 7),
      sampleTask(id: 2, title: 'Two', projectId: 7),
    ], syncRunId: 'run');
  });

  Future<String> queueUpload(
    int taskId, {
    String file = '',
    String? name,
  }) async => (await db.outboxDao.queueUpload(
    taskId,
    QueuedUpload(
      file: file.isEmpty ? 'f' * 32 : file,
      fileName: name ?? 'photo.png',
      size: 3,
      mimeType: 'image/png',
    ),
    now: now,
  ))!;

  Future<List<OutboxRow>> ops() => db.outboxDao.all();

  test('an upload is an op of its own with its payload', () async {
    final id = await queueUpload(1);

    final op = (await ops()).single;
    expect(op.id, id);
    expect(op.kind, OutboxOperationKind.uploadAttachment.name);
    expect(op.taskId, 1);
    final upload = decodeQueuedUpload(op.payload);
    expect(upload.file, 'f' * 32);
    expect(upload.fileName, 'photo.png');
    expect(upload.size, 3);
    expect(upload.mimeType, 'image/png');
    expect((await db.tasksDao.findRow(1))!.pendingChanges, isNull);
    expect(await db.outboxDao.loadPendingTaskIds(), {1});
    expect(await db.outboxDao.count(), 1);
  });

  test('no upload for a task that is unknown or queued for deletion', () async {
    expect(
      await db.outboxDao.queueUpload(
        9,
        const QueuedUpload(file: 'x', fileName: 'x', size: 0),
        now: now,
      ),
      isNull,
    );
    await db.outboxDao.queueDelete(2, now: now);
    expect(await db.outboxDao.takesUploads(2), isFalse);
    expect(await db.outboxDao.takesUploads(1), isTrue);
    expect(
      await db.outboxDao.queueUpload(
        2,
        const QueuedUpload(file: 'x', fileName: 'x', size: 0),
        now: now,
      ),
      isNull,
    );
  });

  test('uploads are never merged and stay apart from updates', () async {
    await queueUpload(1);
    await db.outboxDao.queueUpdate(1, done, now: now);
    await queueUpload(1, file: 'e' * 32);
    await db.outboxDao.queueUpdate(1, const TaskChanges(title: 'T'), now: now);

    final kinds = [for (final op in await ops()) op.kind];
    expect(kinds, [
      OutboxOperationKind.uploadAttachment.name,
      OutboxOperationKind.updateTask.name,
      OutboxOperationKind.uploadAttachment.name,
    ]);
    expect(
      await db.outboxDao.pendingChangesFor(1),
      const TaskChanges(done: true, title: 'T'),
    );
  });

  test('the queue head skips uploads, which wait for the task to have a '
      'server id', () async {
    final localId = await db.outboxDao.queueCreate(
      const NewTask(title: 'New', projectId: 7),
      now: now,
    );
    await queueUpload(localId);
    final second = await queueUpload(2);
    await db.outboxDao.queueUpdate(1, done, now: now);

    expect((await db.outboxDao.nextInLine())!.kind, 'createTask');
    expect(
      [for (final op in await db.outboxDao.queuedUploads()) op.id],
      [second],
    );
  });

  test('a failed update with a newer upload stays failed instead of being '
      'dropped', () async {
    await db.outboxDao.queueUpdate(1, const TaskChanges(title: 'T'), now: now);
    final update = (await ops()).single;
    await queueUpload(1);
    await db.outboxDao.claim(update.id, at: now);

    await db.outboxDao.markFailed(update.id, const Forbidden());

    final failed = await db.outboxDao.find(update.id);
    expect(failed!.state, OutboxState.failed.name);
    expect(decodeTaskChanges(failed.payload), const TaskChanges(title: 'T'));
    expect(await ops(), hasLength(2));
  });

  test('a rejected create with an upload behind it keeps both; the upload '
      'waits', () async {
    final localId = await db.outboxDao.queueCreate(
      const NewTask(title: 'New', projectId: 7),
      now: now,
    );
    final create = (await ops()).single;
    await db.outboxDao.claim(create.id, at: now);
    await queueUpload(localId);

    await db.outboxDao.markFailed(
      create.id,
      const DomainError(400, code: 4001),
    );

    final rows = await ops();
    expect(rows.first.state, OutboxState.failed.name);
    expect(decodeNewTask(rows.first.payload).title, 'New');
    expect(rows.last.kind, OutboxOperationKind.uploadAttachment.name);
    expect(rows.last.state, OutboxState.pending.name);
    expect(await db.outboxDao.queuedUploads(), isEmpty);
  });

  test('clearing the backoffs of the queue alone leaves the uploads '
      'theirs', () async {
    final upload = await queueUpload(1);
    await db.outboxDao.queueUpdate(2, done, now: now);
    final update = (await ops()).last.id;
    final later = now.add(const Duration(minutes: 1));
    for (final id in [upload, update]) {
      await db.outboxDao.scheduleRetry(
        id,
        attempts: 1,
        failure: const ServerFailure(503),
        nextAttemptAt: later,
      );
    }

    expect(await db.outboxDao.clearBackoff(uploads: false), 1);

    expect((await db.outboxDao.find(update))!.nextAttemptAt, isNull);
    expect((await db.outboxDao.find(upload))!.nextAttemptAt, later);
    expect(await db.outboxDao.clearBackoff(), 1);
    expect((await db.outboxDao.find(upload))!.nextAttemptAt, isNull);
  });

  test('a failed upload is just marked failed, its sent_at cleared', () async {
    final id = await queueUpload(1);
    await db.outboxDao.markUncertain(id, sentAt: now);

    await db.outboxDao.markFailed(id, const FileTooLarge(code: 4012));

    final op = (await db.outboxDao.find(id))!;
    expect(op.state, OutboxState.failed.name);
    expect(op.sentAt, isNull);
    final problem = (await db.outboxDao.loadProblems()).single;
    expect(problem.kind, OutboxOperationKind.uploadAttachment);
    expect(problem.fileName, 'photo.png');
    expect(problem.taskTitle, 'One');
    expect(problem.changes, isNull);
    expect(problem.failure, isA<FileTooLarge>());
  });

  test('an upload keeps the time its request last left the device through a '
      'failure, and reads as before; an update is left alone', () async {
    final id = await queueUpload(1);
    await db.outboxDao.markPosted(id, at: now);
    await db.outboxDao.markUncertain(id, sentAt: now);

    await db.outboxDao.markFailed(
      id,
      const NetworkFailure(NetworkProblem.timeout),
    );

    final op = (await db.outboxDao.find(id))!;
    expect(op.state, OutboxState.failed.name);
    expect(op.sentAt, now);
    expect(postedAtOf(op.payload), now);
    final upload = decodeQueuedUpload(op.payload);
    expect(upload.file, 'f' * 32);
    expect(upload.fileName, 'photo.png');
    expect(upload.size, 3);
    expect(upload.mimeType, 'image/png');

    await db.outboxDao.queueUpdate(2, done, now: now);
    final update = (await ops()).last;
    await db.outboxDao.markPosted(update.id, at: now);
    expect((await db.outboxDao.find(update.id))!.payload, update.payload);
  });

  test('a delete keeps the uploads, which wait while it is queued and go on '
      'once it was taken back', () async {
    final sending = await queueUpload(1, file: 'a' * 32);
    final waiting = await queueUpload(1, file: 'b' * 32);
    final failed = await queueUpload(1, file: 'c' * 32);
    final other = await queueUpload(2, file: 'd' * 32);
    await db.outboxDao.claim(sending, at: now);
    await db.outboxDao.markFailed(failed, const Forbidden());

    await db.outboxDao.queueDelete(1, now: now);

    final kinds = [for (final op in await ops()) (op.kind, op.state)];
    expect(kinds, [
      (OutboxOperationKind.uploadAttachment.name, OutboxState.sending.name),
      (OutboxOperationKind.uploadAttachment.name, OutboxState.pending.name),
      (OutboxOperationKind.uploadAttachment.name, OutboxState.failed.name),
      (OutboxOperationKind.uploadAttachment.name, OutboxState.pending.name),
      (OutboxOperationKind.deleteTask.name, OutboxState.pending.name),
    ]);
    expect(
      [for (final op in await db.outboxDao.queuedUploads()) op.id],
      [other],
    );
    expect(await db.outboxDao.uploadFiles(), {
      'a' * 32,
      'b' * 32,
      'c' * 32,
      'd' * 32,
    });
    expect(await db.outboxDao.watchPendingUploads(1).first, hasLength(3));

    await db.outboxDao.unqueueDelete(1);

    expect(
      [for (final op in await db.outboxDao.queuedUploads()) op.id],
      [sending, waiting, other],
    );
  });

  test('cancelling a create drops its uploads', () async {
    final failedCreate = await db.outboxDao.queueCreate(
      const NewTask(title: 'Refused', projectId: 7),
      now: now,
    );
    await queueUpload(failedCreate, file: 'a' * 32);
    final refused = (await ops()).first;
    await db.outboxDao.claim(refused.id, at: now);
    await db.outboxDao.markFailed(
      refused.id,
      const DomainError(400, code: 4001),
    );
    final neverSent = await db.outboxDao.queueCreate(
      const NewTask(title: 'New', projectId: 7),
      now: now,
    );
    await queueUpload(neverSent, file: 'b' * 32);

    await db.outboxDao.queueDelete(failedCreate, now: now);

    expect(await db.outboxDao.uploadFiles(), {'b' * 32});

    await db.outboxDao.queueDelete(neverSent, now: now);
    final create = (await ops()).firstWhere((op) => op.taskId == neverSent);
    await db.outboxDao.claim(create.id, at: now);
    await db.outboxDao.cancelDeletedCreate(create.id);

    expect(await ops(), isEmpty);
    expect(await db.outboxDao.uploadFiles(), isEmpty);
  });

  test('a remap moves the uploads to the server id', () async {
    final localId = await db.outboxDao.queueCreate(
      const NewTask(title: 'New', projectId: 7),
      now: now,
    );
    await queueUpload(localId);
    final create = (await ops()).first;
    final pending = db.outboxDao.watchPendingUploads(localId);
    final seen = <List<PendingUpload>>[];
    final subscription = pending.listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await db.outboxDao.completeCreate(
      create.id,
      sampleTask(id: 50, title: 'New', projectId: 7),
      at: now,
    );
    await pumpEventQueue();

    expect((await ops()).single.taskId, 50);
    expect((await db.outboxDao.queuedUploads()).single.taskId, 50);
    expect(seen.first.single.taskId, localId);
    expect(seen.last.single.taskId, 50);
  });

  test(
    'pending uploads say waiting, sending or failed with the reason',
    () async {
      final waiting = await queueUpload(1, file: 'a' * 32, name: 'a.txt');
      final sending = await queueUpload(1, file: 'b' * 32, name: 'b.txt');
      final failed = await queueUpload(1, file: 'c' * 32, name: 'c.txt');
      await queueUpload(2, file: 'd' * 32);
      await db.outboxDao.scheduleRetry(
        waiting,
        attempts: 1,
        failure: const NetworkFailure(NetworkProblem.unreachable),
        nextAttemptAt: now.add(const Duration(seconds: 2)),
      );
      await db.outboxDao.claim(sending, at: now);
      await db.outboxDao.markFailed(failed, const Forbidden());

      final uploads = await db.outboxDao.watchPendingUploads(1).first;

      expect(uploads.map((upload) => upload.fileName), [
        'a.txt',
        'b.txt',
        'c.txt',
      ]);
      expect(uploads.map((upload) => upload.state), [
        PendingUploadState.waiting,
        PendingUploadState.sending,
        PendingUploadState.failed,
      ]);
      expect(uploads.first.lastFailure, isA<NetworkFailure>());
      expect(uploads.last.lastFailure, isA<Forbidden>());
      expect(uploads.first.size, 3);
      expect(uploads.first.queuedAt, now);
    },
  );

  test('removing an upload answers its stored copy once', () async {
    final id = await queueUpload(1);
    await db.outboxDao.queueUpdate(1, done, now: now);
    final update = (await ops()).last;

    expect(await db.outboxDao.removeUpload(id), 'f' * 32);
    expect(await db.outboxDao.removeUpload(id), isNull);
    expect(await db.outboxDao.removeUpload(update.id), isNull);
    expect(await ops(), hasLength(1));
  });

  group('set aside for an Undo', () {
    const undo = Duration(seconds: 15);

    /// What the sender does once the server made the delete of [taskId].
    Future<int> applyDelete(int taskId, {DateTime? at, Duration? keep}) =>
        db.transaction(() async {
          final time = at ?? now;
          final setAside = await db.outboxDao.setAsideUploadsOf(
            taskId,
            until: time.add(keep ?? undo),
            now: time,
          );
          await db.outboxDao.removeAllOf(taskId);
          await db.tasksDao.deleteRow(taskId);
          return setAside;
        });

    Future<List<SetAsideUpload>> setAside() async => decodeSetAsideUploads(
      (await db.syncStateDao.readAll())[OutboxDao.setAsideUploadsKey],
    );

    test('uploads set aside for an Undo leave the queue as they were, their '
        'copies still named; one on its way is kept pending, marked as '
        'maybe on the server', () async {
      final sending = await queueUpload(1, file: 'a' * 32);
      final waiting = await queueUpload(1, file: 'b' * 32);
      final failed = await queueUpload(1, file: 'c' * 32);
      final attempt = now.subtract(const Duration(seconds: 3));
      await db.outboxDao.claim(sending, at: attempt);
      await db.outboxDao.markPosted(sending, at: attempt, attachmentsBefore: 0);
      await db.outboxDao.markFailed(failed, const Forbidden());
      await db.outboxDao.queueDelete(1, now: now);
      final before = {for (final op in await ops()) op.id: op};

      expect(await applyDelete(1), 3);

      expect(await db.outboxDao.count(), 0);
      expect(await db.outboxDao.countWithSetAside(), 3);
      expect(await db.outboxDao.loadPendingTaskIds(), isEmpty);
      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(await db.outboxDao.queuedUploads(), isEmpty);
      expect(await db.outboxDao.uploadFiles(), {'a' * 32, 'b' * 32, 'c' * 32});
      final entries = await setAside();
      expect(
        [for (final entry in entries) entry.op.id],
        [sending, waiting, failed],
      );
      expect(entries.map((entry) => entry.until), everyElement(now.add(undo)));
      expect(entries[0].op.state, OutboxState.pending.name);
      expect(entries[0].op.sentAt, attempt);
      expect(entries[0].op.lastAttemptAt, attempt);
      expect(entries[1].op, before[waiting]!.copyWith(sequence: 0));
      expect(entries[2].op.state, OutboxState.failed.name);
      expect(entries[2].op.lastError, before[failed]!.lastError);

      // The upload on its way fails or is put back: nothing is written.
      await db.outboxDao.markUncertain(sending, sentAt: now);
      await db.outboxDao.scheduleRetry(
        sending,
        attempts: 1,
        failure: const ServerFailure(503),
        nextAttemptAt: now,
      );
      await db.outboxDao.markFailed(sending, const Forbidden());
      await db.outboxDao.unclaim(sending);
      await db.outboxDao.markPosted(sending, at: now);
      expect(await ops(), isEmpty);
      expect((await setAside()).first.op, entries.first.op);
    });

    test('set-aside uploads go back to the queue behind what was queued '
        'since, under new ids and otherwise as they were; a failed one is a '
        'sync problem again', () async {
      final retried = await queueUpload(1, file: 'a' * 32, name: 'a.png');
      final refused = await queueUpload(1, file: 'b' * 32, name: 'b.png');
      await db.outboxDao.claim(retried, at: now);
      await db.outboxDao.markPosted(retried, at: now);
      await db.outboxDao.markUncertain(retried, sentAt: now);
      await db.outboxDao.scheduleRetry(
        retried,
        attempts: 2,
        failure: const ServerFailure(502),
        nextAttemptAt: now.add(const Duration(seconds: 4)),
      );
      await db.outboxDao.markFailed(refused, const Forbidden());
      await db.outboxDao.queueDelete(1, now: now);
      final before = [
        for (final op in await ops())
          if (op.kind == OutboxOperationKind.uploadAttachment.name) op,
      ];
      await applyDelete(1);
      await db.outboxDao.queueUpdate(2, done, now: now);
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'One', projectId: 7),
      ]);

      expect(await db.outboxDao.requeueSetAsideUploads(1), 2);

      final after = await ops();
      expect(after.map((op) => op.kind), [
        OutboxOperationKind.updateTask.name,
        OutboxOperationKind.uploadAttachment.name,
        OutboxOperationKind.uploadAttachment.name,
      ]);
      expect(after[1].sequence, greaterThan(after[0].sequence));
      expect(after[2].sequence, greaterThan(after[1].sequence));
      for (final (index, op) in after.skip(1).indexed) {
        final old = before[index];
        expect(op.id, isNot(old.id));
        expect(op.copyWith(id: old.id, sequence: old.sequence), old);
      }
      expect(after[1].attempts, 2);
      expect(after[1].nextAttemptAt, now.add(const Duration(seconds: 4)));
      expect(decodeFailure(after[1].lastError!), isA<ServerFailure>());
      expect(after[1].sentAt, now);
      expect(postedAtOf(after[1].payload), now);
      expect(
        [for (final op in await db.outboxDao.queuedUploads()) op.id],
        [after[1].id],
      );
      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.operationId, after[2].id);
      expect(problem.fileName, 'b.png');
      expect(problem.failure, isA<Forbidden>());
      expect(await setAside(), isEmpty);
      expect(await db.outboxDao.requeueSetAsideUploads(1), 0);
    });

    test('set-aside uploads are forgotten once their time is over, and so is '
        'one kept further ahead than any hold, and every one when all go; '
        'the next one due is answered', () async {
      await db.tasksDao.upsertAll([
        sampleTask(id: 3, title: 'Three', projectId: 7),
      ]);
      await queueUpload(1, file: 'a' * 32);
      await queueUpload(2, file: 'b' * 32);
      await queueUpload(3, file: 'c' * 32);
      const hold = Duration(minutes: 5);
      await applyDelete(1, keep: const Duration(seconds: 10));
      await applyDelete(2, keep: const Duration(seconds: 20));

      expect(
        await db.outboxDao.dropSetAsideUploads(now: now, latest: now.add(hold)),
        now.add(const Duration(seconds: 10)),
      );
      expect(await db.outboxDao.uploadFiles(), {'a' * 32, 'b' * 32, 'c' * 32});

      final later = now.add(const Duration(seconds: 10));
      expect(
        await db.outboxDao.dropSetAsideUploads(
          now: later,
          latest: later.add(hold),
        ),
        now.add(const Duration(seconds: 20)),
      );
      expect(await db.outboxDao.uploadFiles(), {'b' * 32, 'c' * 32});

      // Set aside before the clock was set back by an hour.
      await applyDelete(3, at: now.add(const Duration(hours: 1)));
      expect(
        await db.outboxDao.dropSetAsideUploads(
          now: later,
          latest: later.add(hold),
        ),
        now.add(const Duration(seconds: 20)),
      );
      expect(await db.outboxDao.uploadFiles(), {'b' * 32});

      expect(
        await db.outboxDao.dropSetAsideUploads(
          now: now,
          latest: now.add(hold),
          all: true,
        ),
        isNull,
      );
      expect(await db.outboxDao.uploadFiles(), isEmpty);
      expect(
        await db.syncStateDao.readAll(),
        isNot(contains(OutboxDao.setAsideUploadsKey)),
      );
      expect(
        await db.outboxDao.dropSetAsideUploads(now: now, latest: now),
        isNull,
      );
    });

    test('a hold keeps set-aside uploads past their time', () async {
      await queueUpload(1, file: 'a' * 32);
      await queueUpload(2, file: 'b' * 32);
      await applyDelete(1);
      await applyDelete(2);
      const hold = Duration(minutes: 5);
      final before = await db.syncStateDao.readAll();

      await db.outboxDao.holdSetAsideUploads(9, until: now.add(hold));
      expect(await db.syncStateDao.readAll(), before);
      await db.outboxDao.holdSetAsideUploads(1, until: now.add(hold));

      final later = now.add(undo + const Duration(seconds: 1));
      expect(
        await db.outboxDao.dropSetAsideUploads(
          now: later,
          latest: later.add(hold),
        ),
        now.add(hold),
      );
      expect(await db.outboxDao.uploadFiles(), {'a' * 32});
      expect(await db.outboxDao.requeueSetAsideUploads(1), 1);
    });

    test('set-aside uploads of a kept task stay past their time, past any '
        'hold and when all go, and are not due', () async {
      await db.tasksDao.upsertAll([
        sampleTask(id: 3, title: 'Three', projectId: 7),
      ]);
      await queueUpload(1, file: 'a' * 32);
      await queueUpload(2, file: 'b' * 32);
      await queueUpload(3, file: 'c' * 32);
      await applyDelete(1);
      await applyDelete(2, keep: const Duration(seconds: 20));
      // Before the clock was set back by an hour.
      await applyDelete(3, at: now.add(const Duration(hours: 1)));
      const hold = Duration(minutes: 5);

      expect(
        await db.outboxDao.dropSetAsideUploads(
          now: now,
          latest: now.add(hold),
          keep: {1, 3, 9},
        ),
        now.add(const Duration(seconds: 20)),
      );
      expect(await db.outboxDao.uploadFiles(), {'a' * 32, 'b' * 32, 'c' * 32});

      final later = now.add(const Duration(hours: 2));
      expect(
        await db.outboxDao.dropSetAsideUploads(
          now: later,
          latest: later.add(hold),
          keep: {1, 3},
        ),
        isNull,
      );
      expect(await db.outboxDao.uploadFiles(), {'a' * 32, 'c' * 32});
      expect(
        await db.outboxDao.dropSetAsideUploads(
          now: now,
          latest: now.add(hold),
          all: true,
          keep: {1},
        ),
        isNull,
      );
      expect(await db.outboxDao.uploadFiles(), {'a' * 32});

      expect(
        await db.outboxDao.dropSetAsideUploads(
          now: later,
          latest: later.add(hold),
        ),
        isNull,
      );
      expect(await db.outboxDao.uploadFiles(), isEmpty);
    });

    test('removing an upload that was set aside while on its way answers its '
        'copy once and keeps it from going back', () async {
      final id = await queueUpload(1, file: 'a' * 32);
      await queueUpload(1, file: 'b' * 32);
      await db.outboxDao.claim(id, at: now);
      await applyDelete(1);

      expect(await db.outboxDao.removeUpload(id), 'a' * 32);
      expect(await db.outboxDao.removeUpload(id), isNull);

      expect(await db.outboxDao.uploadFiles(), {'b' * 32});
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'One', projectId: 7),
      ]);
      expect(await db.outboxDao.requeueSetAsideUploads(1), 1);
      expect(decodeQueuedUpload((await ops()).single.payload).file, 'b' * 32);
    });
  });

  test('a stuck upload goes back marked uncertain, unless the caller still '
      'streams it', () async {
    final stuck = await queueUpload(1, file: 'a' * 32);
    final streaming = await queueUpload(1, file: 'b' * 32);
    await db.outboxDao.claim(stuck, at: now);
    await db.outboxDao.markPosted(stuck, at: now, attachmentsBefore: 0);
    await db.outboxDao.claim(streaming, at: now);

    await db.outboxDao.resetSending(
      now: now.add(const Duration(minutes: 6)),
      olderThan: const Duration(minutes: 5),
      keep: {streaming},
    );

    final reset = (await db.outboxDao.find(stuck))!;
    expect(reset.state, OutboxState.pending.name);
    expect(reset.sentAt, now);
    final kept = (await db.outboxDao.find(streaming))!;
    expect(kept.state, OutboxState.sending.name);
    expect(kept.sentAt, isNull);
  });

  test(
    'an upload claimed but stopped before its request goes back pending, '
    'not marked uncertain, even with a request from an earlier attempt',
    () async {
      final unposted = await queueUpload(1, file: 'a' * 32);
      final retried = await queueUpload(1, file: 'b' * 32);
      await db.outboxDao.claim(unposted, at: now);
      await db.outboxDao.markPosted(retried, at: now, attachmentsBefore: 0);
      await db.outboxDao.claim(
        retried,
        at: now.add(const Duration(seconds: 1)),
      );

      await db.outboxDao.resetSending(now: now.add(const Duration(minutes: 6)));

      for (final id in [unposted, retried]) {
        final reset = (await db.outboxDao.find(id))!;
        expect(reset.state, OutboxState.pending.name);
        expect(reset.sentAt, isNull);
      }
    },
  );

  test('an upload set aside for an Undo before its request goes back '
      'pending, not marked uncertain', () async {
    final id = await queueUpload(1, file: 'a' * 32);
    await db.outboxDao.claim(id, at: now);

    await db.transaction(() async {
      await db.outboxDao.setAsideUploadsOf(
        1,
        until: now.add(const Duration(seconds: 15)),
        now: now,
      );
      await db.outboxDao.removeAllOf(1);
    });

    final op = decodeSetAsideUploads(
      (await db.syncStateDao.readAll())[OutboxDao.setAsideUploadsKey],
    ).single.op;
    expect(op.state, OutboxState.pending.name);
    expect(op.sentAt, isNull);
  });
}
