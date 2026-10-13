import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/mappers/server_notification_mappers.dart';
import 'package:vikunja_mobile/core/db/tables/server_notifications.dart';

part 'server_notifications_dao.g.dart';

/// The inbox. A local mark sets `read_at` at once and `read_pending` until
/// the activity sync has sent it, so every reader sees the effective read
/// state in `read_at` alone; a pull does not overwrite a row's `read_at`
/// while a mark is pending.
@DriftAccessor(tables: [ServerNotifications])
final class ServerNotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$ServerNotificationsDaoMixin {
  new(super.attachedDatabase);

  Future<int> count() {
    final count = serverNotifications.id.count();
    return (selectOnly(
      serverNotifications,
    )..addColumns([count])).map((row) => row.read(count) ?? 0).getSingle();
  }

  Future<ServerNotification?> find(int id) async {
    final row = await (select(
      serverNotifications,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
    return row == null ? null : serverNotificationFromRow(row);
  }

  /// Which of [ids] are stored.
  Future<Set<int>> existingIds(Iterable<int> ids) async {
    final query = selectOnly(serverNotifications)
      ..addColumns([serverNotifications.id])
      ..where(serverNotifications.id.isIn(ids));
    return {
      for (final row in await query.get()) row.read(serverNotifications.id)!,
    };
  }

  Future<int?> maxId() {
    final max = serverNotifications.id.max();
    return (selectOnly(
      serverNotifications,
    )..addColumns([max])).map((row) => row.read(max)).getSingle();
  }

  /// Stores a pulled page. A stored row keeps its pending mark (and with
  /// it the local `read_at`) and whether it was handled; a new row counts
  /// as handled when [handled] says so or the server has it read already.
  /// Returns the stored ones that were unread here and are read on the
  /// server now.
  Future<List<int>> upsertAll(
    List<ServerNotification> notifications, {
    required bool handled,
  }) => transaction(() async {
    if (notifications.isEmpty) return const [];
    final stored = {
      for (final row in await (select(
        serverNotifications,
      )..where((n) => n.id.isIn(notifications.map((e) => e.id)))).get())
        row.id: row,
    };
    await batch(
      (b) => b.insertAllOnConflictUpdate(serverNotifications, [
        for (final notification in notifications)
          _row(notification, stored[notification.id], handled: handled),
      ]),
    );
    return [
      for (final notification in notifications)
        if (stored[notification.id] case final row?
            when row.readAt == null &&
                row.readPending == null &&
                notification.readAt != null)
          notification.id,
    ];
  });

  ServerNotificationRow _row(
    ServerNotification notification,
    ServerNotificationRow? stored, {
    required bool handled,
  }) => ServerNotificationRow(
    id: notification.id,
    name: notification.name,
    payload: encodeNotificationPayload(notification.payload),
    created: notification.created.toUtc(),
    readAt: stored?.readPending != null
        ? stored!.readAt
        : notification.readAt?.toUtc(),
    readPending: stored?.readPending,
    notified: stored?.notified ?? (handled || notification.readAt != null),
  );

  /// Newest first.
  Stream<List<ServerNotification>> watchAll() =>
      (select(serverNotifications)..orderBy([
            (n) => OrderingTerm.desc(n.created),
            (n) => OrderingTerm.desc(n.id),
          ]))
          .watch()
          .map(
            (rows) =>
                rows.map(serverNotificationFromRow).toList(growable: false),
          );

  /// The badge: unread ones without the server's copies of reminders,
  /// which the phone has shown itself already.
  Stream<int> watchUnreadCount() =>
      _unreadCount(withReminders: false).watchSingle();

  /// Every unread one.
  Future<int> unreadCount() => _unreadCount(withReminders: true).getSingle();

  Selectable<int> _unreadCount({required bool withReminders}) {
    final count = serverNotifications.id.count();
    final unread = serverNotifications.readAt.isNull();
    return (selectOnly(serverNotifications)
          ..addColumns([count])
          ..where(
            withReminders
                ? unread
                : unread &
                      serverNotifications.name.equals(_serverReminder).not(),
          ))
        .map((row) => row.read(count) ?? 0);
  }

  static const _serverReminder = 'task.reminder';

  /// Whether an unread one is stored older than [id]: the pull has not
  /// reached it, and the server may have it read by now.
  Future<bool> hasUnreadBelow(int id) async {
    final row =
        await (selectOnly(serverNotifications)
              ..addColumns([serverNotifications.id])
              ..where(
                serverNotifications.readAt.isNull() &
                    serverNotifications.id.isSmallerThanValue(id),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Marks the unread ones of [ids] read here; the sync sends them.
  Future<void> markRead(Iterable<int> ids, {required DateTime at}) => (update(
    serverNotifications,
  )..where((n) => n.id.isIn(ids) & n.readAt.isNull())).write(_markedRead(at));

  /// Returns the ids it marked.
  Future<List<int>> markAllRead({required DateTime at}) =>
      transaction(() async {
        final unread =
            await (selectOnly(serverNotifications)
                  ..addColumns([serverNotifications.id])
                  ..where(serverNotifications.readAt.isNull()))
                .map((row) => row.read(serverNotifications.id)!)
                .get();
        if (unread.isEmpty) return unread;
        await (update(
          serverNotifications,
        )..where((n) => n.id.isIn(unread))).write(_markedRead(at));
        return unread;
      });

  ServerNotificationsCompanion _markedRead(DateTime at) =>
      ServerNotificationsCompanion(
        readAt: Value(at.toUtc()),
        readPending: const Value(true),
      );

  /// The marks still to send, oldest first.
  Future<List<({int id, bool read})>> pendingReads() async {
    final rows =
        await (select(serverNotifications)
              ..where((n) => n.readPending.isNotNull())
              ..orderBy([(n) => OrderingTerm.asc(n.id)]))
            .get();
    return [for (final row in rows) (id: row.id, read: row.readPending!)];
  }

  /// The server took the marks; `read_at` stays as marked until the next
  /// pull brings the server's.
  Future<void> clearPending(Iterable<int> ids) =>
      (update(serverNotifications)..where((n) => n.id.isIn(ids))).write(
        const ServerNotificationsCompanion(readPending: Value(null)),
      );

  /// Unread and not handled yet, oldest first: what may become an OS
  /// notification.
  Future<List<ServerNotification>> unhandledUnread() async {
    final rows =
        await (select(serverNotifications)
              ..where((n) => n.readAt.isNull() & n.notified.equals(false))
              ..orderBy([(n) => OrderingTerm.asc(n.id)]))
            .get();
    return rows.map(serverNotificationFromRow).toList(growable: false);
  }

  Future<void> markHandled(Iterable<int> ids) =>
      (update(serverNotifications)..where((n) => n.id.isIn(ids))).write(
        const ServerNotificationsCompanion(notified: Value(true)),
      );

  /// Keeps the [keep] newest; a row with a mark still to send stays too.
  Future<int> pruneToNewest(int keep) {
    final newest = selectOnly(serverNotifications)
      ..addColumns([serverNotifications.id])
      ..orderBy([OrderingTerm.desc(serverNotifications.id)])
      ..limit(keep);
    return (delete(
      serverNotifications,
    )..where((n) => n.id.isNotInQuery(newest) & n.readPending.isNull())).go();
  }

  Future<int> deleteAll() => delete(serverNotifications).go();
}
