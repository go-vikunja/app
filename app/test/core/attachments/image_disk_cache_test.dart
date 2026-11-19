import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_api/vikunja_api.dart' show maxAttachmentBytes;
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';
import 'package:vikunja_mobile/core/attachments/image_pixels.dart';

import '../../helpers/task_details_fakes.dart';

void main() {
  late Directory root;
  late Directory folder;
  late DateTime now;
  late Map<int, int?> pixelsByLength;

  AttachmentImage image(int size, {String type = 'image/png', int fill = 1}) =>
      AttachmentImage(
        bytes: Uint8List(size)..fillRange(0, size, fill),
        contentType: type,
      );

  /// Without [clock], every look at the time is a minute later.
  ImageDiskCache open({
    int maxBytes = 1000,
    int maxPixels = 1000,
    DateTime Function()? clock,
  }) => ImageDiskCache(
    () async => folder,
    maxBytes: maxBytes,
    maxEntryBytes: 600,
    maxPixels: maxPixels,
    pixelsOf: (bytes) async => pixelsByLength.containsKey(bytes.length)
        ? pixelsByLength[bytes.length]
        : bytes.length,
    now: clock ?? () => now = now.add(const Duration(minutes: 1)),
  );

  List<String> files() {
    if (!folder.existsSync()) return [];
    return [for (final file in folder.listSync()) p.basename(file.path)]
      ..sort();
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('image_disk_cache_test');
    addTearDown(() => root.deleteSync(recursive: true));
    folder = Directory(p.join(root.path, 'images', 'a1b2'));
    now = DateTime(2026, 11, 19, 12);
    pixelsByLength = {};
  });

  test('100 MB per account, one image up to 25 MB and 40 MP', () {
    final defaults = ImageDiskCache(() async => folder);

    expect(defaults.maxBytes, 100 * 1024 * 1024);
    expect(defaults.maxEntryBytes, maxAttachmentBytes);
    expect(defaults.maxPixels, maxImagePixels);
    expect(maxImagePixels, 40 * 1000 * 1000);
  });

  test('an unchanging image kept already is only marked as used, not '
      'written again; another is replaced', () async {
    final cache = open();
    await cache.write('attachment-1-2-xl', image(40));
    await cache.write('avatar-1-32', image(40));
    final kept = File(p.join(folder.path, 'attachment-1-2-xl'));
    final before = kept.lastModifiedSync();

    await cache.write(
      'attachment-1-2-xl',
      image(50, fill: 2),
      unchanging: true,
    );
    await cache.write('avatar-1-32', image(50, fill: 2));

    expect((await cache.read('attachment-1-2-xl'))!.bytes, image(40).bytes);
    expect((await cache.read('avatar-1-32'))!.bytes, image(50, fill: 2).bytes);
    expect(kept.lastModifiedSync().isAfter(before), isTrue);
  });

  test("an account's images sit in its own folder under the root; only "
      'account ids become paths', () async {
    final cache = ImageDiskCache.forAccount(
      () async => Directory(p.join(root.path, 'images')),
      'a1b2',
    );
    await cache.write('avatar-1-32', samplePngImage);
    await cache.flush();

    expect(files(), ['avatar-1-32']);
    expect(
      () => ImageDiskCache.forAccount(() async => root, '../x'),
      throwsArgumentError,
    );
    expect(
      () => ImageDiskCache.forAccount(() async => root, ''),
      throwsArgumentError,
    );
  });

  test('an image kept by one instance is read by the next over the same '
      'folder, as after a restart', () async {
    final before = open();
    await before.write('attachment-1-2-xl', image(10, type: 'image/jpeg'));

    final after = open();
    final read = await after.read('attachment-1-2-xl');

    expect(read?.contentType, 'image/jpeg');
    expect(read?.bytes, image(10).bytes);
    expect(await after.contains('attachment-1-2-xl'), isTrue);
    expect(await after.read('attachment-1-2-original'), isNull);
    expect(await after.contains('attachment-1-2-original'), isFalse);
  });

  test('a real image passes the pixel check of the header', () async {
    final cache = ImageDiskCache(() async => folder);
    await cache.write('attachment-1-2-xl', samplePngImage);

    expect(
      (await ImageDiskCache(() async => folder).read('attachment-1-2-xl'))
          ?.bytes,
      samplePngBytes,
    );
  });

  test('once the bytes pass the bound, the least recently used images go, '
      'a read counting as a use', () async {
    final cache = open();
    await cache.write('a', image(299));
    await cache.write('b', image(299));
    await cache.write('c', image(299));
    expect(cache.storedBytes, 3 * 309, reason: 'with the type line');

    await cache.read('a');
    await cache.write('d', image(299));

    expect(files(), ['a', 'c', 'd']);
    expect(cache.storedBytes, 3 * 309);
    expect(await cache.read('b'), isNull);
  });

  test('the order of use survives a restart', () async {
    final before = open();
    await before.write('a', image(299));
    await before.write('b', image(299));
    await before.write('c', image(299));
    await before.read('a');

    final after = open();
    await after.write('d', image(299));

    expect(files(), ['a', 'c', 'd']);
  });

  test('a smaller bound after a restart evicts at once', () async {
    final before = open();
    await before.write('a', image(299));
    await before.write('b', image(299));

    final after = open(maxBytes: 400);
    expect(await after.contains('a'), isFalse);
    expect(await after.contains('b'), isTrue);
    expect(files(), ['b']);
  });

  test('writing a key again replaces its image and its bytes', () async {
    final cache = open();
    await cache.write('a', image(100));
    await cache.write('a', image(200, fill: 2));

    expect((await cache.read('a'))?.bytes, image(200, fill: 2).bytes);
    expect(cache.storedBytes, 210);
    expect(files(), ['a']);
  });

  group('only raster images within the limits', () {
    test('never an SVG, what is no image, an odd type, nothing empty and '
        'nothing larger than one entry may be', () async {
      final cache = open();
      await cache.write('svg', image(10, type: 'image/svg+xml'));
      await cache.write('text', image(10, type: 'text/plain'));
      await cache.write('binary', image(10, type: 'application/octet-stream'));
      await cache.write('upper', image(10, type: 'IMAGE/PNG'));
      await cache.write('newline', image(10, type: 'image/png\nimage/png'));
      await cache.write('empty', image(0));
      await cache.write('large', image(601));
      await cache.write('fits', image(600));

      expect(files(), ['fits']);
    });

    test('never more pixels than the cap, nor an image whose header cannot '
        'be read', () async {
      pixelsByLength[11] = 1001;
      pixelsByLength[12] = null;
      pixelsByLength[13] = 1000;
      final cache = open();
      await cache.write('many', image(11));
      await cache.write('unreadable', image(12));
      await cache.write('exactly', image(13));

      expect(files(), ['exactly']);
    });

    test('an answer the rules refuse leaves the image kept under its key, '
        'such as a login page in place of an attachment', () async {
      final cache = open();
      await cache.write('attachment-1-2-xl', image(10));
      await cache.write('attachment-1-2-xl', image(10, type: 'text/html'));
      await cache.write('attachment-1-2-xl', image(10, type: 'image/svg+xml'));

      expect((await cache.read('attachment-1-2-xl'))?.contentType, 'image/png');
      expect(files(), ['attachment-1-2-xl']);
      expect(cache.storedBytes, 20);
    });

    test('one the rules refuse removes the image kept under its key when it '
        'replaces it, as a new avatar does', () async {
      final cache = open();
      await cache.write('avatar-1-32', image(10));
      await cache.write(
        'avatar-1-32',
        image(10, type: 'image/svg+xml'),
        refusedRemoves: true,
      );

      expect(await cache.read('avatar-1-32'), isNull);
      expect(files(), isEmpty);
      expect(cache.storedBytes, 0);
    });

    test('they are checked again when read: a file that no longer passes is '
        'dropped', () async {
      await open().write('a', image(20));
      await open().write('b', image(30));

      final stricter = open(maxPixels: 25);
      expect(await stricter.read('b'), isNull);
      expect(await stricter.read('a'), isNotNull);
      expect(files(), ['a']);
    });

    test('a file without its type line, or with an SVG type written by '
        'someone else, is dropped', () async {
      folder.createSync(recursive: true);
      File(p.join(folder.path, 'plain')).writeAsBytesSync(Uint8List(20));
      File(p.join(folder.path, 'svg'))
          .writeAsStringSync('image/svg+xml\n<svg/>');
      final cache = open();

      expect(await cache.read('plain'), isNull);
      expect(await cache.read('svg'), isNull);
      expect(files(), isEmpty);
    });
  });

  test('a write cut short leaves no image behind', () async {
    folder.createSync(recursive: true);
    File(p.join(folder.path, 'a.1f2e.tmp')).writeAsBytesSync(Uint8List(5));
    final cache = open();

    expect(await cache.contains('a'), isFalse);
    expect(files(), isEmpty);
  });

  test('removes one image or every image of a prefix', () async {
    final cache = open();
    for (final key in [
      'attachment-1-2-xl',
      'attachment-1-2-original',
      'attachment-1-23-xl',
      'avatar-ab-32',
    ]) {
      await cache.write(key, image(10));
    }

    await cache.removeStartingWith('attachment-1-2-');
    await cache.remove('avatar-ab-32');

    expect(files(), ['attachment-1-23-xl']);
    expect(cache.storedBytes, 20);
  });

  group('an image unused for 30 days goes', () {
    late DateTime clock;
    const day = Duration(days: 1);

    setUp(() => clock = DateTime(2026, 11, 19, 12));

    test('30 days by default', () {
      expect(ImageDiskCache(() async => folder).maxAge, day * 30);
    });

    test('when the next start loads what is kept; a read is a use', () async {
      final before = open(clock: () => clock);
      await before.write('old', image(10));
      await before.write('read', image(10));
      clock = clock.add(day * 20);
      await before.read('read');

      clock = clock.add(day * 10 + const Duration(minutes: 1));
      final after = open(clock: () => clock);

      expect(await after.contains('read'), isTrue);
      expect(await after.contains('old'), isFalse);
      expect(files(), ['read']);
      expect(after.storedBytes, 20);
    });

    test('when found while the app runs: by a read, a look-up or the next '
        'write', () async {
      final cache = open(clock: () => clock);
      for (final key in ['a', 'b', 'c']) {
        await cache.write(key, image(10));
      }
      clock = clock.add(day * 30 + const Duration(minutes: 1));

      expect(await cache.read('a'), isNull);
      expect(await cache.contains('b'), isFalse);
      expect(files(), ['c']);
      await cache.write('d', image(10));

      expect(files(), ['d']);
      expect(cache.storedBytes, 20, reason: 'with the type line');
    });
  });

  test('the folders of accounts not kept are deleted, nothing else under '
      'the root', () async {
    final images = Directory(p.join(root.path, 'images'));
    for (final name in ['known', 'unknown', 'not an id']) {
      File(p.join(images.path, name, 'avatar-1-32'))
          .createSync(recursive: true);
    }
    File(p.join(images.path, 'stray')).createSync();

    await ImageDiskCache.deleteOtherAccounts(images, {'known'});

    expect(
      [for (final entry in images.listSync()) p.basename(entry.path)]..sort(),
      ['known', 'not an id', 'stray'],
    );
    await expectLater(
      ImageDiskCache.deleteOtherAccounts(
        Directory(p.join(root.path, 'none')),
        {},
      ),
      completes,
    );
  });

  test('the index is read without a sync file system call per image, on '
      'the UI isolate', () async {
    await open().write('a', image(10));

    final found = await IOOverrides.runZoned(
      () => open().contains('a'),
      statSync: (_) => throw StateError('a sync stat'),
    );

    expect(found, isTrue);
  });

  test('closing skips what was asked for and has not started', () async {
    final cache = open();
    await cache.write('a', image(10));
    final queued = cache.write('b', image(10));
    final read = cache.read('a');

    cache.close();
    await queued;

    expect(await read, isNull);
    expect(files(), ['a']);
  });

  test('deleting all removes the folder once the operation running has '
      'finished, and nothing is read or written after it', () async {
    final cache = open();
    await cache.write('a', image(10));
    final queued = cache.write('b', image(10));

    final deleted = cache.deleteAll();
    await cache.write('c', image(10));
    await queued;
    await deleted;

    expect(folder.existsSync(), isFalse);
    expect(await cache.read('a'), isNull);
    expect(await cache.contains('a'), isFalse);
    expect(folder.existsSync(), isFalse);
  });

  test('deleting a folder that is not there succeeds; one that cannot be '
      'found fails', () async {
    await expectLater(open().deleteAll(), completes);
    await expectLater(
      ImageDiskCache(
        () async => throw const FileSystemException('no cache folder'),
      ).deleteAll(),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('nothing else throws: without its folder it keeps nothing', () async {
    final cache = ImageDiskCache(
      () async => throw const FileSystemException('no cache folder'),
    );

    await expectLater(cache.write('a', samplePngImage), completes);
    expect(await cache.read('a'), isNull);
    expect(await cache.contains('a'), isFalse);
    await expectLater(cache.remove('a'), completes);
  });

  test('only plain keys become file names', () async {
    final cache = open();
    await cache.write('../a', image(10));
    await cache.write('A', image(10));

    expect(await cache.read('../a'), isNull);
    expect(root.listSync(recursive: true), isEmpty);
  });
}
