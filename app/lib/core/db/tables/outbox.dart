import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

/// Queued task and label writes, sent in [sequence] order, uploads in a
/// lane of their own; [state] is `pending`, `sending` or `failed`. A task
/// can have several: its create with the edits queued behind it, an update
/// on its way or one that may have reached the server (`sent_at`) beside a
/// newer one, updates ahead of a queued delete, and one upload per file.
/// `OutboxDao` holds how they merge, fold and wait.
@DataClassName('OutboxRow')
@TableIndex(name: 'outbox_state_sequence', columns: {#state, #sequence})
class Outbox extends Table {
  /// A UUID, so a retry or discard names exactly one op.
  TextColumn get id => text()();

  /// Strictly increasing per database; the send order.
  IntColumn get sequence => integer()();

  /// `OutboxOperationKind.name`.
  TextColumn get kind => text()();

  /// Negative for a task created here that the server has not named yet;
  /// 0 for a label op.
  IntColumn get taskId => integer()();

  /// As JSON: the `NewTask` of a create, the `TaskChanges` of an update,
  /// `{}` for a delete, the `QueuedUpload` of an upload; a label op's
  /// `QueuedLabelCreate`, `LabelChanges` or `QueuedLabelDelete`. A create's
  /// and an upload's carry `posted_at` once their request has left the
  /// device.
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

  /// When a task or label create or an upload may have reached the server
  /// although no answer came back: set on the first such attempt, so the
  /// next one, and a Retry, look for what it may have left there before
  /// sending it again. An update with a repeating task's Done gets it
  /// before its first request, with what the server had then (see
  /// `TaskChanges.doneBase`), so a later attempt checks whether the Done
  /// landed; it takes no more edits from then on. Null for every other op
  /// and for a create or upload the server refused.
  IntColumn get sentAt => integer().map(const EpochMillis()).nullable()();

  /// The label of a `createLabel`, `updateLabel` or `deleteLabel`, negative
  /// until the label's create is answered; null for a task op. Last, as
  /// version 2 adds it to version 1's table.
  IntColumn get labelId => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
