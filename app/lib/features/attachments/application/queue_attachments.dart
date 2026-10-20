import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

final _log = Logger('QueueAttachments');

/// What became of files given to [queueAttachments]: how many were queued,
/// and by name the ones above the server's limit and the ones that could
/// not be queued.
@immutable
final class QueuedAttachments {
  const new({
    this.queued = 0,
    this.tooLarge = const [],
    this.maxBytes,
    this.failed = const [],
  });

  final int queued;
  final List<String> tooLarge;

  /// The limit [tooLarge] exceeded.
  final int? maxBytes;
  final List<String> failed;
}

/// Queues an upload to the task for each file, one op per file, offline
/// too; [moveSource] for files the app owns (the share inbox, the pickers'
/// copies), which are gone afterwards whether queued or not. A file the
/// repository refuses does not stop the others.
Future<QueuedAttachments> queueAttachments(
  TaskRepository repository,
  int taskId,
  Iterable<({String path, String name, String? mimeType})> files, {
  bool moveSource = false,
}) async {
  var queued = 0;
  int? maxBytes;
  final tooLarge = <String>[];
  final failed = <String>[];
  for (final file in files) {
    final name = safeFileName(file.name);
    try {
      final operationId = await repository.queueUpload(
        taskId,
        sourcePath: file.path,
        fileName: name,
        mimeType: file.mimeType,
        moveSource: moveSource,
      );
      if (operationId == null) {
        failed.add(name);
      } else {
        queued++;
      }
    } on UploadTooLarge catch (error) {
      tooLarge.add(name);
      maxBytes = error.maxBytes;
    } on Object catch (error) {
      _log.warning('Queueing an upload failed: ${error.runtimeType}');
      failed.add(name);
      if (moveSource) await _deleteQuietly(File(file.path));
    }
  }
  return QueuedAttachments(
    queued: queued,
    tooLarge: tooLarge,
    maxBytes: maxBytes,
    failed: failed,
  );
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (file.existsSync()) await file.delete();
  } on FileSystemException catch (error) {
    _log.info('Could not delete a file: ${error.osError?.errorCode}');
  }
}
