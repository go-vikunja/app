import 'package:vikunja_domain/vikunja_domain.dart';

/// The labels the account can attach, as this device knows them.
abstract interface class LabelRepository {
  /// Ordered by title, case-insensitively.
  Stream<List<Label>> watchAll();

  /// Creates the label on the server right away, so it needs a connection,
  /// and stores the answer locally; attaching it to a task then works
  /// offline like any other change. A create whose answer was lost is
  /// looked for on the server instead of being made twice. Throws the
  /// `VikunjaFailure`.
  Future<Label> create(NewLabel label);

  /// The label the server already has under [label]'s title, ignoring
  /// case, which this device may not have synced yet; else [create]s it.
  /// Needs a connection; throws the `VikunjaFailure`.
  Future<Label> findOrCreate(NewLabel label);

  /// Changes the label on the server right away, sending only the fields
  /// [changes] sets, and stores the answer locally; a quiet sync follows.
  /// Only the label's creator may (a `Forbidden` otherwise). A label that
  /// is gone on the server (`NotFound` code 8002) is removed here as well
  /// before the failure is thrown. A blank title or one past
  /// `Label.maxTitleLength` code points is an `ArgumentError` before any
  /// request. Any other failure changes nothing here.
  Future<Label> update(int id, LabelChanges changes);

  /// Deletes the label on the server right away, then here: from every
  /// task and from the queued edits; a quiet sync follows. One that is gone
  /// already counts as deleted. Only the label's creator may (a
  /// `Forbidden`, which changes nothing here).
  Future<void> delete(int id);

  void dispose();
}

/// Whether [userId] created [label], which only the creator may change.
/// Lists carry no permission per label.
bool isOwnLabel(Label label, int? userId) =>
    userId != null && label.createdBy?.id == userId;
