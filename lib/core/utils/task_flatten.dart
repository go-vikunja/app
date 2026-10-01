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
