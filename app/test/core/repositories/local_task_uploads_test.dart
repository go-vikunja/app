import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/upload_json.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';

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
  late OutboxSender sender;
  late LocalTaskRepository repository;
  late Directory root;
  late Directory folder;
  final now = DateTime.utc(2026, 10, 20, 12);

  setUp(() async {
    db = testDatabase();
    root = Directory.systemTemp.createTempSync('task_uploads_test');
    addTearDown(() => root.deleteSync(recursive: true));
    folder = Directory(p.join(root.path, 'uploads'));
    final uploads = UploadFiles(() async => folder);
    write = FakeWriteClient(clock: () => now);
    final sync = RecordingSyncEngine();
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: FakeSyncClient(),
      sync: sync,
      now: () => now,
      createTimer: FakeTimers().create,
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
    );
    final task = sampleTask(id: 1, title: 'One', projectId: 7);
    await db.tasksDao.upsertAll([task], syncRunId: 'run');
    write.serverTasks[1] = task;
  });

  File picked(String name, List<int> bytes) =>
      File(p.join(root.path, name))..writeAsBytesSync(bytes);

  List<String> stored() => folder.existsSync()
      ? [for (final entry in folder.listSync()) p.basename(entry.path)]
      : const [];

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
    held.complete();
    await pumpEventQueue();
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

  test('deleting the task drops its unsent uploads and their copies', () async {
    write.beforeRequest = (_) async => throw const Forbidden();
    await repository.queueUpload(
      1,
      sourcePath: picked('a', const [1]).path,
      fileName: 'a',
    );
    await sender.drain();

    await repository.deleteTask(1);
    await pumpEventQueue();

    expect(stored(), isEmpty);
  });
}
