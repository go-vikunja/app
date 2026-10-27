import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';

final _log = Logger('ExternalDone');

/// A Done tapped outside the app's screens, on a notification or a
/// home-screen widget, in whatever container the OS started for it: the
/// task is marked done through the outbox (a temporary id is followed to
/// the server id), its notifications are cancelled and the widgets redrawn
/// before anything waits for the network, the outbox is drained for at
/// most [drainTimeout] (with session managers that never refresh, a
/// rejected token queues a background drain instead), then the account's
/// notifications are planned again and the widgets redrawn once more.
final class ExternalDone {
  new(this._container, {this.drainTimeout = const Duration(seconds: 20)});

  final ProviderContainer _container;

  /// How long the drain is awaited before the isolate may go; the op stays
  /// queued either way.
  final Duration drainTimeout;

  Future<void> markDone(String accountId, int taskId) async {
    // Kept alive for the write: the repository is not a keep-alive provider.
    final repository = _container.listen(
      accountTaskRepositoryProvider(accountId),
      (_, _) {},
    );
    try {
      await repository.read().setDone(taskId, done: true);
      await settle(accountId, {taskId});
    } finally {
      repository.close();
    }
    _log.fine('Marked task $taskId done from outside the app');
  }

  /// What follows once the Done of [taskIds] is in the outbox. Without
  /// [drains] the outbox is left to the caller (a background run drains it
  /// next, with session managers that refresh).
  Future<void> settle(
    String accountId,
    Set<int> taskIds, {
    bool drains = true,
  }) async {
    final db = _container.read(appDatabaseProvider(accountId));
    await _cancelNotificationsOf(taskIds, db);
    await _refreshWidgets(accountId);
    if (drains) await _drain(accountId, taskIds);
    await _container
        .read(notificationSchedulerProvider(accountId))
        ?.reconcile();
    // A repeating task the server reopened with its next dates.
    if (drains) await _refreshWidgets(accountId);
  }

  Future<void> _drain(String accountId, Set<int> taskIds) async {
    final sender = _container.read(outboxSenderProvider(accountId));
    try {
      await sender.drain().timeout(drainTimeout);
      if (sender.blockedBy is TokenRejected) await _enqueueDrain(taskIds);
    } on TimeoutException {
      _log.info(
        'The done of tasks $taskIds is still on its way after '
        '${drainTimeout.inSeconds} s; it stays queued',
      );
    }
  }

  /// The access token had expired, and this isolate never refreshes: a
  /// background run that may refresh sends the op within minutes instead
  /// of at the next app start (Android; a no-op on iOS).
  Future<void> _enqueueDrain(Set<int> taskIds) async {
    try {
      await _container.read(backgroundSchedulerProvider).enqueueDrain();
      _log.info(
        'The done of tasks $taskIds waits for a token refresh; a background '
        'drain is queued',
      );
    } on Object catch (error) {
      _log.warning('Could not queue a background drain: ${error.runtimeType}');
    }
  }

  /// Before the drain, so the OS is told while the isolate is sure to run;
  /// a gateway that fails does not hold the drain back.
  Future<void> _cancelNotificationsOf(Set<int> taskIds, AppDatabase db) async {
    final ids = {
      ...taskIds,
      for (final taskId in taskIds) await db.tasksDao.resolveId(taskId),
    };
    final rows = await db.scheduledNotificationsDao.forTasks(ids);
    final gateway = _container.read(notificationGatewayProvider);
    try {
      for (final row in rows) {
        await gateway.cancel(row.osId);
      }
    } on Object catch (error) {
      _log.warning(
        'Could not cancel the notifications of tasks $taskIds: '
        '${error.runtimeType}',
      );
    }
    await db.scheduledNotificationsDao.deleteForTasks(ids);
  }

  Future<void> _refreshWidgets(String accountId) =>
      _container.read(widgetRefresherProvider).refresh(accountId);
}
