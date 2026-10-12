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
  });

  final int osId;

  /// UTC instant.
  final DateTime fireAt;
  final String title;
  final String body;
  final String payload;

  /// Exact alarm on Android when allowed, else inexact-allow-while-idle.
  final bool exact;
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

  /// Shows a notification at once (the "Send a test notification" button).
  Future<void> showNow({
    required int osId,
    required String title,
    required String body,
    required String payload,
  });
}
