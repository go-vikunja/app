import 'dart:async';

import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';

import 'sample_data.dart';
import 'task_edits.dart';

/// A server-like fake for the outbox sender: [serverTasks] are the tasks
/// as the server holds them, a create stores the task under the next id
/// from [nextId] and answers with it, an update applies the changes and
/// answers with the stored task (a repeating task marked done comes back
/// open with shifted dates and reminders), a delete removes the task and
/// never fails for a task that is already gone. Labels and assignees an
/// update adds must be in [serverLabels] and [serverUsers] or already on
/// the task, else it fails like the server: `NotFound` 8002 for a label,
/// 1005 for a user. Relations go onto both tasks, the inverse edge onto
/// the other one; an edge to a task the server does not hold fails with
/// `RelatedTaskMissing` once the rest of the update is applied, as the
/// real port tries every other request first, and a temporary id with an
/// `ArgumentError`, as the real port refuses one. Kanban placements follow
/// as a move, then a position, per view (see [bucketSlots]), and list
/// positions after them (see [listPositions]). Every request is logged;
/// [beforeRequest] can fail or hold a request, [afterRequest] can lose its
/// answer.
final class FakeWriteClient implements VikunjaWriteClient {
  new({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<int, Task> serverTasks = {};
  final Map<int, Label> serverLabels = {};
  final Map<int, User> serverUsers = {};

  /// The id the next create gets.
  int nextId = 100;

  /// The bucket and position of each task per kanban view, by view id,
  /// then task id, as the server holds them.
  final Map<int, Map<int, ({int bucketId, double position})>> bucketSlots = {};

  /// The done and default bucket of each kanban view by view id (0: none),
  /// for the server's done rules: a move into the done bucket marks the
  /// task done, and a repeating one comes back open into the default
  /// bucket, which the move's answer names; a move out of it marks the
  /// task undone; a done update puts the task into every done bucket and
  /// fails as a whole when one of them is refused, an undone one takes it
  /// from the done bucket to the default bucket.
  final Map<int, ({int doneBucketId, int defaultBucketId})> kanbanViews = {};

  /// What a move into a bucket fails with, by bucket id, like a full one
  /// (`DomainError(412, code: 10004)`).
  final Map<int, VikunjaFailure> refusedBuckets = {};

  /// The buckets of each kanban view by view id, then bucket id, for
  /// [buckets] and [views]; their counts are not kept.
  final Map<int, Map<int, Bucket>> serverBuckets = {};

  /// The kanban views [views] answers with, by id; a view missing here is
  /// answered as a plain manual board.
  final Map<int, ProjectView> serverViews = {};

  /// The position of each task per list view, by view id, then task id,
  /// as the server holds them: stored as sent.
  final Map<int, Map<int, double>> listPositions = {};

  /// What a list position write fails with, by view id, like a read share
  /// (`Forbidden`) or a view that is gone (`NotFound` code 3014).
  final Map<int, VikunjaFailure> refusedListViews = {};

  /// The projects [projects] moves, by id.
  final Map<int, Project> serverProjects = {};

  /// What moving a project fails with, by project id, like a write share
  /// moving it under another project (`Forbidden(code: 1)`).
  final Map<int, VikunjaFailure> refusedProjects = {};

  /// `create <title>`, `update <id>`, `delete <id>`,
  /// `move <id> view <view> bucket <bucket>`,
  /// `position <id> view <view> <position>` (kanban and list views alike),
  /// `move project <id> to <position> under <parent>`,
  /// `create label <title>`,
  /// `create bucket view <view> <title> limit <limit> at <position>`,
  /// `update bucket <id> view <view> <title> limit <limit> at <position>`,
  /// `delete bucket <id> view <view>`,
  /// `view <view> buckets done <id> default <id>` (null: unchanged) and
  /// `read view <view>` (both null), in
  /// order; an update's moves and positions follow it.
  final List<String> requests = [];
  final List<NewTask> creates = [];
  final List<(int, TaskChanges)> updates = [];
  final List<int> deletes = [];

  /// Called before every request with its description; throwing fails the
  /// request, awaiting holds it.
  Future<void> Function(String request)? beforeRequest;

  /// Called once the server has stored the request's result, with its
  /// description; throwing loses the answer on its way back.
  Future<void> Function(String request)? afterRequest;

  @override
  late final FakeTasksWritePort tasks = FakeTasksWritePort(this);

  @override
  late final FakeLabelsWritePort labels = FakeLabelsWritePort(this);

  @override
  late final FakeNotificationsWritePort notifications =
      FakeNotificationsWritePort(this);

  @override
  late final FakeSubscriptionsWritePort subscriptions =
      FakeSubscriptionsWritePort(this);

  @override
  late final FakeBucketsWritePort buckets = FakeBucketsWritePort(this);

  @override
  late final FakeProjectViewsWritePort views = FakeProjectViewsWritePort(this);

  @override
  late final FakeProjectsWritePort projects = FakeProjectsWritePort(this);

  Future<void> _request(String description) async {
    requests.add(description);
    await beforeRequest?.call(description);
  }
}

final class FakeTasksWritePort implements TasksWritePort {
  new(this._client);

  final FakeWriteClient _client;

  @override
  Future<Task> create(NewTask task) async {
    final description = 'create ${task.title}';
    await _client._request(description);
    final id = _client.nextId++;
    final created = taskFromNewTask(
      task,
      id: id,
      now: _client._clock().toUtc(),
    );
    _client.serverTasks[id] = created;
    _client.creates.add(task);
    await _client.afterRequest?.call(description);
    return created;
  }

  @override
  Future<Task> update(int id, TaskChanges changes) async {
    await _client._request('update $id');
    final current = _client.serverTasks[id];
    if (current == null) throw const NotFound(code: 4002);
    final labelIds = {
      ..._client.serverLabels.keys,
      ...current.labels.map((label) => label.id),
    };
    if (!labelIds.containsAll(changes.labels?.added ?? const <int>{})) {
      throw const NotFound(code: 8002);
    }
    final userIds = {
      ..._client.serverUsers.keys,
      ...current.assignees.map((user) => user.id),
    };
    if (!userIds.containsAll(changes.assignees?.added ?? const <int>{})) {
      throw const NotFound(code: 1005);
    }
    final relations = changes.relations;
    for (final ref in [...?relations?.added, ...?relations?.removed]) {
      if (ref.otherTaskId <= 0) {
        throw ArgumentError.value(ref.otherTaskId, 'otherTaskId');
      }
    }
    final missing = [
      for (final ref in relations?.added ?? const <TaskRelationRef>{})
        if (!_client.serverTasks.containsKey(ref.otherTaskId)) ref.otherTaskId,
    ];
    if (changes.done case final done? when done != current.done) {
      _checkDoneBuckets(id, done: done, repeats: current.repeats);
    }
    final applied = withoutRelatedTasks(changes, missing.toSet());
    final now = _client._clock().toUtc();
    var next = applyChangesToTask(
      current,
      applied,
      now: now,
      labels: _client.serverLabels,
      users: _client.serverUsers,
    );
    if (changes.done ?? false) {
      if (current.repeats) next = reopenRepeating(next, now: now);
    }
    _client.serverTasks[id] = next;
    if (changes.done case final done? when done != current.done) {
      _moveForDone(id, done: done, repeats: current.repeats);
    }
    if (applied.relations case final sent?) {
      final related = applyRelationChange(
        [..._client.serverTasks.values],
        id,
        sent,
      );
      _client.serverTasks
        ..clear()
        ..addEntries([for (final task in related) MapEntry(task.id, task)]);
    }
    if (missing.isNotEmpty) throw RelatedTaskMissing(missing.first);
    for (final MapEntry(key: viewId, value: placement)
        in changes.kanban?.entries ?? _noPlacements) {
      await _place(id, viewId, placement, now: now);
    }
    for (final MapEntry(key: viewId, value: position)
        in changes.positions?.entries ?? const <MapEntry<int, double>>[]) {
      await _client._request('position $id view $viewId $position');
      if (_client.refusedListViews[viewId] case final failure?) throw failure;
      (_client.listPositions[viewId] ??= {})[id] = position;
    }
    _client.updates.add((id, changes));
    return _client.serverTasks[id]!;
  }

  void _checkDoneBuckets(int id, {required bool done, required bool repeats}) {
    if (!done || repeats) return;
    for (final MapEntry(key: viewId, value: view)
        in _client.kanbanViews.entries) {
      final slot = _client.bucketSlots[viewId]?[id];
      if (view.doneBucketId == 0 || slot?.bucketId == view.doneBucketId) {
        continue;
      }
      if (_client.refusedBuckets[view.doneBucketId] case final failure?) {
        throw failure;
      }
    }
  }

  void _moveForDone(int id, {required bool done, required bool repeats}) {
    for (final MapEntry(key: viewId, value: view)
        in _client.kanbanViews.entries) {
      final slots = _client.bucketSlots[viewId] ??= {};
      final slot = slots[id];
      final target = switch ((done, repeats)) {
        (true, false) when view.doneBucketId != 0 => view.doneBucketId,
        (true, true) => view.defaultBucketId,
        (false, _) when slot != null && slot.bucketId == view.doneBucketId =>
          view.defaultBucketId,
        _ => null,
      };
      if (target == null || target == 0) continue;
      slots[id] = (bucketId: target, position: slot?.position ?? 0);
    }
  }

  /// The move, then the position when the task stayed in the bucket: a
  /// repeating task moved into the done bucket goes to the default one.
  Future<void> _place(
    int id,
    int viewId,
    BucketPlacement placement, {
    required DateTime now,
  }) async {
    final bucketId = placement.bucketId;
    await _client._request('move $id view $viewId bucket $bucketId');
    final slots = _client.bucketSlots[viewId] ??= {};
    final previous = slots[id];
    if (previous?.bucketId != bucketId) {
      if (_client.refusedBuckets[bucketId] case final failure?) throw failure;
    }
    var answered = bucketId;
    final view = _client.kanbanViews[viewId];
    final task = _client.serverTasks[id]!;
    if (view != null && view.doneBucketId != 0) {
      if (bucketId == view.doneBucketId && !task.done) {
        if (task.repeats) {
          _client.serverTasks[id] = reopenRepeating(
            copyTask(task, done: true, doneAt: now),
            now: now,
          );
          answered = view.defaultBucketId == 0
              ? previous?.bucketId ?? bucketId
              : view.defaultBucketId;
        } else {
          _client.serverTasks[id] = copyTask(task, done: true, doneAt: now);
        }
      } else if (previous?.bucketId == view.doneBucketId &&
          bucketId != view.doneBucketId &&
          task.done) {
        _client.serverTasks[id] = copyTask(task, done: false, doneAt: null);
      }
    }
    slots[id] = (bucketId: answered, position: previous?.position ?? 0);
    final position = placement.position;
    if (position == null || answered != bucketId) return;
    await _client._request('position $id view $viewId $position');
    slots[id] = (bucketId: answered, position: position);
  }

  @override
  Future<Task> duplicate(int id) async {
    await _client._request('duplicate $id');
    final source = _client.serverTasks[id];
    if (source == null) throw const NotFound(code: 4002);
    final copyId = _client.nextId++;
    final copy = Task(
      id: copyId,
      title: source.title,
      projectId: source.projectId,
      description: source.description,
      dueDate: source.dueDate,
      startDate: source.startDate,
      endDate: source.endDate,
      priority: source.priority,
      percentDone: source.percentDone,
      hexColor: source.hexColor,
      identifier: '-$copyId',
      index: copyId,
      repeatAfter: source.repeatAfter,
      repeatMode: source.repeatMode,
      labels: source.labels,
      assignees: source.assignees,
      reminders: source.reminders,
      relatedTasks: {
        TaskRelationKind.copiedFrom: [source],
      },
      created: _client._clock().toUtc(),
      updated: _client._clock().toUtc(),
    );
    _client.serverTasks[copyId] = copy;
    return copy;
  }

  @override
  Future<void> markRead(int id) => _client._request('markRead $id');

  @override
  Future<void> delete(int id) async {
    await _client._request('delete $id');
    _client.deletes.add(id);
    _client.serverTasks.remove(id);
  }
}

final class FakeLabelsWritePort implements LabelsWritePort {
  new(this._client);

  final FakeWriteClient _client;

  /// The id the next label create gets.
  int nextLabelId = 900;

  /// Stored in [FakeWriteClient.serverLabels], so tasks can take it.
  @override
  Future<Label> create(NewLabel label) async {
    final description = 'create label ${label.title}';
    await _client._request(description);
    final created = Label(
      id: nextLabelId++,
      title: label.title,
      description: label.description,
      hexColor: label.hexColor,
      created: _client._clock().toUtc(),
    );
    _client.serverLabels[created.id] = created;
    await _client.afterRequest?.call(description);
    return created;
  }
}

final class FakeNotificationsWritePort implements NotificationsWritePort {
  new(this._client);

  final FakeWriteClient _client;
  final List<(int, bool)> marked = [];
  int markedAll = 0;

  @override
  Future<void> markRead(int id, {bool read = true}) async {
    await _client._request('notification read $id $read');
    marked.add((id, read));
  }

  @override
  Future<void> markAllRead() async {
    await _client._request('notifications read all');
    markedAll++;
  }
}

final class FakeSubscriptionsWritePort implements SubscriptionsWritePort {
  new(this._client);

  final FakeWriteClient _client;

  /// What the fake server holds, `<entity>:<id>`.
  final Set<String> subscribed = {};

  @override
  Future<void> subscribe(SubscriptionEntity entity, int id) async {
    await _client._request('subscribe ${entity.wireName} $id');
    subscribed.add('${entity.wireName}:$id');
  }

  @override
  Future<void> unsubscribe(SubscriptionEntity entity, int id) async {
    await _client._request('unsubscribe ${entity.wireName} $id');
    subscribed.remove('${entity.wireName}:$id');
  }
}

/// Like the server: a create without a position lands at `id × 65536`; an
/// update replaces title, limit and position and answers with what was
/// sent; a delete refuses the last bucket of a view (412 code 10003),
/// clears the view's done or default bucket when it was this one, and
/// moves the bucket's tasks (in [FakeWriteClient.bucketSlots]) to the
/// default bucket, else to the leftmost one counted before the delete, so
/// deleting the leftmost while no other default is set leaves them in no
/// bucket, as the server's bug does. A bucket that is gone counts as
/// deleted, as the real port tolerates it.
final class FakeBucketsWritePort implements BucketsWritePort {
  new(this._client);

  final FakeWriteClient _client;

  /// The id the next bucket create gets.
  int nextBucketId = 700;

  @override
  Future<Bucket> create(
    int projectId,
    int viewId, {
    required String title,
    int limit = 0,
    double? position,
  }) async {
    final description =
        'create bucket view $viewId $title limit $limit at $position';
    await _client._request(description);
    final id = nextBucketId++;
    final created = Bucket(
      id: id,
      viewId: viewId,
      title: title,
      limit: limit,
      position: position == null || position == 0 ? id * 65536.0 : position,
    );
    (_client.serverBuckets[viewId] ??= {})[id] = created;
    await _client.afterRequest?.call(description);
    return created;
  }

  @override
  Future<Bucket> update(
    int projectId,
    int viewId, {
    required int bucketId,
    required String title,
    required int limit,
    required double position,
  }) async {
    await _client._request(
      'update bucket $bucketId view $viewId $title limit $limit at $position',
    );
    final buckets = _client.serverBuckets[viewId] ?? const {};
    if (!buckets.containsKey(bucketId)) throw const NotFound(code: 10001);
    return _client.serverBuckets[viewId]![bucketId] = Bucket(
      id: bucketId,
      viewId: viewId,
      title: title,
      limit: limit,
      position: position,
    );
  }

  @override
  Future<void> delete(int projectId, int viewId, int bucketId) async {
    await _client._request('delete bucket $bucketId view $viewId');
    final buckets = _client.serverBuckets[viewId];
    if (buckets == null || !buckets.containsKey(bucketId)) return;
    if (buckets.length <= 1) throw const DomainError(412, code: 10003);
    var view =
        _client.kanbanViews[viewId] ?? (doneBucketId: 0, defaultBucketId: 0);
    view = (
      doneBucketId: view.doneBucketId == bucketId ? 0 : view.doneBucketId,
      defaultBucketId: view.defaultBucketId == bucketId
          ? 0
          : view.defaultBucketId,
    );
    _client.kanbanViews[viewId] = view;
    if (_client.serverViews[viewId] case final stored?) {
      _client.serverViews[viewId] = _withBuckets(
        stored,
        doneBucketId: view.doneBucketId,
        defaultBucketId: view.defaultBucketId,
      );
    }
    final leftmost = ([...buckets.values]..sort(compareBucketOrder)).first;
    final target = view.defaultBucketId != 0
        ? view.defaultBucketId
        : leftmost.id;
    if (_client.bucketSlots[viewId] case final slots?) {
      final moved = [
        for (final MapEntry(key: taskId, value: slot) in slots.entries)
          if (slot.bucketId == bucketId) (taskId, slot.position),
      ];
      for (final (taskId, position) in moved) {
        if (target == bucketId) {
          slots.remove(taskId);
        } else {
          slots[taskId] = (bucketId: target, position: position);
        }
      }
    }
    buckets.remove(bucketId);
  }
}

/// Stores the done and default bucket in [FakeWriteClient.kanbanViews] and
/// [FakeWriteClient.serverViews]: 0 clears one, a bucket of another view
/// fails with 400 code 10002, an unknown id is stored as 0.
final class FakeProjectViewsWritePort implements ProjectViewsWritePort {
  new(this._client);

  final FakeWriteClient _client;

  @override
  Future<ProjectView> setBuckets(
    int projectId,
    int viewId, {
    int? doneBucketId,
    int? defaultBucketId,
  }) async {
    await _client._request(
      doneBucketId == null && defaultBucketId == null
          ? 'read view $viewId'
          : 'view $viewId buckets done $doneBucketId default $defaultBucketId',
    );
    int? checked(int? id) {
      if (id == null || id == 0) return id;
      if (_client.serverBuckets[viewId]?.containsKey(id) ?? false) return id;
      final elsewhere = _client.serverBuckets.entries.any(
        (entry) => entry.key != viewId && entry.value.containsKey(id),
      );
      if (elsewhere) throw const DomainError(400, code: 10002);
      return 0;
    }

    final done = checked(doneBucketId);
    final defaultId = checked(defaultBucketId);
    final current =
        _client.kanbanViews[viewId] ?? (doneBucketId: 0, defaultBucketId: 0);
    final next = (
      doneBucketId: done ?? current.doneBucketId,
      defaultBucketId: defaultId ?? current.defaultBucketId,
    );
    _client.kanbanViews[viewId] = next;
    return _client.serverViews[viewId] = _withBuckets(
      _client.serverViews[viewId] ??
          ProjectView(
            id: viewId,
            projectId: projectId,
            title: 'Kanban',
            kind: ProjectViewKind.kanban,
            bucketConfigurationMode: BucketConfigurationMode.manual,
          ),
      doneBucketId: next.doneBucketId,
      defaultBucketId: next.defaultBucketId,
    );
  }
}

/// Like the server: moves a project of [FakeWriteClient.serverProjects]
/// and answers with it as stored, `updated` bumped and every other field
/// kept, or refuses as the server does: a project or parent that does not
/// exist (`NotFound` code 3001), an archived project or parent
/// (`DomainError` code 3008), the project itself as the parent (3010), one
/// of its descendants (3011), a pseudo project (3009), and what
/// [FakeWriteClient.refusedProjects] holds for the project. A position
/// below 0.1 is an `ArgumentError` before any request, as in the real port.
final class FakeProjectsWritePort implements ProjectsWritePort {
  new(this._client);

  final FakeWriteClient _client;

  @override
  Future<Project> move(
    int projectId, {
    required double position,
    required int parentProjectId,
  }) async {
    if (!(position >= 0.1)) throw ArgumentError.value(position, 'position');
    final description =
        'move project $projectId to $position under $parentProjectId';
    await _client._request(description);
    final projects = _client.serverProjects;
    final project = projects[projectId];
    if (project == null) throw const NotFound(code: 3001);
    if (project.isArchived) throw const DomainError(412, code: 3008);
    if (_client.refusedProjects[projectId] case final failure?) throw failure;
    if (parentProjectId != 0) {
      if (parentProjectId == projectId) {
        throw const DomainError(412, code: 3010);
      }
      if (parentProjectId < 0) throw const DomainError(412, code: 3009);
      final parent = projects[parentProjectId];
      if (parent == null) throw const NotFound(code: 3001);
      if (parent.isArchived) throw const DomainError(412, code: 3008);
      for (Project? above = parent; above != null && !above.isTopLevel;) {
        if (above.parentProjectId == projectId) {
          throw const DomainError(412, code: 3011);
        }
        above = projects[above.parentProjectId];
      }
    }
    final moved = projects[projectId] = movedProject(
      project,
      position: position,
      parentProjectId: parentProjectId,
      updated: _client._clock().toUtc(),
    );
    await _client.afterRequest?.call(description);
    return moved;
  }
}

ProjectView _withBuckets(
  ProjectView view, {
  required int doneBucketId,
  required int defaultBucketId,
}) => ProjectView(
  id: view.id,
  projectId: view.projectId,
  title: view.title,
  kind: view.kind,
  position: view.position,
  filter: view.filter,
  bucketConfigurationMode: view.bucketConfigurationMode,
  defaultBucketId: defaultBucketId,
  doneBucketId: doneBucketId,
);

const _noPlacements = <MapEntry<int, BucketPlacement>>[];
