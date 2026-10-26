import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

/// The rows of a table view, flat as on the web: subtasks are rows of their
/// own and done tasks stand among the open ones, all in [compare]'s order.
///
/// - [ViewFilterKind.openOnly]: the open tasks; with [showDone] every task.
/// - [ViewFilterKind.none]: every task.
/// - [ViewFilterKind.doneOnly]: the done tasks.
/// - [ViewFilterKind.other]: the tasks the device found the view's filter
///   to match (`matchingIds`), or where it cannot evaluate the filter, the
///   tasks of the view's last download that this device still has.
///
/// [leaving] are the tasks marked done here whose Undo is still offered,
/// by id: they keep their row and their place meanwhile, standing in for
/// the task where the source no longer has it.
List<Task> buildTableRows(
  ProjectListSource source, {
  required ViewFilterKind kind,
  required bool showDone,
  required Comparator<Task> compare,
  Map<int, Task> leaving = const {},
}) {
  final standIns = [
    for (final copy in leaving.values)
      if (!source.tasksById.containsKey(copy.id)) copy,
  ];
  final tasks = [...source.projectTasks, ...standIns];
  bool stays(Task task) => leaving.containsKey(task.id);
  final rows = switch (kind) {
    ViewFilterKind.openOnly when !showDone => [
      for (final task in tasks)
        if (!task.done || stays(task)) task,
    ],
    ViewFilterKind.openOnly || ViewFilterKind.none => tasks,
    ViewFilterKind.doneOnly => [
      for (final task in tasks)
        if (task.done) task,
    ],
    ViewFilterKind.other => switch (source.matchingIds) {
      final matching? => [
        for (final task in tasks)
          if (matching.contains(task.id) || stays(task)) task,
      ],
      null => [for (final id in source.snapshot.taskIds) ?source.tasksById[id]],
    },
  };
  // Placed as the open task it was, so that the row does not move while
  // its Undo is offered.
  Task placed(Task task) => task.done && stays(task)
      ? task.copyWith(done: false, doneAt: null)
      : task;
  return [...rows]..sort((a, b) => compare(placed(a), placed(b)));
}
