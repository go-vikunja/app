import 'package:vikunja_domain/vikunja_domain.dart';

/// The labels the account can attach, as this device knows them.
abstract interface class LabelRepository {
  /// Ordered by title, case-insensitively.
  Stream<List<Label>> watchAll();

  /// One label, following a temporary id to the server id once its create
  /// is answered; null while it is not here.
  Stream<Label?> watchLabel(int id);

  /// Stores the label at once under a temporary negative id, created by the
  /// user, and queues its create in the outbox, offline too: it is an
  /// ordinary label here right away, attaching it works like any other
  /// change, and the label and everything that names it move to the
  /// server's id once the create is answered. A blank title or one past
  /// `Label.maxTitleLength` code points is an `ArgumentError` before any
  /// write.
  Future<Label> create(NewLabel label);

  /// The label this device has under [label]'s title, ignoring case; else
  /// one [create]d, whose create takes a label the server already has
  /// under that title instead of making a second one.
  Future<Label> findOrCreate(NewLabel label);

  /// Changes a label created here, or one with a change still queued, here
  /// at once and queues the change: folded into the label's create while
  /// that has not left the device, else behind it; behind it always for a
  /// label from [findOrCreate], whose create may take a label the server
  /// has, which the change then goes to. Any other label changes
  /// on the server right away, sending only the fields [changes] sets, and
  /// the answer is stored; a quiet sync follows. Only the label's creator
  /// may (a `Forbidden` otherwise). A label that is gone on the server
  /// (`NotFound` code 8002) is removed here as well before the failure is
  /// thrown, and a label created here that is gone is that `NotFound` too.
  /// A blank title or one past `Label.maxTitleLength` code points is an
  /// `ArgumentError` before any request. Any other failure changes nothing
  /// here.
  Future<Label> update(int id, LabelChanges changes);

  /// Deletes the label here, from every task and from the queued edits. A
  /// label created here whose create is not on its way goes without a
  /// request, also one sent without an answer, whose label, if the server
  /// has it, comes back with the next sync; one whose create is on its
  /// way, or with a change still queued, is deleted on the server once
  /// those are through. Any
  /// other label is deleted on the server right away, then here, and a
  /// quiet sync follows; one that is gone already counts as deleted. Only
  /// the label's creator may (a `Forbidden`, which changes nothing here).
  Future<void> delete(int id);

  /// The labels with a change the server does not have yet: created here
  /// and not answered, or changed here since.
  Stream<Set<int>> watchPendingIds();

  /// Every temporary id with the server id its label got, so that a screen
  /// or a selection holding the temporary id can follow it.
  Stream<Map<int, int>> watchRemaps();

  void dispose();
}

/// Whether [userId] created [label], which only the creator may change.
/// Lists carry no permission per label.
bool isOwnLabel(Label label, int? userId) =>
    userId != null && label.createdBy?.id == userId;
