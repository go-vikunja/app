import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationResponse;
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/notifications/notification_action_handler.dart';

var _loggingConfigured = false;

/// What the plugin runs, in a separate engine, for a Done or Snooze chosen
/// on a notification: handed to it through
/// `notificationBackgroundEntryPointProvider`. The pragma keeps it from
/// being tree-shaken, as the native side looks it up by its callback
/// handle.
@pragma('vm:entry-point')
void onNotificationActionInBackground(NotificationResponse response) {
  if (!_loggingConfigured) {
    configureLogging();
    _loggingConfigured = true;
  }
  unawaited(handleNotificationAction(response));
}
