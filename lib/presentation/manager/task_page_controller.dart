import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/search_filter.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/presentation/manager/pagination_mixin.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';

part 'task_page_controller.g.dart';

@riverpod
class TaskPageController extends _$TaskPageController
    with PaginationMixin<Task> {
  String get _currentSearchQuery => state.value?.searchQuery ?? '';

  bool _isCurrentSearch(String searchQuery) {
    final current = state.value;
    return current != null &&
        current.searchQuery == searchQuery &&
        !current.isSearching;
  }

  @override
  Future<TaskPageModel> build() async {
    resetPagination();

    var tasksResponse = await _getAllFiltered();

    switch (tasksResponse) {
      case SuccessResponse<List<Task>>():
        updateTotalPages(tasksResponse.headers);
        return await _createPageModel(tasksResponse.body);
      case ErrorResponse<List<Task>>():
        throw AsyncError(tasksResponse.error, StackTrace.current);
      case ExceptionResponse<List<Task>>():
        throw AsyncError(tasksResponse.message, StackTrace.current);
    }
  }

  void reload() async {
    state = const AsyncLoading();
    resetPagination();

    var tasksResponse = await _getAllFiltered();

    switch (tasksResponse) {
      case SuccessResponse<List<Task>>():
        updateTotalPages(tasksResponse.headers);
        var pageModel = await _createPageModel(tasksResponse.body);
        state = AsyncData(pageModel);
      case ErrorResponse<List<Task>>():
        state = AsyncError(tasksResponse.error, StackTrace.current);
      case ExceptionResponse<List<Task>>():
        state = AsyncError(tasksResponse.message, StackTrace.current);
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.hasError) return;
    if (!canLoadNextPage) return;

    final currentModel = state.value;
    if (currentModel == null || currentModel.isSearching) return;

    final requestedSearchQuery = currentModel.searchQuery;
    state = AsyncData(currentModel.copyWith(isLoadingNextPage: true));

    await loadMoreItems(
      fetcher: (page) =>
          _getAllFiltered(page: page, searchQuery: requestedSearchQuery),
      shouldApply: () => _isCurrentSearch(requestedSearchQuery),
      stateUpdater: (newTasks) async {
        if (!_isCurrentSearch(requestedSearchQuery)) {
          return;
        }

        var projectsResponse = await ref
            .read(projectRepositoryProvider)
            .getAll();
        _setProjectOfTask(projectsResponse, newTasks as List<Task>);

        final latestModel = state.value;
        if (latestModel != null && _isCurrentSearch(requestedSearchQuery)) {
          final updatedTasks = [...latestModel.tasks, ...newTasks];
          state = AsyncData(
            latestModel.copyWith(tasks: updatedTasks, isLoadingNextPage: false),
          );
        }
      },
    );

    final latest = state.value;
    if (latest?.isLoadingNextPage == true &&
        latest?.searchQuery == requestedSearchQuery) {
      state = AsyncData(latest!.copyWith(isLoadingNextPage: false));
    }
  }

  Future<TaskPageModel> _createPageModel(List<Task> tasks) async {
    var defaultProjectId =
        ref.read(currentUserProvider)?.settings?.defaultProjectId ?? 0;

    var projectsResponse = await ref.read(projectRepositoryProvider).getAll();

    _setProjectOfTask(projectsResponse, tasks);

    updateWidget();
    ref
        .read(notificationProvider)
        ?.scheduleDueNotifications(ref.read(taskRepositoryProvider));

    var settings = ref.read(settingsRepositoryProvider);
    var showOnlyDueDateTasks = await settings.getLandingPageOnlyDueDateTasks();
    var displayDoneTasks = await settings.getLandingPageDisplayDoneTasks();

    return TaskPageModel(
      tasks,
      showOnlyDueDateTasks,
      defaultProjectId,
      false,
      displayDoneTasks: displayDoneTasks,
      searchQuery: _currentSearchQuery,
    );
  }

  Future<void> setSearchQuery(String query) async {
    final trimmed = query.trim();
    final current = state.value;
    if (current == null || trimmed == current.searchQuery) {
      return;
    }

    state = AsyncData(
      current.copyWith(searchQuery: trimmed, isSearching: true),
    );

    resetPagination();
    var tasksResponse = await _getAllFiltered(searchQuery: trimmed);
    if (state.value?.searchQuery != trimmed) {
      return;
    }

    switch (tasksResponse) {
      case SuccessResponse<List<Task>>():
        updateTotalPages(tasksResponse.headers);
        var pageModel = await _createPageModel(tasksResponse.body);
        state = AsyncData(pageModel.copyWith(isSearching: false));
      case ErrorResponse<List<Task>>():
        state = AsyncError(tasksResponse.error, StackTrace.current);
      case ExceptionResponse<List<Task>>():
        state = AsyncError(tasksResponse.message, StackTrace.current);
    }
  }

  void _setProjectOfTask(
    Response<List<Project>> projectsResponse,
    List<Task> tasks,
  ) {
    if (projectsResponse.isSuccessful) {
      var projectsMap = {
        for (var v in projectsResponse.toSuccess().body) v.id: v,
      };

      for (var tasks in tasks) {
        tasks.project = projectsMap[tasks.projectId];
      }
    }
  }

  Future<Response<List<Task>>> _getAllFiltered({
    int page = 1,
    String? searchQuery,
  }) async {
    final query = searchQuery ?? _currentSearchQuery;
    var settings = ref.read(settingsRepositoryProvider);
    var showOnlyDueDateTasks = await settings.getLandingPageOnlyDueDateTasks();
    var displayDoneTasks = await settings.getLandingPageDisplayDoneTasks();

    var user = ref.read(currentUserProvider);
    if (user != null) {
      Map<String, dynamic>? frontendSettings = user.settings?.frontendSettings;
      int? filterId = frontendSettings?["filter_id_used_on_overview"];
      if (filterId != null && filterId != 0) {
        final queryParameters = <String, List<String>>{
          "sort_by": ["due_date", "id"],
          "order_by": ["asc", "desc"],
          "page": ["$page"],
        };
        final searchClause = searchLikeClause(query);
        if (searchClause != null) {
          queryParameters["filter"] = [searchClause];
        }

        var tasksResponse = await ref
            .read(taskRepositoryProvider)
            .getAllByProject(filterId, queryParameters);

        return tasksResponse;
      }
    }

    List<String> filterStrings = [];
    if (!displayDoneTasks) {
      filterStrings.add("done = false");
    }
    if (showOnlyDueDateTasks) {
      filterStrings.add("due_date > 0001-01-01 00:00");
    }
    final searchClause = searchLikeClause(query);
    if (searchClause != null) {
      filterStrings.add(searchClause);
    }

    var tasksResponse = await ref
        .read(taskRepositoryProvider)
        .getByFilterString(combineFilterClauses(filterStrings), {
          "sort_by": ["due_date", "id"],
          "order_by": ["asc", "desc"],
          "filter_include_nulls": ["false"],
          "page": ["$page"],
        });

    return tasksResponse;
  }

  Future<void> setLandingPageOnlyDueDateTasks(bool newValue) async {
    await ref
        .read(settingsRepositoryProvider)
        .setLandingPageOnlyDueDateTasks(newValue);

    reload();
  }

  Future<void> setLandingPageDisplayDoneTasks(bool newValue) async {
    await ref
        .read(settingsRepositoryProvider)
        .setLandingPageDisplayDoneTasks(newValue);

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

  Future<bool> markAsDone(Task task, bool done) async {
    if (task.loading) {
      return false;
    }

    final previousDone = task.done;
    task.loading = true;
    _emitTasks(state.value?.tasks);

    task.done = done;
    var response = await ref.read(taskRepositoryProvider).update(task);
    task.loading = false;

    var value = state.value;
    if (response.isSuccessful) {
      if (value != null) {
        if (done && !value.displayDoneTasks) {
          final tasks = List<Task>.from(value.tasks)
            ..removeWhere((element) => element.id == task.id);
          state = AsyncData(value.copyWith(tasks: tasks));
        } else {
          _emitTasks(value.tasks);
        }
      }

      return true;
    }

    task.done = previousDone;
    _emitTasks(value?.tasks);
    return false;
  }

  void _emitTasks(List<Task>? tasks) {
    final value = state.value;
    if (value == null || tasks == null) {
      return;
    }

    state = AsyncData(value.copyWith(tasks: List<Task>.from(tasks)));
  }
}
