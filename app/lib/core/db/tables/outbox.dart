import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

/// Queued task writes, sent in [sequence] order. One row per task at most
/// in `pending` or `failed`: a later edit merges into it, a delete replaces
/// it. [state] is `pending`, `sending` or `failed`.
@DataClassName('OutboxRow')
@TableIndex(name: 'outbox_state_sequence', columns: {#state, #sequence})
class Outbox extends Table {
  /// A UUID, so a retry or discard names exactly one op.
  TextColumn get id => text()();

  /// Strictly increasing per database; the send order.
  IntColumn get sequence => integer()();

  /// `OutboxOperationKind.name`.
  TextColumn get kind => text()();
  IntColumn get taskId => integer()();

  /// The `TaskChanges` as JSON; empty for a delete.
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

  @override
  Set<Column<Object>> get primaryKey => {id};
}
