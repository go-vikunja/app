import 'package:dio/dio.dart';
import 'package:vikunja_api/src/read/read_client.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Read access to the resources the first screens need. Implementations
/// throw `VikunjaFailure` and rethrow a cancelled request's `DioException`.
abstract interface class ProjectsPort {
  /// Real projects plus the pseudo projects (Favorites, saved filters),
  /// which the server repeats on every page.
  Future<Page<Project>> list({
    int page = 1,
    int? perPage,
    bool includeArchived = false,
    String? search,
  });

  /// Every page, pseudo projects de-duplicated.
  Future<List<Project>> listAll({bool includeArchived = false});

  /// Includes the project's views.
  Future<Project> read(int id);
}

abstract interface class LabelsPort {
  Future<Page<Label>> list({int page = 1, int? perPage, String? search});

  Future<List<Label>> listAll();
}

abstract interface class TasksPort {
  /// All tasks the user can see, across projects (`GET /tasks`).
  Future<Page<Task>> list(TaskQuery query);

  /// Tasks of one project, without any view filter.
  Future<Page<Task>> listInProject(int projectId, TaskQuery query);

  /// Tasks through a view: the view's own filter and sort apply server-side
  /// on top of [query]. Never used with kanban views here.
  Future<Page<Task>> listInView(int projectId, int viewId, TaskQuery query);

  Future<Task> read(int id, {Set<TaskExpand> expand = const {}});
}

abstract interface class VikunjaReadClient {
  ProjectsPort get projects;
  LabelsPort get labels;
  TasksPort get tasks;
}

/// [dio] is an authenticated client from `createAuthenticatedDio`; the
/// adapters pick `/api/v2` or `/api/v1` from [connection].
VikunjaReadClient createReadClient({
  required Dio dio,
  required ServerConnection connection,
}) => ReadClient(dio: dio, connection: connection);
