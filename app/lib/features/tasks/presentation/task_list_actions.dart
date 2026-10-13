import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/tasks/application/task_edits.dart';
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
  // the list has the task again.
  final _leaving = <int, Task>{};
  final _leaveTimers = <int, Timer>{};
  List<Task> _shown = const [];
  int? _undoTaskId;

  /// [tasks] with the rows still leaving put back where they were.
  List<Task> withLeavingTasks(List<Task> tasks) {
    if (_leaving.isEmpty) return _shown = tasks;
    final present = {for (final task in tasks) task.id};
    // A task the list has again needs no copy; without this an undone task
    // would come back as open from here after a later sync marked it done.
    _leaving.removeWhere((id, _) => present.contains(id));
    final merged = [...tasks];
    for (final task in _leaving.values) {
      merged.insert(_placeOf(task.id, merged), task);
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
    _leaving.removeWhere((id, copy) => !copy.done && listed[id]?.done == false);
    return Map.unmodifiable(_leaving);
  }

  /// For an account switch: the copies belong to the old list.
  void clearLeavingTasks() {
    _leaving.clear();
    for (final timer in _leaveTimers.values) {
      timer.cancel();
    }
    _leaveTimers.clear();
  }

  @override
  void dispose() {
    for (final timer in _leaveTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> setTaskDone(Task task, {required bool done}) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    final now = ref.read(clockProvider)();
    _leaveTimers.remove(task.id)?.cancel();
    if (!done) {
      setState(() => _leaving.remove(task.id));
      // Reopened from the row: the Undo of the done it undoes is moot.
      if (_undoTaskId == task.id) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      await writeTaskDone(repository, task, done: false);
      return;
    }
    final copy = withDone(task, done: true, now: now);
    setState(() => _leaving[task.id] = copy);
    await writeTaskDone(repository, task, done: true);
    if (!mounted) return;

    void leave() {
      if (mounted && identical(_leaving[task.id], copy)) {
        setState(() => _leaving.remove(task.id));
      }
    }

    var timeUp = false;
    var replaced = false;
    _leaveTimers[task.id] = Timer(markedDoneSnackBarDuration, () {
      timeUp = true;
      _leaveTimers.remove(task.id);
      if (replaced) leave();
    });
    _undoTaskId = task.id;
    final reason = await showMarkedDoneSnackBar(
      context,
      onUndo: () {
        if (mounted) {
          setState(
            () => _leaving[task.id] = withDone(task, done: false, now: now),
          );
        }
        unawaited(writeTaskUndo(repository, task));
      },
    );
    if (_undoTaskId == task.id) _undoTaskId = null;
    switch (reason) {
      case SnackBarClosedReason.action:
        _leaveTimers.remove(task.id)?.cancel();
      case SnackBarClosedReason.hide:
        // Replaced by the next task's snackbar, or reopened from the row.
        replaced = true;
        if (timeUp) leave();
      case SnackBarClosedReason.timeout ||
          SnackBarClosedReason.swipe ||
          SnackBarClosedReason.dismiss ||
          SnackBarClosedReason.remove:
        _leaveTimers.remove(task.id)?.cancel();
        leave();
    }
  }

  Future<void> setTaskFavorite(Task task, {required bool favorite}) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) return;
    await writeTaskFavorite(repository, task, favorite: favorite);
  }
}
