import 'package:meta/meta.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

@immutable
final class TaskTreeNode {
  const new({required this.task, this.depth = 0, this.children = const []});

  final Task task;

  /// 0 for a top-level row.
  final int depth;
  final List<TaskTreeNode> children;
}

/// `useTaskListFiltering`: a task shows at the top level unless one of
/// [parentIds] is in [idsInList].
bool showsAtTopLevel(Iterable<int> parentIds, Set<int> idsInList) =>
    !parentIds.any(idsInList.contains);

/// How deep the web's List view expands subtasks below a top-level row,
/// since Vikunja 2.8.0.
const maxSubtaskDepth = 5;

/// The web's List view. The rows are the tasks of [matching] (the view's
/// tasks, already in display order) that the server sends as roots, those
/// without a matching parent, and that [showsAtTopLevel] keeps against
/// everything the server sends: the roots and every subtask below them in
/// [tasksById], whatever the filter. Each row is followed by its subtasks,
/// a parent's `relatedTasks[subtask]` ids in their order looked up in
/// [tasksById] (a subtask missing there is left out). As on the web since
/// 2.8.0, a task is expanded only where it first appears below its top-level
/// row, depth first, and only down to [maxSubtaskDepth]; a later appearance,
/// a cycle's ancestor included, is a row without subtasks.
List<TaskTreeNode> buildTaskTree({
  required List<Task> matching,
  required Map<int, Task> tasksById,
}) {
  Iterable<int> parentIdsOf(Task task) =>
      task.parentTasks.map((parent) => parent.id);

  final matchingIds = {for (final task in matching) task.id};
  final roots = [
    for (final task in matching)
      if (showsAtTopLevel(parentIdsOf(task), matchingIds)) task,
  ];
  final sent = {for (final task in roots) task.id};
  for (var below = roots; below.isNotEmpty;) {
    below = [
      for (final task in below)
        for (final subtask in task.subtasks)
          if (tasksById[subtask.id] case final child? when sent.add(child.id))
            child,
    ];
  }

  TaskTreeNode nodeOf(Task task, int depth, Set<int> expanded) {
    final expands = depth < maxSubtaskDepth && expanded.add(task.id);
    return TaskTreeNode(
      task: task,
      depth: depth,
      children: List.unmodifiable([
        if (expands)
          for (final subtask in task.subtasks)
            if (tasksById[subtask.id] case final child?)
              nodeOf(child, depth + 1, expanded),
      ]),
    );
  }

  return List.unmodifiable([
    for (final task in roots)
      if (showsAtTopLevel(parentIdsOf(task), sent)) nodeOf(task, 0, <int>{}),
  ]);
}
