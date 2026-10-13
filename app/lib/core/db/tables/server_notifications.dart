import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

/// The server's in-app notifications (the inbox), newest pages only: kept
/// to the newest 200 by the activity sync.
@DataClassName('ServerNotificationRow')
class ServerNotifications extends Table {
  IntColumn get id => integer()();

  /// `task.comment`, `task.assigned`, … as the server names them.
  TextColumn get name => text()();

  /// The server's `notification` object as JSON.
  TextColumn get payload => text()();
  IntColumn get created => integer().map(const EpochMillis())();

  /// When it was read: the server's time, or this device's while
  /// [readPending] holds a local mark the server has not taken yet. Null
  /// while unread.
  IntColumn get readAt => integer().map(const EpochMillis()).nullable()();

  /// The read state to send; null once the server has it.
  BoolColumn get readPending => boolean().nullable()();

  /// Already handled as an OS notification (shown, or deliberately not:
  /// the first sync of an account, a read one, a kind that is not shown).
  BoolColumn get notified => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
