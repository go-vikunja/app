import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

const markedDoneSnackBarDuration = Duration(seconds: 3);

/// The done toggle's write with its haptic.
Future<void> writeTaskDone(
  TaskRepository repository,
  Task task, {
  required bool done,
}) {
  unawaited(HapticFeedback.selectionClick());
  return repository.setDone(task.id, done: done);
}

/// The Undo of a done: [task] as it was before, so a repeating task gets
/// its dates back.
Future<void> writeTaskUndo(TaskRepository repository, Task task) {
  unawaited(HapticFeedback.selectionClick());
  return repository.undoDone(task);
}

Future<void> writeTaskFavorite(
  TaskRepository repository,
  Task task, {
  required bool favorite,
}) {
  unawaited(HapticFeedback.selectionClick());
  return repository.setFavorite(task.id, favorite: favorite);
}

/// "Marked done · Undo", replacing a snackbar still up. Completes with how
/// it closed; [onUndo] runs when Undo is tapped.
Future<SnackBarClosedReason> showMarkedDoneSnackBar(
  BuildContext context, {
  required VoidCallback onUndo,
}) {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.taskMarkedDone),
      duration: markedDoneSnackBarDuration,
      // With an action a snackbar persists by default; this one goes after
      // its duration, except under a screen reader, whose user needs the
      // time to reach Undo.
      persist: MediaQuery.accessibleNavigationOf(context),
      action: SnackBarAction(label: l10n.undo, onPressed: onUndo),
    ),
  );
  return controller.closed;
}
