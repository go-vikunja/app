import 'dart:async';

import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'task_edits.dart';

/// A server-like fake for the outbox sender: [serverTasks] are the tasks
/// as the server holds them, a create stores the task under the next id
/// from [nextId] and answers with it, an update applies the changes and
/// answers with the stored task (a repeating task marked done comes back
/// open with shifted dates), a delete removes the task and never fails for
/// a task that is already gone. Every request is logged; [beforeRequest]
/// can fail or hold a request, [afterRequest] can lose its answer.
final class FakeWriteClient implements VikunjaWriteClient {
  new({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<int, Task> serverTasks = {};

  /// The id the next create gets.
  int nextId = 100;

  /// `create <title>`, `update <id>` and `delete <id>`, in order.
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
    final now = _client._clock().toUtc();
    var next = applyChangesToTask(current, changes, now: now);
    if (changes.done ?? false) {
      if (current.repeats) next = reopenRepeating(next, now: now);
    }
    _client.serverTasks[id] = next;
    _client.updates.add((id, changes));
    return next;
  }

  @override
  Future<void> delete(int id) async {
    await _client._request('delete $id');
    _client.deletes.add(id);
    _client.serverTasks.remove(id);
  }
}
