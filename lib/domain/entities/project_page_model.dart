import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';

class ProjectPageModel {
  Project project;
  int viewIndex;
  List<Task> tasks;
  List<Bucket> buckets;
  bool displayDoneTask;
  bool isLoadingNextPage;
  String searchQuery;
  bool isSearching;

  ProjectPageModel(
    this.project,
    this.viewIndex,
    this.tasks,
    this.buckets,
    this.displayDoneTask,
    this.isLoadingNextPage, {
    this.searchQuery = '',
    this.isSearching = false,
  });

  ProjectPageModel copyWith({
    Project? project,
    int? viewIndex,
    List<Task>? tasks,
    List<Bucket>? buckets,
    bool? displayDoneTask,
    bool? isLoadingNextPage,
    String? searchQuery,
    bool? isSearching,
  }) {
    return ProjectPageModel(
      project ?? this.project,
      viewIndex ?? this.viewIndex,
      tasks ?? this.tasks,
      buckets ?? this.buckets,
      displayDoneTask ?? this.displayDoneTask,
      isLoadingNextPage ?? this.isLoadingNextPage,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}
