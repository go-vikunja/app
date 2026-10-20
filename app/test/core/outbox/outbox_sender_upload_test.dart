import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/upload_json.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

void main() {
  late AppDatabase db;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late RecordingSyncEngine sync;
  late FakeTimers timers;
  late DateTime now;
  late Directory root;
  late UploadFiles uploads;
  const me = User(id: 42, username: 'me');
  final tasks = [
    sampleTask(id: 1, title: 'One', projectId: 7),
    sampleTask(id: 2, title: 'Two', projectId: 7),
  ];

  OutboxSender sender({
    bool headless = false,
    UploadFiles? files,
    int? maxUploadBytes,
  }) {
    final sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: sync,
      now: () => now,
      createTimer: timers.create,
      random: ZeroRandom(),
      uploads: files ?? uploads,
      headless: headless,
      currentUserId: () => me.id,
      maxUploadBytes: () => maxUploadBytes,
    );
    addTearDown(sender.dispose);
    return sender;
  }

  /// Stores [bytes] as a picked file would be and queues its upload.
  Future<String> queueUpload(
    int taskId, {
    String name = 'photo.png',
    List<int> bytes = const [1, 2, 3],
  }) async {
    final source = File(p.join(root.path, 'picked-${bytes.length}'))
      ..writeAsBytesSync(bytes);
    final stored = await uploads.store(source);
    uploads.release(stored.name);
    final id = await db.outboxDao.queueUpload(
      taskId,
      QueuedUpload(
        file: stored.name,
        fileName: name,
        size: stored.size,
        mimeType: 'image/png',
      ),
      now: now,
    );
    return id!;
  }

  Future<List<String>> storedCopies() async {
    final directory = Directory(p.join(root.path, 'uploads'));
    if (!directory.existsSync()) return const [];
    return [for (final entry in directory.listSync()) p.basename(entry.path)];
  }

  setUp(() async {
    db = testDatabase();
    now = DateTime.utc(2026, 10, 20, 12);
    root = Directory.systemTemp.createTempSync('uploads_test');
    addTearDown(() => root.deleteSync(recursive: true));
    uploads = UploadFiles(() async => Directory(p.join(root.path, 'uploads')));
    write = FakeWriteClient(clock: () => now)..uploader = me;
    read = FakeSyncClient()
      ..allProjects = [sampleProject(id: 7, title: 'Work')]
      ..allTasks = tasks;
    sync = RecordingSyncEngine();
    timers = FakeTimers();
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
    write.serverTasks.addEntries(tasks.map((t) => MapEntry(t.id, t)));
  });

  group('uploads', () {
    test('one request per file with timeouts for its size; the stored copy '
        'goes and the attachment is reported', () async {
      await queueUpload(1, bytes: List.filled(10, 7));
      await queueUpload(1, name: 'b.txt', bytes: const [9]);
      final outbox = sender();
      final uploaded = <TaskAttachment>[];
      final subscription = outbox.uploadedAttachments.listen(uploaded.add);
      addTearDown(subscription.cancel);

      await outbox.drain();

      expect(write.requests, ['upload 1 photo.png', 'upload 1 b.txt']);
      expect(write.uploadTimeouts, [uploadTimeoutFor(10), uploadTimeoutFor(1)]);
      expect(write.serverAttachments[1]!.map((a) => a.size), [10, 1]);
      expect(write.uploadedBytes[300], List.filled(10, 7));
      expect(await db.outboxDao.count(), 0);
      expect(await storedCopies(), isEmpty);
      await pumpEventQueue();
      expect(uploaded.map((a) => a.name), ['photo.png', 'b.txt']);
      expect(sync.refreshCalls, 0, reason: 'an upload changes no task');
    });

    test('an upload never holds up an edit queued after it', () async {
      await queueUpload(1);
      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(done: true),
        now: now,
      );

      await sender().drain();

      expect(write.requests, ['update 2', 'upload 1 photo.png']);
    });

    test('an edit queued while an upload is on its way goes at once', () async {
      await queueUpload(1);
      final held = Completer<void>();
      write.beforeRequest = (request) async {
        if (request.startsWith('upload')) await held.future;
      };
      final outbox = sender();
      final drained = outbox.drain();
      await pumpEventQueue();
      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(isFavorite: true),
        now: now,
      );
      unawaited(outbox.drain());
      await pumpEventQueue();

      expect(write.requests, ['upload 1 photo.png', 'update 2']);
      expect(await db.outboxDao.count(), 1, reason: 'only the upload is left');
      expect(outbox.state, OutboxSenderState.draining);

      held.complete();
      await drained;
      expect(await db.outboxDao.count(), 0);
      expect(outbox.state, OutboxSenderState.idle);
    });

    test('a drain while an upload is on its way past the stuck-op age leaves '
        'it alone', () async {
      await queueUpload(1);
      final held = Completer<void>();
      write.beforeRequest = (request) async {
        if (request.startsWith('upload')) await held.future;
      };
      read.taskDetails[1] = const TaskDetails();
      final outbox = sender();
      final drained = outbox.drain();
      await pumpEventQueue();

      now = now.add(OutboxSender.staleSendingAfter);
      unawaited(outbox.drain());
      await pumpEventQueue();
      final op = (await db.outboxDao.all()).single;
      expect(op.state, OutboxState.sending.name);
      expect(op.sentAt, isNull);

      held.complete();
      await drained;
      expect(write.requests, ['upload 1 photo.png']);
      expect(read.requests, isEmpty);
    });

    test('an upload above the limit by now is a too-large problem without a '
        'request', () async {
      await queueUpload(1, bytes: List.filled(10, 1));

      await sender(maxUploadBytes: 9).drain();

      expect(write.requests, isEmpty);
      final problem = (await db.outboxDao.loadProblems()).single;
      expect(
        uploadProblemReason(problem.failure),
        UploadProblemReason.tooLarge,
      );
      expect(await storedCopies(), hasLength(1));
    });

    test('an upload that times out $maxUploadTimeoutsInARow times in a row is '
        'a problem; Retry looks for it first', () async {
      await queueUpload(1);
      write.beforeRequest = (request) async {
        if (request.startsWith('upload')) {
          throw const NetworkFailure(NetworkProblem.timeout);
        }
      };
      read.taskDetails[1] = const TaskDetails();
      final outbox = sender();
      await outbox.drain();
      for (var attempt = 2; attempt <= maxUploadTimeoutsInARow; attempt++) {
        expect(await db.outboxDao.loadProblems(), isEmpty);
        now = now.add(OutboxSender.maxBackoff);
        timers.fireNext();
        await pumpEventQueue(times: 50);
      }

      expect(
        write.requests.where((r) => r.startsWith('upload')),
        hasLength(maxUploadTimeoutsInARow),
      );
      final problem = (await db.outboxDao.loadProblems()).single;
      expect(
        uploadProblemReason(problem.failure),
        UploadProblemReason.timedOut,
      );
      expect(timers.active, isEmpty);

      write.beforeRequest = null;
      read.requests.clear();
      await outbox.retry(problem.operationId);

      expect(read.requests, ['task details 1']);
      expect(await db.outboxDao.count(), 0);
    });

    test("timeouts count from one after other failures; an edit's are "
        'retried for good', () async {
      await queueUpload(1);
      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(done: true),
        now: now,
      );
      VikunjaFailure failure = const NetworkFailure(NetworkProblem.unreachable);
      write.beforeRequest = (_) async => throw failure;
      read.taskDetails[1] = const TaskDetails();
      final outbox = sender();
      Future<OutboxRow> op(OutboxOperationKind kind) async =>
          (await db.outboxDao.all()).singleWhere((op) => op.kind == kind.name);

      await outbox.sendNow();
      await outbox.sendNow();
      failure = const NetworkFailure(NetworkProblem.timeout);
      for (var i = 1; i < maxUploadTimeoutsInARow; i++) {
        await outbox.sendNow();
      }
      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(
        (await op(OutboxOperationKind.uploadAttachment)).attempts,
        maxUploadTimeoutsInARow - 1,
      );

      for (var i = 0; i < 3; i++) {
        await outbox.sendNow();
      }

      expect(
        (await db.outboxDao.loadProblems()).single.kind,
        OutboxOperationKind.uploadAttachment,
      );
      final update = await op(OutboxOperationKind.updateTask);
      expect(update.state, OutboxState.pending.name);
      expect(update.attempts, 2 + maxUploadTimeoutsInARow - 1 + 3);
    });

    test(
      'an upload behind an unsent create waits and follows the remap',
      () async {
        final localId = await db.outboxDao.queueCreate(
          const NewTask(title: 'New', projectId: 7),
          now: now,
        );
        await queueUpload(localId);

        await sender().drain();

        expect(write.requests, ['create New', 'upload 100 photo.png']);
        expect(write.serverAttachments[100]!.single.name, 'photo.png');
      },
    );

    test('a transient failure waits out its own backoff', () async {
      await queueUpload(1);
      write.beforeRequest = (_) async => throw const ServerFailure(503);
      final outbox = sender();

      await outbox.drain();

      final op = (await db.outboxDao.all()).single;
      expect(op.state, OutboxState.pending.name);
      expect(op.attempts, 1);
      expect(outbox.state, OutboxSenderState.waiting);
      expect(timers.pendingWait, OutboxSender.initialBackoff);
      expect(op.sentAt, now, reason: 'a 5xx may have stored it');

      write.beforeRequest = null;
      read.taskDetails[1] = const TaskDetails();
      now = now.add(const Duration(seconds: 3));
      timers.fireNext();
      await pumpEventQueue(times: 50);

      expect(write.requests.where((r) => r.startsWith('upload')), hasLength(2));
      expect(read.requests, ['task details 1']);
      expect(await db.outboxDao.count(), 0);
    });

    test(
      'an upload waiting out its backoff holds up none queued after it',
      () async {
        await queueUpload(1);
        await queueUpload(2, name: 'b.txt', bytes: const [9]);
        write.beforeRequest = (request) async {
          if (request == 'upload 1 photo.png') throw const ServerFailure(503);
        };
        final outbox = sender();

        await outbox.drain();

        expect(write.requests, ['upload 1 photo.png', 'upload 2 b.txt']);
        expect(write.serverAttachments[2]!.single.name, 'b.txt');
        expect((await db.outboxDao.all()).single.taskId, 1);
        expect(outbox.state, OutboxSenderState.waiting);
        expect(timers.pendingWait, OutboxSender.initialBackoff);
      },
    );

    test('an upload a run that died left sending holds up none of the '
        'others', () async {
      final stuck = await queueUpload(1);
      await db.outboxDao.claim(stuck, at: now);
      await queueUpload(2, name: 'b.txt', bytes: const [9]);
      final outbox = sender();

      await outbox.drain();

      expect(write.requests, ['upload 2 b.txt']);
      expect((await db.outboxDao.all()).single.id, stuck);
      expect(timers.pendingWait, OutboxSender.inFlightRecheck);
    });

    test('a lost answer is adopted by name, size and uploader instead of a '
        'second upload', () async {
      await queueUpload(1, bytes: const [1, 2, 3, 4]);
      write.afterRequest = (request) async =>
          throw const NetworkFailure(NetworkProblem.timeout);
      final outbox = sender();
      await outbox.drain();
      expect(write.serverAttachments[1], hasLength(1));
      write.afterRequest = null;
      final stored = write.serverAttachments[1]!.single;
      read.taskDetails[1] = TaskDetails(
        attachments: [
          TaskAttachment(
            id: 1,
            taskId: 1,
            name: 'photo.png',
            size: 4,
            created: now.subtract(const Duration(days: 2)),
            createdBy: me,
          ),
          TaskAttachment(
            id: 2,
            taskId: 1,
            name: 'photo.png',
            size: 4,
            created: now,
            createdBy: const User(id: 7, username: 'other'),
          ),
          stored,
        ],
      );
      final uploaded = <TaskAttachment>[];
      final subscription = outbox.uploadedAttachments.listen(uploaded.add);
      addTearDown(subscription.cancel);

      await outbox.sendNow();
      await pumpEventQueue();

      expect(write.requests.where((r) => r.startsWith('upload')), hasLength(1));
      expect(uploaded, [stored]);
      expect(await db.outboxDao.count(), 0);
      expect(await storedCopies(), isEmpty);
    });

    test('a lost answer without a match is sent again', () async {
      await queueUpload(1);
      final op = (await db.outboxDao.all()).single;
      await db.outboxDao.markUncertain(op.id, sentAt: now);
      read.taskDetails[1] = const TaskDetails();

      await sender().drain();

      expect(read.requests, ['task details 1']);
      expect(write.requests, ['upload 1 photo.png']);
    });

    test('too large, archived, no permission and a gone task are sync problems '
        'that keep the stored copy', () async {
      for (final (taskId, failure) in [
        (1, const FileTooLarge(code: 4012)),
        (2, const DomainError(412, code: 3008)),
      ]) {
        await queueUpload(taskId, bytes: [taskId]);
        write.beforeRequest = (request) async {
          if (request.startsWith('upload $taskId')) throw failure;
        };
        await sender().drain();
      }

      final problems = await db.outboxDao.loadProblems();
      expect(problems.map((problem) => problem.kind), [
        OutboxOperationKind.uploadAttachment,
        OutboxOperationKind.uploadAttachment,
      ]);
      expect(problems.map((problem) => problem.fileName), [
        'photo.png',
        'photo.png',
      ]);
      expect(problems.map((problem) => problem.taskTitle), ['One', 'Two']);
      expect(problems.map((problem) => uploadProblemReason(problem.failure)), [
        UploadProblemReason.tooLarge,
        UploadProblemReason.projectArchived,
      ]);
      expect(await storedCopies(), hasLength(2));
    });

    test(
      'a missing route is final: attachments are off on the server',
      () async {
        await queueUpload(1);
        write.beforeRequest = (_) async => throw const NotFound();

        await sender().drain();

        final problem = (await db.outboxDao.loadProblems()).single;
        expect(
          uploadProblemReason(problem.failure),
          UploadProblemReason.attachmentsDisabled,
        );
        expect(timers.active, isEmpty);
      },
    );

    test('a stored copy that is gone is a problem without a request', () async {
      await queueUpload(1);
      for (final name in await storedCopies()) {
        await uploads.delete(name);
      }

      await sender().drain();

      final problem = (await db.outboxDao.loadProblems()).single;
      expect(
        uploadProblemReason(problem.failure),
        UploadProblemReason.fileMissing,
      );
      expect(write.requests, isEmpty);
    });

    test('Retry sends a failed upload again', () async {
      final id = await queueUpload(1);
      write.beforeRequest = (_) async => throw const Forbidden();
      final outbox = sender();
      await outbox.drain();
      expect(await db.outboxDao.loadProblems(), hasLength(1));

      write.beforeRequest = null;
      await outbox.retry(id);

      expect(await db.outboxDao.count(), 0);
      expect(write.serverAttachments[1], hasLength(1));
    });

    test('Discard drops the op and its stored copy without a read', () async {
      final id = await queueUpload(1);
      write.beforeRequest = (_) async => throw const Forbidden();
      final outbox = sender();
      await outbox.drain();

      await outbox.discard(id);

      expect(await db.outboxDao.count(), 0);
      expect(await storedCopies(), isEmpty);
      expect(read.requests, isEmpty);
    });

    test('cancel before the send drops the op and the copy', () async {
      final id = await queueUpload(1);

      await sender().cancelUpload(id);

      expect(await db.outboxDao.count(), 0);
      expect(await storedCopies(), isEmpty);
    });

    test('cancel while sending aborts the request and drops the op', () async {
      final id = await queueUpload(1);
      final held = Completer<void>();
      write.beforeRequest = (_) => held.future;
      final outbox = sender();
      final drained = outbox.drain();
      await pumpEventQueue();
      expect(
        (await db.outboxDao.watchPendingUploads(1).first).single.state.name,
        'sending',
      );

      await outbox.cancelUpload(id);
      expect(write.uploadCancelTokens.single!.isCancelled, isTrue);
      held.complete();
      await drained;

      expect(await db.outboxDao.count(), 0);
      expect(write.serverAttachments[1], isNull);
      expect(await storedCopies(), isEmpty);
    });

    test('an upload another isolate sends is waited for, and sent again once '
        'it is stale, after a look for the attachment', () async {
      final id = await queueUpload(1);
      await db.outboxDao.claim(id, at: now);
      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(done: true),
        now: now,
      );
      read.taskDetails[1] = const TaskDetails();
      final outbox = sender();

      await outbox.drain();

      expect(write.requests, ['update 2']);
      expect(outbox.state, OutboxSenderState.waiting);
      expect(timers.pendingWait, OutboxSender.inFlightRecheck);

      now = now.add(OutboxSender.staleSendingAfter);
      timers.fireNext();
      await pumpEventQueue(times: 50);

      expect(read.requests, ['task details 1']);
      expect(write.requests, ['update 2', 'upload 1 photo.png']);
      expect(await db.outboxDao.count(), 0);
    });

    test('a headless sender leaves uploads alone', () async {
      await queueUpload(1);
      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(done: true),
        now: now,
      );

      final outbox = sender(headless: true);
      await outbox.drain();

      expect(write.requests, ['update 2']);
      expect(outbox.state, OutboxSenderState.idle);
      expect(await db.outboxDao.count(), 1);
    });

    test('the first drain sweeps copies no op names', () async {
      await queueUpload(1);
      final orphan = File(p.join(root.path, 'uploads', 'a' * 32))
        ..writeAsBytesSync(const [0]);
      write.beforeRequest = (_) async => throw const Forbidden();

      await sender().drain();

      expect(orphan.existsSync(), isFalse);
      expect(await storedCopies(), hasLength(1));
    });

    test(
      'a copy being queued is not swept even though no op names it yet',
      () async {
        final source = File(p.join(root.path, 'picked'))
          ..writeAsBytesSync(const [1]);
        final stored = await uploads.store(source);

        await sender().drain();

        expect(await storedCopies(), [stored.name]);
      },
    );

    test(
      'a delete of the task sent drops its uploads and their copies',
      () async {
        await queueUpload(1);
        write.beforeRequest = (request) async {
          if (request.startsWith('upload')) throw const Forbidden();
        };
        final outbox = sender();
        await outbox.drain();
        await db.outboxDao.queueDelete(1, now: now);

        await outbox.drain();

        expect(await db.outboxDao.count(), 0);
        expect(await storedCopies(), isEmpty);
      },
    );
  });

  group('dangling cover', () {
    test(
      'an update refused with 4020 goes once more with the cover cleared',
      () async {
        write.covers[1] = 99;
        await db.outboxDao.queueUpdate(
          1,
          const TaskChanges(title: 'Renamed'),
          now: now,
        );

        await sender().drain();

        expect(write.requests, ['update 1', 'update 1']);
        expect(write.updates.single.$2, isA<TaskChanges>());
        expect(write.updates.single.$2.coverImageAttachmentId, 0);
        expect(write.updates.single.$2.title, 'Renamed');
        expect(write.covers[1], 0);
        expect((await db.tasksDao.find(1))!.title, 'Renamed');
        expect(await db.outboxDao.count(), 0);
      },
    );

    test('a 4020 for a cover the change sets itself is a problem', () async {
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(coverImageAttachmentId: 99),
        now: now,
      );

      await sender().drain();

      expect(write.requests, ['update 1']);
      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.failure.code, 4020);
    });

    test('a second 4020 is a problem', () async {
      write.beforeRequest = (_) async =>
          throw const DomainError(400, code: 4020);
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(title: 'Renamed'),
        now: now,
      );

      await sender().drain();

      expect(write.requests, ['update 1', 'update 1']);
      expect(
        decodeFailure((await db.outboxDao.all()).single.lastError!).code,
        4020,
      );
    });
  });
}
