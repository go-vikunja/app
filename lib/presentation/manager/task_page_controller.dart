import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';

part 'task_page_controller.g.dart';

@riverpod
class TaskPageController extends _$TaskPageController {
  @override
  Future<TaskPageModel> build() async {
    var showOnlyDueDateTasks = await ref
        .read(settingsRepositoryProvider)
        .getLandingPageOnlyDueDateTasks();

    var tasksResponse = await _getAllFiltered(showOnlyDueDateTasks);

    var defaultProjectId =
        ref.read(currentUserProvider)?.settings?.default_project_id ?? 0;

    switch (tasksResponse) {
      case SuccessResponse<List<Task>>():
        var tasks = tasksResponse.body;
        var projectsResponse = await ref
            .read(projectRepositoryProvider)
            .getAll();

        if (projectsResponse.isSuccessful) {
          var projectsMap = {
            for (var v in projectsResponse.toSuccess().body) v.id: v,
          };

          for (var tasks in tasks) {
            tasks.project = projectsMap[tasks.projectId];
          }
        }

        return TaskPageModel(tasks, showOnlyDueDateTasks, defaultProjectId);
      case ErrorResponse<List<Task>>():
        throw AsyncError(tasksResponse.error, StackTrace.current);
      case ExceptionResponse<List<Task>>():
        throw AsyncError(tasksResponse.message, StackTrace.current);
    }
  }

  void reload() async {
    var showOnlyDueDateTasks = await ref
        .read(settingsRepositoryProvider)
        .getLandingPageOnlyDueDateTasks();

    var tasksResponse = await _getAllFiltered(showOnlyDueDateTasks);

    var defaultProjectId =
        ref.read(currentUserProvider)?.settings?.default_project_id ?? 0;

    switch (tasksResponse) {
      case SuccessResponse<List<Task>>():
        var tasks = tasksResponse.body;
        var projectsResponse = await ref
            .read(projectRepositoryProvider)
            .getAll();

        if (projectsResponse.isSuccessful) {
          var projectsMap = {
            for (var v in projectsResponse.toSuccess().body) v.id: v,
          };

          for (var tasks in tasks) {
            tasks.project = projectsMap[tasks.projectId];
          }
        }

        state = AsyncData(
          TaskPageModel(
            tasksResponse.body,
            showOnlyDueDateTasks,
            defaultProjectId,
          ),
        );
      case ErrorResponse<List<Task>>():
        state = AsyncError(tasksResponse.error, StackTrace.current);
      case ExceptionResponse<List<Task>>():
        state = AsyncError(tasksResponse.message, StackTrace.current);
    }
  }

  Future<Response<List<Task>>> _getAllFiltered(
    bool showOnlyDueDateTasks,
  ) async {
    var user = ref.read(currentUserProvider);
    if (user != null) {
      Map<String, dynamic>? frontendSettings = user.settings?.frontend_settings;
      int? filterId = frontendSettings?["filter_id_used_on_overview"];

      if (filterId != null && filterId != 0) {
        var tasksResponse = await ref
            .read(taskRepositoryProvider)
            .getAllByProject(filterId, {
              "sort_by": ["due_date", "id"],
              "order_by": ["asc", "desc"],
            });

        return tasksResponse;
      }
    }

    List<String> filterStrings = ["done = false"];
    if (showOnlyDueDateTasks) {
      filterStrings.add("due_date > 0001-01-01 00:00");
    }

    var tasksResponse = await ref
        .read(taskRepositoryProvider)
        .getByFilterString(filterStrings.join(" && "), {
          "sort_by": ["due_date", "id"],
          "order_by": ["asc", "desc"],
          "filter_include_nulls": ["false"],
        });

    return tasksResponse;
  }

  Future<void> setLandingPageOnlyDueDateTasks(bool newValue) async {
    await ref
        .read(settingsRepositoryProvider)
        .setLandingPageOnlyDueDateTasks(newValue);

    reload();
  }

  Future<bool> addTask(int projectId, Task task) async {
    var response = await ref.read(taskRepositoryProvider).add(projectId, task);
    if (response.isSuccessful) {
      reload();

      return true;
    }

    return false;
  }

  Future<bool> deleteTask(int id) async {
    var response = await ref.read(taskRepositoryProvider).delete(id);
    if (response.isSuccessful) {
      var value = state.value;
      if (value != null) {
        var tasks = value.tasks;
        tasks.removeWhere((element) => element.id == id);
        state = AsyncData(value.copyWith(tasks: tasks));
      }

      return true;
    }

    return false;
  }

  Future<bool> updateTask(Task task) async {
    var response = await ref.read(taskRepositoryProvider).update(task);
    if (response.isSuccessful) {
      reload();

      return true;
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
      }

      return true;
    }

    return false;
  }
}
