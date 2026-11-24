import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_cache.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';
import 'package:vikunja_mobile/core/attachments/upload_files.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/upload_json.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/task_details_fakes.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

void main() {
  late AppDatabase db;
  late FakeSyncClient read;
  late FakeWriteClient write;
  late Directory cache;
  late AttachmentDownloads downloads;
  late Directory imageFolder;
  late ImageDiskCache disk;
  late AttachmentImageCache images;
  late OutboxSender sender;
  late LocalAttachmentRepository repository;
  const accountId = 'acc1';
  const photo = TaskAttachment(id: 300, taskId: 1, name: 'photo.png', size: 3);
  const offline = NetworkFailure(NetworkProblem.unreachable);
  final now = DateTime.utc(2026, 11, 19, 12);

  LocalAttachmentRepository repositoryWith({int maxUploadBytes = 1024}) =>
      LocalAttachmentRepository(
        db,
        read,
        write,
        downloads,
        outbox: sender,
        accountId: accountId,
        images: images,
        uploadsEnabled: true,
        maxUploadBytes: maxUploadBytes,
        now: () => now,
      );

  Future<TaskChanges?> queued() => db.outboxDao.pendingChangesFor(1);

  Future<TaskDetails> stored() async =>
      (await db.taskDetailsDao.storedDetails(1))!.value;

  AttachmentImageCache imagesOver(ImageDiskCache disk) => AttachmentImageCache(
    (taskId, attachmentId, preview) =>
        read.attachments.fetch(taskId, attachmentId, preview: preview),
    disk: disk,
  );

  List<String> keptImages() => imageFolder.existsSync()
      ? ([for (final file in imageFolder.listSync()) p.basename(file.path)]
          ..sort())
      : [];

  setUp(() async {
    db = testDatabase();
    read = FakeSyncClient();
    write = FakeWriteClient(clock: () => now);
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: RecordingSyncEngine(),
      now: () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    cache = Directory.systemTemp.createTempSync('attachment_repo_test');
    addTearDown(() => cache.deleteSync(recursive: true));
    downloads = AttachmentDownloads(() async => cache);
    imageFolder = Directory(p.join(cache.path, 'images', accountId));
    disk = ImageDiskCache(() async => imageFolder);
    images = imagesOver(disk);
    repository = repositoryWith();
    final task = sampleTask(id: 1, title: 'One', projectId: 7);
    read.allTasks = [task];
    write.serverTasks[1] = task;
    write.serverAttachments[1] = [photo];
    await db.tasksDao.upsertAll([task]);
  });

  test('a delete sends the delete alone and leaves the cover, as the server '
      'keeps the id of a deleted cover', () async {
    write.covers[1] = 300;

    await repository.delete(1, 300);

    expect(write.requests, ['delete attachment 1 300']);
    expect(write.covers[1], 300);
    expect(write.serverAttachments[1], isEmpty);
  });

  test('clearing the cover and then deleting its attachment sends the clear '
      'through the queue first', () async {
    write.covers[1] = 300;

    await repository.setCover(1, null);
    await repository.delete(1, 300);

    expect(write.requests, ['update 1', 'delete attachment 1 300']);
    expect(
      write.updates.single.$2,
      const TaskChanges(coverImageAttachmentId: 0),
    );
    expect(write.covers[1], 0);
    expect(await db.outboxDao.count(), 0);
  });

  test('offline, a cover cleared and then a delete of its attachment is '
      'refused with the network failure; the clear stays queued and the '
      'attachment stays', () async {
    write
      ..covers[1] = 300
      ..beforeRequest = (_) async => throw offline;

    await repository.setCover(1, null);
    await expectLater(
      repository.delete(1, 300),
      throwsA(isA<NetworkFailure>()),
    );

    expect(write.requests, isNotEmpty);
    expect(write.requests, everyElement('update 1'));
    expect(await queued(), const TaskChanges(coverImageAttachmentId: 0));
    expect(write.serverAttachments[1], [photo]);
    expect(write.covers[1], 300);
  });

  test(
    'a Delete tried again while the cover clear is still queued sends the '
    'clear first, though the attachment no longer shows as the cover',
    () async {
      write
        ..covers[1] = 300
        ..beforeRequest = (_) async => throw offline;
      await repository.setCover(1, null);
      await expectLater(
        repository.delete(1, 300),
        throwsA(isA<NetworkFailure>()),
      );

      write
        ..beforeRequest = null
        ..requests.clear();
      await repository.delete(1, 300);

      expect(write.requests, ['update 1', 'delete attachment 1 300']);
      expect(write.covers[1], 0);
      expect(write.serverAttachments[1], isEmpty);
      expect(await db.outboxDao.count(), 0);
    },
  );

  test('the cover clear sent before a delete waits neither for an upload on '
      'its way nor for one backing off', () async {
    final folder = Directory(p.join(cache.path, 'uploads'));
    final files = UploadFiles(() async => folder);
    final timers = FakeTimers();
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: RecordingSyncEngine(),
      now: () => now,
      createTimer: timers.create,
      random: ZeroRandom(),
      uploads: files,
    );
    addTearDown(sender.dispose);
    repository = repositoryWith();
    Future<void> queueFile(String name) async {
      final stored = await files.store(
        File(p.join(cache.path, name))..writeAsBytesSync(const [1]),
      );
      files.release(stored.name);
      await db.outboxDao.queueUpload(
        1,
        QueuedUpload(file: stored.name, fileName: name, size: stored.size),
        now: now,
      );
    }

    await queueFile('later.png');
    final later = (await db.outboxDao.all()).single.id;
    await db.outboxDao.scheduleRetry(
      later,
      attempts: 1,
      failure: const ServerFailure(503),
      nextAttemptAt: now.add(const Duration(minutes: 1)),
    );
    await queueFile('big.png');
    final reached = Completer<void>();
    final held = Completer<void>();
    write
      ..covers[1] = 300
      ..beforeRequest = (request) async {
        if (!request.startsWith('upload')) return;
        reached.complete();
        await held.future;
      };
    final draining = sender.drain();
    await reached.future;

    await repository.setCover(1, null);
    await repository.delete(1, 300);

    expect(write.requests, [
      'upload 1 big.png',
      'update 1',
      'delete attachment 1 300',
    ]);
    expect(write.covers[1], 0);
    expect(held.isCompleted, isFalse);
    final waiting = await db.outboxDao.find(later);
    expect(waiting!.nextAttemptAt, now.add(const Duration(minutes: 1)));

    held.complete();
    await draining;
    expect(write.serverAttachments[1]!.map((file) => file.name), ['big.png']);
    expect(await db.outboxDao.count(), 1);
  });

  test('a cover change the server refused for good holds the delete back as '
      'not synced yet', () async {
    write
      ..covers[1] = 300
      ..beforeRequest = (request) async {
        if (request.startsWith('update')) throw const Forbidden();
      };

    await repository.setCover(1, null);
    await expectLater(
      repository.delete(1, 300),
      throwsA(isA<TaskNotSyncedYet>()),
    );

    expect(write.requests, isNot(contains('delete attachment 1 300')));
    expect(write.serverAttachments[1], [photo]);
    final problem = (await db.outboxDao.loadProblems()).single;
    expect(problem.kind, OutboxOperationKind.updateTask);
    expect(problem.failure, isA<Forbidden>());
  });

  test('a cover for a task queued for deletion is refused as gone, and '
      'nothing is queued', () async {
    await db.outboxDao.queueDelete(1, now: now);

    await expectLater(
      repository.setCover(1, 300),
      throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
    );

    expect(await db.outboxDao.count(), 1);
    expect(await queued(), isNull);
  });

  test('a cover cleared before a delete that fails stays cleared, on the '
      'server and in what is stored', () async {
    await db.taskDetailsDao.storeDetails(
      1,
      const TaskDetails(attachments: [photo], coverImageAttachmentId: 300),
      at: now,
    );
    write
      ..covers[1] = 300
      ..beforeRequest = (request) async {
        if (request.startsWith('delete attachment')) throw offline;
      };

    await repository.setCover(1, null);
    await expectLater(
      repository.delete(1, 300),
      throwsA(isA<NetworkFailure>()),
    );

    expect(write.requests, ['update 1', 'delete attachment 1 300']);
    expect(write.covers[1], 0);
    expect((await stored()).coverImageAttachmentId, 0);
    expect((await stored()).attachments, [photo]);
  });

  test('a delete removes the downloaded copy', () async {
    final file = await downloads.fileFor(accountId, 1, photo);
    file.createSync(recursive: true);

    await repository.delete(1, 300);

    expect(write.requests, ['delete attachment 1 300']);
    expect(file.parent.existsSync(), isFalse);
  });

  test('a delete drops every size of its images, in memory and on disk, so '
      'an image in the description does not show it after a restart '
      'offline', () async {
    for (final id in [300, 301]) {
      for (final preview in [
        AttachmentPreviewSize.medium,
        AttachmentPreviewSize.extraLarge,
        null,
      ]) {
        read.attachmentBlobs[(1, id, preview)] = AttachmentBlob(
          bytes: samplePngBytes,
          contentType: 'image/png',
        );
        await images.load(1, id, preview: preview);
      }
    }
    await disk.flush();
    expect(keptImages(), hasLength(6));

    await repository.delete(1, 300);

    expect(images.peek(1, 300, preview: AttachmentPreviewSize.medium), isNull);
    expect(
      images.peek(1, 300, preview: AttachmentPreviewSize.extraLarge),
      isNull,
    );
    expect(images.peek(1, 300), isNull);
    expect(images.peek(1, 301), isNotNull);
    expect(keptImages(), [
      'attachment-1-301-md',
      'attachment-1-301-original',
      'attachment-1-301-xl',
    ]);
    read.beforeRequest = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    final restarted = imagesOver(ImageDiskCache(() async => imageFolder));
    await expectLater(
      restarted.load(1, 300, preview: AttachmentPreviewSize.extraLarge),
      throwsA(isA<NetworkFailure>()),
    );
    expect(
      (await restarted.load(
        1,
        301,
        preview: AttachmentPreviewSize.extraLarge,
      )).bytes,
      samplePngBytes,
    );
  });

  test('the cover is queued like an edit: stored at once, offline too, and '
      'sent by the sender', () async {
    await db.taskDetailsDao.storeDetails(
      1,
      const TaskDetails(attachments: [photo]),
      at: now,
    );
    write.beforeRequest = (_) async => throw offline;

    await repository.setCover(1, 300);
    await pumpEventQueue();

    expect((await stored()).coverImageAttachmentId, 300);
    expect(
      (await db.outboxDao.all()).single.kind,
      OutboxOperationKind.updateTask.name,
    );
    expect(write.updates, isEmpty);

    write
      ..beforeRequest = null
      ..requests.clear();
    await sender.sendNow();

    expect(write.requests, ['update 1']);
    expect(write.covers[1], 300);
    expect(await db.outboxDao.count(), 0);

    write.beforeRequest = (_) async => throw offline;
    await repository.setCover(1, 301);
    await pumpEventQueue();
    await repository.setCover(1, null);
    await pumpEventQueue();

    expect(await db.outboxDao.count(), 1);
    expect(await queued(), const TaskChanges(coverImageAttachmentId: 0));
    expect((await stored()).coverImageAttachmentId, 0);

    write
      ..beforeRequest = null
      ..requests.clear();
    await sender.sendNow();

    expect(write.requests, ['update 1']);
    expect(write.updates.last.$2, const TaskChanges(coverImageAttachmentId: 0));
    expect(write.covers[1], 0);
    expect(await db.outboxDao.count(), 0);
  });

  test(
    'a download goes to the cache and is reused while its size matches',
    () async {
      read.attachmentBlobs[(1, 300, null)] = AttachmentBlob(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        contentType: 'image/png',
      );

      final file = await repository.download(1, photo);
      final again = await repository.download(1, photo);

      expect(file.readAsBytesSync(), const [1, 2, 3]);
      expect(
        file.path,
        p.join(cache.path, 'attachments', accountId, '1', '300', 'photo.png'),
      );
      expect(again.path, file.path);
      expect(read.requests, ['download 1 300']);
    },
  );

  test('a cancelled download fails with the cancel', () async {
    final cancel = CancelToken()..cancel();
    await expectLater(
      repository.download(1, photo, cancel: cancel),
      throwsA(isA<Object>()),
    );
  });

  test(
    'an upload now sends the file with timeouts for its size and a safe name',
    () async {
      final file = File(p.join(cache.path, 'picked'))
        ..writeAsBytesSync(const [5, 6]);

      final attachment = await repository.uploadNow(
        1,
        file,
        fileName: 'a/b.png',
        mimeType: 'image/png',
      );

      expect(write.requests, ['upload 1 a_b.png']);
      expect(write.uploadTimeouts, [uploadTimeoutFor(2)]);
      expect(attachment.size, 2);
      expect(write.uploadedBytes[attachment.id], const [5, 6]);
    },
  );

  test('a file above the limit is refused before any request', () async {
    final file = File(p.join(cache.path, 'big'))
      ..writeAsBytesSync(List.filled(11, 0));

    await expectLater(
      repositoryWith(maxUploadBytes: 10).uploadNow(1, file, fileName: 'big'),
      throwsA(
        isA<UploadTooLarge>()
            .having((e) => e.size, 'size', 11)
            .having((e) => e.maxBytes, 'maxBytes', 10),
      ),
    );
    expect(write.requests, isEmpty);
  });

  test('a task whose create is queued is not synced yet', () async {
    final localId = await db.outboxDao.queueCreate(
      const NewTask(title: 'New', projectId: 7),
      now: DateTime.utc(2026),
    );

    await expectLater(
      repository.setCover(localId, 1),
      throwsA(isA<TaskNotSyncedYet>()),
    );
    expect(write.requests, isEmpty);
  });

  test('a refusal comes through', () async {
    write.beforeRequest = (_) async => throw const DomainError(412, code: 3008);

    await expectLater(
      repository.delete(1, 300),
      throwsA(isA<DomainError>().having((e) => e.code, 'code', 3008)),
    );
  });

  group("the task's stored details follow what the server took", () {
    final morning = DateTime.utc(2026, 11, 19, 8);
    const pdf = TaskAttachment(id: 301, taskId: 1, name: 'pass.pdf', size: 4);

    setUp(() async {
      await db.taskDetailsDao.storeDetails(
        1,
        const TaskDetails(
          attachments: [photo, pdf],
          coverImageAttachmentId: 300,
        ),
        at: morning,
      );
      write.serverAttachments[1] = [photo, pdf];
    });

    test('a delete, with the cover it was; a cover set, at once before it '
        'is sent', () async {
      await repository.delete(1, 300);
      expect((await stored()).attachments, [pdf]);
      expect((await stored()).coverImageAttachmentId, 0);

      final gate = RequestGate()..pattern = 'update';
      write.beforeRequest = gate.call;
      await repository.setCover(1, 301);
      expect((await stored()).coverImageAttachmentId, 301);
      await repository.setCover(1, null);
      expect((await stored()).coverImageAttachmentId, 0);
      expect(write.updates, isEmpty);

      gate
        ..pattern = null
        ..release();
      await sender.drain();
      expect(write.covers[1], 0);
      expect((await stored()).coverImageAttachmentId, 0);
    });

    test('an upload now, last', () async {
      final file = File(p.join(cache.path, 'picked'))
        ..writeAsBytesSync(const [5, 6]);
      write.nextAttachmentId = 400;

      final attachment = await repository.uploadNow(
        1,
        file,
        fileName: 'scan.png',
      );

      expect((await stored()).attachments, [photo, pdf, attachment]);
    });

    test('a refused delete changes nothing', () async {
      write.beforeRequest = (_) async => throw offline;

      await expectLater(
        repository.delete(1, 300),
        throwsA(isA<NetworkFailure>()),
      );

      expect((await stored()).attachments, [photo, pdf]);
      expect((await stored()).coverImageAttachmentId, 300);
    });

    test('a cover that cannot be stored is not queued either', () async {
      await db.customStatement(
        'CREATE TRIGGER no_cover BEFORE UPDATE ON task_detail_loads '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );

      await expectLater(repository.setCover(1, 301), throwsA(anything));

      expect(await db.outboxDao.count(), 0);
      expect((await stored()).coverImageAttachmentId, 300);
      expect(write.requests, isEmpty);
    });

    test('a delete or an upload now that cannot be stored stands on the '
        'server and does not fail', () async {
      for (final event in ['DELETE', 'INSERT']) {
        await db.customStatement(
          'CREATE TRIGGER no_${event.toLowerCase()} BEFORE $event ON '
          "task_attachments BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        );
      }

      await repository.delete(1, 300);

      expect(write.serverAttachments[1], [pdf]);
      expect((await stored()).attachments, [photo, pdf]);

      final file = File(p.join(cache.path, 'picked'))
        ..writeAsBytesSync(const [5, 6]);
      final attachment = await repository.uploadNow(
        1,
        file,
        fileName: 'scan.png',
      );

      expect(write.serverAttachments[1], [pdf, attachment]);
      expect((await stored()).attachments, [photo, pdf]);
    });
  });

  group('on a server without the v2 API, beside an edit of the task on its '
      'way', () {
    late RequestGate gate;
    late Future<void> draining;

    setUp(() async {
      write.replacesWholeTask = true;
      gate = RequestGate()..pattern = 'update 1';
      write.beforeRequest = gate.call;
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(title: 'Renamed'),
        now: now,
      );
    });

    Future<void> editOnItsWay() async {
      draining = sender.drain();
      for (var i = 0; i < 100 && !gate.isHolding; i++) {
        await pumpEventQueue(times: 1);
      }
      expect(gate.isHolding, isTrue);
    }

    Future<void> releaseAndSettle(Future<void> change) async {
      gate
        ..pattern = null
        ..release();
      await change;
      await draining;
      await sender.drain();
    }

    test('a cover set goes after the edit, and neither is reverted', () async {
      await editOnItsWay();

      final setting = repository.setCover(1, 300);
      await pumpEventQueue();
      expect(write.requests, ['update 1']);
      await releaseAndSettle(setting);

      expect(write.requests, ['update 1', 'update 1']);
      expect(write.serverTasks[1]!.title, 'Renamed');
      expect(write.covers[1], 300);
      expect(await db.outboxDao.count(), 0);
    });

    test(
      'a cover removed goes after the edit, and neither is reverted',
      () async {
        write.covers[1] = 300;
        await editOnItsWay();

        final removing = repository.setCover(1, null);
        await pumpEventQueue();
        expect(write.requests, ['update 1']);
        await releaseAndSettle(removing);

        expect(write.requests, ['update 1', 'update 1']);
        expect(write.serverTasks[1]!.title, 'Renamed');
        expect(write.covers[1], 0);
        expect(await db.outboxDao.count(), 0);
      },
    );

    test('deleting the cover attachment clears the cover after the edit, then '
        'deletes the file', () async {
      write.covers[1] = 300;
      await editOnItsWay();

      final deleting = () async {
        await repository.setCover(1, null);
        await repository.delete(1, 300);
      }();
      await pumpEventQueue();
      expect(write.requests, ['update 1']);
      await releaseAndSettle(deleting);

      expect(write.requests, [
        'update 1',
        'update 1',
        'delete attachment 1 300',
      ]);
      expect(write.serverTasks[1]!.title, 'Renamed');
      expect(write.covers[1], 0);
      expect(write.serverAttachments[1], isEmpty);
      expect(await db.outboxDao.count(), 0);
    });
  });

  test('offline, a download in the cache opens from the stored details; one '
      'that is not needs the connection', () async {
    await db.taskDetailsDao.storeDetails(
      1,
      const TaskDetails(attachments: [photo]),
      at: DateTime.utc(2026, 11, 19, 8),
    );
    final cached = await downloads.fileFor(accountId, 1, photo);
    cached
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [1, 2, 3]);
    read.beforeRequest = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    final listed = (await db.taskDetailsDao.storedDetails(1))!.value;

    final file = await repository.download(1, listed.attachments.single);
    await expectLater(
      repository.download(
        1,
        const TaskAttachment(id: 302, taskId: 1, name: 'b.pdf', size: 3),
      ),
      throwsA(isA<NetworkFailure>()),
    );

    expect(file.readAsBytesSync(), const [1, 2, 3]);
    expect(read.requests, ['download 1 302']);
  });
}
