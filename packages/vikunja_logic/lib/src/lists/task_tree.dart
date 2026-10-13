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

/// The web's List view: the rows are the tasks of [matching] (the view's
/// tasks, already in display order) that [showsAtTopLevel] keeps, each
/// followed by its subtasks, the way the server appends every descendant
/// of a row whatever the filter: a parent's `relatedTasks[subtask]` ids in
/// their order, looked up in [tasksById] (a subtask missing there is left
/// out), recursively and without a depth limit. A subtask with two shown
/// parents appears under both; a task already on the path is not repeated,
/// which guards against a relation cycle.
List<TaskTreeNode> buildTaskTree({
  required List<Task> matching,
  required Map<int, Task> tasksById,
}) {
  final idsInList = {for (final task in matching) task.id};
  final path = <int>{};

  TaskTreeNode nodeOf(Task task, int depth) {
    path.add(task.id);
    final children = [
      for (final subtask in task.subtasks)
        if (!path.contains(subtask.id))
          if (tasksById[subtask.id] case final child?) nodeOf(child, depth + 1),
    ];
    path.remove(task.id);
    return TaskTreeNode(
      task: task,
      depth: depth,
      children: List.unmodifiable(children),
    );
  }

  return List.unmodifiable([
    for (final task in matching)
      if (showsAtTopLevel(
        task.parentTasks.map((parent) => parent.id),
        idsInList,
      ))
        nodeOf(task, 0),
  ]);
}
