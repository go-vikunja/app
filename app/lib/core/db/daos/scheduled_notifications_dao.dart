import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/tables/scheduled_notifications.dart';

part 'scheduled_notifications_dao.g.dart';

@DriftAccessor(tables: [ScheduledNotifications])
final class ScheduledNotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduledNotificationsDaoMixin {
  new(super.attachedDatabase);

  /// Every row, by fire time then key.
  Future<List<ScheduledNotificationRow>> all() =>
      (select(scheduledNotifications)..orderBy([
            (n) => OrderingTerm.asc(n.fireAt),
            (n) => OrderingTerm.asc(n.key),
          ]))
          .get();

  Future<ScheduledNotificationRow?> find(String key) => (select(
    scheduledNotifications,
  )..where((n) => n.key.equals(key))).getSingleOrNull();

  Future<Set<int>> osIds() async {
    final query = selectOnly(scheduledNotifications)
      ..addColumns([scheduledNotifications.osId]);
    return {
      for (final row in await query.get())
        row.read(scheduledNotifications.osId)!,
    };
  }

  Stream<int> watchCount() {
    final count = scheduledNotifications.key.count();
    final query = selectOnly(scheduledNotifications)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// The table becomes exactly [rows], in one transaction. With [sinceRead],
  /// the rows the caller planned from, nothing is written and false comes
  /// back when the table changed meanwhile (another isolate's reconcile or
  /// snooze): the caller plans again from the table as it is now.
  Future<bool> replaceAll(
    List<ScheduledNotificationRow> rows, {
    List<ScheduledNotificationRow>? sinceRead,
  }) => transaction(() async {
    if (sinceRead != null && !listEquals(await all(), sinceRead)) return false;
    await delete(scheduledNotifications).go();
    await batch(
      (b) => b.insertAll(scheduledNotifications, [
        for (final row in rows) row.toCompanion(false),
      ]),
    );
    return true;
  });

  /// Inserts the row or replaces the one with its key; the caller chooses
  /// an os id no other key holds.
  Future<void> upsert(ScheduledNotificationRow row) =>
      into(scheduledNotifications).insertOnConflictUpdate(row);

  /// Records that the entry is to fire at [until]; [originalFireAt] is the
  /// task's own instant, so a later snooze of the same notification keeps
  /// it. `fire_at` stays what the OS was told, until the next reconcile
  /// reschedules the entry and writes the new time.
  Future<void> setSnooze(
    String key, {
    required DateTime until,
    required DateTime originalFireAt,
  }) => (update(scheduledNotifications)..where((n) => n.key.equals(key))).write(
    ScheduledNotificationsCompanion(
      snoozedUntil: Value(until.toUtc()),
      snoozeOriginalFireAt: Value(originalFireAt.toUtc()),
    ),
  );

  Future<void> clearSnooze(String key) =>
      (update(scheduledNotifications)..where((n) => n.key.equals(key))).write(
        const ScheduledNotificationsCompanion(
          snoozedUntil: Value(null),
          snoozeOriginalFireAt: Value(null),
        ),
      );

  Future<List<ScheduledNotificationRow>> forTasks(Iterable<int> taskIds) =>
      (select(
        scheduledNotifications,
      )..where((n) => n.taskId.isIn(taskIds))).get();

  Future<int> deleteForTasks(Iterable<int> taskIds) => (delete(
    scheduledNotifications,
  )..where((n) => n.taskId.isIn(taskIds))).go();

  Future<int> deleteAll() => delete(scheduledNotifications).go();
}
