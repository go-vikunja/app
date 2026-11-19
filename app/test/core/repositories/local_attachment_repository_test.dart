import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_cache.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/task_details_fakes.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeSyncClient read;
  late FakeWriteClient write;
  late Directory cache;
  late AttachmentDownloads downloads;
  late Directory imageFolder;
  late ImageDiskCache disk;
  late AttachmentImageCache images;
  late LocalAttachmentRepository repository;
  const accountId = 'acc1';
  const photo = TaskAttachment(id: 300, taskId: 1, name: 'photo.png', size: 3);

  LocalAttachmentRepository repositoryWith({int maxUploadBytes = 1024}) =>
      LocalAttachmentRepository(
        db,
        read,
        write,
        downloads,
        accountId: accountId,
        images: images,
        uploadsEnabled: true,
        maxUploadBytes: maxUploadBytes,
      );

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
    write = FakeWriteClient();
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

  test('a delete of the cover clears the cover first', () async {
    write.covers[1] = 300;

    await repository.delete(1, 300, isCover: true);

    expect(write.requests, ['update 1', 'delete attachment 1 300']);
    expect(
      write.updates.single.$2,
      const TaskChanges(coverImageAttachmentId: 0),
    );
    expect(write.covers[1], 0);
    expect(write.serverAttachments[1], isEmpty);
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

  test('the cover is set and cleared through the task update', () async {
    await repository.setCover(1, 300);
    await repository.setCover(1, null);

    expect(write.updates.map((update) => update.$2.coverImageAttachmentId), [
      300,
      0,
    ]);
    expect(write.covers[1], 0);
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

    Future<TaskDetails> stored() async =>
        (await db.taskDetailsDao.storedDetails(1))!.value;

    test('a delete, with the cover it was; a cover set', () async {
      await repository.delete(1, 300, isCover: true);
      expect((await stored()).attachments, [pdf]);
      expect((await stored()).coverImageAttachmentId, 0);

      await repository.setCover(1, 301);
      expect((await stored()).coverImageAttachmentId, 301);
      await repository.setCover(1, null);
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

    test('a refused write changes nothing, and a failure to store leaves '
        'the write standing', () async {
      write.beforeRequest = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await expectLater(
        repository.delete(1, 300),
        throwsA(isA<NetworkFailure>()),
      );
      expect((await stored()).attachments, [photo, pdf]);

      write.beforeRequest = null;
      await db.customStatement(
        'CREATE TRIGGER no_cover BEFORE UPDATE ON task_detail_loads '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await repository.setCover(1, 301);
      expect(write.covers[1], 301);
      expect((await stored()).coverImageAttachmentId, 300);
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
