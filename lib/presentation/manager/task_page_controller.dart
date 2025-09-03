import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';

part 'task_page_controller.g.dart';

@riverpod
class TaskPageController extends _$TaskPageController {
  @override
  Future<TaskPageModel> build() async {
    return _getAllFiltered();
  }

  void reload() async {
    state = AsyncData(await _getAllFiltered());
  }

  Future<TaskPageModel> _getAllFiltered() async {
    var showOnlyDueDateTasks = await ref
        .read(settingsRepositoryProvider)
        .getLandingPageOnlyDueDateTasks();

    var defaultProjectId =
        (await ref.read(userRepositoryProvider).getCurrentUser())
                .settings
                ?.default_project_id ??
            0;

    var currentUser = await ref.read(userRepositoryProvider).getCurrentUser();
    Map<String, dynamic>? frontend_settings =
        currentUser.settings?.frontend_settings;
    if (frontend_settings != null) {
      if (frontend_settings["filter_id_used_on_overview"] != null) {
        int? filterId = frontend_settings["filter_id_used_on_overview"];

        if (filterId != null && filterId != 0) {
          var tasks =
              await ref.read(taskRepositoryProvider).getAllByProject(filterId, {
            "sort_by": ["due_date", "id"],
            "order_by": ["asc", "desc"],
          });

          if (tasks != null) {
            updateWidgetTasks(tasks.body);
          }
          return TaskPageModel(
              tasks?.body ?? [], showOnlyDueDateTasks, defaultProjectId);
        }
      }
    }

    List<String> filterStrings = ["done = false"];
    if (showOnlyDueDateTasks) {
      filterStrings.add("due_date > 0001-01-01 00:00");
    }

    var tasks = await ref
        .read(taskRepositoryProvider)
        .getByFilterString(filterStrings.join(" && "), {
      "sort_by": ["due_date", "id"],
      "order_by": ["asc", "desc"],
      "filter_include_nulls": ["false"],
    });

    if (tasks != null) {
      updateWidgetTasks(tasks);
    }
    return TaskPageModel(tasks ?? [], showOnlyDueDateTasks, defaultProjectId);
  }

  Future<void> setLandingPageOnlyDueDateTasks(bool newValue) async {
    await ref
        .read(settingsRepositoryProvider)
        .setLandingPageOnlyDueDateTasks(newValue);

    reload();
  }

  Future<void> addTask(int projectId, Task task) async {
    await ref.read(taskRepositoryProvider).add(projectId, task);
    return reload();
  }

  Future<void> deleteTask(int id) async {
    await ref.read(taskRepositoryProvider).delete(id);
    return reload();
  }

  Future<void> updateTask(Task task) async {
    await ref.read(taskRepositoryProvider).update(task);
    return reload();
  }
}
