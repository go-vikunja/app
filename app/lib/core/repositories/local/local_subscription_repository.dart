import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

/// Subscriptions straight from the server, which has the state only on a
/// single read of the task or project. A task created here is addressed
/// by its server id once the create was answered; before that it throws
/// [TaskNotSyncedYet].
final class LocalSubscriptionRepository implements SubscriptionRepository {
  new(this._db, this._read, this._write);

  final AppDatabase _db;
  final VikunjaReadClient _read;
  final VikunjaWriteClient _write;

  @override
  Future<Subscription?> forTask(int taskId) async =>
      await _read.subscriptions.forTask(await _serverId(taskId));

  @override
  Future<Subscription?> forProject(int projectId) =>
      _read.subscriptions.forProject(projectId);

  @override
  Future<Subscription?> setTaskSubscribed(
    int taskId, {
    required bool subscribed,
  }) async {
    final id = await _serverId(taskId);
    await _set(SubscriptionEntity.task, id, subscribed: subscribed);
    return await _read.subscriptions.forTask(id);
  }

  @override
  Future<Subscription?> setProjectSubscribed(
    int projectId, {
    required bool subscribed,
  }) async {
    await _set(SubscriptionEntity.project, projectId, subscribed: subscribed);
    return await _read.subscriptions.forProject(projectId);
  }

  Future<void> _set(
    SubscriptionEntity entity,
    int id, {
    required bool subscribed,
  }) => subscribed
      ? _write.subscriptions.subscribe(entity, id)
      : _write.subscriptions.unsubscribe(entity, id);

  Future<int> _serverId(int taskId) async {
    final id = await _db.tasksDao.resolveId(taskId);
    if (id < 0) throw TaskNotSyncedYet(taskId);
    return id;
  }
}
