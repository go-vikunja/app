import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationResponse, NotificationResponseType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_scheduler.dart';
import 'package:vikunja_mobile/core/outbox/external_done.dart';
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

  /// Done is [ExternalDone.markDone]: through the outbox, the task's other
  /// notifications cancelled, the drain awaited up to [drainTimeout], then
  /// a reconcile; a snooze moves the notification to now plus 10 min or
  /// 1 h ([NotificationScheduler.snooze]). A payload or account that is not
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
        await ExternalDone(
          _container,
          drainTimeout: drainTimeout,
        ).markDone(payload.accountId, payload.taskId);
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

  Future<void> _snooze(NotificationPayload payload, Duration duration) =>
      _scheduler(
        payload,
      )?.snooze(key: payload.key, taskId: payload.taskId, duration: duration) ??
      Future.value();
}
