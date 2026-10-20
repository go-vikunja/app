import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeSyncClient read;
  late FakeWriteClient write;
  late Directory cache;
  late AttachmentDownloads downloads;
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
        uploadsEnabled: true,
        maxUploadBytes: maxUploadBytes,
      );

  setUp(() async {
    db = testDatabase();
    read = FakeSyncClient();
    write = FakeWriteClient();
    cache = Directory.systemTemp.createTempSync('attachment_repo_test');
    addTearDown(() => cache.deleteSync(recursive: true));
    downloads = AttachmentDownloads(() async => cache);
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
}
