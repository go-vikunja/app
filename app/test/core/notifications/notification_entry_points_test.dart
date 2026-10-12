import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/notifications/notification_entry_points.dart';

void main() {
  test('the background entry point has the plugin callback shape and a '
      'callback handle, as a top-level function', () {
    expect(
      onNotificationActionInBackground,
      isA<DidReceiveBackgroundNotificationResponseCallback>(),
    );
    expect(
      PluginUtilities.getCallbackHandle(onNotificationActionInBackground),
      isNotNull,
    );
  });
}
