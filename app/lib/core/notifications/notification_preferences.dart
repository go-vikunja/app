import 'package:flutter/foundation.dart';

/// Per account, in the preferences store (not in its database: the
/// scheduler needs them before the database is open and they are not
/// sync state). Defaults on, D17.
@immutable
final class NotificationPreferences {
  const new({this.reminders = true, this.dueDates = true});

  final bool reminders;
  final bool dueDates;

  bool get anyEnabled => reminders || dueDates;

  NotificationPreferences copyWith({bool? reminders, bool? dueDates}) =>
      NotificationPreferences(
        reminders: reminders ?? this.reminders,
        dueDates: dueDates ?? this.dueDates,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.reminders == reminders &&
      other.dueDates == dueDates;

  @override
  int get hashCode => Object.hash(reminders, dueDates);
}

abstract interface class NotificationPreferencesStore {
  Future<NotificationPreferences> read(String accountId);

  Future<void> write(String accountId, NotificationPreferences preferences);

  Future<void> delete(String accountId);

  /// Emits after every write through this instance.
  Stream<(String accountId, NotificationPreferences preferences)> get changes;
}
