import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_plan.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';

final _log = Logger('ExternalDone');

/// What a notification or a widget row showed of a task when its Done was
/// tapped. The server moves a repeating task on with every Done it gets,
/// so a Done tapped on an occurrence the task has left behind (done in the
/// app or on the web since) would move it once more and lose its next
/// reminder.
@immutable
final class TappedOccurrence {
  /// A reminder or due-date notification: its key and the task's own
  /// instant it stood for.
  const new notification({
    required String this._key,
    required DateTime this._at,
  });

  /// A widget row and the due date it showed, null for none.
  const new widgetRow({DateTime? dueAt}) : _key = null, _at = dueAt;

  final String? _key;
  final DateTime? _at;

  /// The Done is not for [task] as it is now: it is done already, or it
  /// repeats and has another instant than the one shown. A task that does
  /// not repeat takes the Done whatever was shown. A widget row tells by
  /// the due date alone, so a repeating task without one takes it too.
  bool passedBy(Task task) {
    if (task.done) return true;
    if (!task.repeats) return false;
    final DateTime? current;
    if (_key case final key?) {
      final parsed = parseNotificationKey(key);
      if (parsed == null) return false;
      current = notificationInstantOf(task, parsed.kind, parsed.ordinal);
    } else {
      current = task.dueDate;
    }
    return !sameInstant(current, _at);
  }
}

/// A Done tapped outside the app's screens, on a notification or a
/// home-screen widget, in whatever container the OS started for it: the
/// task is marked done through the outbox (a temporary id is followed to
/// the server id), its notifications are cancelled, also in the tray, and
/// the widgets redrawn before anything waits for the network, the outbox is
/// drained for at most [drainTimeout] (with session managers that never
/// refresh, a rejected token queues a background drain instead), then the
/// account's notifications are planned again and the widgets redrawn once
/// more.
final class ExternalDone {
  new(this._container, {this.drainTimeout = const Duration(seconds: 20)});

  final ProviderContainer _container;

  /// How long the drain is awaited before the isolate may go; the op stays
  /// queued either way.
  final Duration drainTimeout;

  /// With [shown], a Done the task has passed by ([TappedOccurrence]) is
  /// ignored, and only the account's notifications are planned again,
  /// which withdraws what the tray still shows of the old occurrence; but
  /// a Done of the task that still waits in the outbox (a widget's,
  /// imported just before on iOS) is settled then as a new one would be,
  /// drain included. Without [shown] (a notification scheduled before step
  /// 40e) the Done always goes.
  Future<void> markDone(
    String accountId,
    int taskId, {
    TappedOccurrence? shown,
  }) async {
    if (shown != null) {
      final db = _container.read(appDatabaseProvider(accountId));
      final task = await db.tasksDao.find(await db.tasksDao.resolveId(taskId));
      if (task != null && shown.passedBy(task)) {
        if ((await db.outboxDao.pendingChangesFor(task.id))?.done == true) {
          await settle(accountId, {taskId});
          return;
        }
        _log.info(
          'Ignored a Done of task $taskId from outside the app: the task is '
          'done or has moved on since',
        );
        await _container
            .read(notificationSchedulerProvider(accountId))
            ?.reconcile();
        return;
      }
    }
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
  /// [drains] the outbox stays as it is: a background run drains it next,
  /// with session managers that refresh; after a notification action's
  /// import on iOS, that action's Done sends it, else the next start,
  /// resume or background run.
  Future<void> settle(
    String accountId,
    Set<int> taskIds, {
    bool drains = true,
  }) async {
    final db = _container.read(appDatabaseProvider(accountId));
    await _cancelNotificationsOf(accountId, taskIds, db);
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

  /// The scheduled ones and those in the tray, before the drain, so the OS
  /// is told while the isolate is sure to run; a gateway that fails does
  /// not hold the drain back.
  Future<void> _cancelNotificationsOf(
    String accountId,
    Set<int> taskIds,
    AppDatabase db,
  ) async {
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
      for (final shown in await gateway.delivered()) {
        final payload = NotificationPayload.tryParse(shown.payload);
        if (payload == null || payload.accountId != accountId) continue;
        if (parseNotificationKey(payload.key) case final key?
            when ids.contains(key.taskId)) {
          await gateway.cancel(shown.osId);
        }
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
