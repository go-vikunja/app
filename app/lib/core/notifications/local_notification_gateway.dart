import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('LocalNotificationGateway');

/// What the OS shows outside the app: the Android channel and the action
/// buttons. Resolved for the device locale when the gateway is built, so a
/// background isolate gets them without a widget tree.
@immutable
final class LocalNotificationTexts {
  const new({
    required this.channelName,
    required this.channelDescription,
    required this.markDone,
    required this.snooze10Minutes,
    required this.snooze1Hour,
    required this.activityChannelName,
    required this.activityChannelDescription,
  });

  final String channelName;
  final String channelDescription;
  final String markDone;
  final String snooze10Minutes;
  final String snooze1Hour;
  final String activityChannelName;
  final String activityChannelDescription;
}

typedef NotificationResponseCallback = void Function(
  NotificationResponse response,
);

/// [NotificationGateway] over `flutter_local_notifications` 22.3.
///
/// `onResponse` gets taps and actions that show the app while it runs;
/// `onBackgroundResponse` must be a top-level `@pragma('vm:entry-point')`
/// function, which the plugin runs in a separate engine for the actions
/// that show no UI. The notification that launched the app is not reported
/// through `onResponse`: ask [launchResponse].
final class LocalNotificationGateway implements NotificationGateway {
  new({
    required this._texts,
    required this._preferences,
    this._onResponse,
    this._onBackgroundResponse,
    FlutterLocalNotificationsPlugin? plugin,
    this._clock = DateTime.now,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'reminders';

  /// Comments, assignments, mentions and the "Sign in again" notice: less
  /// urgent than a reminder, and without the task actions.
  static const activityChannelId = 'activity';

  /// iOS keeps a category's actions until the app is reinstalled, so a
  /// change to the actions needs a new identifier.
  static const darwinCategoryId = 'task';

  /// `res/drawable/ic_notification.xml`, kept by `res/raw/keep.xml`.
  static const androidIcon = 'ic_notification';

  /// Neither platform reports "never asked", so the gateway remembers it.
  static const permissionAskedKey = 'notifications.permissionAsked';

  final LocalNotificationTexts _texts;
  final PreferencesStore _preferences;
  final NotificationResponseCallback? _onResponse;
  final DidReceiveBackgroundNotificationResponseCallback? _onBackgroundResponse;
  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _clock;
  Future<void>? _initialized;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Also run by the first schedule, show or cancel, so the background
  /// isolate's handler needs no call of its own; a failed attempt is not
  /// remembered, so the next call tries again.
  @override
  Future<void> initialize() => _initialized ??= _initializeOnce();

  Future<void> _initializeOnce() async {
    try {
      await _initialize();
    } on Object {
      _initialized = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    final settings = InitializationSettings(
      android: const AndroidInitializationSettings(androidIcon),
      iOS: DarwinInitializationSettings(
        // Asked by requestPermission, from the setup screen.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            darwinCategoryId,
            // No `foreground` option: the actions run in the background
            // engine, like the Android actions without a user interface.
            actions: [
              DarwinNotificationAction.plain(
                NotificationActionIds.markDone,
                _texts.markDone,
              ),
              DarwinNotificationAction.plain(
                NotificationActionIds.snooze10Minutes,
                _texts.snooze10Minutes,
              ),
              DarwinNotificationAction.plain(
                NotificationActionIds.snooze1Hour,
                _texts.snooze1Hour,
              ),
            ],
          ),
        ],
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        _texts.channelName,
        description: _texts.channelDescription,
        importance: Importance.high,
      ),
    );
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        activityChannelId,
        _texts.activityChannelName,
        description: _texts.activityChannelDescription,
      ),
    );
  }

  @override
  Future<NotificationCapabilities> capabilities() async {
    final enabled = switch ((_android, _ios)) {
      (final android?, _) => await android.areNotificationsEnabled() ?? false,
      (_, final ios?) => (await ios.checkPermissions())?.isEnabled ?? false,
      _ => false,
    };
    final NotificationPermission permission;
    if (enabled) {
      permission = NotificationPermission.granted;
    } else if (await _preferences.getString(permissionAskedKey) != null) {
      permission = NotificationPermission.denied;
    } else {
      permission = NotificationPermission.notAsked;
    }
    // Android before 12 answers true; iOS has no such permission.
    final exactAlarms = switch (_android) {
      final android? => await android.canScheduleExactNotifications() ?? false,
      null => true,
    };
    return NotificationCapabilities(
      permission: permission,
      exactAlarms: exactAlarms,
    );
  }

  @override
  Future<NotificationCapabilities> requestPermission() async {
    try {
      if (_android case final android?) {
        await android.requestNotificationsPermission();
      } else if (_ios case final ios?) {
        await ios.requestPermissions(alert: true, badge: true, sound: true);
      }
    } on PlatformException catch (error) {
      _log.warning('Notification permission request failed: ${error.code}');
    }
    await _preferences.setString(permissionAskedKey, 'true');
    return await capabilities();
  }

  @override
  Future<void> openExactAlarmSettings() async {
    try {
      // Opens the system page on Android 12+ and returns when the user
      // comes back; a no-op that answers true below that.
      await _android?.requestExactAlarmsPermission();
    } on PlatformException catch (error) {
      _log.warning('Could not open the exact alarm settings: ${error.code}');
    }
  }

  @override
  Future<void> openNotificationSettings() async {
    try {
      final opened = await _plugin.openAppNotificationSettings();
      if (opened == false) _log.info('The notification settings did not open');
    } on PlatformException catch (error) {
      _log.warning('Could not open the notification settings: ${error.code}');
    }
  }

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    // The plugin refuses an instant that has passed, and it sends whole
    // seconds, so what is due within the second is shown at once.
    if (!notification.fireAt.isAfter(
      _clock().add(const Duration(seconds: 1)),
    )) {
      await showNow(
        osId: notification.osId,
        title: notification.title,
        body: notification.body,
        payload: notification.payload,
      );
      return;
    }
    try {
      await _zonedSchedule(notification, exact: notification.exact);
    } on PlatformException catch (error) {
      // Exact alarms can be revoked between the capability check and this
      // call; late is better than never.
      if (!notification.exact) rethrow;
      _log.info('Exact alarm refused (${error.code}), scheduling inexactly');
      await _zonedSchedule(notification, exact: false);
    }
  }

  Future<void> _zonedSchedule(
    ScheduledNotification notification, {
    required bool exact,
  }) async {
    await initialize();
    await _plugin.zonedSchedule(
      id: notification.osId,
      title: notification.title,
      body: notification.body,
      // Dates are absolute instants; tz.UTC is built in, so the time zone
      // database stays unloaded.
      scheduledDate: tz.TZDateTime.from(notification.fireAt, tz.UTC),
      notificationDetails: _details(),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: notification.payload,
    );
  }

  @override
  Future<void> cancel(int osId) async {
    await initialize();
    await _plugin.cancel(id: osId);
  }

  @override
  Future<Set<int>> pendingIds() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final request in pending) request.id};
  }

  @override
  Future<void> showNow({
    required int osId,
    required String title,
    required String body,
    required String payload,
  }) async {
    await initialize();
    await _plugin.show(
      id: osId,
      title: title,
      body: body,
      notificationDetails: _details(),
      payload: payload,
    );
  }

  @override
  Future<List<DeliveredNotification>> delivered() async {
    await initialize();
    return [
      for (final notification in await _plugin.getActiveNotifications())
        if (notification.id case final id?)
          (osId: id, payload: notification.payload),
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
  }) async {
    await initialize();
    await _plugin.show(
      id: osId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          activityChannelId,
          _texts.activityChannelName,
          channelDescription: _texts.activityChannelDescription,
          category: AndroidNotificationCategory.social,
          // A comment's first line rarely fits the collapsed view.
          styleInformation: BigTextStyleInformation(body),
          subText: subtitle,
          groupKey: group,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          subtitle: subtitle,
          threadIdentifier: group,
        ),
      ),
      payload: payload,
    );
  }

  /// The tap that started the app, for a cold start; null otherwise.
  Future<NotificationResponse?> launchResponse() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse;
  }

  NotificationDetails _details() => NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      _texts.channelName,
      channelDescription: _texts.channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      // The defaults do what the background handler needs: no user
      // interface (`showsUserInterface`), dismissed on tap
      // (`cancelNotification`).
      actions: [
        for (final (id, title) in [
          (NotificationActionIds.markDone, _texts.markDone),
          (NotificationActionIds.snooze10Minutes, _texts.snooze10Minutes),
          (NotificationActionIds.snooze1Hour, _texts.snooze1Hour),
        ])
          AndroidNotificationAction(id, title),
      ],
    ),
    iOS: const DarwinNotificationDetails(
      categoryIdentifier: darwinCategoryId,
      // Shown while the app is in front too.
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    ),
  );
}
