import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

@immutable
final class StoredUpload {
  const new({required this.name, required this.size});

  /// The stored copy's name in the uploads folder.
  final String name;
  final int size;
}

/// One account's stored copies of queued uploads,
/// `<application support>/accounts/<id>/uploads/<random name>`: a queued
/// upload must survive the app's caches being cleared and the picker's
/// copies going. The user's file name never becomes a path. Shared by the
/// account's repository and outbox sender, so a copy that is being queued
/// is never swept as an orphan.
final class UploadFiles {
  new(this._directory);

  final Future<Directory> Function() _directory;
  final _random = Random.secure();
  final _storing = <String>{};

  /// Copies [source] into the folder, or moves it with [move] (a rename
  /// where the file system allows, else a copy and a delete). The copy
  /// counts as being queued until [release]; a failed copy leaves nothing.
  Future<StoredUpload> store(File source, {bool move = false}) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final name = _newName();
    final target = File(p.join(directory.path, name));
    _storing.add(name);
    try {
      if (move) {
        try {
          await source.rename(target.path);
        } on FileSystemException {
          await source.copy(target.path);
          await source.delete();
        }
      } else {
        await source.copy(target.path);
      }
      return StoredUpload(name: name, size: await target.length());
    } on Object {
      _storing.remove(name);
      if (target.existsSync()) await target.delete();
      rethrow;
    }
  }

  /// The copy is queued (or deleted): a sweep may judge it from now on.
  void release(String name) => _storing.remove(name);

  Future<File> fileFor(String name) async =>
      File(p.join((await _directory()).path, _checked(name)));

  /// Safe when the copy is already gone, or [name] was never one.
  Future<void> delete(String name) async {
    if (!_namePattern.hasMatch(name)) return;
    final file = await fileFor(name);
    if (file.existsSync()) await file.delete();
  }

  /// Deletes every stored copy [referenced] does not name and that is not
  /// being queued: what a cancelled create, a deleted task or a killed run
  /// left behind.
  Future<int> sweep(Future<Set<String>> Function() referenced) async {
    final directory = await _directory();
    if (!directory.existsSync()) return 0;
    // Listed before the queued names are read: a copy released after the
    // listing has its op by then, one stored after it is not listed.
    final candidates = [
      await for (final entry in directory.list())
        if (entry is File && !_storing.contains(p.basename(entry.path))) entry,
    ];
    if (candidates.isEmpty) return 0;
    final kept = await referenced();
    var deleted = 0;
    for (final file in candidates) {
      final name = p.basename(file.path);
      if (kept.contains(name) || _storing.contains(name)) continue;
      if (file.existsSync()) await file.delete();
      deleted++;
    }
    return deleted;
  }

  static final _namePattern = RegExp(r'^[0-9a-f]{32}$');

  /// Whether [name] can be a stored copy's name, which [fileFor] requires.
  static bool isStoredName(String name) => _namePattern.hasMatch(name);

  static String _checked(String name) {
    if (!_namePattern.hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'not a stored upload');
    }
    return name;
  }

  String _newName() =>
      [for (var i = 0; i < 16; i++) _random.nextInt(256)]
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
}
