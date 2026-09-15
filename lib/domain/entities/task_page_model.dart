import 'package:vikunja_app/domain/entities/task.dart';

class TaskPageModel {
  List<Task> tasks;
  bool onlyDueDate;
  bool displayDoneTasks;
  int defaultProjectId;
  bool isLoadingNextPage;
  String searchQuery;
  bool isSearching;

  TaskPageModel(
    this.tasks,
    this.onlyDueDate,
    this.defaultProjectId,
    this.isLoadingNextPage, {
    this.displayDoneTasks = false,
    this.searchQuery = '',
    this.isSearching = false,
  });

  TaskPageModel copyWith({
    List<Task>? tasks,
    bool? onlyDueDate,
    bool? displayDoneTasks,
    int? defaultProjectId,
    bool? isLoadingNextPage,
    String? searchQuery,
    bool? isSearching,
  }) {
    return TaskPageModel(
      tasks ?? this.tasks,
      onlyDueDate ?? this.onlyDueDate,
      defaultProjectId ?? this.defaultProjectId,
      isLoadingNextPage ?? this.isLoadingNextPage,
      displayDoneTasks: displayDoneTasks ?? this.displayDoneTasks,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}
