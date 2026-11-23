import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/local_change.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/application/task_edits.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attribute_editors.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';

/// The done and favourite controls of a task list. A task marked done shows
/// done at once and, where the list would drop it, stays on screen until
/// its Undo snackbar has gone, so the row does not vanish under the finger.
/// Each row has its own time: when the next tap replaces the snackbar, the
/// earlier row still gets its full [markedDoneSnackBarDuration], so the
/// list does not shift under the finger that tapped the next one. The
/// snackbar undoes the latest task only.
mixin TaskListActions<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  // Done copies while the snackbar is up; after Undo the open copy, until
  // the list has the task again. By the id the row shows now.
  final _leaving = <int, _LeavingRow>{};
  // Every row whose snackbar, leave timer or id watch may still run.
  final _rows = <_LeavingRow>{};
  List<Task> _shown = const [];
  _LeavingRow? _undoRow;

  /// [tasks] with the rows still leaving put back where they were.
  List<Task> withLeavingTasks(List<Task> tasks) {
    if (_leaving.isEmpty) return _shown = tasks;
    final present = {for (final task in tasks) task.id};
    // A task the list has again needs no copy; without this an undone task
    // would come back as open from here after a later sync marked it done.
    _dropWhere((row) => present.contains(row.id));
    final merged = [...tasks];
    for (final row in _leaving.values) {
      merged.insert(_placeOf(row.id, merged), row.copy);
    }
    return _shown = merged;
  }

  /// Right after the nearest row that preceded it last time and is still
  /// there, so the row does not move while it leaves.
  int _placeOf(int id, List<Task> merged) {
    final indexById = {for (var i = 0; i < merged.length; i++) merged[i].id: i};
    var place = 0;
    for (final task in _shown) {
      if (task.id == id) break;
      if (indexById[task.id] case final index?) place = index + 1;
    }
    return place;
  }

  /// For a list that places its rows itself (a project's, with its done
  /// part), by id: the done copies of the tasks marked done here whose Undo
  /// is still offered, which keep their place among the open rows
  /// meanwhile; after Undo the open copy, until [listed] has the task open
  /// again, as a list that loads only the done tasks it shows may not have
  /// it until then.
  Map<int, Task> leavingTasksIn(Map<int, Task> listed) {
    _dropWhere((row) => !row.copy.done && listed[row.id]?.done == false);
    return Map.unmodifiable({
      for (final row in _leaving.values) row.id: row.copy,
    });
  }

  /// For an account switch: the copies belong to the old list.
  void clearLeavingTasks() {
    _leaving.clear();
    for (final row in _rows) {
      row.stop();
    }
    _rows.clear();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.stop();
    }
    super.dispose();
  }

  void _show(_LeavingRow row) {
    final replaced = _leaving[row.id];
    _leaving[row.id] = row;
    if (replaced != null && !identical(replaced, row)) _settle(replaced);
  }

  void _drop(_LeavingRow row) {
    if (identical(_leaving[row.id], row)) _leaving.remove(row.id);
    _settle(row);
  }

  void _dropWhere(bool Function(_LeavingRow row) test) {
    for (final row in [..._leaving.values]) {
      if (test(row)) _drop(row);
    }
  }

  /// Lets a row go once nothing of it runs or shows any more.
  void _settle(_LeavingRow row) {
    if (!row.closed || row.timer != null) return;
    if (identical(_leaving[row.id], row)) return;
    row.stop();
    _rows.remove(row);
  }

  /// A task created here gets its server id once its create is answered,
  /// which may come while the row leaves or after its Undo: the row takes
  /// that id, so that the list's row of it replaces it.
  void _followId(_LeavingRow row, TaskRepository repository) {
    if (row.id >= 0) return;
    row.watch = repository
        .watchTask(row.id)
        .listen(
          (latest) {
            if (latest == null || latest.id == row.id || !mounted) return;
            final from = row.id;
            setState(() {
              row
                ..task = latest
                ..copy = latest.copyWith(
                  done: row.copy.done,
                  doneAt: row.copy.doneAt,
                );
              if (identical(_leaving[from], row)) {
                _leaving.remove(from);
                _show(row);
              }
              _shown = [
                for (final task in _shown)
                  if (task.id == from) row.copy else task,
              ];
            });
            row.stopWatching();
          },
          // Without the server id the row leaves as it did before.
          onError: (Object _) {},
          cancelOnError: true,
        );
  }

  Future<void> setTaskDone(Task task, {required bool done}) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    final now = ref.read(clockProvider)();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    for (final row in [..._rows]) {
      if (row.id != task.id) continue;
      row.cancelTimer();
      _settle(row);
    }
    if (!done) {
      final leaving = _leaving[task.id];
      setState(() {
        if (leaving != null) _drop(leaving);
      });
      // Reopened from the row: the Undo of the done it undoes is moot.
      if (_undoRow?.id == task.id) messenger?.hideCurrentSnackBar();
      // Reopening a row still shown done is its Undo: a bare done: false
      // after a done already sent would leave a repeating task on its next
      // occurrence.
      final before = leaving != null && leaving.copy.done ? leaving.task : null;
      await saveLocalChangeIn(
        messenger,
        l10n,
        () => before != null
            ? writeTaskUndo(repository, before)
            : writeTaskDone(repository, task, done: false),
        action: 'Reopening a task',
      );
      return;
    }
    final row = _LeavingRow(task, withDone(task, done: true, now: now));
    _rows.add(row);
    setState(() => _show(row));
    _followId(row, repository);
    final saved = await saveLocalChangeIn(
      messenger,
      l10n,
      () => writeTaskDone(repository, task, done: true),
      action: 'Marking a task done',
    );
    if (!mounted) return;
    if (!saved) {
      row.closed = true;
      // The task was never marked done; the row shows it as the list has it.
      if (identical(_leaving[row.id], row)) {
        setState(() => _drop(row));
      } else {
        _settle(row);
      }
      return;
    }

    void leave() {
      if (mounted && identical(_leaving[row.id], row) && row.copy.done) {
        setState(() => _drop(row));
      }
    }

    row.timer = Timer(markedDoneSnackBarDuration, () {
      row
        ..timer = null
        ..timeUp = true;
      if (row.replaced) leave();
      _settle(row);
    });
    _undoRow = row;
    final reason = await showMarkedDoneSnackBar(
      context,
      onUndo: () {
        if (mounted) {
          setState(() {
            row.copy = withDone(row.task, done: false, now: now);
            _show(row);
          });
        }
        unawaited(
          saveLocalChangeIn(
            messenger,
            l10n,
            () => writeTaskUndo(repository, task),
            action: 'Undoing a done',
          ).then((saved) {
            // The task stays done; the row shows it as the list has it.
            if (!saved &&
                mounted &&
                identical(_leaving[row.id], row) &&
                !row.copy.done) {
              setState(() => _drop(row));
            }
          }),
        );
      },
    );
    if (identical(_undoRow, row)) _undoRow = null;
    row.closed = true;
    switch (reason) {
      case SnackBarClosedReason.action:
        row.cancelTimer();
      case SnackBarClosedReason.hide:
        // Replaced by the next task's snackbar, or reopened from the row.
        row.replaced = true;
        if (row.timeUp) leave();
      case SnackBarClosedReason.timeout ||
          SnackBarClosedReason.swipe ||
          SnackBarClosedReason.dismiss ||
          SnackBarClosedReason.remove:
        row.cancelTimer();
        leave();
    }
    _settle(row);
  }

  /// The due-date choices of the task sheet, for the swipe toward the start
  /// and its screen reader action.
  Future<void> changeTaskDueDate(Task task) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    await editDueDate(
      context,
      repository: repository,
      task: task,
      now: ref.read(clockProvider)(),
      display: ref.read(displaySettingsProvider),
    );
  }

  Future<void> setTaskFavorite(Task task, {required bool favorite}) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    await saveLocalChange(
      context,
      () => writeTaskFavorite(repository, task, favorite: favorite),
      action: 'Changing a favorite',
    );
  }
}

/// A task marked done in the list, from the tap until its row has left.
final class _LeavingRow {
  new(this.task, this.copy);

  /// As tapped; under its server id once a temporary one was remapped.
  Task task;

  /// What the list shows: done while Undo is offered, open after Undo.
  Task copy;
  Timer? timer;
  bool timeUp = false;
  bool replaced = false;

  /// The snackbar has gone.
  bool closed = false;
  StreamSubscription<Task?>? watch;

  int get id => task.id;

  void cancelTimer() {
    timer?.cancel();
    timer = null;
  }

  void stopWatching() {
    unawaited(watch?.cancel());
    watch = null;
  }

  void stop() {
    cancelTimer();
    stopWatching();
  }
}
