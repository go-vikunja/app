import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_api/vikunja_api.dart' show maxAttachmentBytes;
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/attachments/image_pixels.dart';

final _log = Logger('ImageDiskCache');

const int _megabyte = 1024 * 1024;

/// One account's images on disk, behind the memory caches of attachment
/// images and avatars: filled by their loads from the account's server,
/// read when the server cannot be asked, so the images show offline and
/// after a restart. In the app's cache folder, which backups leave out.
///
/// At most [maxBytes] together, the least recently used going first, and
/// none unused for [maxAge]; only raster images (`image/*`, never SVG) of
/// at most [maxEntryBytes] whose header names at most [maxPixels], checked
/// again when read. One file per key, written beside it and moved into
/// place. One operation at a time; none throws but [deleteAll], and a file
/// that cannot be read counts as missing.
final class ImageDiskCache {
  new(
    this._directory, {
    this.maxBytes = 100 * _megabyte,
    this.maxEntryBytes = maxAttachmentBytes,
    this.maxPixels = maxImagePixels,
    this.maxAge = const Duration(days: 30),
    ImagePixelCount? pixelsOf,
    DateTime Function()? now,
  }) : _pixelsOf = pixelsOf ?? encodedImagePixels,
       _now = now ?? DateTime.now;

  /// `<root>/<accountId>`.
  factory forAccount(Future<Directory> Function() root, String accountId) {
    if (!_accountIdPattern.hasMatch(accountId)) {
      throw ArgumentError.value(accountId, 'accountId', 'not an account id');
    }
    return ImageDiskCache(
      () async => Directory(p.join((await root()).path, accountId)),
    );
  }

  /// The folder in the app's cache that holds one folder per account.
  static const folder = 'images';

  /// Deletes the folders under [root] of accounts not in [keep], such as
  /// one whose sign-out lost track of it. Never throws.
  static Future<void> deleteOtherAccounts(
    Directory root,
    Set<String> keep,
  ) async {
    final List<FileSystemEntity> others;
    try {
      if (!root.existsSync()) return;
      others = await root.list(followLinks: false).where((entry) {
        final name = p.basename(entry.path);
        return entry is Directory &&
            _accountIdPattern.hasMatch(name) &&
            !keep.contains(name);
      }).toList();
    } on PathNotFoundException {
      return;
    } on Object catch (error) {
      _log.info('Could not look for unknown accounts: ${error.runtimeType}');
      return;
    }
    for (final entry in others) {
      final accountId = p.basename(entry.path);
      try {
        await entry.delete(recursive: true);
        _log.info('Deleted the kept images of unknown account $accountId');
      } on FileSystemException catch (error) {
        _log.info('Could not delete kept images: ${error.runtimeType}');
      }
    }
  }

  final Future<Directory> Function() _directory;
  final int maxBytes;
  final int maxEntryBytes;
  final int maxPixels;
  final Duration maxAge;
  final ImagePixelCount _pixelsOf;
  final DateTime Function() _now;

  static final _accountIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');
  static final _keyPattern = RegExp(r'^[a-z0-9][a-z0-9-]{0,99}$');
  static final _rasterType = RegExp(r'^image/[a-z0-9][a-z0-9.+-]{0,60}$');
  static const _maxHeaderBytes = 72;
  static final _random = Random();

  /// Least recently used first.
  Map<String, _Entry>? _index;
  var _total = 0;
  var _closed = false;
  Future<void> _tail = Future.value();

  /// The bytes the kept images take on disk, as far as this cache knows.
  int get storedBytes => _total;

  /// The image kept under [key], null when there is none or it no longer
  /// passes the rules. Counts as a use.
  Future<AttachmentImage?> read(String key) => _quietly('read', null, () async {
    _checkKey(key);
    if (_closed) return null;
    final index = await _loadIndex();
    final entry = index[key];
    if (entry == null) return null;
    final directory = await _directory();
    if (_expired(entry, _now().subtract(maxAge))) {
      await _delete(index, directory, key);
      return null;
    }
    final file = File(p.join(directory.path, key));
    final image = await _readFile(file);
    if (image == null) {
      await _delete(index, directory, key);
      return null;
    }
    index.remove(key);
    index[key] = (size: entry.size, used: await _markUsed(file));
    return image;
  });

  /// Whether an image is kept under [key], without reading it.
  Future<bool> contains(String key) => _quietly('look up', false, () async {
    _checkKey(key);
    if (_closed) return false;
    final index = await _loadIndex();
    final entry = index[key];
    if (entry == null) return false;
    if (!_expired(entry, _now().subtract(maxAge))) return true;
    await _delete(index, await _directory(), key);
    return false;
  });

  /// Keeps [image] under [key] in place of what was there. One the rules
  /// refuse leaves what was there, unless [refusedRemoves]. With
  /// [unchanging], what is kept under [key] already is only marked as used.
  Future<void> write(
    String key,
    AttachmentImage image, {
    bool refusedRemoves = false,
    bool unchanging = false,
  }) => _quietly('write', null, () async {
    _checkKey(key);
    if (_closed) return;
    final index = await _loadIndex();
    final directory = await _directory();
    if (index[key] case final entry? when unchanging) {
      final file = File(p.join(directory.path, key));
      index[key] = (size: entry.size, used: await _markUsed(file));
      return;
    }
    if (!await _storable(image)) {
      if (refusedRemoves) await _delete(index, directory, key);
      return;
    }
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, key));
    final next = File(
      '${file.path}.${_random.nextInt(1 << 32).toRadixString(16)}.tmp',
    );
    final header = ascii.encode('${image.contentType}\n');
    try {
      final sink = next.openWrite()
        ..add(header)
        ..add(image.bytes);
      await sink.close();
      await next.rename(file.path);
    } on Object {
      await _deleteFile(next);
      rethrow;
    }
    _total -= index.remove(key)?.size ?? 0;
    final size = header.length + image.bytes.length;
    index[key] = (size: size, used: await _markUsed(file));
    _total += size;
    await _evict(index, directory);
  });

  Future<void> remove(String key) => removeWhere((stored) => stored == key);

  /// Removes every image whose key starts with [prefix].
  Future<void> removeStartingWith(String prefix) =>
      removeWhere((key) => key.startsWith(prefix));

  Future<void> removeWhere(bool Function(String key) test) =>
      _quietly('remove', null, () async {
        if (_closed) return;
        final index = await _loadIndex();
        final directory = await _directory();
        for (final key in [...index.keys.where(test)]) {
          await _delete(index, directory, key);
        }
      });

  /// Completes once every operation asked for so far has finished.
  Future<void> flush() => _serial(() async {});

  /// Reads and writes nothing more: what was asked for and has not
  /// started yet is skipped.
  void close() => _closed = true;

  /// [close], then deletes the account's folder once the operation running
  /// has finished. Throws when the folder could not be deleted.
  Future<void> deleteAll() {
    close();
    return _serial(() async {
      _index = {};
      _total = 0;
      final directory = await _directory();
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<T> _quietly<T>(
    String what,
    T fallback,
    Future<T> Function() operation,
  ) => _serial(() async {
    try {
      return await operation();
    } on Object catch (error) {
      _log.info('Could not $what a kept image: ${error.runtimeType}');
      return fallback;
    }
  });

  static void _checkKey(String key) {
    if (!_keyPattern.hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'not an image key');
    }
  }

  Future<Map<String, _Entry>> _loadIndex() async {
    if (_index case final index?) return index;
    final directory = await _directory();
    final found = <(String, _Entry)>[];
    // One sync call per folder, so a cache that keeps nothing yet answers
    // at once.
    if (directory.existsSync()) {
      final kept = <File>[];
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is! File) continue;
        if (!_keyPattern.hasMatch(p.basename(entry.path))) {
          // A write cut short.
          await _deleteFile(entry);
          continue;
        }
        kept.add(entry);
      }
      final stats = await Future.wait([
        // A sync call per kept image would block the UI isolate, and one
        // after the other would hold up the first read.
        // ignore: avoid_slow_async_io
        for (final file in kept) file.stat(),
      ]);
      for (final (i, stat) in stats.indexed) {
        if (stat.type == FileSystemEntityType.notFound) continue;
        found.add((
          p.basename(kept[i].path),
          (size: stat.size, used: stat.modified),
        ));
      }
    }
    found.sort((a, b) => a.$2.used.compareTo(b.$2.used));
    final index = {for (final (name, entry) in found) name: entry};
    _index = index;
    _total = found.fold(0, (sum, found) => sum + found.$2.size);
    await _evict(index, directory);
    return index;
  }

  /// The index is in the order of use, so the expired come first.
  Future<void> _evict(Map<String, _Entry> index, Directory directory) async {
    final cutoff = _now().subtract(maxAge);
    while (index.isNotEmpty &&
        (_total > maxBytes || _expired(index.values.first, cutoff))) {
      await _delete(index, directory, index.keys.first);
    }
  }

  static bool _expired(_Entry entry, DateTime cutoff) =>
      entry.used.isBefore(cutoff);

  Future<void> _delete(
    Map<String, _Entry> index,
    Directory directory,
    String key,
  ) async {
    final entry = index.remove(key);
    if (entry == null) return;
    _total -= entry.size;
    await _deleteFile(File(p.join(directory.path, key)));
  }

  Future<void> _deleteFile(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Gone already.
    }
  }

  /// The time of use, which the file keeps for the next start.
  Future<DateTime> _markUsed(File file) async {
    final now = _now();
    try {
      await file.setLastModified(now);
    } on FileSystemException catch (error) {
      _log.fine('Could not mark a kept image as used: ${error.runtimeType}');
    }
    return now;
  }

  Future<AttachmentImage?> _readFile(File file) async {
    final Uint8List data;
    try {
      if (await file.length() > _maxHeaderBytes + maxEntryBytes) return null;
      data = await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
    final newline = data.take(_maxHeaderBytes).toList().indexOf(0x0A);
    if (newline < 1) return null;
    final image = AttachmentImage(
      bytes: Uint8List.sublistView(data, newline + 1),
      contentType: ascii.decode(data.sublist(0, newline), allowInvalid: true),
    );
    return await _storable(image) ? image : null;
  }

  Future<bool> _storable(AttachmentImage image) async {
    if (!_rasterType.hasMatch(image.contentType) || image.isSvg) return false;
    if (image.bytes.isEmpty || image.bytes.length > maxEntryBytes) {
      return false;
    }
    final pixels = await _pixelsOf(image.bytes);
    return pixels != null && pixels <= maxPixels;
  }
}

typedef _Entry = ({int size, DateTime used});
