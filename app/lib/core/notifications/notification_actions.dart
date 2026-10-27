import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The actions of a reminder or due-date notification. The ids are what
/// the plugin reports back; iOS needs them in the category too.
abstract final class NotificationActionIds {
  static const markDone = 'mark_done';
  static const snooze10Minutes = 'snooze_10m';
  static const snooze1Hour = 'snooze_1h';
}

/// What a notification carries back: enough to find the task in the right
/// account's database from any isolate. On Android any app can send a tap
/// with a made-up payload to the app, so only one with the install's
/// widget-link key ([linkKey], `k`) may switch accounts without asking;
/// notifications scheduled before it existed have none.
@immutable
final class NotificationPayload {
  const new({
    required this.accountId,
    required this.taskId,
    required this.key,
    this.linkKey,
  });

  factory fromJson(String json) {
    if (jsonDecode(json)
        case final Map<String, Object?> fields &&
            {
              'account': final String accountId,
              'task': final int taskId,
              'key': final String key,
            }) {
      return NotificationPayload(
        accountId: accountId,
        taskId: taskId,
        key: key,
        linkKey: switch (fields['k']) {
          final String linkKey when linkKey.isNotEmpty => linkKey,
          _ => null,
        },
      );
    }
    throw FormatException('not a notification payload', json);
  }

  final String accountId;
  final int taskId;

  /// The scheduled notification's key, see `ScheduledNotifications`.
  final String key;

  final String? linkKey;

  String toJson() => jsonEncode({
    'account': accountId,
    'task': taskId,
    'key': key,
    'k': ?linkKey,
  });
}
