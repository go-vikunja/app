import 'dart:async';

import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';

/// An OS that holds what was scheduled in [pending] until it is cancelled
/// or [fire]d; every call is logged. [current] is what [capabilities]
/// reports and what [requestPermission] answers.
final class FakeNotificationGateway implements NotificationGateway {
  NotificationCapabilities current = const NotificationCapabilities(
    permission: NotificationPermission.granted,
    exactAlarms: true,
  );

  final Map<int, ScheduledNotification> pending = {};
  final List<ScheduledNotification> scheduled = [];
  final List<int> cancelled = [];
  final List<
    ({
      int osId,
      String title,
      String body,
      String payload,
      NotificationPrivacy privacy,
    })
  >
  shown = [];

  /// `initialize`, `capabilities`, `requestPermission`,
  /// `openExactAlarmSettings`, `openNotificationSettings`,
  /// `schedule <osId>`, `cancel <osId>`, `pendingIds`, `showNow <osId>`.
  final List<String> calls = [];

  /// Called before every call with its description; throwing fails it,
  /// awaiting holds it.
  Future<void> Function(String call)? beforeCall;

  /// The OS showed the notification: it is no longer pending.
  void fire(int osId) => pending.remove(osId);

  Future<void> _call(String description) async {
    calls.add(description);
    await beforeCall?.call(description);
  }

  @override
  Future<void> initialize() => _call('initialize');

  @override
  Future<NotificationCapabilities> capabilities() async {
    await _call('capabilities');
    return current;
  }

  @override
  Future<NotificationCapabilities> requestPermission() async {
    await _call('requestPermission');
    return current;
  }

  @override
  Future<void> openExactAlarmSettings() => _call('openExactAlarmSettings');

  @override
  Future<void> openNotificationSettings() => _call('openNotificationSettings');

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    await _call('schedule ${notification.osId}');
    scheduled.add(notification);
    pending[notification.osId] = notification;
  }

  @override
  Future<void> cancel(int osId) async {
    await _call('cancel $osId');
    cancelled.add(osId);
    pending.remove(osId);
    tray.remove(osId);
  }

  @override
  Future<Set<int>> pendingIds() async {
    await _call('pendingIds');
    return pending.keys.toSet();
  }

  @override
  Future<void> showNow({
    required int osId,
    required String title,
    required String body,
    required String payload,
    NotificationPrivacy privacy = const NotificationPrivacy(),
  }) async {
    await _call('showNow $osId');
    shown.add((
      osId: osId,
      title: title,
      body: body,
      payload: payload,
      privacy: privacy,
    ));
  }

  final List<
    ({
      int osId,
      String title,
      String body,
      String payload,
      String? subtitle,
      String? group,
      NotificationPrivacy privacy,
    })
  >
  activities = [];

  /// What the tray holds: shown activity notifications until cancelled.
  final Map<int, String?> tray = {};

  @override
  Future<List<DeliveredNotification>> delivered() async {
    await _call('delivered');
    return [
      for (final MapEntry(:key, :value) in tray.entries)
        (osId: key, payload: value),
    ];
  }

  @override
  Future<void> showActivity({
    required int osId,
    required String title,
    required String body,
    required String payload,
    String? subtitle,
    String? group,
    NotificationPrivacy privacy = const NotificationPrivacy(),
  }) async {
    await _call('showActivity $osId');
    activities.add((
      osId: osId,
      title: title,
      body: body,
      payload: payload,
      subtitle: subtitle,
      group: group,
      privacy: privacy,
    ));
    tray[osId] = payload;
  }
}

final class FakeNotificationPreferencesStore
    implements NotificationPreferencesStore {
  final Map<String, NotificationPreferences> values = {};
  final List<(String, NotificationPreferences)> writes = [];
  final _changes =
      StreamController<(String, NotificationPreferences)>.broadcast();

  @override
  Stream<(String accountId, NotificationPreferences preferences)> get changes =>
      _changes.stream;

  @override
  Future<NotificationPreferences> read(String accountId) async =>
      values[accountId] ?? const NotificationPreferences();

  @override
  Future<void> write(
    String accountId,
    NotificationPreferences preferences,
  ) async {
    values[accountId] = preferences;
    writes.add((accountId, preferences));
    if (!_changes.isClosed) _changes.add((accountId, preferences));
  }

  @override
  Future<void> delete(String accountId) async => values.remove(accountId);

  void dispose() => unawaited(_changes.close());
}
