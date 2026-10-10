import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

typedef TaskListHandler = Future<Page<Task>> Function(TaskQuery query);
typedef ProjectTaskListHandler = Future<Page<Task>> Function(
  int projectId,
  TaskQuery query,
);

Page<T> pageOf<T>(
  List<T> all, {
  required int page,
  int perPage = 50,
  int? total,
}) {
  final start = (page - 1) * perPage;
  final items = start >= all.length
      ? <T>[]
      : all.sublist(start, (start + perPage).clamp(0, all.length));
  return Page(
    items: items,
    page: page,
    perPage: perPage,
    totalPages: all.isEmpty ? 1 : (all.length / perPage).ceil(),
    total: total ?? all.length,
  );
}

/// Serves in-memory data and records every call; handlers override the
/// defaults, e.g. to fail or to hold a request open.
final class FakeReadClient implements VikunjaReadClient {
  @override
  final FakeProjectsPort projects = FakeProjectsPort();
  @override
  final FakeLabelsPort labels = FakeLabelsPort();
  @override
  final FakeTasksPort tasks = FakeTasksPort();
}

final class FakeProjectsPort implements ProjectsPort {
  List<Project> all = [];
  Future<List<Project>> Function()? onListAll;
  int listAllCalls = 0;

  @override
  Future<Page<Project>> list({
    int page = 1,
    int? perPage,
    bool includeArchived = false,
    String? search,
  }) async => pageOf(all, page: page, perPage: perPage ?? 50);

  @override
  Future<List<Project>> listAll({bool includeArchived = false}) {
    listAllCalls++;
    return onListAll?.call() ?? Future.value(List.of(all));
  }

  @override
  Future<Project> read(int id) async =>
      all.firstWhere((project) => project.id == id);
}

final class FakeLabelsPort implements LabelsPort {
  List<Label> all = [];

  @override
  Future<Page<Label>> list({
    int page = 1,
    int? perPage,
    String? search,
  }) async => pageOf(all, page: page, perPage: perPage ?? 50);

  @override
  Future<List<Label>> listAll() async => List.of(all);
}

final class FakeTasksPort implements TasksPort {
  /// Served by `list` (all projects), paged by [perPage].
  List<Task> openTasks = [];

  /// Served by `listInProject`, filtered by `done = false` when asked.
  Map<int, List<Task>> projectTasks = {};
  int perPage = 50;
  TaskListHandler? onList;
  ProjectTaskListHandler? onListInProject;
  final List<TaskQuery> listQueries = [];
  final List<(int, TaskQuery)> projectQueries = [];

  @override
  Future<Page<Task>> list(TaskQuery query) {
    listQueries.add(query);
    return onList?.call(query) ??
        Future.value(pageOf(openTasks, page: query.page, perPage: perPage));
  }

  @override
  Future<Page<Task>> listInProject(int projectId, TaskQuery query) {
    projectQueries.add((projectId, query));
    if (onListInProject case final handler?) return handler(projectId, query);
    final all = projectTasks[projectId] ?? const <Task>[];
    final filtered = query.filter == 'done = false'
        ? [
            for (final task in all)
              if (!task.done) task,
          ]
        : all;
    return Future.value(pageOf(filtered, page: query.page, perPage: perPage));
  }

  @override
  Future<Page<Task>> listInView(int projectId, int viewId, TaskQuery query) =>
      listInProject(projectId, query);

  @override
  Future<Task> read(int id, {Set<TaskExpand> expand = const {}}) async {
    for (final tasks in [openTasks, ...projectTasks.values]) {
      for (final task in tasks) {
        if (task.id == id) return task;
      }
    }
    throw const NotFound(code: 4001);
  }
}
