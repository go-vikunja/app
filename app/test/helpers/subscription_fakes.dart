import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository.dart';

/// Subscriptions as the server holds them: [taskStates] and
/// [projectStates] are what a read answers per id (absent: not
/// subscribed); an inherited one names the project. Subscribing stores the
/// entity's own subscription, unsubscribing leaves none (for an inherited
/// one that is the server's opt-out). Every call is recorded in [calls]
/// (`forTask 3`, `forProject 7`, `setTask 3 true`, `setProject 7 false`);
/// [beforeCall] can hold one, and [readFailure] / [writeFailure] (a
/// `VikunjaFailure`, or `TaskNotSyncedYet`) are thrown instead while set.
final class FakeSubscriptionRepository implements SubscriptionRepository {
  final Map<int, Subscription?> taskStates = {};
  final Map<int, Subscription?> projectStates = {};
  final List<String> calls = [];
  Exception? readFailure;
  Exception? writeFailure;
  Future<void> Function(String call)? beforeCall;

  @override
  Future<Subscription?> forTask(int taskId) async {
    await _call('forTask $taskId', readFailure);
    return taskStates[taskId];
  }

  @override
  Future<Subscription?> forProject(int projectId) async {
    await _call('forProject $projectId', readFailure);
    return projectStates[projectId];
  }

  @override
  Future<Subscription?> setTaskSubscribed(
    int taskId, {
    required bool subscribed,
  }) async {
    await _call('setTask $taskId $subscribed', writeFailure);
    return taskStates[taskId] = subscribed
        ? Subscription(entity: SubscriptionEntity.task, entityId: taskId)
        : null;
  }

  @override
  Future<Subscription?> setProjectSubscribed(
    int projectId, {
    required bool subscribed,
  }) async {
    await _call('setProject $projectId $subscribed', writeFailure);
    return projectStates[projectId] = subscribed
        ? Subscription(entity: SubscriptionEntity.project, entityId: projectId)
        : null;
  }

  Future<void> _call(String call, Exception? failure) async {
    calls.add(call);
    await beforeCall?.call(call);
    if (failure != null) throw failure;
  }
}
