import 'dart:async';

import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A server-like fake for the sync engine: projects (archived ones only
/// with `includeArchived`, pseudo projects repeated on every page), labels,
/// and tasks served keyset-style from the engine's `done = … && id > …`
/// filters, capped at [maxPerPage] like a real server. Every request is
/// logged; [beforeRequest] can fail or hold a request.
final class FakeSyncClient implements VikunjaReadClient {
  new({this.maxPerPage = 50, this.reportsTotal = true});

  /// The server's `max_items_per_page`.
  final int maxPerPage;

  /// v2 envelopes carry `total`; v1 headers do not.
  final bool reportsTotal;

  List<Project> allProjects = [];
  List<Project> pseudoProjects = [];
  List<Label> allLabels = [];
  List<Task> allTasks = [];
  User? currentUser;

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

  @override
  Future<Page<Label>> list({int page = 1, int? perPage, String? search}) async {
    await _client._request('labels page $page');
    return _client._page(_client.allLabels, page: page, perPage: perPage);
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
final _updatedClause = RegExp(r"^updated >= '([^']+)'$");
final _idClause = RegExp(r'^id > (\d+)$');

final class FakeTasksPort implements TasksPort {
  new(this._client);

  final FakeSyncClient _client;

  /// Every task query the engine sent, in order.
  final List<TaskQuery> queries = [];

  /// A broken server that answers every keyset request with the first page.
  bool ignoresCursor = false;

  /// A server that applies the web's position order instead of `sort_by=id`.
  bool ignoresSort = false;

  @override
  Future<Page<Task>> list(TaskQuery query) async {
    await _client._request('tasks ${_describe(query)}');
    return _serve([
      for (final task in _client.allTasks)
        if (!_isArchivedProject(task.projectId)) task,
    ], query);
  }

  @override
  Future<Page<Task>> listInProject(int projectId, TaskQuery query) async {
    await _client._request('project $projectId tasks ${_describe(query)}');
    return _serve([
      for (final task in _client.allTasks)
        if (task.projectId == projectId) task,
    ], query);
  }

  @override
  Future<Page<Task>> listInView(int projectId, int viewId, TaskQuery query) =>
      listInProject(projectId, query);

  @override
  Future<Task> read(int id, {Set<TaskExpand> expand = const {}}) async {
    await _client._request('task $id');
    return _client.allTasks.firstWhere((task) => task.id == id);
  }

  /// `done = …`, `updated >= '…'` and `id > …` joined by `&&`, in any
  /// combination the engine sends.
  Page<Task> _serve(List<Task> all, TaskQuery query) {
    queries.add(query);
    bool? done;
    DateTime? updatedSince;
    var afterId = 0;
    for (final clause in (query.filter ?? '').split(' && ')) {
      if (_doneClause.firstMatch(clause) case final match?) {
        done = match.group(1) == 'true';
      } else if (_updatedClause.firstMatch(clause) case final match?) {
        updatedSince = DateTime.parse(match.group(1)!);
      } else if (_idClause.firstMatch(clause) case final match?) {
        afterId = ignoresCursor ? 0 : int.parse(match.group(1)!);
      } else {
        throw StateError('unexpected task filter: ${query.filter}');
      }
    }
    final matching = [
      for (final task in all)
        if ((done == null || task.done == done) &&
            (updatedSince == null ||
                (task.updated?.isBefore(updatedSince) == false)) &&
            task.id > afterId)
          task,
    ];
    if (ignoresSort) {
      matching.sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        return byPosition != 0 ? byPosition : b.id.compareTo(a.id);
      });
    } else {
      matching.sort((a, b) => a.id.compareTo(b.id));
    }
    return _client._page(matching, page: query.page, perPage: query.perPage);
  }

  bool _isArchivedProject(int projectId) {
    final byId = {for (final p in _client.allProjects) p.id: p};
    var current = byId[projectId];
    while (current != null) {
      if (current.isArchived) return true;
      current = byId[current.parentProjectId];
    }
    return false;
  }

  String _describe(TaskQuery query) =>
      '${query.filter} per_page=${query.perPage} page=${query.page}';
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
