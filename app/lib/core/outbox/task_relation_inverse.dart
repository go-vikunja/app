import 'package:vikunja_domain/vikunja_domain.dart';

/// The kind the server stores on the other task for an edge of [kind]: a
/// task's `subtask` is the other's `parenttask`, and so on.
TaskRelationKind inverseRelationKind(TaskRelationKind kind) => switch (kind) {
  TaskRelationKind.subtask => TaskRelationKind.parentTask,
  TaskRelationKind.parentTask => TaskRelationKind.subtask,
  TaskRelationKind.related => TaskRelationKind.related,
  TaskRelationKind.duplicateOf => TaskRelationKind.duplicates,
  TaskRelationKind.duplicates => TaskRelationKind.duplicateOf,
  TaskRelationKind.blocking => TaskRelationKind.blocked,
  TaskRelationKind.blocked => TaskRelationKind.blocking,
  TaskRelationKind.precedes => TaskRelationKind.follows,
  TaskRelationKind.follows => TaskRelationKind.precedes,
  TaskRelationKind.copiedFrom => TaskRelationKind.copiedTo,
  TaskRelationKind.copiedTo => TaskRelationKind.copiedFrom,
};
