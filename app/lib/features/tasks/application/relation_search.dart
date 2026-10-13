import 'package:vikunja_domain/vikunja_domain.dart';

/// The kinds the detail sheet lists under "Related tasks", in this order;
/// subtasks and parents have places of their own.
const List<TaskRelationKind> otherRelationKinds = [
  TaskRelationKind.related,
  TaskRelationKind.blocking,
  TaskRelationKind.blocked,
  TaskRelationKind.precedes,
  TaskRelationKind.follows,
  TaskRelationKind.duplicateOf,
  TaskRelationKind.duplicates,
  TaskRelationKind.copiedFrom,
  TaskRelationKind.copiedTo,
];

/// The order the user can pick a kind in: the default first.
const List<TaskRelationKind> pickableRelationKinds = [
  TaskRelationKind.related,
  TaskRelationKind.subtask,
  TaskRelationKind.parentTask,
  TaskRelationKind.blocking,
  TaskRelationKind.blocked,
  TaskRelationKind.precedes,
  TaskRelationKind.follows,
  TaskRelationKind.duplicateOf,
  TaskRelationKind.duplicates,
  TaskRelationKind.copiedFrom,
  TaskRelationKind.copiedTo,
];

/// Server tasks by id, then the ones whose create is still queued in the
/// order they were made (−1, −2, …), so a task added here lands at the end
/// and keeps its place once the server has named it.
List<Task> inCreationOrder(Iterable<Task> tasks) {
  int rank(Task task) => task.id > 0 ? 0 : 1;
  return [...tasks]..sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return a.id.abs().compareTo(b.id.abs());
  });
}

/// Of [tasks], those [task] could get a relation of [kind] to: not the task
/// itself, none it already has that relation to, not its parent as a
/// subtask nor its subtask as a parent (the server refuses the loop), done
/// ones only with [includeDone], and with the trimmed [query] in the title
/// or the identifier, ignoring case. At most [limit].
List<Task> relationCandidates(
  Iterable<Task> tasks, {
  required Task task,
  required TaskRelationKind kind,
  required String query,
  required bool includeDone,
  int limit = 50,
}) {
  final needle = query.trim().toLowerCase();
  final related = {
    for (final other in [
      ...?task.relatedTasks[kind],
      if (kind == TaskRelationKind.subtask) ...task.parentTasks,
      if (kind == TaskRelationKind.parentTask) ...task.subtasks,
    ])
      other.id,
  };
  bool matches(Task other) =>
      needle.isEmpty ||
      other.title.toLowerCase().contains(needle) ||
      (other.id > 0 && other.displayIdentifier.toLowerCase().contains(needle));
  return [
    for (final other in tasks)
      if (other.id != task.id &&
          !related.contains(other.id) &&
          (includeDone || !other.done) &&
          matches(other))
        other,
  ].take(limit).toList();
}
