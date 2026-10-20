import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_mobile/core/attachments/upload_files.dart';

void main() {
  late Directory root;
  late Directory folder;
  late UploadFiles uploads;

  setUp(() {
    root = Directory.systemTemp.createTempSync('upload_files_test');
    addTearDown(() => root.deleteSync(recursive: true));
    folder = Directory(p.join(root.path, 'accounts', 'a1', 'uploads'));
    uploads = UploadFiles(() async => folder);
  });

  File source(String name, List<int> bytes) =>
      File(p.join(root.path, name))..writeAsBytesSync(bytes);

  test(
    'a copy goes into the folder under a random name; the source stays',
    () async {
      final picked = source('evil name.png', const [1, 2, 3]);

      final stored = await uploads.store(picked);

      expect(stored.size, 3);
      expect(stored.name, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(UploadFiles.isStoredName(stored.name), isTrue);
      final file = await uploads.fileFor(stored.name);
      expect(p.dirname(file.path), folder.path);
      expect(file.readAsBytesSync(), const [1, 2, 3]);
      expect(picked.existsSync(), isTrue);
      expect(
        (await uploads.store(picked)).name,
        isNot(stored.name),
        reason: 'two copies of one file never share a name',
      );
    },
  );

  test('a move takes the file away from where it was', () async {
    final inbox = source('inbox-copy', const [4, 5]);

    final stored = await uploads.store(inbox, move: true);

    expect(inbox.existsSync(), isFalse);
    expect((await uploads.fileFor(stored.name)).readAsBytesSync(), const [
      4,
      5,
    ]);
  });

  test('a source that cannot be read leaves nothing behind', () async {
    await expectLater(
      uploads.store(File(p.join(root.path, 'missing'))),
      throwsA(isA<FileSystemException>()),
    );
    expect(folder.listSync(), isEmpty);
  });

  test('only stored names become paths; deleting is forgiving', () async {
    expect(() => uploads.fileFor('../vikunja.db'), throwsArgumentError);
    await uploads.delete('../vikunja.db');
    await uploads.delete('a' * 32);
    expect(UploadFiles.isStoredName(''), isFalse);
  });

  test(
    'a sweep deletes copies no op names, but not one being queued',
    () async {
      final kept = await uploads.store(source('a', const [1]));
      uploads.release(kept.name);
      final orphan = await uploads.store(source('b', const [2]));
      uploads.release(orphan.name);
      final queueing = await uploads.store(source('c', const [3]));

      expect(await uploads.sweep(() async => {kept.name}), 1);

      expect((await uploads.fileFor(kept.name)).existsSync(), isTrue);
      expect((await uploads.fileFor(orphan.name)).existsSync(), isFalse);
      expect((await uploads.fileFor(queueing.name)).existsSync(), isTrue);

      uploads.release(queueing.name);
      expect(await uploads.sweep(() async => {kept.name}), 1);
    },
  );

  test('a copy queued while the sweep reads the queue is kept', () async {
    final orphan = await uploads.store(source('d', const [4]));
    uploads.release(orphan.name);
    StoredUpload? queued;

    final deleted = await uploads.sweep(() async {
      queued = await uploads.store(source('e', const [5]));
      uploads.release(queued!.name);
      return {queued!.name};
    });

    expect(deleted, 1);
    expect((await uploads.fileFor(queued!.name)).existsSync(), isTrue);
    expect((await uploads.fileFor(orphan.name)).existsSync(), isFalse);
  });

  test('a sweep without a folder deletes nothing', () async {
    expect(await uploads.sweep(() async => const {}), 0);
  });
}
