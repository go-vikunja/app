import 'package:flutter/foundation.dart';

enum NotificationPermission { granted, denied, notAsked }

/// What the OS allows: notifications at all, and exact alarms on Android
/// (always true on iOS).
@immutable
final class NotificationCapabilities {
  const new({required this.permission, required this.exactAlarms});

  final NotificationPermission permission;
  final bool exactAlarms;
}

enum ScheduledNotificationKind { reminder, dueDate }

/// A notification the OS shows in its tray right now.
typedef DeliveredNotification = ({int osId, String? payload});

/// What the OS may show of a notification while the device is locked, from
/// the device's privacy settings.
@immutable
final class NotificationPrivacy {
  const new({this.hiddenOnLockScreen = false, this.doneNeedsUnlock = false});

  /// Android: no part of it on a secure lock screen. iOS decides this
  /// in its own settings.
  final bool hiddenOnLockScreen;

  /// iOS: the Done action asks for the device to be unlocked. Android
  /// cannot ask per action.
  final bool doneNeedsUnlock;

  @override
  bool operator ==(Object other) =>
      other is NotificationPrivacy &&
      other.hiddenOnLockScreen == hiddenOnLockScreen &&
      other.doneNeedsUnlock == doneNeedsUnlock;

  @override
  int get hashCode => Object.hash(hiddenOnLockScreen, doneNeedsUnlock);
}

/// One notification as handed to the OS. [osId] is the plugin's integer id;
/// [payload] travels back with a tap or an action.
@immutable
final class ScheduledNotification {
  const new({
    required this.osId,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.payload,
    required this.exact,
    this.privacy = const NotificationPrivacy(),
  });

  final int osId;

  /// UTC instant.
  final DateTime fireAt;
  final String title;
  final String body;
  final String payload;

  /// Exact alarm on Android when allowed, else inexact-allow-while-idle.
  final bool exact;
  final NotificationPrivacy privacy;
}

/// The thin wrapper around `flutter_local_notifications`; everything above
/// it is testable with a fake. Every method is safe to call from a
/// background isolate.
abstract interface class NotificationGateway {
  /// Channels, categories and action handlers; once per isolate.
  Future<void> initialize();

  Future<NotificationCapabilities> capabilities();

  /// Asks for the notification permission (Android 13+, iOS); returns the
  /// capabilities afterwards.
  Future<NotificationCapabilities> requestPermission();

  /// Android 14+: opens the system page where the user allows exact
  /// alarms; a no-op elsewhere.
  Future<void> openExactAlarmSettings();

  Future<void> openNotificationSettings();

  Future<void> schedule(ScheduledNotification notification);

  Future<void> cancel(int osId);

  /// The ids the OS still holds for this app, every account included.
  Future<Set<int>> pendingIds();

  /// What this app has in the tray, every account included.
  Future<List<DeliveredNotification>> delivered();

  /// Shows an activity notification at once (a comment, an assignment, a
  /// mention, a session that ended) on the separate activity channel,
  /// without the task actions. [subtitle] names the account when several
  /// are signed in; notifications of one [group] are bundled.
  Future<void> showActivity({
    required int osId,
    required String title,
    required String body,
    required String payload,
    String? subtitle,
    String? group,
    NotificationPrivacy privacy = const NotificationPrivacy(),
  });

  /// Shows a notification at once (the "Send a test notification" button).
  Future<void> showNow({
    required int osId,
    required String title,
    required String body,
    required String payload,
    NotificationPrivacy privacy = const NotificationPrivacy(),
  });
}
