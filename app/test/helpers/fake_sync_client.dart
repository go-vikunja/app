import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A server-like fake for the sync engine: projects (archived ones only
/// with `includeArchived`, pseudo projects repeated on every page), labels,
/// and tasks served from exactly the filters and sorts the engine sends,
/// capped at [maxPerPage] like a real server, their comment count and
/// unread flag only when the request expands them. Every request is logged;
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

  /// Each kanban view's buckets by view id, and the bucket and position of
  /// each of its tasks by view id, then task id: what [buckets] serves. A
  /// bucket's count is the number of tasks of [allTasks] in it.
  final Map<int, List<Bucket>> viewBuckets = {};
  final Map<int, Map<int, ({int bucketId, double position})>> bucketSlots = {};

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
  late final FakeBucketsPort buckets = FakeBucketsPort(this);

  @override
  AvatarsPort get avatars => throw UnimplementedError();

  @override
  late final FakeCommentsPort comments = FakeCommentsPort(this);

  @override
  late final FakeAttachmentsPort attachments = FakeAttachmentsPort(this);

  /// What `GET /filters/{id}` answers, by saved filter id; another id is a
  /// `NotFound` code 11001.
  final Map<int, SavedFilter> savedFilterDefinitions = {};

  @override
  late final FakeSavedFiltersReadPort savedFilters = FakeSavedFiltersReadPort(
    this,
  );

  /// The subscription each task / project shows on a single read.
  final Map<int, Subscription> taskSubscriptions = {};
  final Map<int, Subscription> projectSubscriptions = {};

  /// What a details read answers per task of [allTasks]; absent: nothing
  /// beyond the row, with the task's subscription.
  final Map<int, TaskDetails> taskDetails = {};

  /// Every comment per task id, in the order the server stored them.
  final Map<int, List<TaskComment>> taskComments = {};

  /// The bytes the server answers per `(task, attachment, preview)`.
  final Map<(int, int, AttachmentPreviewSize?), AttachmentBlob>
  attachmentBlobs = {};

  /// Addresses a task had before it moved, `(project id, index)` to its
  /// id: a by-index read of one answers the task, as v2 does after its
  /// redirect.
  final Map<(int, int), int> retiredIndexes = {};

  /// The server's notifications for the user, newest first.
  List<ServerNotification> serverNotifications = [];

  /// The users with access per project, for the assignee search.
  final Map<int, List<User>> projectUsers = {};

  /// Everyone on the server, for the global user search.
  List<User> allUsers = [];

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
      if (task.id == id) return _expanded(task, expand);
    }
    throw const NotFound(code: 4002);
  }

  @override
  Future<TaskDetails> readDetails(int id) async {
    await _client._request('task details $id');
    if (!_client.allTasks.any((task) => task.id == id)) {
      throw const NotFound(code: 4002);
    }
    return _client.taskDetails[id] ??
        TaskDetails(subscription: _client.taskSubscriptions[id]);
  }

  /// [project] is a project id when it is all digits, else an identifier
  /// compared ignoring case; like the server, a project the user cannot
  /// read is `Forbidden` and an unknown one `NotFound` 3001.
  @override
  Future<Task> readByIndex(String project, int index) async {
    await _client._request('task by-index $project $index');
    final projectId = int.tryParse(project);
    final found = _client.allProjects.where(
      (candidate) => projectId != null
          ? candidate.id == projectId
          : candidate.identifier.isNotEmpty &&
                candidate.identifier.toLowerCase() == project.toLowerCase(),
    );
    final match = found.firstOrNull;
    if (match == null) throw const NotFound(code: 3001);
    if (_client.forbiddenProjects.contains(match.id)) {
      throw const Forbidden();
    }
    final retired = _client.retiredIndexes[(match.id, index)];
    for (final task in _client.allTasks) {
      if (retired != null
          ? task.id == retired
          : task.projectId == match.id && task.index == index) {
        return task;
      }
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
    return _client._page(
      [for (final task in matching) _expanded(task, query.expand)],
      page: query.page,
      perPage: query.perPage,
    );
  }

  /// The comment count and the unread flag only with their expands, like
  /// the server; the codec reads their absence as 0 and false.
  static Task _expanded(Task task, Set<TaskExpand> expand) => task.copyWith(
    commentCount: expand.contains(TaskExpand.commentCount)
        ? task.commentCount
        : 0,
    isUnread: expand.contains(TaskExpand.isUnread) && task.isUnread,
  );

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

/// The boards of [FakeSyncClient.viewBuckets] like 2.7.0 through the real
/// port: a page size per bucket capped at the server's, cards by position
/// then id, each with its position and bucket. A view without buckets
/// answers `NotFound` 3014.
final class FakeBucketsPort implements BucketsPort {
  new(this._client);

  final FakeSyncClient _client;

  /// The `filterTimezone` of every read, in order.
  final List<String?> timezones = [];

  @override
  Future<List<BoardBucket>> board(
    int projectId,
    int viewId, {
    int perPage = 50,
    String? filterTimezone,
  }) async {
    await _client._request(
      'board project $projectId view $viewId per_page=$perPage',
    );
    timezones.add(filterTimezone);
    final buckets = _client.viewBuckets[viewId];
    if (buckets == null) throw const NotFound(code: 3014);
    final size = perPage > _client.maxPerPage ? _client.maxPerPage : perPage;
    return [
      for (final bucket in buckets)
        _boardBucket(projectId, bucket, _cardsIn(projectId, bucket), size),
    ];
  }

  BoardBucket _boardBucket(
    int projectId,
    Bucket bucket,
    List<Task> cards,
    int size,
  ) => BoardBucket(
    bucket: Bucket(
      id: bucket.id,
      viewId: bucket.viewId,
      title: bucket.title,
      limit: bucket.limit,
      count: cards.length,
      position: bucket.position,
    ),
    tasks: [
      for (final task in cards.take(size)) task.copyWith(bucketId: bucket.id),
    ],
  );

  @override
  Future<Page<Task>> bucketTasks(
    int projectId,
    int viewId,
    int bucketId, {
    required int page,
    int perPage = 50,
    String? filterTimezone,
  }) async {
    await _client._request(
      'bucket $bucketId of view $viewId page $page per_page=$perPage',
    );
    timezones.add(filterTimezone);
    final buckets = _client.viewBuckets[viewId];
    if (buckets == null) throw const NotFound(code: 3014);
    final bucket = buckets.where((bucket) => bucket.id == bucketId).firstOrNull;
    final cards = bucket == null ? <Task>[] : _cardsIn(projectId, bucket);
    return _client._page(
      [for (final task in cards) task.copyWith(bucketId: bucketId)],
      page: page,
      perPage: perPage,
    );
  }

  List<Task> _cardsIn(int projectId, Bucket bucket) {
    final slots = _client.bucketSlots[bucket.viewId] ?? const {};
    return [
      for (final task in _client.allTasks)
        if (slots[task.id] case final slot?
            when task.projectId == projectId && slot.bucketId == bucket.id)
          task.copyWith(position: slot.position),
    ]..sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
    });
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

  /// Matches the exact username in any case or a part of the name, as the
  /// server does for people who allow it; a blank query without a request.
  @override
  Future<List<User>> searchUsers(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    await _client._request('search users $needle');
    return [
      for (final user in _client.allUsers)
        if (user.username.toLowerCase() == needle ||
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

/// Pages of [FakeSyncClient.taskComments] in the server's order: by
/// `created` to the second only, ties in id order whichever the direction,
/// like 2.7.0.
final class FakeCommentsPort implements CommentsPort {
  new(this._client);

  final FakeSyncClient _client;

  @override
  Future<Page<TaskComment>> list(
    int taskId, {
    int page = 1,
    int? perPage,
    bool newestFirst = false,
  }) async {
    await _client._request(
      'comments $taskId page $page ${newestFirst ? 'desc' : 'asc'}',
    );
    if (!_client.allTasks.any((task) => task.id == taskId)) {
      throw const NotFound(code: 4002);
    }
    int second(TaskComment comment) =>
        (comment.created?.millisecondsSinceEpoch ?? 0) ~/ 1000;
    final ordered = [...?_client.taskComments[taskId]]
      ..sort((a, b) {
        final byCreated = newestFirst
            ? second(b).compareTo(second(a))
            : second(a).compareTo(second(b));
        return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
      });
    return _client._page(ordered, page: page, perPage: perPage);
  }
}

final class FakeAttachmentsPort implements AttachmentsPort {
  new(this._client);

  final FakeSyncClient _client;

  @override
  Future<AttachmentBlob> fetch(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) async {
    await _client._request(
      'attachment $taskId $attachmentId ${preview?.wireName ?? 'original'}',
    );
    return _client.attachmentBlobs[(taskId, attachmentId, preview)] ??
        (throw const NotFound(code: 4002));
  }

  /// Writes the original of `attachmentBlobs` to [target], creating its
  /// folder; a cancelled token fails like dio.
  @override
  Future<void> download(
    int taskId,
    int attachmentId, {
    required File target,
    CancelToken? cancel,
  }) async {
    await _client._request('download $taskId $attachmentId');
    if (cancel?.isCancelled ?? false) {
      throw DioException.requestCancelled(
        requestOptions: RequestOptions(),
        reason: cancel!.cancelError,
      );
    }
    final blob =
        _client.attachmentBlobs[(taskId, attachmentId, null)] ??
        (throw const NotFound(code: 4011));
    await target.parent.create(recursive: true);
    await target.writeAsBytes(blob.bytes);
  }
}

final class FakeSavedFiltersReadPort implements SavedFiltersReadPort {
  new(this._client);

  final FakeSyncClient _client;

  @override
  Future<SavedFilter> read(int id) async {
    await _client._request('filter $id');
    return _client.savedFilterDefinitions[id] ??
        (throw const NotFound(code: 11001));
  }
}
