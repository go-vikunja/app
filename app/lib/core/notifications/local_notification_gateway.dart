import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_payload_records.dart';
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('LocalNotificationGateway');

/// What the OS shows outside the app: the Android channels and the action
/// buttons. Resolved for the device locale when the gateway is built, so a
/// background isolate gets them without a widget tree, and again when the
/// app's language changes ([LocalNotificationGateway.updateTexts]).
@immutable
final class LocalNotificationTexts {
  const new({
    required this.channelName,
    required this.channelDescription,
    required this.markDone,
    required this.snooze10Minutes,
    required this.snooze1Hour,
    required this.snoozeTomorrow,
    required this.activityChannelName,
    required this.activityChannelDescription,
  });

  final String channelName;
  final String channelDescription;
  final String markDone;
  final String snooze10Minutes;
  final String snooze1Hour;
  final String snoozeTomorrow;
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
    required this._payloads,
    this._onResponse,
    this._onBackgroundResponse,
    FlutterLocalNotificationsPlugin? plugin,
    this._clock = DateTime.now,
    this._excursions,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'reminders';

  /// Comments, assignments, mentions and the "Sign in again" notice: less
  /// urgent than a reminder, and without the task actions.
  static const activityChannelId = 'activity';

  /// iOS keeps a category's actions until the app is reinstalled, so a
  /// change to the actions needs a new identifier.
  static const darwinCategoryId = 'task';

  /// [darwinCategoryId] with a Done that asks for the device to be
  /// unlocked, chosen while the app lock is on. Snoozing stays plain: it
  /// only moves a local notification.
  static const darwinLockedCategoryId = 'task_locked';

  /// Only the snoozes, for a task the user may not change.
  static const darwinSnoozeOnlyCategoryId = 'task_snooze';

  /// `res/drawable-*dpi/ic_notification.png`, kept by `res/raw/keep.xml`.
  static const androidIcon = 'ic_notification';

  /// Neither platform reports "never asked", so the gateway remembers it.
  static const permissionAskedKey = 'notifications.permissionAsked';

  LocalNotificationTexts _texts;
  final PreferencesStore _preferences;
  final NotificationPayloadRecords _payloads;
  final NotificationResponseCallback? _onResponse;
  final DidReceiveBackgroundNotificationResponseCallback? _onBackgroundResponse;
  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _clock;

  /// The permission prompts and the system pages they open do not lock
  /// the app.
  final AppExcursions? _excursions;
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
        // Every isolate registers all three: the action isolate initialises
        // the plugin again for each run, and a registration replaces the
        // whole set.
        notificationCategories: [
          _darwinCategory(darwinCategoryId),
          _darwinCategory(darwinLockedCategoryId, doneNeedsUnlock: true),
          _darwinCategory(darwinSnoozeOnlyCategoryId, done: false),
        ],
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );
    await _createChannels();
  }

  Future<void> _createChannels() async {
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

  /// For what is shown and scheduled from now on. Android renames a
  /// channel created again under its id and keeps the user's settings for
  /// it; iOS restarts the app when its language changes, so the categories
  /// keep the texts they were registered with. Never throws.
  Future<void> updateTexts(LocalNotificationTexts texts) async {
    _texts = texts;
    if (_initialized == null) return;
    try {
      await initialize();
      await _createChannels();
    } on Object catch (error) {
      _log.warning(
        'Could not rename the notification channels: ${error.runtimeType}',
      );
    }
  }

  // No `foreground` option: the actions run in the background engine, like
  // the Android actions without a user interface.
  DarwinNotificationCategory _darwinCategory(
    String identifier, {
    bool done = true,
    bool doneNeedsUnlock = false,
  }) => DarwinNotificationCategory(
    identifier,
    actions: [
      if (done)
        DarwinNotificationAction.plain(
          NotificationActionIds.markDone,
          _texts.markDone,
          options: {
            if (doneNeedsUnlock)
              DarwinNotificationActionOption.authenticationRequired,
          },
        ),
      DarwinNotificationAction.plain(
        NotificationActionIds.snooze10Minutes,
        _texts.snooze10Minutes,
      ),
      DarwinNotificationAction.plain(
        NotificationActionIds.snooze1Hour,
        _texts.snooze1Hour,
      ),
      DarwinNotificationAction.plain(
        NotificationActionIds.snoozeTomorrow,
        _texts.snoozeTomorrow,
      ),
    ],
  );

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
      remindersChannelOff: switch (_android) {
        final android? when enabled => await _remindersChannelOff(android),
        _ => false,
      },
    );
  }

  /// A channel the user turned off reports the importance none; a channel
  /// that cannot be read counts as on.
  Future<bool> _remindersChannelOff(
    AndroidFlutterLocalNotificationsPlugin android,
  ) async {
    try {
      final channels = await android.getNotificationChannels() ?? const [];
      return channels.any(
        (channel) =>
            channel.id == channelId && channel.importance == Importance.none,
      );
    } on Object catch (error) {
      _log.info(
        'Could not read the notification channels: ${error.runtimeType}',
      );
      return false;
    }
  }

  @override
  Future<NotificationCapabilities> requestPermission() async {
    try {
      await _roundTrip(() async {
        if (_android case final android?) {
          await android.requestNotificationsPermission();
        } else if (_ios case final ios?) {
          await ios.requestPermissions(alert: true, badge: true, sound: true);
        }
      });
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
      await _roundTrip(
        () async => await _android?.requestExactAlarmsPermission(),
      );
    } on PlatformException catch (error) {
      _log.warning('Could not open the exact alarm settings: ${error.code}');
    }
  }

  Future<T> _roundTrip<T>(Future<T> Function() action) =>
      _excursions?.roundTrip(action) ?? action();

  @override
  Future<void> openNotificationSettings() async {
    try {
      // Answers as soon as the page opens.
      Future<bool?> open() => _plugin.openAppNotificationSettings();
      final excursions = _excursions;
      final opened = excursions == null
          ? await open()
          : await excursions.launchAway(
              open,
              opened: (opened) => opened != false,
            );
      if (opened == false) _log.info('The notification settings did not open');
    } on PlatformException catch (error) {
      _log.warning('Could not open the notification settings: ${error.code}');
    }
  }

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    // The plugin refuses an instant that has passed, and it sends whole
    // seconds, so what is due within the second is shown at once. An alarm
    // still pending under the id, one Android deferred, would show it again
    // when it fires.
    if (!notification.fireAt.isAfter(
      _clock().add(const Duration(seconds: 1)),
    )) {
      await cancel(notification.osId);
      await _show(
        osId: notification.osId,
        title: notification.title,
        body: notification.body,
        payload: notification.payload,
        details: _details(notification.privacy, _actionsOf(notification)),
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
      notificationDetails: _details(
        notification.privacy,
        _actionsOf(notification),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: notification.payload,
    );
    await _keep(notification.osId, notification.payload);
  }

  @override
  Future<void> cancel(int osId) async {
    await initialize();
    // Before the cancel: a payload another isolate keeps under the id
    // meanwhile, for its own schedule, then stays.
    await _forget([osId]);
    await _plugin.cancel(id: osId);
  }

  @override
  Future<Map<int, String?>> pendingIds() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final request in pending) request.id: request.payload};
  }

  @override
  Future<void> showNow({
    required int osId,
    required String title,
    required String body,
    required String payload,
    NotificationPrivacy privacy = const NotificationPrivacy(),
  }) => _show(
    osId: osId,
    title: title,
    body: body,
    payload: payload,
    details: _details(privacy, _TaskActions.none),
  );

  Future<void> _show({
    required int osId,
    required String title,
    required String body,
    required String payload,
    required NotificationDetails details,
  }) async {
    await initialize();
    await _plugin.show(
      id: osId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
    await _keep(osId, payload);
  }

  @override
  Future<List<DeliveredNotification>> delivered() async {
    await initialize();
    // In this order: a payload kept by now belongs to a notification that
    // is pending or shown unless it has gone since, and an alarm that fires
    // meanwhile is in one of the two lists.
    final kept = await _keptPayloads();
    final pending = await _pendingPayloads();
    final shown = {
      for (final notification in await _plugin.getActiveNotifications())
        ?notification.id: notification.payload,
    };
    if (pending != null) {
      // What the user dismissed or tapped leaves its payload behind, as
      // Android reports neither.
      await _forget([
        for (final osId in kept.keys)
          if (!shown.containsKey(osId) && !pending.containsKey(osId)) osId,
      ]);
      // Scheduled before payloads were kept, or its payload was forgotten
      // by another isolate that looked just before the schedule.
      for (final MapEntry(key: osId, value: payload) in pending.entries) {
        if (payload != null && !kept.containsKey(osId)) {
          await _keep(osId, payload);
        }
      }
    }
    return [
      for (final MapEntry(key: osId, value: payload) in shown.entries)
        (osId: osId, payload: payload ?? kept[osId]),
    ];
  }

  /// Android hands back the id of a notification it shows but not its
  /// payload, so the payload given under each id is kept; iOS returns its
  /// own. Never throws: a notification without one only stays in the tray.
  Future<void> _keep(int osId, String payload) async {
    if (_android == null) return;
    try {
      await _payloads.put(osId, payload);
    } on Object catch (error) {
      _log.info('Could not keep a notification payload: ${error.runtimeType}');
    }
  }

  Future<void> _forget(Iterable<int> osIds) async {
    if (_android == null) return;
    try {
      await _payloads.removeAll(osIds);
    } on Object catch (error) {
      _log.info(
        'Could not forget a notification payload: ${error.runtimeType}',
      );
    }
  }

  Future<Map<int, String>> _keptPayloads() async {
    if (_android == null) return const {};
    try {
      return await _payloads.all();
    } on Object catch (error) {
      _log.info(
        'Could not read the notification payloads: ${error.runtimeType}',
      );
      return const {};
    }
  }

  /// Null on iOS, and when the list cannot be read: nothing is forgotten
  /// then.
  Future<Map<int, String?>?> _pendingPayloads() async {
    if (_android == null) return null;
    try {
      return {
        for (final request in await _plugin.pendingNotificationRequests())
          request.id: request.payload,
      };
    } on Object catch (error) {
      _log.info(
        'Could not list the pending notifications: ${error.runtimeType}',
      );
      return null;
    }
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
    await initialize();
    await _plugin.show(
      id: osId,
      title: title,
      body: body,
      notificationDetails: _activityDetails(
        body: body,
        subtitle: subtitle,
        group: group,
        privacy: privacy,
      ),
      payload: payload,
    );
    await _keep(osId, payload);
  }

  @override
  Future<void> scheduleActivity({
    required int osId,
    required DateTime fireAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!fireAt.isAfter(_clock().add(const Duration(seconds: 1)))) {
      await showActivity(
        osId: osId,
        title: title,
        body: body,
        payload: payload,
      );
      return;
    }
    await initialize();
    await _plugin.zonedSchedule(
      id: osId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(fireAt, tz.UTC),
      notificationDetails: _activityDetails(
        body: body,
        privacy: const NotificationPrivacy(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
    await _keep(osId, payload);
  }

  NotificationDetails _activityDetails({
    required String body,
    required NotificationPrivacy privacy,
    String? subtitle,
    String? group,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      activityChannelId,
      _texts.activityChannelName,
      channelDescription: _texts.activityChannelDescription,
      category: AndroidNotificationCategory.social,
      // A comment's first line rarely fits the collapsed view.
      styleInformation: BigTextStyleInformation(body),
      subText: subtitle,
      groupKey: group,
      visibility: _visibility(privacy),
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      subtitle: subtitle,
      threadIdentifier: group,
    ),
  );

  /// The tap that started the app, for a cold start; null otherwise.
  Future<NotificationResponse?> launchResponse() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse;
  }

  // `private` would still show the content title, which is the task's, and
  // the plugin has no public version to put in its place.
  static NotificationVisibility? _visibility(NotificationPrivacy privacy) =>
      privacy.hiddenOnLockScreen ? NotificationVisibility.secret : null;

  static _TaskActions _actionsOf(ScheduledNotification notification) =>
      notification.snoozeOnly ? _TaskActions.snoozes : _TaskActions.all;

  NotificationDetails _details(
    NotificationPrivacy privacy,
    _TaskActions actions,
  ) => NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      _texts.channelName,
      channelDescription: _texts.channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: _visibility(privacy),
      // The defaults do what the background handler needs: no user
      // interface (`showsUserInterface`), dismissed on tap
      // (`cancelNotification`). Such an action also runs from a secure
      // lock screen, so Done is left out while the app lock is on.
      // Android shows at most three actions, so 10 minutes gives way
      // to Tomorrow (decision log: Notifications and widgets).
      // Done is also left out for a task the user may not change, and 10
      // minutes does not take its place (decision log:
      // Notifications and widgets).
      actions: [
        if (actions != _TaskActions.none)
          for (final (id, title) in [
            if (actions == _TaskActions.all && !privacy.doneNeedsUnlock)
              (NotificationActionIds.markDone, _texts.markDone),
            (NotificationActionIds.snooze1Hour, _texts.snooze1Hour),
            (NotificationActionIds.snoozeTomorrow, _texts.snoozeTomorrow),
          ])
            AndroidNotificationAction(id, title),
      ],
    ),
    iOS: DarwinNotificationDetails(
      categoryIdentifier: switch (actions) {
        _TaskActions.none => null,
        _TaskActions.snoozes => darwinSnoozeOnlyCategoryId,
        _TaskActions.all =>
          privacy.doneNeedsUnlock ? darwinLockedCategoryId : darwinCategoryId,
      },
      // Shown while the app is in front too.
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    ),
  );
}

enum _TaskActions { all, snoozes, none }
