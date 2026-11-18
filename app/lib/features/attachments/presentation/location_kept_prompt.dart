import 'dart:io';

import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';

final _log = Logger('LocationKept');

/// [files] to upload: those whose location could not be removed only when
/// the user chooses to upload them with it. Without a [context] to ask in,
/// or when skipped or dismissed, their copies are deleted.
Future<List<PickedFile>> withoutUnwantedLocations(
  BuildContext? context,
  List<PickedFile> files,
) async {
  final kept = [
    for (final file in files)
      if (file.keptLocation) file,
  ];
  if (kept.isEmpty) return files;
  if (context != null && context.mounted) {
    final l10n = context.l10n;
    final upload = await confirmAdaptive(
      context,
      title: l10n.attachmentLocationKeptTitle,
      body: [
        l10n.attachmentLocationKeptBody(kept.length),
        '',
        for (final file in kept) safeFileName(file.name),
      ].join('\n'),
      confirmLabel: l10n.attachmentLocationKeptUpload,
      cancelLabel: l10n.attachmentLocationKeptSkip,
    );
    if (upload) return files;
  }
  for (final file in kept) {
    try {
      final copy = File(file.path);
      if (copy.existsSync()) await copy.delete();
    } on FileSystemException catch (error) {
      _log.info('Could not delete a skipped file: ${error.osError?.errorCode}');
    }
  }
  return [
    for (final file in files)
      if (!file.keptLocation) file,
  ];
}
