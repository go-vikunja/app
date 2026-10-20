import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

final _log = Logger('AttachmentDownloads');

/// Downloaded originals to open, share or save, in the app's cache:
/// `<cache>/attachments/<account>/<task>/<attachment>/<sanitised name>`.
/// The folder per attachment keeps two attachments of the same name apart
/// while the file keeps its name for the app it is handed to. Android's
/// file provider shares only this folder. Purged per account on sign-out
/// and after [maxAge] without use.
final class AttachmentDownloads {
  new(this._cacheDirectory, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const folder = 'attachments';
  static const maxAge = Duration(days: 3);

  final Future<Directory> Function() _cacheDirectory;
  final DateTime Function() _now;

  Future<File> fileFor(
    String accountId,
    int taskId,
    TaskAttachment attachment,
  ) async => File(
    p.join(
      (await _attachmentDirectory(accountId, taskId, attachment.id)).path,
      safeFileName(attachment.name),
    ),
  );

  /// The downloaded file when it is complete: a size that differs from the
  /// attachment's is a different or broken file. Using it counts as a use.
  Future<File?> cached(
    String accountId,
    int taskId,
    TaskAttachment attachment,
  ) async {
    final file = await fileFor(accountId, taskId, attachment);
    if (!file.existsSync() || await file.length() != attachment.size) {
      return null;
    }
    try {
      await file.setLastModified(_now());
    } on FileSystemException catch (error) {
      _log.fine(
        'Could not mark a download as used: ${error.osError?.errorCode}',
      );
    }
    return file;
  }

  Future<void> forget(String accountId, int taskId, int attachmentId) async {
    final directory = await _attachmentDirectory(
      accountId,
      taskId,
      attachmentId,
    );
    if (directory.existsSync()) await directory.delete(recursive: true);
  }

  Future<void> purgeAccount(String accountId) async {
    final directory = Directory(
      p.join((await _root()).path, _checked(accountId)),
    );
    if (directory.existsSync()) await directory.delete(recursive: true);
  }

  /// Deletes every download not used for [maxAge], with the folders left
  /// empty. Never throws.
  Future<int> purgeStale() async {
    var deleted = 0;
    try {
      final root = await _root();
      if (!root.existsSync()) return 0;
      final cutoff = _now().subtract(maxAge);
      await for (final entry in root.list(recursive: true)) {
        if (entry is File && entry.lastModifiedSync().isBefore(cutoff)) {
          await entry.delete();
          deleted++;
        }
      }
      await _deleteEmptyFolders(root);
    } on Object catch (error) {
      _log.info('Purging old downloads failed: ${error.runtimeType}');
    }
    return deleted;
  }

  Future<void> _deleteEmptyFolders(Directory directory) async {
    for (final entry in directory.listSync()) {
      if (entry is Directory) {
        await _deleteEmptyFolders(entry);
        if (entry.listSync().isEmpty) await entry.delete();
      }
    }
  }

  Future<Directory> _root() async =>
      Directory(p.join((await _cacheDirectory()).path, folder));

  Future<Directory> _attachmentDirectory(
    String accountId,
    int taskId,
    int attachmentId,
  ) async => Directory(
    p.join(
      (await _root()).path,
      _checked(accountId),
      '$taskId',
      '$attachmentId',
    ),
  );

  static final _accountIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  static String _checked(String accountId) {
    if (!_accountIdPattern.hasMatch(accountId)) {
      throw ArgumentError.value(accountId, 'accountId', 'not an account id');
    }
    return accountId;
  }
}
