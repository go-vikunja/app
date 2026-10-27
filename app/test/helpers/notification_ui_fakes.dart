import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/features/notifications/application/notification_providers.dart'
    as ui;
import 'package:vikunja_mobile/features/notifications/application/notification_taps.dart';

/// The OS as the screens see it: [current] is what it allows, every call
/// is logged, and [beforeCall] can hold a call or change the answer.
final class FakeNotificationOs implements NotificationGateway {
  NotificationCapabilities current = const NotificationCapabilities(
    permission: NotificationPermission.granted,
    exactAlarms: true,
  );

  /// `initialize`, `capabilities`, `requestPermission`,
  /// `openExactAlarmSettings`, `openNotificationSettings`,
  /// `schedule <osId>`, `cancel <osId>`, `pendingIds`, `showNow <osId>`.
  final List<String> calls = [];
  Future<void> Function(String call)? beforeCall;
  final Map<int, ScheduledNotification> pending = {};
  final List<({int osId, String title, String body, String payload})> shown =
      [];

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
    pending[notification.osId] = notification;
  }

  @override
  Future<void> cancel(int osId) async {
    await _call('cancel $osId');
    pending.remove(osId);
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
    shown.add((osId: osId, title: title, body: body, payload: payload));
  }

  final List<({int osId, String title, String body, String payload})>
  activities = [];

  @override
  Future<List<DeliveredNotification>> delivered() async {
    await _call('delivered');
    return const [];
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
    activities.add((osId: osId, title: title, body: body, payload: payload));
  }
}

final class FakeNotificationPreferences
    implements NotificationPreferencesStore {
  final Map<String, NotificationPreferences> values = {};
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
    _changes.add((accountId, preferences));
  }

  @override
  Future<void> delete(String accountId) async => values.remove(accountId);
}

/// Taps a test sends; [launchedWith] is the payload that launched the app.
final class FakeNotificationTapSource implements NotificationTapSource {
  new({this.launchedWith});

  String? launchedWith;
  final _taps = StreamController<String>.broadcast();

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async => launchedWith;

  void tap(String payload) => _taps.add(payload);
}

/// The notification plugin and the scheduler core under the screens: no
/// scheduler runs, and the scheduled count is what a test says, unless
/// [schedulers] is set, when the real schedulers run over the databases
/// the test provides and the count comes from the table.
final class NotificationFakes {
  new({
    NotificationCapabilities? capabilities,
    this.scheduledCount = 0,
    this.schedulers = false,
  }) {
    if (capabilities != null) gateway.current = capabilities;
  }

  final gateway = FakeNotificationOs();
  final preferences = FakeNotificationPreferences();
  final taps = FakeNotificationTapSource();
  final bool schedulers;

  /// What the account's `scheduled_notifications` table holds.
  int scheduledCount;

  /// What the OS reports once the permission has been requested.
  void answerRequestWith(NotificationCapabilities capabilities) {
    gateway.beforeCall = (call) async {
      if (call == 'requestPermission') gateway.current = capabilities;
    };
  }

  int calls(String call) => gateway.calls.where((made) => made == call).length;

  List<Override> get overrides => [
    notificationGatewayProvider.overrideWithValue(gateway),
    notificationPreferencesStoreProvider.overrideWithValue(preferences),
    ui.notificationTapSourceProvider.overrideWithValue(taps),
    if (!schedulers) ...[
      accountNotificationSchedulersProvider.overrideWithValue(const {}),
      ui.scheduledNotificationCountProvider.overrideWith(
        (ref, accountId) => Stream.value(scheduledCount),
      ),
    ],
  ];
}
