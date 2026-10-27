import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

/// What the OS holds for this account: one row per scheduled reminder or
/// due-date notification, so the scheduler can diff against it from any
/// isolate. [key] is `<taskId>:reminder:<ordinal>` or `<taskId>:due`;
/// [osId] is the plugin's integer id, a hash of the account and the key.
@DataClassName('ScheduledNotificationRow')
class ScheduledNotifications extends Table {
  TextColumn get key => text()();
  IntColumn get osId => integer().unique()();
  IntColumn get taskId => integer()();

  /// `ScheduledNotificationKind.name`.
  TextColumn get kind => text()();

  /// When the OS will show it: the task's instant, or [snoozedUntil].
  IntColumn get fireAt => integer().map(const EpochMillis())();
  TextColumn get title => text()();
  TextColumn get body => text()();

  /// A snooze the user chose from the notification; it holds until the
  /// task's own instant no longer equals [snoozeOriginalFireAt].
  IntColumn get snoozedUntil => integer().map(const EpochMillis()).nullable()();
  IntColumn get snoozeOriginalFireAt =>
      integer().map(const EpochMillis()).nullable()();

  /// Whether the OS was given an exact alarm. Part of the diff: a granted
  /// or revoked exact-alarm permission re-registers the whole window.
  BoolColumn get exact => boolean()();

  /// What the OS may show of it on a locked device (`NotificationPrivacy`),
  /// part of the diff like [exact]: an entry another isolate scheduled
  /// with older privacy settings is scheduled again by the next run.
  BoolColumn get hiddenOnLockScreen =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get doneNeedsUnlock =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
