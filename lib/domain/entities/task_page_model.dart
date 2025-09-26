import 'package:vikunja_app/domain/entities/task.dart';

class TaskPageModel {
  List<Task> tasks;
  bool onlyDueDate;
  int defaultProjectId;

  TaskPageModel(this.tasks, this.onlyDueDate, this.defaultProjectId);

  TaskPageModel copyWith({
    List<Task>? tasks,
    bool? onlyDueDate,
    int? defaultProjectId,
  }) {
    return TaskPageModel(
      tasks ?? this.tasks,
      onlyDueDate ?? this.onlyDueDate,
      defaultProjectId ?? this.defaultProjectId,
    );
  }
}
