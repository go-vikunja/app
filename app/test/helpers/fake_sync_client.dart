import 'dart:async';

import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A server-like fake for the sync engine: projects (archived ones only
/// with `includeArchived`, pseudo projects repeated on every page), labels,
/// and tasks served from exactly the filters and sorts the engine sends,
/// capped at [maxPerPage] like a real server. Every request is logged;
/// [beforeRequest] can fail or hold a request.
final class FakeSyncClient implements VikunjaReadClient {
  new({this.maxPerPage = 50, this.reportsTotal = true});

  /// The server's `max_items_per_page`.
  final int maxPerPage;

  /// v2 envelopes carry `total`; v1 headers do not.
  final bool reportsTotal;

  List<Project> allProjects = [];
  List<Project> pseudoProjects = [];

  /// Projects the user lost access to since the list: their task requests
  /// answer 403 with Vikunja's code 7003, like the 2.7.0 server.
  final Set<int> forbiddenProjects = {};
  List<Label> allLabels = [];
  List<Task> allTasks = [];
  User? currentUser;

  /// The tasks each saved filter matches, by its pseudo project id:
  /// `listInProject` on a pseudo project in [pseudoProjects] serves them.
  final Map<int, Set<int>> savedFilterTasks = {};

  /// Each view's task positions (`task_positions`); a task without one is
  /// at 0, and only a view's task list shows them.
  final Map<int, Map<int, double>> viewPositions = {};

  /// Called before every request with its description; throwing fails the
  /// request, awaiting holds it.
  Future<void> Function(String request)? beforeRequest;
  final List<String> requests = [];

  @override
  late final FakeProjectsPort projects = FakeProjectsPort(this);
  @override
  late final FakeLabelsPort labels = FakeLabelsPort(this);
  @override
  late final FakeTasksPort tasks = FakeTasksPort(this);
  @override
  late final FakeUsersPort users = FakeUsersPort(this);
  @override
  late final FakeNotificationsPort notifications = FakeNotificationsPort(this);
  @override
  late final FakeSubscriptionsPort subscriptions = FakeSubscriptionsPort(this);

  @override
  AvatarsPort get avatars => throw UnimplementedError();

  /// The subscription each task / project shows on a single read.
  final Map<int, Subscription> taskSubscriptions = {};
  final Map<int, Subscription> projectSubscriptions = {};

  /// The server's notifications for the user, newest first.
  List<ServerNotification> serverNotifications = [];

  /// The users with access per project, for the assignee search.
  final Map<int, List<User>> projectUsers = {};

  Future<void> _request(String description) async {
    requests.add(description);
    await beforeRequest?.call(description);
  }

  Page<T> _page<T>(
    List<T> all, {
    required int page,
    required int? perPage,
    List<T> appendToEveryPage = const [],
  }) {
    final size = perPage == null || perPage > maxPerPage ? maxPerPage : perPage;
    final start = (page - 1) * size;
    final items = start >= all.length
        ? <T>[]
        : all.sublist(start, (start + size).clamp(0, all.length));
    return Page(
      items: [...items, ...appendToEveryPage],
      page: page,
      perPage: size,
      totalPages: all.isEmpty ? 0 : (all.length / size).ceil(),
      total: reportsTotal ? all.length : null,
    );
  }
}

final class FakeProjectsPort implements ProjectsPort {
  new(this._client);

  final FakeSyncClient _client;

  @override
  Future<Page<Project>> list({
    int page = 1,
    int? perPage,
    bool includeArchived = false,
    String? search,
  }) async {
    await _client._request('projects page $page archived=$includeArchived');
    final visible = [
      for (final project in _client.allProjects)
        if (includeArchived || !project.isArchived) project,
    ];
    return _client._page(
      visible,
      page: page,
      perPage: perPage,
      appendToEveryPage: _client.pseudoProjects,
    );
  }

  @override
  Future<List<Project>> listAll({bool includeArchived = false}) async {
    final byId = <int, Project>{};
    for (var page = 1; ; page++) {
      final current = await list(page: page, includeArchived: includeArchived);
      for (final project in current.items) {
        byId.putIfAbsent(project.id, () => project);
      }
      if (!current.hasMore) return byId.values.toList();
    }
  }

  @override
  Future<Project> read(int id) async {
    await _client._request('project $id');
    return _client.allProjects.firstWhere((project) => project.id == id);
  }
}

final class FakeLabelsPort implements LabelsPort {
  new(this._client);

  final FakeSyncClient _client;

  /// [search] matches titles by substring, ignoring case, as on the
  /// server.
  @override
  Future<Page<Label>> list({int page = 1, int? perPage, String? search}) async {
    await _client._request(
      'labels page $page${search == null ? '' : ' search $search'}',
    );
    final needle = search?.toLowerCase() ?? '';
    return _client._page(
      [
        for (final label in _client.allLabels)
          if (label.title.toLowerCase().contains(needle)) label,
      ],
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<List<Label>> listAll() async {
    final all = <Label>[];
    for (var page = 1; ; page++) {
      final current = await list(page: page);
      all.addAll(current.items);
      if (!current.hasMore) return all;
    }
  }
}

final _doneClause = RegExp(r'^done = (true|false)$');
final _updatedClause = RegExp(r"^updated (>=|>) '([^']+)'$");
final _createdClause = RegExp(r"^created >= '([^']+)'$");
final _idClause = RegExp(r'^id > (\d+)$');

typedef _Matches = bool Function(Task task);

final class FakeTasksPort implements TasksPort {
  new(this._client);

  final FakeSyncClient _client;

  /// Every task query the engine sent, in order.
  final List<TaskQuery> queries = [];

  /// A broken server that answers every keyset request with the first page.
  bool ignoresCursor = false;

  /// A server that applies the web's position order instead of the sort.
  bool ignoresSort = false;

  @override
  Future<Page<Task>> list(TaskQuery query) async {
    await _client._request('tasks ${_describe(query)}');
    return _serve([
      for (final task in _client.allTasks)
        if (!_isArchivedProject(task.projectId)) task,
    ], query);
  }

  /// A project the server does not have answers like a deleted one; a
  /// saved filter's pseudo project serves the filter's tasks.
  @override
  Future<Page<Task>> listInProject(int projectId, TaskQuery query) async {
    await _client._request('project $projectId tasks ${_describe(query)}');
    if (_client.forbiddenProjects.contains(projectId)) {
      throw const Forbidden(code: 7003);
    }
    if (projectId < Project.favoritesId) {
      final listed = _client.pseudoProjects.any((p) => p.id == projectId);
      final matching = _client.savedFilterTasks[projectId];
      if (!listed || matching == null) throw const NotFound(code: 3001);
      return _serve([
        for (final task in _client.allTasks)
          if (matching.contains(task.id)) task,
      ], query);
    }
    if (!_client.allProjects.any((project) => project.id == projectId)) {
      throw const NotFound(code: 3001);
    }
    return _serve([
      for (final task in _client.allTasks)
        if (task.projectId == projectId) task,
    ], query);
  }

  /// The view's filter applies on top of the query's, and the tasks carry
  /// their positions in the view.
  @override
  Future<Page<Task>> listInView(
    int projectId,
    int viewId,
    TaskQuery query,
  ) async {
    await _client._request(
      'project $projectId view $viewId tasks ${_describe(query)}',
    );
    final project = _client.allProjects
        .where((project) => project.id == projectId)
        .firstOrNull;
    final view = project?.views.where((view) => view.id == viewId).firstOrNull;
    if (view == null) throw const NotFound(code: 3001);
    final inView = _predicate(view.filter?.filter);
    final positions = _client.viewPositions[viewId] ?? const {};
    return _serve([
      for (final task in _client.allTasks)
        if (task.projectId == projectId && inView(task))
          task.copyWith(position: positions[task.id] ?? 0),
    ], query);
  }

  /// A task the server does not have answers like a deleted one.
  @override
  Future<Task> read(int id, {Set<TaskExpand> expand = const {}}) async {
    await _client._request('task $id');
    for (final task in _client.allTasks) {
      if (task.id == id) return task;
    }
    throw const NotFound(code: 4002);
  }

  Page<Task> _serve(List<Task> all, TaskQuery query) {
    queries.add(query);
    final matches = _predicate(query.filter);
    final matching = [
      for (final task in all)
        if (matches(task)) task,
    ];
    final sorts = ignoresSort
        ? const [
            TaskSort(TaskSortField.position),
            TaskSort(TaskSortField.id, descending: true),
          ]
        : query.sort;
    matching.sort((a, b) {
      for (final sort in sorts) {
        final order = switch (sort.field) {
          TaskSortField.id => a.id.compareTo(b.id),
          TaskSortField.updated => _epoch(
            a.updated,
          ).compareTo(_epoch(b.updated)),
          TaskSortField.created => _epoch(
            a.created,
          ).compareTo(_epoch(b.created)),
          TaskSortField.position => a.position.compareTo(b.position),
          TaskSortField.dueDate => switch ((a.dueDate, b.dueDate)) {
            (null, null) => 0,
            // Nulls last in both directions, like the server.
            (null, _) => sort.descending ? -1 : 1,
            (_, null) => sort.descending ? 1 : -1,
            (final a?, final b?) => a.compareTo(b),
          },
          _ => throw StateError('unsupported task sort: ${sort.field}'),
        };
        if (order != 0) return sort.descending ? -order : order;
      }
      // The server's final tie-breaker.
      return a.id.compareTo(b.id);
    });
    return _client._page(matching, page: query.page, perPage: query.perPage);
  }

  /// The filters the engine and the outbox sender send: `done = …`,
  /// `updated >= '…'`, `updated > '…'`, `created >= '…'` and `id > …`
  /// joined by `&&`, or parenthesized groups of those joined by `||`.
  /// Anything else is a bug in the engine.
  _Matches _predicate(String? filter) {
    if (filter == null || filter.isEmpty) return (_) => true;
    final groups = [
      for (final group in filter.split(' || ')) _conjunction(group, filter),
    ];
    return (task) => groups.any((matches) => matches(task));
  }

  _Matches _conjunction(String group, String filter) {
    var clauses = group;
    if (clauses.startsWith('(') && clauses.endsWith(')')) {
      clauses = clauses.substring(1, clauses.length - 1);
    } else if (filter != group) {
      throw StateError('unparenthesized group in task filter: $filter');
    }
    final tests = <_Matches>[];
    for (final clause in clauses.split(' && ')) {
      if (_doneClause.firstMatch(clause) case final match?) {
        final done = match.group(1) == 'true';
        tests.add((task) => task.done == done);
      } else if (_updatedClause.firstMatch(clause) case final match?) {
        final strict = match.group(1) == '>';
        final moment = DateTime.parse(match.group(2)!);
        tests.add(
          (task) => switch (task.updated) {
            null => false,
            final updated =>
              strict ? updated.isAfter(moment) : !updated.isBefore(moment),
          },
        );
      } else if (_createdClause.firstMatch(clause) case final match?) {
        final moment = DateTime.parse(match.group(1)!);
        tests.add(
          (task) => switch (task.created) {
            null => false,
            final created => !created.isBefore(moment),
          },
        );
      } else if (_idClause.firstMatch(clause) case final match?) {
        final after = ignoresCursor ? 0 : int.parse(match.group(1)!);
        tests.add((task) => task.id > after);
      } else {
        throw StateError('unexpected task filter: $filter');
      }
    }
    return (task) => tests.every((test) => test(task));
  }

  static int _epoch(DateTime? moment) => moment?.millisecondsSinceEpoch ?? 0;

  bool _isArchivedProject(int projectId) {
    final byId = {for (final p in _client.allProjects) p.id: p};
    var current = byId[projectId];
    while (current != null) {
      if (current.isArchived) return true;
      current = byId[current.parentProjectId];
    }
    return false;
  }

  /// A descending sort is named, so that the newest-`updated` probe reads
  /// apart from the count probe.
  String _describe(TaskQuery query) {
    final descending = [
      for (final sort in query.sort)
        if (sort.descending) '${sort.field.wireName} desc',
    ];
    return '${query.filter ?? '(all)'}'
        '${descending.isEmpty ? '' : ' sort=${descending.join(',')}'}'
        ' per_page=${query.perPage} page=${query.page}';
  }
}

/// Holds every request matching [pattern] until [release] is called.
final class RequestGate {
  final _waiting = <Completer<void>>[];
  Pattern? pattern;

  bool get isHolding => _waiting.isNotEmpty;

  Future<void> call(String request) {
    if (pattern case final pattern? when request.contains(pattern)) {
      final completer = Completer<void>();
      _waiting.add(completer);
      return completer.future;
    }
    return Future.value();
  }

  void release() {
    final waiting = List.of(_waiting);
    _waiting.clear();
    for (final completer in waiting) {
      completer.complete();
    }
  }
}

final class FakeUsersPort implements UsersPort {
  new(this._client);

  final FakeSyncClient _client;

  @override
  Future<List<User>> searchProjectUsers(
    int projectId, {
    String query = '',
  }) async {
    await _client._request('users $projectId $query');
    final needle = query.toLowerCase();
    return [
      for (final user in _client.projectUsers[projectId] ?? const <User>[])
        if (user.username.toLowerCase().contains(needle) ||
            user.name.toLowerCase().contains(needle))
          user,
    ];
  }
}

final class FakeNotificationsPort implements NotificationsPort {
  new(this._client);

  final FakeSyncClient _client;

  @override
  Future<Page<ServerNotification>> list({int page = 1, int? perPage}) async {
    await _client._request('notifications $page');
    return _client._page(
      _client.serverNotifications,
      page: page,
      perPage: perPage,
    );
  }
}

final class FakeSubscriptionsPort implements SubscriptionsPort {
  new(this._client);

  final FakeSyncClient _client;

  @override
  Future<Subscription?> forTask(int taskId) async {
    await _client._request('subscription task $taskId');
    return _client.taskSubscriptions[taskId];
  }

  @override
  Future<Subscription?> forProject(int projectId) async {
    await _client._request('subscription project $projectId');
    return _client.projectSubscriptions[projectId];
  }
}
