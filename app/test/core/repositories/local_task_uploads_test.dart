import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/upload_json.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/trash_fakes.dart';
import '../../helpers/zero_random.dart';

void main() {
  late AppDatabase db;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late RecordingSyncEngine sync;
  late FakeTimers timers;
  late UploadFiles uploads;
  late OutboxSender sender;
  late LocalTaskRepository repository;
  late Directory root;
  late Directory folder;
  late DateTime now;

  void build({TrashPort? trash}) {
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: sync,
      now: () => now,
      createTimer: timers.create,
      random: ZeroRandom(),
      uploads: uploads,
    );
    addTearDown(sender.dispose);
    repository = LocalTaskRepository(
      db,
      sync,
      sender,
      write,
      now: () => now,
      uploads: uploads,
      maxUploadBytes: 8,
      trash: trash,
    );
  }

  setUp(() async {
    now = DateTime.utc(2026, 10, 20, 12);
    db = testDatabase();
    root = Directory.systemTemp.createTempSync('task_uploads_test');
    addTearDown(() => root.deleteSync(recursive: true));
    folder = Directory(p.join(root.path, 'uploads'));
    uploads = UploadFiles(() async => folder);
    final task = sampleTask(id: 1, title: 'One', projectId: 7);
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient()..allTasks = [task];
    sync = RecordingSyncEngine();
    timers = FakeTimers();
    build();
    await db.tasksDao.upsertAll([task], syncRunId: 'run');
    write.serverTasks[1] = task;
  });

  File picked(String name, List<int> bytes) =>
      File(p.join(root.path, name))..writeAsBytesSync(bytes);

  List<String> stored() => folder.existsSync()
      ? [for (final entry in folder.listSync()) p.basename(entry.path)]
      : const [];

  /// Waits for [done]: a sweep a timer starts is not awaited, and its file
  /// I/O can outlast any fixed number of event-loop turns.
  Future<void> until(bool Function() done) async {
    final waited = Stopwatch()..start();
    while (!done()) {
      if (waited.elapsed > const Duration(seconds: 5)) fail('Timed out');
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  test('a file is copied into the uploads folder, queued under a safe name and '
      'sent', () async {
    final source = picked('photo', const [1, 2, 3]);
    final held = Completer<void>();
    write.beforeRequest = (_) => held.future;

    final id = await repository.queueUpload(
      1,
      sourcePath: source.path,
      fileName: '../holiday\u202e.png',
      mimeType: 'image/png',
    );

    expect(id, isNotNull);
    expect(source.existsSync(), isTrue);
    final upload = decodeQueuedUpload((await db.outboxDao.find(id!))!.payload);
    expect(upload.fileName, '.._holiday.png');
    expect(upload.size, 3);
    expect(stored(), [upload.file]);
    final pending = await repository.watchPendingUploads(1).first;
    expect(pending.single.operationId, id);
    expect(pending.single.state, isNot(PendingUploadState.failed));

    final uploaded = repository.uploadedAttachments.first;
    held.complete();
    expect((await uploaded).name, '.._holiday.png');
    await pumpEventQueue();
    expect(stored(), isEmpty);
    expect(await db.outboxDao.count(), 0);
  });

  test('a share inbox copy is moved, not copied', () async {
    final source = picked('inbox', const [1]);
    write.beforeRequest = (_) => Completer<void>().future;

    await repository.queueUpload(
      1,
      sourcePath: source.path,
      fileName: 'note.txt',
      moveSource: true,
    );

    expect(source.existsSync(), isFalse);
    expect(stored(), hasLength(1));
  });

  test('a file above the limit is refused before anything is stored', () async {
    final source = picked('big', List.filled(9, 0));

    await expectLater(
      repository.queueUpload(1, sourcePath: source.path, fileName: 'big'),
      throwsA(isA<UploadTooLarge>()),
    );
    expect(stored(), isEmpty);
    expect(await db.outboxDao.count(), 0);
  });

  test(
    'a moved file above the limit is deleted, as it is not queued',
    () async {
      final source = picked('big', List.filled(9, 0));

      await expectLater(
        repository.queueUpload(
          1,
          sourcePath: source.path,
          fileName: 'big',
          moveSource: true,
        ),
        throwsA(isA<UploadTooLarge>()),
      );
      expect(source.existsSync(), isFalse);
      expect(stored(), isEmpty);
    },
  );

  test('an upload is shown as sending only while this sender sends it; one '
      'a dead run left sending waits', () async {
    final held = Completer<void>();
    // The copy is real file I/O, which a fixed number of event loop turns
    // does not always outlast under load.
    final requested = Completer<void>();
    write.beforeRequest = (_) {
      if (!requested.isCompleted) requested.complete();
      return held.future;
    };
    await repository.queueUpload(
      1,
      sourcePath: picked('photo', const [1]).path,
      fileName: 'photo.png',
    );
    await requested.future;
    await pumpEventQueue();
    expect(
      (await repository.watchPendingUploads(1).first).single.state,
      PendingUploadState.sending,
    );
    final uploaded = repository.uploadedAttachments.first;
    held.complete();
    await uploaded;
    expect(await db.outboxDao.count(), 0);

    final left = await db.outboxDao.queueUpload(
      1,
      QueuedUpload(file: 'a' * 32, fileName: 'left.png', size: 1),
      now: now,
    );
    await db.outboxDao.claim(left!, at: now);

    expect(
      (await db.outboxDao.watchPendingUploads(1).first).single.state,
      PendingUploadState.sending,
    );
    expect(
      (await repository.watchPendingUploads(1).first).single.state,
      PendingUploadState.waiting,
    );
  });

  test('nothing is kept for a task that is not on the device', () async {
    final source = picked('inbox', const [1]);

    expect(
      await repository.queueUpload(
        9,
        sourcePath: source.path,
        fileName: 'x',
        moveSource: true,
      ),
      isNull,
    );
    expect(source.existsSync(), isFalse);
    expect(stored(), isEmpty);
  });

  test('cancel drops the queued upload and its copy', () async {
    write.beforeRequest = (_) async => throw const Forbidden();
    final id = await repository.queueUpload(
      1,
      sourcePath: picked('a', const [1]).path,
      fileName: 'a',
    );
    await sender.drain();

    await repository.cancelUpload(id!);

    expect(await db.outboxDao.count(), 0);
    expect(stored(), isEmpty);
  });

  test('a delete keeps the uploads while it is queued; once sent, they are '
      'set aside for the Undo and their copies go once it is over', () async {
    write.beforeRequest = (request) async {
      if (request.startsWith('upload')) throw const Forbidden();
      if (request.startsWith('delete')) {
        throw const NetworkFailure(NetworkProblem.unreachable);
      }
    };
    await repository.queueUpload(
      1,
      sourcePath: picked('a', const [1]).path,
      fileName: 'a',
    );
    await sender.drain();

    expect(await repository.deleteTask(1), TaskDeletion.queued);
    await pumpEventQueue();

    expect(stored(), hasLength(1));

    write.beforeRequest = null;
    await repository.sendPendingChanges();

    expect(await db.outboxDao.count(), 0);
    expect(stored(), hasLength(1));
    expect(timers.pendingWait, OutboxSender.setAsideFor);

    now = now.add(OutboxSender.setAsideFor);
    timers.fireNext();

    await until(() => stored().isEmpty);
  });

  test('an upload waiting behind a delete that is taken back goes', () async {
    sender.pause();
    await repository.queueUpload(
      1,
      sourcePath: picked('a', const [1]).path,
      fileName: 'a',
    );
    await repository.deleteTask(1);
    expect(
      await repository.queueUpload(
        1,
        sourcePath: picked('b', const [2]).path,
        fileName: 'b',
      ),
      isNull,
    );

    await repository.restoreTask(1);
    await sender.resume();

    expect(write.requests, ['upload 1 a']);
    expect(await db.outboxDao.count(), 0);
    expect(stored(), isEmpty);
  });

  group('a delete that was sent, on a server with the trash', () {
    late Task task;
    late FakeTrashPort trash;
    var offline = false;

    setUp(() {
      task = write.serverTasks[1]!;
      trash = FakeTrashPort()..restoredTasks[1] = task;
      trash.beforeCall = (call) async {
        if (call == 'restoreTask 1' &&
            !trash.failures.containsKey('restoreTask')) {
          write.serverTasks[1] = task;
        }
      };
      build(trash: trash);
      offline = false;
      write.beforeRequest = (request) async {
        if (offline && request.startsWith('upload')) {
          throw const NetworkFailure(NetworkProblem.unreachable);
        }
      };
    });

    Future<void> queueUploads(List<String> names) async {
      for (final name in names) {
        await repository.queueUpload(
          1,
          sourcePath: picked(name, const [1]).path,
          fileName: name,
        );
      }
      await sender.drain();
    }

    Future<void> deleteAndSend() async {
      expect(await repository.deleteTask(1), TaskDeletion.queued);
      await sender.drain();
      expect(write.requests.last, 'delete 1');
      expect(await db.outboxDao.count(), 0);
    }

    test('files of the task not uploaded yet come back with the Undo and '
        'upload once the task is restored', () async {
      offline = true;
      await queueUploads(['a', 'b']);
      await deleteAndSend();

      expect(stored(), hasLength(2));
      expect(await db.outboxDao.loadProblems(), isEmpty);

      offline = false;
      // The Undo comes after the uploads' backoff.
      now = now.add(const Duration(seconds: 3));
      final before = write.requests.length;
      await repository.restoreTask(1);
      await sender.drain();

      expect(trash.calls, ['restoreTask 1']);
      expect(write.requests.sublist(before), ['upload 1 a', 'upload 1 b']);
      expect(write.serverAttachments[1]!.map((file) => file.name), ['a', 'b']);
      expect(await db.outboxDao.count(), 0);
      expect(stored(), isEmpty);
    });

    test('a file that had failed as a sync problem comes back with the Undo '
        'as that problem, and Retry uploads it', () async {
      var refused = true;
      write.beforeRequest = (request) async {
        if (refused && request.startsWith('upload')) throw const Forbidden();
      };
      await queueUploads(['a']);
      expect((await db.outboxDao.loadProblems()).single.fileName, 'a');
      await deleteAndSend();

      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(stored(), hasLength(1));

      refused = false;
      await repository.restoreTask(1);
      await sender.drain();

      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.fileName, 'a');
      expect(problem.failure, isA<Forbidden>());
      expect(write.requests.last, 'delete 1');

      await repository.retrySyncProblem(problem.operationId);

      expect(write.requests.last, 'upload 1 a');
      expect(write.serverAttachments[1], hasLength(1));
      expect(await db.outboxDao.count(), 0);
      expect(stored(), isEmpty);
    });

    test('once the Undo window is over the files and their copies go, and a '
        'later restore from the trash brings the task back without '
        'them', () async {
      offline = true;
      await queueUploads(['a']);
      await deleteAndSend();
      expect(stored(), hasLength(1));
      expect(timers.pendingWait, OutboxSender.setAsideFor);

      now = now.add(OutboxSender.setAsideFor + const Duration(seconds: 1));
      timers.fireNext();
      await until(() => stored().isEmpty);

      offline = false;
      final before = write.requests.length;
      await repository.restoreTask(1);
      await sender.drain();

      expect(trash.calls, ['restoreTask 1']);
      expect(await db.tasksDao.find(1), isNotNull);
      expect(write.requests.sublist(before), isEmpty);
      expect(await db.outboxDao.count(), 0);
    });

    test('a restore that fails keeps the files for the Undo offered '
        'again', () async {
      offline = true;
      await queueUploads(['a']);
      await deleteAndSend();
      trash.failures['restoreTask'] = const NetworkFailure(
        NetworkProblem.unreachable,
      );

      await expectLater(
        repository.restoreTask(1),
        throwsA(isA<NetworkFailure>()),
      );

      final later = OutboxSender.setAsideFor + const Duration(seconds: 1);
      now = now.add(later);
      timers.fireNext();
      // Armed again for the hold of the restore that failed.
      await until(() => timers.active.isNotEmpty);
      expect(timers.pendingWait, OutboxSender.staleSendingAfter - later);
      expect(stored(), hasLength(1));

      trash.failures.clear();
      offline = false;
      await repository.restoreTask(1);
      await sender.drain();

      expect(trash.calls, ['restoreTask 1', 'restoreTask 1']);
      expect(write.requests.last, 'upload 1 a');
      expect(write.serverAttachments[1], hasLength(1));
      expect(stored(), isEmpty);
    });

    test('an Undo still offered, as under a screen reader, holds the files '
        'past its window and past a clock set back; its restore brings them '
        'back', () async {
      offline = true;
      await queueUploads(['a']);
      final release = repository.holdForUndo([1]);
      await deleteAndSend();

      expect(timers.active, isEmpty);
      final deleted = now;
      now = deleted.subtract(const Duration(hours: 1));
      await sender.sweepUploads();
      now = deleted.add(OutboxSender.staleSendingAfter * 2);
      await sender.sweepUploads();
      expect(stored(), hasLength(1));
      expect(timers.active, isEmpty);

      offline = false;
      final before = write.requests.length;
      await repository.restoreTask(1);
      await sender.drain();
      release();

      expect(trash.calls, ['restoreTask 1']);
      expect(write.requests.sublist(before), ['upload 1 a']);
      expect(write.serverAttachments[1], hasLength(1));
      expect(await db.outboxDao.count(), 0);
      await until(() => stored().isEmpty);
    });

    test('a hold let go leaves the files to their time, and two holds of a '
        'task keep them until both are let go', () async {
      offline = true;
      await queueUploads(['a']);
      final first = repository.holdForUndo([1]);
      final second = repository.holdForUndo([1, 1]);
      await deleteAndSend();
      now = now.add(const Duration(seconds: 3));

      first();
      first();
      await pumpEventQueue();
      expect(timers.active, isEmpty);

      second();
      await until(() => timers.active.isNotEmpty);
      expect(
        timers.pendingWait,
        OutboxSender.setAsideFor - const Duration(seconds: 3),
      );
      expect(stored(), hasLength(1));

      now = now.add(OutboxSender.setAsideFor);
      timers.fireNext();
      await until(() => stored().isEmpty);
      expect(await db.outboxDao.uploadFiles(), isEmpty);
    });

    test('a hold over several tasks keeps the files of the last one while '
        'slow restores of the others go first', () async {
      final other = sampleTask(id: 2, title: 'Two', projectId: 7);
      await db.tasksDao.upsertAll([other], syncRunId: 'run');
      write.serverTasks[2] = other;
      read.allTasks = [task, other];
      trash.restoredTasks[2] = other;
      offline = true;
      await queueUploads(['a']);
      await repository.queueUpload(
        2,
        sourcePath: picked('b', const [2]).path,
        fileName: 'b',
      );
      await sender.drain();
      final release = repository.holdForUndo([1, 2]);
      expect(await repository.deleteTask(1), TaskDeletion.queued);
      expect(await repository.deleteTask(2), TaskDeletion.queued);
      await sender.drain();
      expect(await db.outboxDao.count(), 0);
      offline = false;
      trash.beforeCall = (call) async {
        if (call == 'restoreTask 1') {
          write.serverTasks[1] = task;
          // A slow restore, and a sweep before the next one starts.
          now = now.add(OutboxSender.setAsideFor * 2);
          await sender.sweepUploads();
        } else if (call == 'restoreTask 2') {
          write.serverTasks[2] = other;
        }
      };

      final before = write.requests.length;
      await repository.restoreTask(1);
      await repository.restoreTask(2);
      await sender.drain();
      release();

      expect(trash.calls, ['restoreTask 1', 'restoreTask 2']);
      expect(write.requests.sublist(before), ['upload 1 a', 'upload 2 b']);
      expect(write.serverAttachments[2], hasLength(1));
      await until(() => stored().isEmpty);
    });

    // In real time: testWidgets' fake clock would hold the file I/O of the
    // sweep and the upload.
    test('an Undo while the delete is on its way waits for it and brings the '
        'files back too', () async {
      offline = true;
      await queueUploads(['a']);
      final gate = RequestGate()..pattern = 'delete';
      write.beforeRequest = (request) async {
        if (offline && request.startsWith('upload')) {
          throw const NetworkFailure(NetworkProblem.unreachable);
        }
        await gate(request);
      };
      expect(await repository.deleteTask(1), TaskDeletion.queued);
      await until(() => gate.isHolding);
      offline = false;
      now = now.add(const Duration(seconds: 3));

      Task? restored;
      final restoring = repository.restoreTask(1).then((task) {
        restored = task;
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(restored, isNull);
      expect(trash.calls, isEmpty);

      gate.release();
      await restoring;
      await sender.drain();

      expect(trash.calls, ['restoreTask 1']);
      expect(restored!.id, 1);
      expect(write.requests.sublist(write.requests.indexOf('delete 1')), [
        'delete 1',
        'upload 1 a',
      ]);
      expect(write.serverAttachments[1], hasLength(1));
      expect(await db.outboxDao.count(), 0);
      expect(stored(), isEmpty);
    });
  });

  test('deleting a task whose create the server refused drops its uploads '
      'and their copies at once', () async {
    write.beforeRequest = (_) async => throw const DomainError(400, code: 4001);
    final id = await repository.createTask(
      const NewTask(projectId: 7, title: 'New'),
    );
    await repository.queueUpload(
      id,
      sourcePath: picked('a', const [1]).path,
      fileName: 'a',
    );
    await sender.drain();
    expect(stored(), hasLength(1));

    expect(await repository.deleteTask(id), TaskDeletion.discarded);
    expect(await db.outboxDao.count(), 0);

    // deleteTask does not await the sweep of the copies, and its file I/O
    // can outlast any fixed number of event loop turns under load.
    final waited = Stopwatch()..start();
    while (stored().isNotEmpty && waited.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(stored(), isEmpty);
  });
}
