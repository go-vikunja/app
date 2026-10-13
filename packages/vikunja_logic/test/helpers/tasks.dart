import 'package:vikunja_domain/vikunja_domain.dart';

/// A task whose relations carry only the related ids, like the nested
/// tasks the server embeds.
Task task(
  int id, {
  String? title,
  int projectId = 1,
  bool done = false,
  DateTime? doneAt,
  DateTime? dueDate,
  DateTime? startDate,
  DateTime? endDate,
  TaskPriority priority = TaskPriority.unset,
  double percentDone = 0,
  DateTime? created,
  DateTime? updated,
  List<int> subtaskIds = const [],
  List<int> parentIds = const [],
}) => Task(
  id: id,
  title: title ?? 'Task $id',
  projectId: projectId,
  done: done,
  doneAt: doneAt,
  dueDate: dueDate,
  startDate: startDate,
  endDate: endDate,
  priority: priority,
  percentDone: percentDone,
  created: created,
  updated: updated,
  relatedTasks: {
    if (subtaskIds.isNotEmpty)
      TaskRelationKind.subtask: [for (final id in subtaskIds) _stub(id)],
    if (parentIds.isNotEmpty)
      TaskRelationKind.parentTask: [for (final id in parentIds) _stub(id)],
  },
);

Task _stub(int id) => Task(id: id, title: 'Task $id', projectId: 1);

List<int> idsOf(Iterable<Task> tasks) => [for (final task in tasks) task.id];
