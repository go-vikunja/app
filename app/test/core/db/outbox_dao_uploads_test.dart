import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
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

  test('a stuck upload goes back marked uncertain, unless the caller still '
      'streams it', () async {
    final stuck = await queueUpload(1, file: 'a' * 32);
    final streaming = await queueUpload(1, file: 'b' * 32);
    await db.outboxDao.claim(stuck, at: now);
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
}
