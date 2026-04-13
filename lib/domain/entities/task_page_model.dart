import 'package:vikunja_app/domain/entities/task.dart';

class TaskPageModel {
  List<Task> tasks;
  bool onlyDueDate;
  int defaultProjectId;
  bool isLoadingNextPage;

  TaskPageModel(
    this.tasks,
    this.onlyDueDate,
    this.defaultProjectId,
    this.isLoadingNextPage,
  );

  TaskPageModel copyWith({
    List<Task>? tasks,
    bool? onlyDueDate,
    int? defaultProjectId,
    bool? isLoadingNextPage,
  }) {
    return TaskPageModel(
      tasks ?? this.tasks,
      onlyDueDate ?? this.onlyDueDate,
      defaultProjectId ?? this.defaultProjectId,
      isLoadingNextPage ?? this.isLoadingNextPage,
    );
  }
}
