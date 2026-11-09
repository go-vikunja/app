import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_failure_text.dart';

final _log = Logger('TrashFeedback');

/// As long as the web offers its Undo of a delete.
const deletedSnackBarDuration = Duration(seconds: 10);

/// [text] about a delete, replacing a snackbar still up, with an Undo
/// labelled [undoLabel] when [onUndo] is given. With an Undo, [persist]
/// keeps it until it is closed; the caller reads it (whether a screen
/// reader is on) before its page or sheet closes. Without one it goes
/// after [deletedSnackBarDuration] anyway, as nothing else would close it.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showDeletedSnackBar(
  ScaffoldMessengerState messenger, {
  required String text,
  required String undoLabel,
  required bool persist,
  VoidCallback? onUndo,
}) {
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      duration: deletedSnackBarDuration,
      persist: onUndo != null && persist,
      action: onUndo == null
          ? null
          : SnackBarAction(label: undoLabel, onPressed: onUndo),
    ),
  );
}

/// The Undo of a delete: runs [restore], then says [restored] in a
/// snackbar, or why it failed as a restore of [action]. The snackbar
/// queues behind one still up, which keeps its own action. A restore that
/// may work a little later (the delete is still on its way, or the server
/// is out of reach) offers Undo again, which persists under a screen
/// reader like the delete's. Never throws, and does nothing once
/// [messenger] is gone.
Future<void> runUndo(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n, {
  required Future<Object?> Function() restore,
  required String restored,
  required TrashAction action,
}) async {
  if (!messenger.mounted) return;
  unawaited(HapticFeedback.selectionClick());
  String text;
  var again = false;
  try {
    await restore();
    text = restored;
  } on Object catch (error) {
    _log.info('Undoing a delete failed: ${error.runtimeType}');
    unawaited(HapticFeedback.heavyImpact());
    text = trashFailureText(l10n, error, action);
    again = error is TaskDeleteInFlight || error is NetworkFailure;
  }
  if (!messenger.mounted) return;
  if (!again) {
    messenger.showSnackBar(SnackBar(content: Text(text)));
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      duration: deletedSnackBarDuration,
      persist: MediaQuery.accessibleNavigationOf(messenger.context),
      action: SnackBarAction(
        label: l10n.undo,
        onPressed: () => unawaited(
          runUndo(
            messenger,
            l10n,
            restore: restore,
            restored: restored,
            action: action,
          ),
        ),
      ),
    ),
  );
}
