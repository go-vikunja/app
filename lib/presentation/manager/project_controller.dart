import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_page_model.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';

part 'project_controller.g.dart';

@riverpod
class ProjectController extends _$ProjectController {
  @override
  Future<ProjectPageModel> build(Project project) async {
    var displayDoneTask = await ref
        .read(settingsRepositoryProvider)
        .getDisplayDoneTasks(project.id);

    var tasks = await loadTasks(project.id, displayDoneTask);

    return ProjectPageModel(project, 0, tasks, [], displayDoneTask);
  }

  Future<void> loadForView(Project project, int viewIndex) async {
    var displayDoneTask = await ref
        .read(settingsRepositoryProvider)
        .getDisplayDoneTasks(project.id);

    var tasks = await loadTasks(project.id, displayDoneTask);
    var buckets = <Bucket>[];
    if (project.views[viewIndex].viewKind == ViewKind.kanban) {
      buckets = await loadBuckets(
        projectId: project.id,
        viewId: project.views[viewIndex].id,
      );
    }

    state = AsyncData(
      ProjectPageModel(project, viewIndex, tasks, buckets, displayDoneTask),
    );
  }

  Future<List<Task>> loadTasks(int projectId, bool displayDoneTasks) async {
    var repo = ref.read(taskRepositoryProvider);

    Map<String, List<String>> queryParams = {
      "sort_by": ["done", "id"],
      "order_by": ["asc", "desc"],
      "page": ["1"],
    };

    if (!displayDoneTasks) {
      queryParams.addAll({
        "filter": ["done=false"],
      });
    }
    var tasks = await repo.getAllByProject(projectId, queryParams);

    return tasks?.body ?? [];
  }

  Future<List<Bucket>> loadBuckets({
    required int projectId,
    required int viewId,
    int page = 1,
  }) async {
    Map<String, List<String>> queryParams = {
      "page": [page.toString()],
    };

    var buckets = await ref
        .read(bucketRepositoryProvider)
        .getAllByList(projectId, viewId, queryParams);

    return buckets?.body ?? [];
  }

  Future<void> addTask(Project project, Task newTask) async {
    await ref.read(taskRepositoryProvider).add(project.id, newTask);

    loadForView(project, state.value!.viewIndex);
  }

  Future<void> addBucket({
    required Bucket newBucket,
    required Project project,
    required int viewId,
  }) async {
    await ref.read(bucketRepositoryProvider).add(project.id, viewId, newBucket);

    loadForView(project, state.value!.viewIndex);
  }

  void deleteBucket({required Bucket bucket, required Project project}) async {
    await ref
        .read(bucketRepositoryProvider)
        .delete(
          project.id,
          project.views[state.value!.viewIndex].id,
          bucket.id,
        );

    loadForView(project, state.value!.viewIndex);
  }

  void updateBucket({required Bucket bucket, required Project project}) async {
    await ref
        .read(bucketRepositoryProvider)
        .update(project.id, project.views[state.value!.viewIndex].id, bucket);

    loadForView(project, state.value!.viewIndex);
  }

  void moveTask(
    Project project,
    Task task,
    Bucket bucket,
    double position,
  ) async {
    var viewId = project.views[state.value!.viewIndex].id;

    await ref
        .read(bucketRepositoryProvider)
        .updateTaskBucket(task.id, bucket.id, project.id, viewId);

    await ref
        .read(bucketRepositoryProvider)
        .updateTaskPosition(task.id, viewId, position);
  }

  void updateDoneBucket(Project project, int bucketId, isDoneColumn) async {
    var viewId = project.views[state.value!.viewIndex].id;

    var projectView = project.views.firstWhere((e) => e.id == viewId);
    projectView.doneBucketId = isDoneColumn ? 0 : bucketId;

    await ref.read(projectViewRepositoryProvider).update(projectView);
  }

  void selectDefaultBucket(
    Project project,
    int bucketId,
    isDefaultColumn,
  ) async {
    var viewId = project.views[state.value!.viewIndex].id;

    var projectView = project.views.firstWhere((e) => e.id == viewId);
    projectView.defaultBucketId = isDefaultColumn ? 0 : bucketId;

    await ref.read(projectViewRepositoryProvider).update(projectView);
  }

  void setDisplayDoneTasks(bool value) {
    state.value!.displayDoneTask = value;

    ref
        .read(settingsRepositoryProvider)
        .setDisplayDoneTasks(state.value!.project.id, value);

    state = state;
  }

  Future<void> updateProject(Project project) async {
    var projectUpdated = await ref
        .read(projectRepositoryProvider)
        .update(project);

    if (projectUpdated != null) {
      state.value!.project = projectUpdated;

      state = state;

      ref.read(projectsControllerProvider.notifier).reload();
    }
  }

  void updateTask(Task task) async {
    await ref.read(taskRepositoryProvider).update(task);

    loadForView(project, state.value!.viewIndex);
  }
}
