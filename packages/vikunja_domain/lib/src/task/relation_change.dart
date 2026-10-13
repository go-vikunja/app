import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/task/task_relation_kind.dart';

/// One edge from a task to another, as the server stores it from the
/// task's side; the server keeps the inverse edge on the other task.
@immutable
final class TaskRelationRef {
  const new(this.kind, this.otherTaskId);

  final TaskRelationKind kind;

  /// Negative for a task created here whose create is still queued.
  final int otherTaskId;

  @override
  bool operator ==(Object other) =>
      other is TaskRelationRef &&
      other.kind == kind &&
      other.otherTaskId == otherTaskId;

  @override
  int get hashCode => Object.hash(kind, otherTaskId);

  @override
  String toString() => 'TaskRelationRef(${kind.wireName}, $otherTaskId)';
}

/// Relations to add and remove, through the task's relation endpoints;
/// like `IdSetChange`, only the difference travels.
@immutable
final class RelationChange {
  const new({this.added = const {}, this.removed = const {}});

  final Set<TaskRelationRef> added;
  final Set<TaskRelationRef> removed;

  bool get isEmpty => added.isEmpty && removed.isEmpty;

  /// [later] wins for an edge both touch.
  RelationChange merge(RelationChange later) => RelationChange(
    added: {...added.difference(later.removed), ...later.added},
    removed: {...removed.difference(later.added), ...later.removed},
  );

  Set<TaskRelationRef> applyTo(Iterable<TaskRelationRef> current) => {
    for (final ref in current)
      if (!removed.contains(ref)) ref,
    ...added,
  };

  /// The same change with every other-task id passed through [resolve],
  /// for a temporary id the server has named meanwhile.
  RelationChange mapTaskIds(int Function(int id) resolve) => RelationChange(
    added: {
      for (final ref in added)
        TaskRelationRef(ref.kind, resolve(ref.otherTaskId)),
    },
    removed: {
      for (final ref in removed)
        TaskRelationRef(ref.kind, resolve(ref.otherTaskId)),
    },
  );

  @override
  bool operator ==(Object other) =>
      other is RelationChange &&
      _same(other.added, added) &&
      _same(other.removed, removed);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(added),
    Object.hashAllUnordered(removed),
  );

  static bool _same(Set<TaskRelationRef> a, Set<TaskRelationRef> b) =>
      a.length == b.length && a.containsAll(b);
}
