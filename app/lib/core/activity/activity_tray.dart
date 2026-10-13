import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';

/// The activity notifications of an account in the system's tray. Their
/// ids follow from the account and the payload key, so one can be
/// withdrawn without remembering what was shown, and cancelling one that
/// never was costs nothing.
final class ActivityTray {
  new(this._gateway);

  final NotificationGateway _gateway;

  static const _activityPrefix = 'activity:';
  static const _sessionPrefix = 'session:';
  static const _morePrefix = 'inbox:';

  /// A server notification shown on the device.
  static String activityKey(int notificationId) =>
      '$_activityPrefix$notificationId';

  /// The "Sign in again" notification.
  static String sessionKey(String accountId) => '$_sessionPrefix$accountId';

  /// The one notification that stands for the account's new ones beyond
  /// those shown one by one; a tap opens the inbox.
  static String moreKey(String accountId) => '$_morePrefix$accountId';

  static int? activityIdOf(String key) => key.startsWith(_activityPrefix)
      ? int.tryParse(key.substring(_activityPrefix.length))
      : null;

  static bool isSessionKey(String key) => key.startsWith(_sessionPrefix);

  static bool isMoreKey(String key) => key.startsWith(_morePrefix);

  /// Read here or on the server: the notifications go from the tray.
  Future<void> withdraw(String accountId, Iterable<int> notificationIds) async {
    for (final id in notificationIds) {
      await _gateway.cancel(notificationOsIdFor(accountId, activityKey(id)));
    }
  }

  Future<void> withdrawSession(String accountId) =>
      _gateway.cancel(notificationOsIdFor(accountId, sessionKey(accountId)));

  /// Sign-out: whatever the account still has in the tray, reminders
  /// included, whose taps would find no account any more.
  Future<void> withdrawAll(String accountId) async {
    for (final (osId, payload) in await _delivered()) {
      if (payload.accountId == accountId) await _gateway.cancel(osId);
    }
  }

  /// Android drops every post beyond 50 notifications of an app, reminders
  /// included, so the account keeps its [keep] newest activity
  /// notifications; the oldest go.
  Future<void> trim(String accountId, {required int keep}) async {
    final shown = <(int, int)>[
      for (final (osId, payload) in await _delivered())
        if (payload.accountId == accountId)
          if (activityIdOf(payload.key) case final id?) (id, osId),
    ];
    if (shown.length <= keep) return;
    shown.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, osId) in shown.take(shown.length - keep)) {
      await _gateway.cancel(osId);
    }
  }

  Future<List<(int, NotificationPayload)>> _delivered() async => [
    for (final notification in await _gateway.delivered())
      if (_payloadOf(notification.payload) case final payload?)
        (notification.osId, payload),
  ];

  static NotificationPayload? _payloadOf(String? json) {
    if (json == null) return null;
    try {
      return NotificationPayload.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}
