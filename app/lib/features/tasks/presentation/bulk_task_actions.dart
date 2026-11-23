import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/repositories/trash_repository_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/local_change.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attribute_editors.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/shortcut_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/project_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_failure_text.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_feedback.dart';

final _log = Logger('BulkTaskActions');

/// Whether the user may change [task] from a list, as its row decides:
/// not in a project they may only read, nor in an archived one, whose
/// tasks the server refuses to change.
bool taskChangeable(Task task, Map<int, Project> projectsById) =>
    ProjectAccess(projectsById[task.projectId]?.maxPermission).canChangeTasks &&
    !isArchivedInTree(task.projectId, projectsById);

/// Marks [tasks] done, or not done when every one of them is done, one
/// queued change each, with "N tasks marked as done · Undo". False when
/// nothing was written.
Future<bool> markTasksDone(
  BuildContext context,
  WidgetRef ref,
  List<Task> tasks,
) async {
  final repository = ref.read(taskRepositoryProvider);
  if (repository == null || tasks.isEmpty) return false;
  final done = !tasks.every((task) => task.done);
  final changed = [
    for (final task in tasks)
      if (task.done != done) task,
  ];
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final persist = MediaQuery.accessibleNavigationOf(context);
  unawaited(HapticFeedback.selectionClick());
  final (:written, :failed) = await _writeEach(messenger, l10n, changed, (
    task,
  ) async {
    await repository.setDone(task.id, done: done);
    return true;
  }, action: 'Marking tasks done');
  if (written.isEmpty) return false;
  _showUndo(
    messenger,
    l10n: l10n,
    persist: persist,
    text: failed
        ? l10n.tasksChangedPartly(written.length, changed.length)
        : done
        ? l10n.tasksMarkedDone(written.length)
        : l10n.tasksMarkedNotDone(written.length),
    undo: () async {
      for (final task in written) {
        // A repeating task gets the dates back that its done moved on.
        await (done
            ? repository.undoDone(task)
            : repository.setDone(task.id, done: true));
      }
    },
    action: 'Undoing a done of several tasks',
  );
  return true;
}

sealed class _DueChoice {
  const new();
}

final class _DueOn extends _DueChoice {
  const new(this.day);

  final DateTime day;
}

final class _PickDue extends _DueChoice {
  const new();
}

final class _ClearDue extends _DueChoice {
  const new();
}

/// Sets the due date of [tasks] from Today, Tomorrow and Next week, each
/// task keeping its time of day (else the user's default due time, else
/// the next breakpoint; on today never a time that has passed), from the
/// date and time picker, the same moment for all, or clears it. Asks once
/// when some of them would get two reminders on one moment. Says "Due date
/// changed for N tasks · Undo". False when nothing was written.
Future<bool> rescheduleTasks(
  BuildContext context,
  WidgetRef ref,
  List<Task> tasks, {
  required String title,
}) async {
  final repository = ref.read(taskRepositoryProvider);
  if (repository == null || tasks.isEmpty) return false;
  final l10n = context.l10n;
  final now = ref.read(clockProvider)();
  final display = ref.read(displaySettingsProvider);
  final localizations = MaterialLocalizations.of(context);
  final picked = await showOptionSheet<_DueChoice>(
    context,
    title: title,
    options: [
      for (final option in buildDateShortcuts(now))
        if (dueDateShortcuts.contains(option.shortcut))
          SheetOption(
            value: _DueOn(option.day),
            label: shortcutLabel(l10n, option.shortcut),
            subtitle: localizations.formatMediumDate(option.day),
          ),
      SheetOption(value: const _PickDue(), label: l10n.newTaskPickDate),
      if (tasks.any((task) => task.dueDate != null))
        SheetOption(value: const _ClearDue(), label: l10n.taskEditClearDueDate),
    ],
  );
  if (picked == null || !context.mounted) return false;
  final DateTime? Function(Task task) dueOf;
  switch (picked) {
    case _DueOn(:final day):
      dueOf = (task) => dayWithTime(
        day,
        current: task.dueDate,
        now: now,
        defaultTime: display.defaultDueTime,
      ).toUtc();
    case _PickDue():
      final chosen = await pickDateTime(
        context,
        current: null,
        now: now,
        display: display,
      );
      if (chosen == null || !context.mounted) return false;
      dueOf = (_) => chosen.toUtc();
    case _ClearDue():
      dueOf = (_) => null;
  }
  final changes = [
    for (final task in tasks)
      if (dueOf(task) != toTheMinute(task.dueDate)?.toUtc())
        (task: task, due: dueOf(task)),
  ];
  if (changes.isEmpty) return false;
  final merging = {
    for (final change in changes)
      if (dueChangeMergesReminders(change.task, change.due)) change.task.id,
  };
  if (merging.isNotEmpty) {
    final confirmed = await confirmAdaptive(
      context,
      title: l10n.tasksDueDateCoincideTitle,
      body: l10n.tasksDueDateCoincideBody(merging.length),
      confirmLabel: l10n.taskDetailDueDateCoincideConfirm,
    );
    if (!confirmed || !context.mounted) return false;
  }
  DateChange dateChange(DateTime? due) =>
      due == null ? const DateChange.clear() : DateChange.set(due);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final persist = MediaQuery.accessibleNavigationOf(context);
  unawaited(HapticFeedback.selectionClick());
  final (:written, :failed) = await _writeEach(messenger, l10n, changes, (
    change,
  ) async {
    await repository.updateTask(
      change.task.id,
      TaskChanges(dueDate: dateChange(change.due)),
    );
    return true;
  }, action: 'Changing the due date of several tasks');
  if (written.isEmpty) return false;
  _showUndo(
    messenger,
    l10n: l10n,
    persist: persist,
    text: failed
        ? l10n.tasksChangedPartly(written.length, changes.length)
        : l10n.tasksDueDateChanged(written.length),
    undo: () async {
      for (final (:task, due: _) in written) {
        await repository.updateTask(
          task.id,
          TaskChanges(
            dueDate: dateChange(task.dueDate),
            // The server kept one of the reminders that fell together.
            reminders: merging.contains(task.id) ? task.reminders : null,
          ),
        );
      }
    },
    action: 'Undoing a due date change of several tasks',
  );
  return true;
}

/// Sets the priority of [tasks] from the six levels, with "Priority
/// changed for N tasks · Undo". False when nothing was written.
Future<bool> setTasksPriority(
  BuildContext context,
  WidgetRef ref,
  List<Task> tasks,
) async {
  final repository = ref.read(taskRepositoryProvider);
  if (repository == null || tasks.isEmpty) return false;
  final l10n = context.l10n;
  final shared = tasks.map((task) => task.priority).toSet();
  final picked = await showOptionSheet<TaskPriority>(
    context,
    title: l10n.selectionPriorityTitle(tasks.length),
    options: [
      for (final priority in TaskPriority.values)
        SheetOption(
          value: priority,
          label: priorityLabel(l10n, priority),
          selected: shared.length == 1 && shared.single == priority,
        ),
    ],
  );
  if (picked == null || !context.mounted) return false;
  final changed = [
    for (final task in tasks)
      if (task.priority != picked) task,
  ];
  if (changed.isEmpty) return false;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final persist = MediaQuery.accessibleNavigationOf(context);
  unawaited(HapticFeedback.selectionClick());
  final (:written, :failed) = await _writeEach(messenger, l10n, changed, (
    task,
  ) async {
    await repository.updateTask(task.id, TaskChanges(priority: picked.value));
    return true;
  }, action: 'Changing the priority of several tasks');
  if (written.isEmpty) return false;
  _showUndo(
    messenger,
    l10n: l10n,
    persist: persist,
    text: failed
        ? l10n.tasksChangedPartly(written.length, changed.length)
        : l10n.tasksPriorityChanged(written.length),
    undo: () async {
      for (final task in written) {
        await repository.updateTask(
          task.id,
          TaskChanges(priority: task.priority.value),
        );
      }
    },
    action: 'Undoing a priority change of several tasks',
  );
  return true;
}

/// Moves [tasks] to a project picked from those the user may write to,
/// with "N tasks moved to … · Undo". False when nothing was written.
Future<bool> moveTasks(
  BuildContext context,
  WidgetRef ref,
  List<Task> tasks,
) async {
  final repository = ref.read(taskRepositoryProvider);
  if (repository == null || tasks.isEmpty) return false;
  final l10n = context.l10n;
  final projects = ref.read(projectsProvider).value ?? const <Project>[];
  final from = tasks.map((task) => task.projectId).toSet();
  final picked = await pickProject(
    context,
    projects: projects,
    selectedId: from.length == 1 ? from.single : null,
  );
  if (picked == null || !context.mounted) return false;
  final changed = [
    for (final task in tasks)
      if (task.projectId != picked.id) task,
  ];
  if (changed.isEmpty) return false;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final persist = MediaQuery.accessibleNavigationOf(context);
  unawaited(HapticFeedback.selectionClick());
  final (:written, :failed) = await _writeEach(messenger, l10n, changed, (
    task,
  ) async {
    await repository.updateTask(task.id, TaskChanges(projectId: picked.id));
    return true;
  }, action: 'Moving several tasks');
  if (written.isEmpty) return false;
  _showUndo(
    messenger,
    l10n: l10n,
    persist: persist,
    text: failed
        ? l10n.tasksChangedPartly(written.length, changed.length)
        : l10n.tasksMovedTo(written.length, picked.displayTitle(l10n)),
    undo: () async {
      for (final task in written) {
        await repository.updateTask(
          task.id,
          TaskChanges(projectId: task.projectId),
        );
      }
    },
    action: 'Undoing a move of several tasks',
  );
  return true;
}

/// Deletes [tasks] after asking, one queued delete each, and takes them
/// out of the pane beside the list. The question promises the trash only
/// for tasks surely on the server, as the task sheet's does (decision log:
/// Tasks). On a server with the trash Undo takes back every delete still
/// queued or restores the task from the trash, as the task sheet's Undo
/// does: "N tasks moved to the trash", or "N tasks deleted" when one of
/// them may not be in the trash. False when nothing was deleted.
Future<bool> deleteTasks(
  BuildContext context,
  WidgetRef ref,
  List<Task> tasks,
) async {
  final repository = ref.read(taskRepositoryProvider);
  if (repository == null || tasks.isEmpty) return false;
  final l10n = context.l10n;
  final trash = ref.read(activeServerHasTrashProvider);
  final guest = ref.read(activeAccountIsGuestProvider);
  final count = tasks.length;
  final onServer = [
    if (trash)
      for (final task in tasks)
        if (task.id < 0)
          await _onServer(repository, task.id)
        else
          TaskOnServer.yes,
  ];
  if (!context.mounted) return false;
  final unsent = onServer.where((status) => status == TaskOnServer.no).length;
  final confirmed = await confirmAdaptive(
    context,
    title: l10n.tasksDeleteDialogTitle(count),
    body: switch ((trash, guest)) {
      (false, _) => l10n.tasksDeleteDialogBody(count),
      _ when onServer.contains(TaskOnServer.maybe) =>
        l10n.tasksDeleteDialogBodyUnconfirmed(count),
      _ when unsent == count => l10n.tasksDeleteDialogBodyUnsent(count),
      _ when unsent > 0 => l10n.tasksDeleteDialogBodyPartlyUnsent(
        unsent,
        count,
        count - unsent,
      ),
      (true, false) => l10n.tasksDeleteDialogBodyTrash(count),
      (true, true) => l10n.tasksDeleteDialogBodyTrashGuest(count),
    },
    confirmLabel: l10n.taskDeleteDialogConfirm,
    cancelLabel: l10n.taskDeleteDialogCancel,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final persist = MediaQuery.accessibleNavigationOf(context);
  final dropFromPane = TaskDetailPaneScope.deletedOf(context);
  final restorable = <int>[];
  unawaited(HapticFeedback.selectionClick());
  final (written: deletedTasks, :failed) = await _writeEach(
    messenger,
    l10n,
    tasks,
    (task) async {
      final deletion = await repository.deleteTask(task.id);
      if (deletion == TaskDeletion.queued) restorable.add(task.id);
      return deletion != TaskDeletion.none;
    },
    action: 'Deleting several tasks',
  );
  final deleted = {for (final task in deletedTasks) task.id};
  if (deleted.isNotEmpty) dropFromPane?.call(deleted);
  if (deleted.isEmpty || messenger == null || !messenger.mounted) {
    return deleted.isNotEmpty;
  }
  final undo = trash && restorable.isNotEmpty;
  if (!undo && !failed) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.tasksDeleted(deleted.length))),
      );
    return true;
  }
  showDeletedSnackBar(
    messenger,
    text: failed
        ? l10n.tasksDeletedPartly(deleted.length, count)
        : restorable.length == deleted.length &&
              restorable.every((id) => id > 0)
        ? l10n.tasksMovedToTrash(restorable.length)
        : l10n.tasksDeleted(deleted.length),
    undoLabel: l10n.undo,
    persist: persist,
    onUndo: undo
        ? () => unawaited(
            runUndo(
              messenger,
              l10n,
              restore: () => _restoreAll(repository, restorable),
              restored: l10n.tasksRestored(restorable.length),
              action: TrashAction.restoreTask,
            ),
          )
        : null,
  );
  return true;
}

/// As the task sheet decides: a create that cannot be read counts as one
/// the server may have, which promises nothing.
Future<TaskOnServer> _onServer(TaskRepository repository, int taskId) async {
  try {
    return await repository.taskOnServer(taskId);
  } on Object catch (error) {
    _log.warning('Reading a create failed: ${error.runtimeType}');
    return TaskOnServer.maybe;
  }
}

/// Writes [items] one by one, each a local change of its own, and stops at
/// the first one this device cannot store. [write] says whether it changed
/// something; the record's `written` holds those that did, which stay
/// changed. Only when none did does it say that the change failed: else the
/// caller says which part was changed, with Undo for that part.
Future<({List<T> written, bool failed})> _writeEach<T>(
  ScaffoldMessengerState? messenger,
  AppLocalizations l10n,
  List<T> items,
  Future<bool> Function(T item) write, {
  required String action,
}) async {
  final written = <T>[];
  for (final item in items) {
    var changed = false;
    final saved = await saveLocalChangeIn(
      written.isEmpty ? messenger : null,
      l10n,
      () async => changed = await write(item),
      action: action,
    );
    if (!saved) return (written: written, failed: true);
    if (changed) written.add(item);
  }
  return (written: written, failed: false);
}

/// Restores every one of [ids], then throws the first failure, so the
/// others come back even when one cannot.
Future<void> _restoreAll(TaskRepository repository, List<int> ids) async {
  Object? failure;
  StackTrace? trace;
  for (final id in ids) {
    try {
      await repository.restoreTask(id);
    } on Object catch (error, stack) {
      failure ??= error;
      trace ??= stack;
    }
  }
  if (failure != null) Error.throwWithStackTrace(failure, trace!);
}

/// [text] with Undo, which runs [undo] as one local change; under a
/// screen reader it stays until dismissed.
void _showUndo(
  ScaffoldMessengerState? messenger, {
  required AppLocalizations l10n,
  required bool persist,
  required String text,
  required Future<void> Function() undo,
  required String action,
}) {
  if (messenger == null || !messenger.mounted) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: markedDoneSnackBarDuration,
        persist: persist,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(saveLocalChangeIn(messenger, l10n, undo, action: action));
          },
        ),
      ),
    );
}
