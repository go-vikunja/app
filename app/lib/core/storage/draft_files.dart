import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

part 'draft_files.g.dart';

/// Where the unsent comments and description edits are kept: files in the
/// accounts folder, which iOS backups leave out (D66), while the
/// preferences go into them.
@Riverpod(keepAlive: true)
PreferencesStore draftStore(Ref ref) => DraftFiles(directory: draftsDirectory);

Future<Directory> draftsDirectory({
  Future<Directory> Function()? supportDirectory,
}) async => Directory(
  p.join(
    (await (supportDirectory ?? getApplicationSupportDirectory)()).path,
    PathProviderAccountDatabaseFiles.accountsFolder,
    // Account folders are named by id, which has no dot.
    '.drafts',
  ),
);

/// One file per key in a directory, each written whole beside it and then
/// moved over it, so a reader never sees half a write.
final class DraftFiles implements PreferencesStore {
  new({required this._directory});

  final Future<Directory> Function() _directory;

  // Other isolates write too.
  static final _random = Random();

  static final _key = RegExp(r'^[A-Za-z0-9_-][A-Za-z0-9_.-]*$');

  @override
  Future<String?> getString(String key) async {
    final file = await _file(key);
    try {
      return await file.readAsString();
    } on PathNotFoundException {
      return null;
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    final file = await _file(key);
    await file.parent.create(recursive: true);
    final next = File(
      '${file.path}.${_random.nextInt(1 << 32).toRadixString(16)}.tmp',
    );
    try {
      await next.writeAsString(value, flush: true);
      await next.rename(file.path);
    } on Object {
      if (next.existsSync()) await next.delete();
      rethrow;
    }
  }

  @override
  Future<void> remove(String key) async {
    final file = await _file(key);
    try {
      await file.delete();
    } on PathNotFoundException {
      return;
    }
  }

  Future<File> _file(String key) async {
    if (!_key.hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'not a draft key');
    }
    return File(p.join((await _directory()).path, '$key.json'));
  }
}
