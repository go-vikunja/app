import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';

class ProjectPageModel {
  Project project;
  int viewIndex;
  List<Task> tasks;
  List<Bucket> buckets;
  bool displayDoneTask;

  ProjectPageModel(
    this.project,
    this.viewIndex,
    this.tasks,
    this.buckets,
    this.displayDoneTask,
  );
}
