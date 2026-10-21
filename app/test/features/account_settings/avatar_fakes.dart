import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_mobile/features/account_settings/application/avatar_files.dart';

/// 40 × 20 pixels: red for the first 10 columns, green for the middle 20,
/// blue for the last 10, so the middle square is all green.
final Uint8List wideTestPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAIAAABwJOjsAAAAKUlEQVR42mP4z8CABzH8pwDh'
  'lx61eNTiUYtHLR61eNTiUYtHLR45FgMAYO0dDsDfMy4AAAAASUVORK5CYII=',
);

/// The avatar files without a disk: a picked path reads as [picked] (or
/// throws [readFailure]), a written PNG is kept in [written] and named
/// `avatar.png` under a folder that does not exist; deletes are recorded.
final class FakeAvatarFiles implements AvatarFiles {
  Uint8List picked = wideTestPng;
  Exception? readFailure;
  final List<String> readPaths = [];
  final List<Uint8List> written = [];
  final List<String> deleted = [];

  Override get providerOverride => avatarFilesProvider.overrideWithValue(this);

  @override
  Future<Uint8List> readPicked(String path) async {
    readPaths.add(path);
    if (readFailure case final failure?) throw failure;
    return picked;
  }

  @override
  Future<File> write(Uint8List png) async {
    written.add(png);
    return File('/no-such-folder/avatar-${written.length}/avatar.png');
  }

  @override
  Future<void> delete(File file) async => deleted.add(file.path);
}
