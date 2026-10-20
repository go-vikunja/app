import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where each account's SQLite file and the stored copies of its queued
/// uploads live, and how they are removed on sign-out.
abstract interface class AccountDatabaseFiles {
  /// `<application support>/accounts/<accountId>/vikunja.db`; the directory
  /// exists when this returns.
  Future<String> pathFor(String accountId);

  /// `<application support>/accounts/<accountId>/uploads`, which may not
  /// exist yet.
  Future<Directory> uploadsDirectoryFor(String accountId);

  /// Deletes the database, its WAL/journal files and the uploads folder.
  /// Safe when nothing exists.
  Future<void> deleteFor(String accountId);
}

/// Account ids are hex digests; anything else never becomes a path.
final _accountIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');

final class PathProviderAccountDatabaseFiles implements AccountDatabaseFiles {
  new({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static const fileName = 'vikunja.db';
  static const uploadsFolder = 'uploads';
  static const _sidecars = ['', '-wal', '-shm', '-journal'];

  final Future<Directory> Function() _supportDirectory;

  @override
  Future<String> pathFor(String accountId) async {
    final directory = await _directoryFor(accountId);
    await directory.create(recursive: true);
    return p.join(directory.path, fileName);
  }

  @override
  Future<Directory> uploadsDirectoryFor(String accountId) async =>
      Directory(p.join((await _directoryFor(accountId)).path, uploadsFolder));

  @override
  Future<void> deleteFor(String accountId) async {
    final directory = await _directoryFor(accountId);
    final uploads = Directory(p.join(directory.path, uploadsFolder));
    if (uploads.existsSync()) await uploads.delete(recursive: true);
    for (final suffix in _sidecars) {
      final file = File(p.join(directory.path, '$fileName$suffix'));
      if (file.existsSync()) await file.delete();
    }
    if (directory.existsSync() && directory.listSync().isEmpty) {
      await directory.delete();
    }
  }

  Future<Directory> _directoryFor(String accountId) async {
    if (!_accountIdPattern.hasMatch(accountId)) {
      throw ArgumentError.value(accountId, 'accountId', 'not an account id');
    }
    final support = await _supportDirectory();
    return Directory(p.join(support.path, 'accounts', accountId));
  }
}
