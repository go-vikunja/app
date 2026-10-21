import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'avatar_files.g.dart';

final _log = Logger('AvatarFiles');

/// The picked photo read once, and the cropped avatar as a file for the
/// upload, which streams it from disk; named `avatar.png` like the web's.
abstract interface class AvatarFiles {
  /// Reads the picker's copy at [path] and deletes it.
  Future<Uint8List> readPicked(String path);

  Future<File> write(Uint8List png);

  /// Never throws.
  Future<void> delete(File file);
}

final class TemporaryAvatarFiles implements AvatarFiles {
  const new();

  @override
  Future<Uint8List> readPicked(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } on FileSystemException catch (error) {
      _log.fine('Could not delete the picked photo: ${error.runtimeType}');
    }
    return bytes;
  }

  @override
  Future<File> write(Uint8List png) async {
    final folder = await (await getTemporaryDirectory()).createTemp('avatar');
    final file = File(p.join(folder.path, 'avatar.png'));
    await file.writeAsBytes(png, flush: true);
    return file;
  }

  @override
  Future<void> delete(File file) async {
    try {
      await file.parent.delete(recursive: true);
    } on FileSystemException catch (error) {
      _log.fine('Could not delete the avatar file: ${error.runtimeType}');
    }
  }
}

@Riverpod(keepAlive: true)
AvatarFiles avatarFiles(Ref ref) => const TemporaryAvatarFiles();
