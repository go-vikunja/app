import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

/// What the previous app left on the device that the native side can see
/// without reading a secret.
@immutable
final class PreviousAppTraces {
  const new({
    this.secureEntries = 0,
    this.legacyChannels = false,
    this.legacyWidgets = 0,
    this.homeWidgetData = false,
    this.scheduledNotifications = false,
  });

  /// Missing keys and wrong types read as nothing found.
  factory fromMap(Map<Object?, Object?>? map) => PreviousAppTraces(
    secureEntries: _count(map?['secureEntries']),
    legacyChannels: map?['legacyChannels'] == true,
    legacyWidgets: _count(map?['legacyWidgets']),
    homeWidgetData: map?['homeWidgetData'] == true,
    scheduledNotifications: map?['scheduledNotifications'] == true,
  );

  static const none = PreviousAppTraces();

  /// Entries in flutter_secure_storage's file, also those of builds whose
  /// entries this version cannot decrypt.
  final int secureEntries;

  /// Its notification channels `Vikunja1` or `Vikunja2`.
  final bool legacyChannels;

  /// Its widgets on the home screen.
  final int legacyWidgets;
  final bool homeWidgetData;
  final bool scheduledNotifications;

  bool get any =>
      secureEntries > 0 ||
      legacyChannels ||
      legacyWidgets > 0 ||
      homeWidgetData ||
      scheduledNotifications;

  static int _count(Object? value) => value is int && value > 0 ? value : 0;

  @override
  bool operator ==(Object other) =>
      other is PreviousAppTraces &&
      other.secureEntries == secureEntries &&
      other.legacyChannels == legacyChannels &&
      other.legacyWidgets == legacyWidgets &&
      other.homeWidgetData == homeWidgetData &&
      other.scheduledNotifications == scheduledNotifications;

  @override
  int get hashCode => Object.hash(
    secureEntries,
    legacyChannels,
    legacyWidgets,
    homeWidgetData,
    scheduledNotifications,
  );

  @override
  String toString() =>
      'PreviousAppTraces(secureEntries: $secureEntries, '
      'legacyChannels: $legacyChannels, legacyWidgets: $legacyWidgets, '
      'homeWidgetData: $homeWidgetData, '
      'scheduledNotifications: $scheduledNotifications)';
}

/// The previous app's leftovers on Android that only the native side and
/// the notification plugin reach.
abstract interface class PreviousAppPlatform {
  Future<PreviousAppTraces> traces();

  /// Its scheduled alarms, their stored list and its shown notifications.
  Future<void> cancelNotifications();

  /// Its jobs, notification channels and widget data.
  Future<void> clear();

  /// The per-app language on Android 13 and later, unless one is set
  /// already; whether it was set.
  Future<bool> setAppLanguage(String languageCode);
}

final class ChannelPreviousAppPlatform implements PreviousAppPlatform {
  new({
    this._channel = deviceChannel,
    FlutterLocalNotificationsPlugin? notifications,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  final MethodChannel _channel;
  final FlutterLocalNotificationsPlugin _notifications;

  @override
  Future<PreviousAppTraces> traces() async => PreviousAppTraces.fromMap(
    await _channel.invokeMapMethod<Object?, Object?>('previousAppTraces'),
  );

  // The plugin's cancelAll also works before its initialize.
  @override
  Future<void> cancelNotifications() => _notifications.cancelAll();

  @override
  Future<void> clear() => _channel.invokeMethod<void>('clearPreviousApp');

  @override
  Future<bool> setAppLanguage(String languageCode) async =>
      await _channel.invokeMethod<bool>('setAppLanguage', {
        'language': languageCode,
      }) ??
      false;
}
