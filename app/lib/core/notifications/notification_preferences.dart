import 'package:flutter/foundation.dart';

/// Per account, in the preferences store (not in its database: the
/// scheduler needs them before the database is open and they are not
/// sync state). Defaults on, D17.
@immutable
final class NotificationPreferences {
  const new({
    this.reminders = true,
    this.dueDates = true,
    this.activity = true,
  });

  final bool reminders;
  final bool dueDates;

  /// Comments, assignments, mentions and the like from the server's
  /// notifications.
  final bool activity;

  /// Whether the scheduler has anything to plan; [activity] is not
  /// scheduled.
  bool get anyEnabled => reminders || dueDates;

  NotificationPreferences copyWith({
    bool? reminders,
    bool? dueDates,
    bool? activity,
  }) => NotificationPreferences(
    reminders: reminders ?? this.reminders,
    dueDates: dueDates ?? this.dueDates,
    activity: activity ?? this.activity,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.reminders == reminders &&
      other.dueDates == dueDates &&
      other.activity == activity;

  @override
  int get hashCode => Object.hash(reminders, dueDates, activity);
}

abstract interface class NotificationPreferencesStore {
  Future<NotificationPreferences> read(String accountId);

  Future<void> write(String accountId, NotificationPreferences preferences);

  Future<void> delete(String accountId);

  /// Emits after every write through this instance.
  Stream<(String accountId, NotificationPreferences preferences)> get changes;
}
