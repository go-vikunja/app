import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/set_aside_upload_json.dart';
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
    Duration? serverClockOffset,
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
      serverClockOffset: () async => serverClockOffset,
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

  /// Holds every upload request until [release] completes; completes once
  /// the first one has reached the server.
  Future<void> holdUploads(Future<void> release) {
    final reached = Completer<void>();
    write.beforeRequest = (request) async {
      if (!request.startsWith('upload')) return;
      if (!reached.isCompleted) reached.complete();
      await release;
    };
    return reached.future;
  }

  /// Waits for [done]: a sweep a timer starts is not awaited, and its file
  /// I/O can outlast any fixed number of event-loop turns.
  Future<void> until(Future<bool> Function() done) async {
    final waited = Stopwatch()..start();
    while (!await done()) {
      if (waited.elapsed > const Duration(seconds: 5)) fail('Timed out');
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<List<SetAsideUpload>> setAside() async => decodeSetAsideUploads(
    (await db.syncStateDao.readAll())[OutboxDao.setAsideUploadsKey],
  );

  /// Fires the next timer and waits until the drain it starts is done or
  /// waits again: an upload does real file I/O, which no fixed number of
  /// event-loop turns is sure to outlast.
  Future<void> fireNextAndSettle(OutboxSender outbox) async {
    timers.fireNext();
    expect(outbox.state, OutboxSenderState.draining);
    await outbox.states.firstWhere(
      (state) => state != OutboxSenderState.draining,
    );
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
      expect(
        sync.refreshAfterWriteCalls,
        0,
        reason: 'an upload changes no task',
      );
    });

    test("an uploaded file joins the task's stored attachments, after "
        'those of the last read; none are stored for a task never '
        'read', () async {
      const listed = TaskAttachment(id: 9, taskId: 1, name: 'a.pdf', size: 4);
      await db.taskDetailsDao.storeDetails(
        1,
        const TaskDetails(attachments: [listed]),
        at: now,
      );
      await queueUpload(1);
      await queueUpload(2, name: 'b.png');

      await sender().drain();

      final stored = (await db.taskDetailsDao.storedDetails(1))!.value;
      expect(stored.attachments.map((a) => a.id), [9, 300]);
      expect(stored.attachments.last.name, 'photo.png');
      expect(await db.taskDetailsDao.storedDetails(2), isNull);
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
      final onItsWay = holdUploads(held.future);
      final outbox = sender();
      final drained = outbox.drain();
      await onItsWay;
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
      final onItsWay = holdUploads(held.future);
      read.taskDetails[1] = const TaskDetails();
      final outbox = sender();
      final drained = outbox.drain();
      await onItsWay;

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
        await fireNextAndSettle(outbox);
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

    // Such a request never left the device, though it fails as a network
    // failure (decision log: Sessions).
    for (final failure in const [
      NetworkFailure(NetworkProblem.timeout, cause: RefreshDeferred.race),
      NetworkFailure(
        NetworkProblem.unreachable,
        cause: SecureStorageUnreadable(PlatformException),
      ),
    ]) {
      test('an upload whose request got no token (${failure.cause}) is '
          'neither a timeout nor possibly stored', () async {
        await queueUpload(1);
        write.beforeRequest = (request) async {
          if (request.startsWith('upload')) throw failure;
        };
        final outbox = sender();

        for (var i = 0; i <= maxUploadTimeoutsInARow; i++) {
          await outbox.sendNow();
        }

        expect(await db.outboxDao.loadProblems(), isEmpty);
        final op = (await db.outboxDao.all()).single;
        expect(op.state, OutboxState.pending.name);
        expect(op.sentAt, isNull);
      });
    }

    test('a renewal put off between timeouts counts as none of them', () async {
      await queueUpload(1);
      VikunjaFailure failure = const NetworkFailure(NetworkProblem.timeout);
      write.beforeRequest = (request) async {
        if (request.startsWith('upload')) throw failure;
      };
      final outbox = sender();
      for (var i = 1; i < maxUploadTimeoutsInARow; i++) {
        await outbox.sendNow();
      }

      failure = const NetworkFailure(
        NetworkProblem.timeout,
        cause: RefreshDeferred.race,
      );
      await outbox.sendNow();
      failure = const NetworkFailure(NetworkProblem.timeout);
      await outbox.sendNow();

      expect(await db.outboxDao.loadProblems(), isEmpty);
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
      await fireNextAndSettle(outbox);

      expect(write.requests.where((r) => r.startsWith('upload')), hasLength(2));
      expect(read.requests, ['task details 1']);
      expect(await db.outboxDao.count(), 0);
    });

    test('an upload that keeps getting a 5xx is a problem after '
        '${OutboxSender.maxFailedUploadAnswersInARow} attempts, far fewer '
        "than an edit's, as each sends the whole file", () async {
      await queueUpload(1);
      write.beforeRequest = (request) async {
        if (request.startsWith('upload')) throw const ServerFailure(502);
      };
      read.taskDetails[1] = const TaskDetails();
      final outbox = sender();
      await outbox.drain();
      for (
        var attempt = 2;
        attempt <= OutboxSender.maxFailedUploadAnswersInARow;
        attempt++
      ) {
        expect(await db.outboxDao.loadProblems(), isEmpty);
        now = now.add(timers.pendingWait);
        await fireNextAndSettle(outbox);
      }

      expect(
        write.requests.where((r) => r.startsWith('upload')),
        hasLength(OutboxSender.maxFailedUploadAnswersInARow),
      );
      expect(
        OutboxSender.maxFailedUploadAnswersInARow,
        lessThan(OutboxSender.maxFailedAnswersInARow),
      );
      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.kind, OutboxOperationKind.uploadAttachment);
      expect(problem.failure, isA<ServerFailure>());
      expect(timers.active, isEmpty);
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

    TaskAttachment uploadedOnTheWeb(int size) => TaskAttachment(
      id: 999,
      taskId: 1,
      name: 'photo.png',
      size: size,
      created: now.subtract(const Duration(hours: 1)),
      createdBy: me,
    );

    test('a same-named file of that size uploaded on the web hours after a '
        'lost upload is not taken: the one the lost request stored is '
        'adopted', () async {
      await queueUpload(1, bytes: const [1, 2, 3, 4]);
      write.afterRequest = (request) async =>
          throw const NetworkFailure(NetworkProblem.timeout);
      final outbox = sender();
      await outbox.drain();
      write.afterRequest = null;
      final stored = write.serverAttachments[1]!.single;
      now = now.add(const Duration(hours: 5));
      read.taskDetails[1] = TaskDetails(
        attachments: [stored, uploadedOnTheWeb(stored.size)],
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

    test('a lost upload the server never got is sent again when only a '
        'same-named file uploaded on the web hours later is there', () async {
      await queueUpload(1, bytes: const [1, 2, 3, 4]);
      write.beforeRequest = (request) async {
        if (request.startsWith('upload')) {
          throw const NetworkFailure(NetworkProblem.timeout);
        }
      };
      final outbox = sender();
      await outbox.drain();
      expect((await db.outboxDao.all()).single.sentAt, now);
      write.beforeRequest = null;
      now = now.add(const Duration(hours: 5));
      read.taskDetails[1] = TaskDetails(attachments: [uploadedOnTheWeb(4)]);
      final uploaded = <TaskAttachment>[];
      final subscription = outbox.uploadedAttachments.listen(uploaded.add);
      addTearDown(subscription.cancel);

      await outbox.sendNow();
      await pumpEventQueue();

      expect(write.requests, ['upload 1 photo.png', 'upload 1 photo.png']);
      expect(uploaded.single.id, isNot(999));
      expect(await db.outboxDao.count(), 0);
      expect(await storedCopies(), isEmpty);
    });

    for (final (what, answer) in [
      (
        'a 2xx whose body cannot be read',
        () => throw const UnexpectedResponse(200, message: 'not an attachment'),
      ),
      ('an exception after the request', () => throw StateError('a bug')),
    ]) {
      test('$what may have stored the file: it is looked for, not uploaded '
          'again', () async {
        await queueUpload(1, bytes: const [1, 2, 3, 4]);
        write.afterRequest = (request) async => answer();
        final outbox = sender();
        await outbox.drain();

        final op = (await db.outboxDao.all()).single;
        expect(op.state, OutboxState.pending.name);
        expect(op.sentAt, now);
        expect(await db.outboxDao.loadProblems(), isEmpty);

        write.afterRequest = null;
        read.taskDetails[1] = TaskDetails(
          attachments: [write.serverAttachments[1]!.single],
        );
        now = now.add(OutboxSender.initialBackoff);
        await fireNextAndSettle(outbox);

        expect(
          write.requests.where((r) => r.startsWith('upload')),
          hasLength(1),
        );
        expect(read.requests, ['task details 1']);
        expect(await db.outboxDao.count(), 0);
      });
    }

    test('a phone clock hours ahead of the server still finds the stored '
        "file: the window moves by the server's clock offset the session "
        'learned', () async {
      const offset = Duration(hours: -3);
      final id = await queueUpload(1, bytes: const [1, 2, 3, 4]);
      await db.outboxDao.markUncertain(id, sentAt: now);
      final stored = TaskAttachment(
        id: 9,
        taskId: 1,
        name: 'photo.png',
        size: 4,
        created: now.add(offset),
        createdBy: me,
      );
      read.taskDetails[1] = TaskDetails(attachments: [stored]);
      final outbox = sender(serverClockOffset: offset);
      final uploaded = <TaskAttachment>[];
      final subscription = outbox.uploadedAttachments.listen(uploaded.add);
      addTearDown(subscription.cancel);

      await outbox.drain();
      await pumpEventQueue();

      expect(write.requests, isEmpty);
      expect(uploaded, [stored]);
      expect(await db.outboxDao.count(), 0);
    });

    test('a phone clock set back after the lost attempt still finds the '
        'stored file: the offset learned since does not move the window past '
        'the attempt', () async {
      final id = await queueUpload(1, bytes: const [1, 2, 3, 4]);
      await db.outboxDao.markUncertain(id, sentAt: now);
      final stored = TaskAttachment(
        id: 9,
        taskId: 1,
        name: 'photo.png',
        size: 4,
        created: now,
        createdBy: me,
      );
      read.taskDetails[1] = TaskDetails(attachments: [stored]);
      final outbox = sender(serverClockOffset: const Duration(hours: 2));
      final uploaded = <TaskAttachment>[];
      final subscription = outbox.uploadedAttachments.listen(uploaded.add);
      addTearDown(subscription.cancel);

      await outbox.drain();
      await pumpEventQueue();

      expect(write.requests, isEmpty);
      expect(uploaded, [stored]);
      expect(await db.outboxDao.count(), 0);
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

    for (final failure in const [Forbidden(), NotFound()]) {
      test('a lookup the server answers with ${failure.runtimeType} is no '
          'refusal of the upload: Retry looks again and adopts the file the '
          'lost request stored', () async {
        final id = await queueUpload(1, bytes: const [1, 2, 3, 4]);
        write.afterRequest = (request) async =>
            throw const NetworkFailure(NetworkProblem.timeout);
        final outbox = sender();
        await outbox.drain();
        write.afterRequest = null;
        read.beforeRequest = (_) async => throw failure;

        await outbox.sendNow();
        if (failure is NotFound) {
          for (var i = 1; i < OutboxSender.maxFailedUploadAnswersInARow; i++) {
            now = now.add(timers.pendingWait);
            await fireNextAndSettle(outbox);
          }
        }

        final failed = (await db.outboxDao.all()).single;
        expect(failed.state, OutboxState.failed.name);
        expect(failed.sentAt, isNotNull);

        read.beforeRequest = null;
        read.taskDetails[1] = TaskDetails(
          attachments: [write.serverAttachments[1]!.single],
        );
        await outbox.retry(id);

        expect(
          write.requests.where((r) => r.startsWith('upload')),
          hasLength(1),
        );
        expect(await db.outboxDao.count(), 0);
        expect(await storedCopies(), isEmpty);
      });
    }

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
      final onItsWay = holdUploads(held.future);
      final outbox = sender();
      final drained = outbox.drain();
      await onItsWay;
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
      await fireNextAndSettle(outbox);

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

    test('a delete of the task sent sets its uploads aside with their copies '
        'for the Undo; once that is over, the copies go', () async {
      await queueUpload(1);
      write.beforeRequest = (request) async {
        if (request.startsWith('upload')) throw const Forbidden();
      };
      final outbox = sender();
      await outbox.drain();
      await db.outboxDao.queueDelete(1, now: now);

      await outbox.drain();

      expect(await db.outboxDao.count(), 0);
      expect(await storedCopies(), hasLength(1));
      expect(timers.pendingWait, OutboxSender.setAsideFor);

      now = now.add(OutboxSender.setAsideFor);
      timers.fireNext();

      await until(() async => (await storedCopies()).isEmpty);
      expect(await db.outboxDao.uploadFiles(), isEmpty);
      expect(timers.active, isEmpty);
    });
  });

  group('uploads set aside for an Undo', () {
    test('an upload on its way when the delete is applied is set aside as '
        'maybe sent; if it lands after all, its copy goes and nothing goes '
        'back', () async {
      final id = await queueUpload(1);
      final reached = Completer<void>();
      final held = Completer<void>();
      write.afterRequest = (request) async {
        if (!request.startsWith('upload')) return;
        reached.complete();
        await held.future;
      };
      final outbox = sender();
      final uploading = outbox.drain();
      await reached.future;
      await db.outboxDao.queueDelete(1, now: now);

      final deleting = outbox.drain();
      await until(() async => await db.outboxDao.count() == 0);

      expect(write.requests, ['upload 1 photo.png', 'delete 1']);
      final entry = (await setAside()).single;
      expect(entry.op.id, id);
      expect(entry.op.state, OutboxState.pending.name);
      expect(entry.op.sentAt, now);
      expect(entry.op.lastAttemptAt, now);
      expect(await storedCopies(), hasLength(1));

      held.complete();
      await uploading;
      await deleting;

      expect(await storedCopies(), isEmpty);
      expect(await setAside(), isEmpty);
      expect(await db.outboxDao.requeueSetAsideUploads(1), 0);
      expect(await db.outboxDao.count(), 0);
    });

    test('an upload on its way that the server refuses once the task is in '
        'the trash stays set aside and goes again, looked up first, after a '
        'restore', () async {
      final id = await queueUpload(1);
      final held = Completer<void>();
      final onItsWay = holdUploads(held.future);
      final outbox = sender();
      final uploading = outbox.drain();
      await onItsWay;
      await db.outboxDao.queueDelete(1, now: now);
      final deleting = outbox.drain();
      await until(() async => await db.outboxDao.count() == 0);

      held.complete();
      await uploading;
      await deleting;

      expect(write.requests, ['upload 1 photo.png', 'delete 1']);
      expect(write.serverAttachments[1], isNull);
      expect(await db.outboxDao.loadProblems(), isEmpty);
      final entry = (await setAside()).single;
      expect(entry.op.id, id);
      expect(entry.op.state, OutboxState.pending.name);
      expect(entry.op.sentAt, now);
      expect(await storedCopies(), hasLength(1));

      write.serverTasks[1] = tasks[0];
      await db.tasksDao.upsertAll([tasks[0]]);
      expect(await db.outboxDao.requeueSetAsideUploads(1), 1);
      read.taskDetails[1] = const TaskDetails();
      List<String>? readBeforeUpload;
      write.beforeRequest = (request) async {
        if (request.startsWith('upload')) readBeforeUpload = [...read.requests];
      };
      await outbox.drain();

      expect(readBeforeUpload, ['task details 1']);
      expect(write.requests.last, 'upload 1 photo.png');
      expect(write.serverAttachments[1], hasLength(1));
      expect(await db.outboxDao.count(), 0);
      expect(await storedCopies(), isEmpty);
    });

    test('the next start drops every set-aside upload and its copy, even '
        'inside the Undo window; a later sweep keeps them and arms the drop, '
        'and dispose cancels it', () async {
      await queueUpload(1);
      await db.outboxDao.queueDelete(1, now: now);
      final outbox = sender();
      await outbox.drain();
      expect(write.requests, ['delete 1']);
      expect(await storedCopies(), hasLength(1));
      expect(timers.pendingWait, OutboxSender.setAsideFor);

      now = now.add(const Duration(seconds: 5));
      await outbox.sweepUploads();

      expect(await storedCopies(), hasLength(1));
      expect(
        timers.pendingWait,
        OutboxSender.setAsideFor - const Duration(seconds: 5),
      );

      await outbox.dispose();

      expect(timers.active, isEmpty);

      await sender().drain();

      expect(await storedCopies(), isEmpty);
      expect(await setAside(), isEmpty);
      expect(await db.outboxDao.uploadFiles(), isEmpty);
      expect(timers.active, isEmpty);
    });

    test('a headless sender sets the uploads of a deleted task aside and '
        'leaves them and their copies to the app, also past their '
        'time', () async {
      final app = sender();
      await app.drain();
      await queueUpload(1);
      await db.outboxDao.queueDelete(1, now: now);
      final background = sender(headless: true);

      await background.drain();

      expect(write.requests, ['delete 1']);
      expect(await db.outboxDao.count(), 0);
      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(await db.outboxDao.uploadFiles(), hasLength(1));
      expect(await storedCopies(), hasLength(1));
      expect(timers.active, isEmpty);

      now = now.add(OutboxSender.setAsideFor + const Duration(seconds: 1));
      await background.sweepUploads();

      expect(await db.outboxDao.uploadFiles(), hasLength(1));
      expect(await storedCopies(), hasLength(1));

      await app.sweepUploads();

      expect(await db.outboxDao.uploadFiles(), isEmpty);
      expect(await storedCopies(), isEmpty);
    });
  });

  test('discarding a problem of a task the server no longer has takes its '
      'uploads and their copies with it', () async {
    await db.outboxDao.queueUpdate(
      1,
      const TaskChanges(title: 'Renamed'),
      now: now,
    );
    write.beforeRequest = (_) async => throw const NotFound(code: 4002);
    final outbox = sender();
    await outbox.drain();
    final problem = (await db.outboxDao.loadProblems()).single;
    await queueUpload(1);
    read.allTasks = [tasks[1]];

    await outbox.discard(problem.operationId);

    expect(await db.tasksDao.findRow(1), isNull);
    expect(await db.outboxDao.count(), 0);
    expect(await storedCopies(), isEmpty);
  });

  test("Use the web's for a task the server no longer has takes its uploads "
      'and their copies with it, as Discard does', () async {
    await db.outboxDao.queueUpdate(
      1,
      const TaskChanges(description: '<p>Mine</p>', descriptionBase: ''),
      now: now,
    );
    write.serverTasks[1] = tasks[0].copyWith(description: '<p>Web</p>');
    final outbox = sender();
    await outbox.drain();
    final problem = (await db.outboxDao.loadProblems()).single;
    expect(problem.failure, isA<DescriptionConflict>());
    await queueUpload(1);
    read.allTasks = [tasks[1]];

    await outbox.useWebDescription(problem.operationId);

    expect(write.requests.where((r) => r.startsWith('upload')), isEmpty);
    expect(await db.tasksDao.findRow(1), isNull);
    expect(await db.outboxDao.count(), 0);
    expect(await storedCopies(), isEmpty);
  });

  group('a queued delete', () {
    test('holds the uploads of its task back; once the delete is applied, '
        'they are set aside and their copies go after the Undo', () async {
      await queueUpload(1);
      await queueUpload(2, name: 'other.png', bytes: const [4, 5]);
      await db.outboxDao.queueDelete(1, now: now);
      write.beforeRequest = (request) async {
        if (request.startsWith('delete')) {
          throw const NetworkFailure(NetworkProblem.unreachable);
        }
      };
      final outbox = sender();

      await outbox.drain();

      expect(write.requests, ['delete 1', 'upload 2 other.png']);
      expect(await storedCopies(), hasLength(1));
      expect(outbox.state, OutboxSenderState.waiting);

      write.beforeRequest = null;
      await outbox.sendNow();

      expect(write.requests, ['delete 1', 'upload 2 other.png', 'delete 1']);
      expect(await db.outboxDao.count(), 0);
      expect(await storedCopies(), hasLength(1));
      expect(timers.pendingWait, OutboxSender.setAsideFor);

      now = now.add(OutboxSender.setAsideFor);
      timers.fireNext();

      await until(() async => (await storedCopies()).isEmpty);
    });

    test('taken back, the uploads go on', () async {
      await queueUpload(1);
      await db.outboxDao.queueDelete(1, now: now);
      write.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      final outbox = sender();
      await outbox.drain();
      expect(write.requests, ['delete 1']);

      write.beforeRequest = null;
      await db.outboxDao.unqueueDelete(1);
      await outbox.drain();

      expect(write.requests, ['delete 1', 'upload 1 photo.png']);
      expect(await db.outboxDao.count(), 0);
      expect(await storedCopies(), isEmpty);
    });

    test('behind a create never sent drops both without a request and '
        'sweeps the copies', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(title: 'New', projectId: 7),
        now: now,
      );
      await queueUpload(id);
      await db.outboxDao.queueDelete(id, now: now);
      expect(await storedCopies(), hasLength(1));

      await sender().drain();

      expect(write.requests, isEmpty);
      expect(await db.outboxDao.count(), 0);
      expect(await db.tasksDao.findRow(id), isNull);
      expect(await storedCopies(), isEmpty);
    });

    test('behind a create the server refuses goes with it, and so do the '
        'copies', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(title: 'New', projectId: 7),
        now: now,
      );
      await queueUpload(id);
      await db.outboxDao.queueUpdate(
        id,
        const TaskChanges(done: true),
        now: now,
      );
      write.beforeRequest = (request) async {
        if (request.startsWith('create')) {
          // Deleted while the create is on its way.
          await db.outboxDao.queueDelete(id, now: now);
          throw const DomainError(400, code: 4001);
        }
      };

      await sender().drain();

      expect(write.requests, ['create New']);
      expect(await db.outboxDao.count(), 0);
      expect(await db.tasksDao.findRow(id), isNull);
      expect(await storedCopies(), isEmpty);
    });
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

    test('a cover deleted on the server before its change went is left out, '
        'and the rest of the change goes', () async {
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(title: 'Renamed', coverImageAttachmentId: 99),
        now: now,
      );

      await sender().drain();

      expect(write.requests, ['update 1', 'update 1']);
      expect(write.updates.single.$2, const TaskChanges(title: 'Renamed'));
      expect(write.covers[1], isNull);
      expect((await db.tasksDao.find(1))!.title, 'Renamed');
      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(await db.outboxDao.count(), 0);
    });

    test('a cover deleted meanwhile on a task that still names a deleted one: '
        'left out, then the old one cleared', () async {
      write.covers[1] = 98;
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(title: 'Renamed', coverImageAttachmentId: 99),
        now: now,
      );

      await sender().drain();

      expect(write.requests, ['update 1', 'update 1', 'update 1']);
      expect(
        write.updates.single.$2,
        const TaskChanges(title: 'Renamed', coverImageAttachmentId: 0),
      );
      expect(write.covers[1], 0);
      expect(write.serverTasks[1]!.title, 'Renamed');
      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(await db.outboxDao.count(), 0);
    });

    test('a cover alone whose attachment is gone is not written: the task is '
        'read instead', () async {
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(coverImageAttachmentId: 99),
        now: now,
      );

      await sender().drain();

      expect(write.requests, ['update 1']);
      expect(write.updates, isEmpty);
      expect(read.requests, contains('task 1'));
      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(await db.outboxDao.count(), 0);
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

  group('the queue and the uploads', () {
    void failBoth() => write.beforeRequest = (request) async {
      if (request == 'update 2') {
        throw const NetworkFailure(NetworkProblem.unreachable);
      }
      if (request.startsWith('upload')) throw const ServerFailure(503);
    };

    Future<void> queueBoth() async {
      await queueUpload(1);
      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(done: true),
        now: now,
      );
    }

    test('an upload waiting out its backoff while the queue is idle is what '
        'the sender waits for, and Send now reports it; with an op of the '
        'queue waiting too, that op is', () async {
      await queueUpload(1);
      failBoth();
      read.taskDetails[1] = const TaskDetails();
      final outbox = sender();

      await outbox.drain();

      expect(outbox.state, OutboxSenderState.waiting);
      expect(outbox.blockedBy, isA<ServerFailure>());
      expect(await outbox.sendNow(), isA<ServerFailure>());
      expect(write.requests, ['upload 1 photo.png', 'upload 1 photo.png']);

      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(done: true),
        now: now,
      );
      write.requests.clear();

      expect(await outbox.sendNow(), isA<NetworkFailure>());
      expect(write.requests, ['update 2', 'upload 1 photo.png']);
      expect(outbox.state, OutboxSenderState.waiting);
      expect(timers.active, hasLength(2));
    });

    test('a database error while sending the uploads is logged, not thrown: '
        'the drain resolves, the sender is idle and the same sender sends '
        'the upload later', () async {
      final id = await queueUpload(1);
      await db.customStatement(
        'CREATE TRIGGER claim_fails BEFORE UPDATE ON outbox '
        "WHEN NEW.kind = 'uploadAttachment' "
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final outbox = sender();

      await outbox.drain();

      expect(write.requests, isEmpty);
      expect(outbox.state, OutboxSenderState.idle);
      expect([
        for (final record in records) record.message,
      ], contains(startsWith('Sending the uploads failed')));
      expect((await db.outboxDao.find(id))!.state, OutboxState.pending.name);

      await db.customStatement('DROP TRIGGER claim_fails');
      await outbox.drain();

      expect(write.requests, ['upload 1 photo.png']);
      expect(await db.outboxDao.count(), 0);
      expect(outbox.state, OutboxSenderState.idle);
    });

    test('a drain with an edit and an upload is one stretch of draining: the '
        'uploads start before the queue goes idle', () async {
      await queueBoth();
      final outbox = sender();
      final states = <OutboxSenderState>[];
      final subscription = outbox.states.listen(states.add);
      addTearDown(subscription.cancel);

      await outbox.drain();

      expect(write.requests, ['update 2', 'upload 1 photo.png']);
      expect(states, [
        OutboxSenderState.idle,
        OutboxSenderState.draining,
        OutboxSenderState.idle,
      ]);
    });

    test('pause with the queue and the uploads both waiting cancels both '
        'timers', () async {
      await queueBoth();
      failBoth();
      final outbox = sender();
      await outbox.drain();
      expect(outbox.state, OutboxSenderState.waiting);
      expect(timers.active, hasLength(2));

      outbox.pause();

      expect(timers.active, isEmpty);
      expect(outbox.state, OutboxSenderState.paused);
      expect(outbox.blockedBy, isNull);
    });

    test('dispose with the queue and the uploads both waiting cancels both '
        'timers', () async {
      await queueBoth();
      failBoth();
      final outbox = sender();
      await outbox.drain();
      expect(timers.active, hasLength(2));

      await outbox.dispose();

      expect(timers.active, isEmpty);
    });

    test('an upload another isolate sends names no failure, also after an '
        'attempt here failed: the sender only waits for it', () async {
      final id = await queueUpload(1);
      write.beforeRequest = (request) async {
        if (request.startsWith('upload')) throw const ServerFailure(503);
      };
      final outbox = sender();
      await outbox.drain();
      expect(outbox.blockedBy, isA<ServerFailure>());
      now = now.add(const Duration(seconds: 3));
      expect(await db.outboxDao.claim(id, at: now), isNotNull);

      await fireNextAndSettle(outbox);

      expect(outbox.state, OutboxSenderState.waiting);
      expect(timers.pendingWait, OutboxSender.inFlightRecheck);
      expect(outbox.blockedBy, isNull);
      expect(await outbox.sendNow(), isNull);
      expect(write.requests, ['upload 1 photo.png']);
    });

    test('an upload waiting out its own backoff still names its failure '
        'while another one is in flight elsewhere', () async {
      final first = await queueUpload(1);
      await queueUpload(2, name: 'b.txt', bytes: const [9]);
      write.beforeRequest = (request) async {
        if (request.startsWith('upload')) throw const ServerFailure(503);
      };
      final outbox = sender();
      await outbox.drain();
      expect(write.requests, ['upload 1 photo.png', 'upload 2 b.txt']);
      expect(await db.outboxDao.claim(first, at: now), isNotNull);

      await fireNextAndSettle(outbox);

      expect(outbox.state, OutboxSenderState.waiting);
      expect(timers.pendingWait, OutboxSender.initialBackoff);
      expect(outbox.blockedBy, isA<ServerFailure>());
    });
  });
}
