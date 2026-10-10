import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

/// Queued task writes, sent in [sequence] order. One row per task at most
/// in `pending` or `failed`: a later edit merges into it, a delete replaces
/// it; only a create that may already be on the server keeps the ops
/// queued after it apart, under its temporary id until the server id is
/// known. [state] is `pending`, `sending` or `failed`.
@DataClassName('OutboxRow')
@TableIndex(name: 'outbox_state_sequence', columns: {#state, #sequence})
class Outbox extends Table {
  /// A UUID, so a retry or discard names exactly one op.
  TextColumn get id => text()();

  /// Strictly increasing per database; the send order.
  IntColumn get sequence => integer()();

  /// `OutboxOperationKind.name`.
  TextColumn get kind => text()();

  /// Negative for a task created here that the server has not named yet.
  IntColumn get taskId => integer()();

  /// The `TaskChanges` as JSON, the `NewTask` for a create; empty for a
  /// delete.
  TextColumn get payload => text()();
  IntColumn get createdAt => integer().map(const EpochMillis())();
  IntColumn get attempts => integer()();
  IntColumn get nextAttemptAt =>
      integer().map(const EpochMillis()).nullable()();
  IntColumn get lastAttemptAt =>
      integer().map(const EpochMillis()).nullable()();
  TextColumn get state => text()();

  /// The normalized `VikunjaFailure` of the last attempt as JSON.
  TextColumn get lastError => text().nullable()();

  /// When a create's request may have reached the server although no
  /// answer came back: set on the first such attempt, so the next one looks
  /// for the task before sending it again. Null for every other op and for
  /// a create the server rejected.
  IntColumn get sentAt => integer().map(const EpochMillis()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
