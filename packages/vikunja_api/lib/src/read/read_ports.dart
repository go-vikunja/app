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

abstract interface class UsersPort {
  /// The users who can be assigned to tasks of [projectId]: owner, shares
  /// and team members, matched by [query] on username and name (and email
  /// where the user allows it); an empty query lists them all. v2
  /// `GET /projects/{id}/users/search?q=`, v1
  /// `GET /projects/{id}/projectusers?s=`. One page, never paged.
  Future<List<User>> searchProjectUsers(int projectId, {String query = ''});
}

abstract interface class NotificationsPort {
  /// The user's notifications, newest first: v2 envelope, v1 bare array
  /// with paging headers. Only notifications of projects the user can
  /// still read come back.
  Future<Page<ServerNotification>> list({int page = 1, int? perPage});
}

abstract interface class SubscriptionsPort {
  /// The subscription covering the task (its own or a parent project's),
  /// from `GET /tasks/{id}`; null when not subscribed.
  Future<Subscription?> forTask(int taskId);

  /// From `GET /projects/{id}`; null when not subscribed.
  Future<Subscription?> forProject(int projectId);
}

abstract interface class VikunjaReadClient {
  ProjectsPort get projects;
  LabelsPort get labels;
  TasksPort get tasks;
  UsersPort get users;
  NotificationsPort get notifications;
  SubscriptionsPort get subscriptions;
}

/// [dio] is an authenticated client from `createAuthenticatedDio`; the
/// adapters pick `/api/v2` or `/api/v1` from [connection].
VikunjaReadClient createReadClient({
  required Dio dio,
  required ServerConnection connection,
}) => ReadClient(dio: dio, connection: connection);
