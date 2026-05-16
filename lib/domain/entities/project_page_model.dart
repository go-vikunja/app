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

  ProjectPageModel(
    this.project,
    this.viewIndex,
    this.tasks,
    this.buckets,
    this.displayDoneTask,
    this.isLoadingNextPage,
  );

  ProjectPageModel copyWith({
    Project? project,
    int? viewIndex,
    List<Task>? tasks,
    List<Bucket>? buckets,
    bool? displayDoneTask,
    bool? isLoadingNextPage,
  }) {
    return ProjectPageModel(
      project ?? this.project,
      viewIndex ?? this.viewIndex,
      tasks ?? this.tasks,
      buckets ?? this.buckets,
      displayDoneTask ?? this.displayDoneTask,
      isLoadingNextPage ?? this.isLoadingNextPage,
    );
  }
}
