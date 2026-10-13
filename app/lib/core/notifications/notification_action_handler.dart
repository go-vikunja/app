import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationResponse, NotificationResponseType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_scheduler.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('NotificationAction');

/// The Done, Snooze 10 min and Snooze 1 h actions, in the isolate the
/// plugin starts for them: a container like bootstrap's, with session
/// managers that never refresh, the action, then the account's scheduler
/// brought in step. Never throws; the container is disposed at the end.
///
/// iOS completes the notification response before this runs and may
/// suspend the process within seconds, so the handler tells the OS what
/// changed before it waits for the network, and waits less there.
Future<void> handleNotificationAction(NotificationResponse response) async {
  final ProviderContainer container;
  try {
    container = ProviderContainer(
      overrides: [
        clientIdentityProvider.overrideWithValue(await ClientIdentity.load()),
        deviceAppLocalizationsProvider.overrideWithValue(
          await loadDeviceAppLocalizations(SharedPreferencesStore()),
        ),
        ...backgroundActionOverrides,
      ],
    );
  } on Object catch (error) {
    _log.severe(
      'Could not start for a notification action: ${error.runtimeType}',
    );
    return;
  }
  try {
    await NotificationActionHandler(
      container,
      drainTimeout: defaultTargetPlatform == TargetPlatform.iOS
          ? const Duration(seconds: 5)
          : const Duration(seconds: 20),
    ).handle(response);
  } finally {
    container.dispose();
  }
}

/// Session managers that never rotate the refresh token (D26, architecture
/// §5.8): a stored access token that is still valid is used, otherwise the
/// op stays queued for the app to send.
final List<Override> backgroundActionOverrides = [
  sessionManagersProvider.overrideWith(_nonRefreshingSessionManagers),
  runsHeadlessProvider.overrideWithValue(true),
];

SessionManagers _nonRefreshingSessionManagers(Ref ref) {
  final registry = ref.watch(accountRegistryProvider);
  return SessionManagers(
    tokenStore: ref.watch(tokenStoreProvider),
    clockOffsets: ref.watch(serverClockOffsetsProvider),
    tokenGateway: ref.watch(tokenGatewayProvider),
    connectionFor: (accountId) async =>
        (await registry.find(accountId))?.connection,
    markNeedsReauth: registry.markNeedsReauth,
    refreshes: false,
  );
}

final class NotificationActionHandler {
  new(this._container, {this.drainTimeout = const Duration(seconds: 20)});

  final ProviderContainer _container;

  /// How long Done waits for the outbox before the isolate may go; the op
  /// stays queued either way.
  final Duration drainTimeout;

  /// Done marks the task done through the outbox (a temporary id is
  /// followed to the server id), cancels the task's other notifications,
  /// waits for the drain up to [drainTimeout] and reconciles; a snooze
  /// moves the notification to now plus 10 min or 1 h
  /// ([NotificationScheduler.snooze]). A payload or account that is not
  /// understood is ignored. Errors are logged, never thrown.
  Future<void> handle(NotificationResponse response) async {
    try {
      await _handle(response);
    } on Object catch (error, stackTrace) {
      _log.warning(
        'Notification action ${response.actionId} failed: '
        '${error.runtimeType}',
        null,
        stackTrace,
      );
    }
  }

  Future<void> _handle(NotificationResponse response) async {
    final actionId = response.actionId;
    if (actionId == null ||
        response.notificationResponseType !=
            NotificationResponseType.selectedNotificationAction) {
      return;
    }
    final json = response.payload;
    if (json == null) {
      _log.info('Ignored a notification action without a payload');
      return;
    }
    final NotificationPayload payload;
    try {
      payload = NotificationPayload.fromJson(json);
    } on FormatException {
      _log.info('Ignored a notification action with an unreadable payload');
      return;
    }
    final accounts = await _container.read(accountsProvider.future);
    if (accounts.find(payload.accountId) == null) {
      _log.info('Ignored a notification action of an unknown account');
      return;
    }
    switch (actionId) {
      case NotificationActionIds.markDone:
        await _markDone(payload);
        await _scheduler(payload)?.reconcile();
      case NotificationActionIds.snooze10Minutes:
        await _snooze(payload, const Duration(minutes: 10));
      case NotificationActionIds.snooze1Hour:
        await _snooze(payload, const Duration(hours: 1));
      default:
        _log.info('Ignored the unknown notification action $actionId');
    }
  }

  NotificationScheduler? _scheduler(NotificationPayload payload) =>
      _container.read(notificationSchedulerProvider(payload.accountId));

  Future<void> _markDone(NotificationPayload payload) async {
    final db = _container.read(appDatabaseProvider(payload.accountId));
    // Kept alive for the write: the repository is not a keep-alive provider.
    final repository = _container.listen(
      accountTaskRepositoryProvider(payload.accountId),
      (_, _) {},
    );
    try {
      await repository.read().setDone(payload.taskId, done: true);
      await _cancelNotificationsOf(payload, db);
      final sender = _container.read(outboxSenderProvider(payload.accountId));
      try {
        await sender.drain().timeout(drainTimeout);
        if (sender.blockedBy is TokenRejected) await _enqueueDrain(payload);
      } on TimeoutException {
        _log.info(
          'The done of task ${payload.taskId} is still on its way after '
          '${drainTimeout.inSeconds} s; it stays queued',
        );
      }
    } finally {
      repository.close();
    }
    _log.fine('Marked task ${payload.taskId} done from its notification');
  }

  /// The access token had expired, and this isolate never refreshes: a
  /// background run that may refresh sends the op within minutes instead
  /// of at the next app start (Android; a no-op on iOS).
  Future<void> _enqueueDrain(NotificationPayload payload) async {
    try {
      await _container.read(backgroundSchedulerProvider).enqueueDrain();
      _log.info(
        'The done of task ${payload.taskId} waits for a token refresh; '
        'a background drain is queued',
      );
    } on Object catch (error) {
      _log.warning('Could not queue a background drain: ${error.runtimeType}');
    }
  }

  /// Before the drain, so the OS is told while the isolate is sure to run;
  /// a gateway that fails does not hold the drain back.
  Future<void> _cancelNotificationsOf(
    NotificationPayload payload,
    AppDatabase db,
  ) async {
    final taskIds = {
      payload.taskId,
      await db.tasksDao.resolveId(payload.taskId),
    };
    final rows = await db.scheduledNotificationsDao.forTasks(taskIds);
    final gateway = _container.read(notificationGatewayProvider);
    try {
      for (final row in rows) {
        await gateway.cancel(row.osId);
      }
    } on Object catch (error) {
      _log.warning(
        'Could not cancel the notifications of task ${payload.taskId}: '
        '${error.runtimeType}',
      );
    }
    await db.scheduledNotificationsDao.deleteForTasks(taskIds);
  }

  Future<void> _snooze(NotificationPayload payload, Duration duration) =>
      _scheduler(
        payload,
      )?.snooze(key: payload.key, taskId: payload.taskId, duration: duration) ??
      Future.value();
}
