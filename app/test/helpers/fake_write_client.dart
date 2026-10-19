import 'dart:async';

import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';

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
/// as a move, then a position, per view (see [bucketSlots]). Every request
/// is logged; [beforeRequest] can fail or hold a request, [afterRequest]
/// can lose its answer.
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

  /// `create <title>`, `update <id>`, `delete <id>`,
  /// `move <id> view <view> bucket <bucket>`,
  /// `position <id> view <view> <position>` and `create label <title>`, in
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

const _noPlacements = <MapEntry<int, BucketPlacement>>[];
