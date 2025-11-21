import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_page_model.dart';
import 'package:vikunja_app/domain/entities/project_view.dart';
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
    int? viewId = _getFirstListViewIdFromProject(project);
    var tasksResponse = await _loadTasks(project.id, displayDoneTask, viewId);

    switch (tasksResponse) {
      case SuccessResponse<List<Task>>():
        return ProjectPageModel(
          project,
          -1,
          tasksResponse.body,
          [],
          displayDoneTask,
        );
      case ExceptionResponse<List<Task>>():
        throw Exception(tasksResponse.message);
      case ErrorResponse<List<Task>>():
        throw Exception(tasksResponse.error.toString());
    }
  }

  Future<void> loadForView(Project project, int viewIndex) async {
    var displayDoneTask = await ref
        .read(settingsRepositoryProvider)
        .getDisplayDoneTasks(project.id);

    var tasks = <Task>[];
    int? viewId = _getFirstListViewIdFromProject(project);
    var tasksResponse = await _loadTasks(project.id, displayDoneTask, viewId);

    switch (tasksResponse) {
      case SuccessResponse<List<Task>>():
        tasks = tasksResponse.body;
      case ErrorResponse<List<Task>>():
        state = AsyncError(tasksResponse.error, StackTrace.current);
      case ExceptionResponse<List<Task>>():
        state = AsyncError(tasksResponse.message, StackTrace.current);
    }

    var buckets = <Bucket>[];
    if (project.views[viewIndex].viewKind == ViewKind.kanban) {
      var bucketsResponse = await _loadBuckets(
        projectId: project.id,
        viewId: project.views[viewIndex].id,
      );

      switch (bucketsResponse) {
        case SuccessResponse<List<Bucket>>():
          buckets = bucketsResponse.body;
        case ErrorResponse<List<Bucket>>():
          state = AsyncError(bucketsResponse.error, StackTrace.current);
        case ExceptionResponse<List<Bucket>>():
          state = AsyncError(bucketsResponse.message, StackTrace.current);
      }
    }

    state = AsyncData(
      ProjectPageModel(project, viewIndex, tasks, buckets, displayDoneTask),
    );
  }

  int? _getFirstListViewIdFromProject(Project project) {
    // Return null in case the first view is kanban
    return project.views.isNotEmpty &&
            project.views.first.viewKind == ViewKind.list
        ? project.views.first.id
        : null;
  }

  Future<Response<List<Task>>> _loadTasks(
    int projectId,
    bool displayDoneTasks, [
    int? view,
  ]) async {
    var repo = ref.read(taskRepositoryProvider);

    Map<String, List<String>> queryParams = view == null
        ? {
            "sort_by": ["done", "id"],
            "order_by": ["asc", "desc"],
            "page": ["1"],
          }
        : {
            "sort_by": ["position"],
            "order_by": ["asc"],
            "page": ["1"],
          };

    if (!displayDoneTasks) {
      queryParams.addAll({
        "filter": ["done=false"],
      });
    }

    return view == null
        ? await repo.getAllByProject(projectId, queryParams)
        : await repo.getAllByProjectView(projectId, view, queryParams);
  }

  Future<Response<List<Bucket>>> _loadBuckets({
    required int projectId,
    required int viewId,
    int page = 1,
  }) async {
    Map<String, List<String>> queryParams = {
      "page": [page.toString()],
    };

    var bucketsResponse = await ref
        .read(bucketRepositoryProvider)
        .getAllByList(projectId, viewId, queryParams);

    return bucketsResponse;
  }

  Future<bool> addTask(Project project, Task newTask) async {
    var response = await ref
        .read(taskRepositoryProvider)
        .add(project.id, newTask);
    if (response.isSuccessful) {
      var value = state.value;
      if (value != null) {
        var tasks = value.tasks;
        tasks.add(response.toSuccess().body);
        state = AsyncData(value.copyWith(tasks: tasks));

        return true;
      }
    }

    return false;
  }

  Future<bool> addBucket({
    required Bucket newBucket,
    required Project project,
    required int viewId,
  }) async {
    var response = await ref
        .read(bucketRepositoryProvider)
        .add(project.id, viewId, newBucket);
    if (response.isSuccessful) {
      var value = state.value;
      if (value != null) {
        var buckets = value.buckets;
        buckets.add(newBucket);
        state = AsyncData(value.copyWith(buckets: buckets));

        return true;
      }
    }

    return false;
  }

  Future<bool> deleteBucket({
    required Bucket bucket,
    required Project project,
  }) async {
    var response = await ref
        .read(bucketRepositoryProvider)
        .delete(
          project.id,
          project.views[state.value!.viewIndex].id,
          bucket.id,
        );

    if (response.isSuccessful) {
      var value = state.value;
      if (value != null) {
        var buckets = value.buckets;
        buckets.removeWhere((element) => element.id == bucket.id);
        state = AsyncData(value.copyWith(buckets: buckets));

        return true;
      }
    }

    return false;
  }

  Future<bool> updateBucket({
    required Bucket bucket,
    required Project project,
  }) async {
    var response = await ref
        .read(bucketRepositoryProvider)
        .update(project.id, project.views[state.value!.viewIndex].id, bucket);

    if (response.isSuccessful) {
      var value = state.value;
      if (value != null) {
        var buckets = value.buckets;
        buckets.removeWhere((element) => element.id == bucket.id);
        buckets.add(bucket);
        state = AsyncData(value.copyWith(buckets: buckets));

        return true;
      }
    }

    return false;
  }

  Future<bool> reorderTask(Project project, int oldIndex, int newIndex) async {
    var value = state.value;
    if (value == null || oldIndex == newIndex) {
      return true;
    }

    final moved = value.tasks[oldIndex];

    // Dragging to top = newIndex -1
    double? before = null;
    if (newIndex > 0) {
      before = value.tasks[newIndex - 1].position;
    } else if (newIndex == -1) {
      before = value.tasks[0].position;
    } else {
      before = null;
    }

    double? after = newIndex < value.tasks.length ? value.tasks[newIndex].position : null;

    double newPos;
    if (before != null && after != null) {
      newPos = (before + after) / 2;
    } else if (before == null && after != null) {
      newPos = after - 1;
    } else if (before != null && after == null) {
      newPos = before + 1;
    } else {
      newPos = newIndex.toDouble();
    }
    int? viewId = _getFirstListViewIdFromProject(value.project);
    if (viewId != null) {
      final res = await ref
        .read(bucketRepositoryProvider)
        .updateTaskPosition(moved.id, viewId, newPos);
      if (!res.isSuccessful) {
        return false;
      } 
    }

    var displayDoneTasks = await ref
      .read(settingsRepositoryProvider)
      .getDisplayDoneTasks(value.project.id);
    var tasksResponse = await _loadTasks(value.project.id, displayDoneTasks, viewId);
    if (tasksResponse.isSuccessful) {
      var tasks = tasksResponse.toSuccess().body;
      state = AsyncData(
        value.copyWith(tasks: tasks, displayDoneTask: displayDoneTasks),
      );
    }

    return true;
  }

  Future<bool> moveTask(
    Project project,
    Task task,
    Bucket bucket,
    double position,
  ) async {
    var viewId = project.views[state.value!.viewIndex].id;

    var updateBucketResponse = await ref
        .read(bucketRepositoryProvider)
        .updateTaskBucket(task.id, bucket.id, project.id, viewId);

    var updateTaskResponse = await ref
        .read(bucketRepositoryProvider)
        .updateTaskPosition(task.id, viewId, position);

    if (updateBucketResponse.isSuccessful && updateTaskResponse.isSuccessful) {
      return true;
    }

    return false;
  }

  Future<bool> updateDoneBucket(
    Project project,
    int bucketId,
    isDoneColumn,
  ) async {
    var projectView = project.views[state.value!.viewIndex];
    projectView.doneBucketId = isDoneColumn ? 0 : bucketId;

    var response = await ref
        .read(projectViewRepositoryProvider)
        .update(projectView);
    if (response.isSuccessful) {
      var value = state.value;
      if (value != null) {
        state = AsyncData(value.copyWith(project: project));

        return true;
      }
    }

    return false;
  }

  Future<bool> selectDefaultBucket(
    Project project,
    int bucketId,
    isDefaultColumn,
  ) async {
    var projectView = project.views[state.value!.viewIndex];
    projectView.defaultBucketId = isDefaultColumn ? 0 : bucketId;

    var response = await ref
        .read(projectViewRepositoryProvider)
        .update(projectView);
    if (response.isSuccessful) {
      var value = state.value;
      if (value != null) {
        state = AsyncData(value.copyWith(project: project));

        return true;
      }
    }

    return false;
  }

  Future<bool> setDisplayDoneTasks(bool displayDoneTasks) async {
    await ref
        .read(settingsRepositoryProvider)
        .setDisplayDoneTasks(state.value!.project.id, displayDoneTasks);

    var value = state.value;
    if (value != null) {
      int? viewId = _getFirstListViewIdFromProject(value.project);
      var tasksResponse = await _loadTasks(value.project.id, displayDoneTasks, viewId);
      if (tasksResponse.isSuccessful) {
        var tasks = tasksResponse.toSuccess().body;
        state = AsyncData(
          value.copyWith(tasks: tasks, displayDoneTask: displayDoneTasks),
        );
        return true;
      } else {
        return false;
      }
    }

    return false;
  }

  Future<bool> updateProject(Project project) async {
    var updateResponse = await ref
        .read(projectRepositoryProvider)
        .update(project);

    if (updateResponse.isSuccessful) {
      var value = state.value;
      if (value != null) {
        state = AsyncData(value.copyWith(project: project));

        return true;
      }

      ref.read(projectsControllerProvider.notifier).reload();
    }

    return false;
  }

  Future<bool> markAsDone(Task task) async {
    task.done = true;
    var response = await ref.read(taskRepositoryProvider).update(task);
    if (response.isSuccessful) {
      var value = state.value;
      if (value != null) {
        var tasks = value.tasks;
        tasks.removeWhere((element) => element.id == task.id);
        state = AsyncData(value.copyWith(tasks: tasks));

        return true;
      }
    }

    return false;
  }

  void reload() {
    var value = state.value;
    if (value != null) {
      loadForView(value.project, value.viewIndex);
    }
  }
}
