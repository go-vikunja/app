import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

final _log = Logger('AccountData');

/// Subscriptions straight from the server, which has the state only on a
/// single read of the task or project. A task created here is addressed
/// by its server id once the create was answered; before that it throws
/// [TaskNotSyncedYet]. What a read or a toggle's read-back says is stored
/// for the notifications (D80), and a task's unfollow that went through
/// also before its read-back; a failure to store it is logged and never
/// fails the call.
final class LocalSubscriptionRepository implements SubscriptionRepository {
  new(
    this._db,
    this._read,
    this._write, {
    this._subscriberId,
    this._refreshAfterWrite,
  });

  final AppDatabase _db;
  final VikunjaReadClient _read;
  final VikunjaWriteClient _write;

  /// The user's id on a server whose reminders follow the subscriptions:
  /// a task's state is then recorded for the user. Null records no task's;
  /// a project's state is stored on every server, as the project lists
  /// store it.
  final int? _subscriberId;

  /// Started after a project's toggle, so that its subprojects follow with
  /// the next project list.
  final Future<void> Function()? _refreshAfterWrite;

  @override
  Future<Subscription?> forTask(int taskId) async {
    final id = await _serverId(taskId);
    final read = await _read.subscriptions.forTask(id);
    await _recordTask(id, read);
    return read;
  }

  @override
  Future<Subscription?> forProject(int projectId) async {
    final read = await _read.subscriptions.forProject(projectId);
    await _recordProject(projectId, read);
    return read;
  }

  @override
  Future<Subscription?> setTaskSubscribed(
    int taskId, {
    required bool subscribed,
  }) async {
    final id = await _serverId(taskId);
    await _set(SubscriptionEntity.task, id, subscribed: subscribed);
    // An unfollow that went through always leaves none (a row deleted or an
    // opt-out stored), for a task as for a project, so a failed read-back
    // must not keep the old state; a follow that went through may still be
    // one through a parent (412).
    if (!subscribed) await _recordTask(id, null);
    final read = await _read.subscriptions.forTask(id);
    await _recordTask(id, read);
    return read;
  }

  @override
  Future<Subscription?> setProjectSubscribed(
    int projectId, {
    required bool subscribed,
  }) async {
    await _set(SubscriptionEntity.project, projectId, subscribed: subscribed);
    try {
      if (!subscribed) await _recordProject(projectId, null);
      final read = await _read.subscriptions.forProject(projectId);
      await _recordProject(projectId, read);
      return read;
    } finally {
      _refreshQuietly();
    }
  }

  Future<void> _set(
    SubscriptionEntity entity,
    int id, {
    required bool subscribed,
  }) => subscribed
      ? _write.subscriptions.subscribe(entity, id)
      : _write.subscriptions.unsubscribe(entity, id);

  Future<void> _recordTask(int id, Subscription? read) async {
    final userId = _subscriberId;
    if (userId == null) return;
    try {
      await _db.tasksDao.storeOwnSubscription(id, read, userId: userId);
    } on Object catch (error) {
      _log.warning(
        'Could not store whether the user follows a task: '
        '${error.runtimeType}',
      );
    }
  }

  Future<void> _recordProject(int projectId, Subscription? read) async {
    try {
      await _db.projectsDao.storeSubscription(projectId, read);
    } on Object catch (error) {
      _log.warning(
        'Could not store whether the user follows a project: '
        '${error.runtimeType}',
      );
    }
  }

  void _refreshQuietly() {
    final refresh = _refreshAfterWrite;
    if (refresh == null) return;
    unawaited(
      refresh().then<void>(
        (_) {},
        onError: (Object error) => _log.fine(
          'Sync after a follow change failed: ${error.runtimeType}',
        ),
      ),
    );
  }

  Future<int> _serverId(int taskId) async {
    final id = await _db.tasksDao.resolveId(taskId);
    if (id < 0) throw TaskNotSyncedYet(taskId);
    return id;
  }
}
