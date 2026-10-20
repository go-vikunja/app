import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';

void main() {
  late Directory cache;
  late DateTime now;
  late AttachmentDownloads downloads;
  const accountId = 'a1b2';
  const photo = TaskAttachment(id: 7, taskId: 3, name: 'photo.png', size: 3);

  setUp(() {
    cache = Directory.systemTemp.createTempSync('downloads_test');
    addTearDown(() => cache.deleteSync(recursive: true));
    now = DateTime(2026, 10, 20, 12);
    downloads = AttachmentDownloads(() async => cache, now: () => now);
  });

  test('a download sits in a folder per account, task and attachment under '
      'its sanitised name', () async {
    final file = await downloads.fileFor(accountId, 3, photo);
    expect(
      file.path,
      p.join(cache.path, 'attachments', accountId, '3', '7', 'photo.png'),
    );

    final hostile = await downloads.fileFor(
      accountId,
      3,
      const TaskAttachment(id: 8, taskId: 3, name: r'..\..\x/../.db'),
    );
    expect(
      p.dirname(hostile.path),
      p.join(cache.path, 'attachments', accountId, '3', '8'),
    );
    expect(p.basename(hostile.path), isNot(contains('/')));

    final dots = await downloads.fileFor(
      accountId,
      3,
      const TaskAttachment(id: 9, taskId: 3, name: '..'),
    );
    expect(p.basename(dots.path), 'file');
  });

  test('only account ids become paths', () async {
    await expectLater(downloads.fileFor('../x', 3, photo), throwsArgumentError);
    await expectLater(downloads.purgeAccount('..'), throwsArgumentError);
  });

  test('a complete download is reused; a different size is not', () async {
    expect(await downloads.cached(accountId, 3, photo), isNull);
    final file = await downloads.fileFor(accountId, 3, photo);
    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(const [1, 2]);
    expect(await downloads.cached(accountId, 3, photo), isNull);

    file
      ..writeAsBytesSync(const [1, 2, 3])
      ..setLastModifiedSync(DateTime(2026));
    final cached = await downloads.cached(accountId, 3, photo);

    expect(cached!.path, file.path);
    expect(file.lastModifiedSync(), now, reason: 'a use keeps it fresh');
  });

  test('forgetting an attachment and purging an account', () async {
    final first = await downloads.fileFor(accountId, 3, photo);
    final second = await downloads.fileFor(
      accountId,
      4,
      const TaskAttachment(id: 9, taskId: 4, name: 'a.txt'),
    );
    final other = await downloads.fileFor('other', 3, photo);
    for (final file in [first, second, other]) {
      file.createSync(recursive: true);
    }

    await downloads.forget(accountId, 3, 7);
    expect(first.parent.existsSync(), isFalse);
    expect(second.existsSync(), isTrue);

    await downloads.purgeAccount(accountId);
    expect(second.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('downloads unused for days go, with their empty folders', () async {
    final stale = await downloads.fileFor(accountId, 3, photo);
    final fresh = await downloads.fileFor(
      accountId,
      4,
      const TaskAttachment(id: 9, taskId: 4, name: 'a.txt'),
    );
    for (final file in [stale, fresh]) {
      file.createSync(recursive: true);
    }
    stale.setLastModifiedSync(now.subtract(const Duration(days: 4)));
    fresh.setLastModifiedSync(now.subtract(const Duration(days: 1)));

    expect(await downloads.purgeStale(), 1);

    expect(stale.parent.parent.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
  });

  test(
    'purging without a cache folder, or with an error, never throws',
    () async {
      expect(await downloads.purgeStale(), 0);
      final failing = AttachmentDownloads(
        () async => throw const FileSystemException('no cache'),
      );
      expect(await failing.purgeStale(), 0);
    },
  );
}
