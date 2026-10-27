import 'package:flutter/foundation.dart';

enum LockAfter {
  immediately(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  fifteenMinutes(Duration(minutes: 15)),
  oneHour(Duration(hours: 1));

  new(this.duration);

  /// How long the app may stay out of sight before it locks.
  final Duration duration;
}

/// How much reminders and activity notifications show.
enum NotificationContent { all, hiddenOnLockScreen, noTitles }

/// Device-level privacy choices, the same for every account and kept on
/// sign-out.
@immutable
final class PrivacySettings {
  const new({
    this.appLock = false,
    this.lockAfter = LockAfter.oneMinute,
    this.blockScreenshots = false,
    this.notificationContent = NotificationContent.all,
    this.widgetTitles = true,
  });

  /// Throws a [FormatException] for anything but a version 1 object with
  /// fields of the right types. Unknown fields are ignored, and an unknown
  /// choice falls back to that field's default.
  factory fromJson(Object? json) {
    if (json case final Map<Object?, Object?> json
        when json['version'] == version) {
      const defaults = PrivacySettings();
      return PrivacySettings(
        appLock: _bool(json, 'appLock', defaults.appLock),
        lockAfter: _choice(
          json,
          'lockAfter',
          LockAfter.values,
          defaults.lockAfter,
        ),
        blockScreenshots: _bool(
          json,
          'blockScreenshots',
          defaults.blockScreenshots,
        ),
        notificationContent: _choice(
          json,
          'notificationContent',
          NotificationContent.values,
          defaults.notificationContent,
        ),
        widgetTitles: _bool(json, 'widgetTitles', defaults.widgetTitles),
      );
    }
    throw const FormatException('Not version 1 privacy settings');
  }

  static const version = 1;

  final bool appLock;
  final LockAfter lockAfter;

  /// Android only: `FLAG_SECURE` on the whole window.
  final bool blockScreenshots;
  final NotificationContent notificationContent;
  final bool widgetTitles;

  Map<String, Object?> toJson() => {
    'version': version,
    'appLock': appLock,
    'lockAfter': lockAfter.name,
    'blockScreenshots': blockScreenshots,
    'notificationContent': notificationContent.name,
    'widgetTitles': widgetTitles,
  };

  PrivacySettings copyWith({
    bool? appLock,
    LockAfter? lockAfter,
    bool? blockScreenshots,
    NotificationContent? notificationContent,
    bool? widgetTitles,
  }) => PrivacySettings(
    appLock: appLock ?? this.appLock,
    lockAfter: lockAfter ?? this.lockAfter,
    blockScreenshots: blockScreenshots ?? this.blockScreenshots,
    notificationContent: notificationContent ?? this.notificationContent,
    widgetTitles: widgetTitles ?? this.widgetTitles,
  );

  @override
  bool operator ==(Object other) =>
      other is PrivacySettings &&
      other.appLock == appLock &&
      other.lockAfter == lockAfter &&
      other.blockScreenshots == blockScreenshots &&
      other.notificationContent == notificationContent &&
      other.widgetTitles == widgetTitles;

  @override
  int get hashCode => Object.hash(
    appLock,
    lockAfter,
    blockScreenshots,
    notificationContent,
    widgetTitles,
  );

  @override
  String toString() =>
      'PrivacySettings(appLock: $appLock, lockAfter: ${lockAfter.name}, '
      'blockScreenshots: $blockScreenshots, '
      'notificationContent: ${notificationContent.name}, '
      'widgetTitles: $widgetTitles)';
}

bool _bool(Map<Object?, Object?> json, String key, bool fallback) =>
    switch (json[key]) {
      null => fallback,
      final bool value => value,
      _ => throw FormatException('$key is not a bool'),
    };

T _choice<T extends Enum>(
  Map<Object?, Object?> json,
  String key,
  List<T> values,
  T fallback,
) => switch (json[key]) {
  null => fallback,
  final String name => values.asNameMap()[name] ?? fallback,
  _ => throw FormatException('$key is not a string'),
};
