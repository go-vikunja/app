import 'package:vikunja_app/domain/entities/task.dart';

class FlattenedTaskEntry {
  final Task task;
  final int depth;

  const FlattenedTaskEntry({required this.task, required this.depth});
}

List<FlattenedTaskEntry> flattenTasks(List<Task> tasks) {
  final result = <FlattenedTaskEntry>[];
  void walk(List<Task> taskList, int depth) {
    for (final task in taskList) {
      result.add(FlattenedTaskEntry(task: task, depth: depth));
      if (task.subtasks.isNotEmpty) {
        walk(task.subtasks, depth + 1);
      }
    }
  }
  walk(tasks, 0);
  return result;
}

Set<int> _collectSubtaskIds(List<Task> tasks) {
  final ids = <int>{};
  for (final task in tasks) {
    for (final sub in task.subtasks) {
      ids.add(sub.id);
      ids.addAll(_collectSubtaskIds(task.subtasks));
    }
  }
  return ids;
}

List<Task> deduplicateSubtasks(List<Task> tasks) {
  final ids = _collectSubtaskIds(tasks);
  return tasks.where((t) => !ids.contains(t.id)).toList();
}
