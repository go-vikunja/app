import 'package:vikunja_domain/vikunja_domain.dart';

/// Managing saved filters. Online only and never queued, like the view
/// changes: every call goes to the server and throws its `VikunjaFailure`
/// (offline a `NetworkFailure`) with nothing changed here; on success the
/// stored saved filters follow at once (`ProjectRepository.
/// watchSavedFilters`, with the definition) and a sync runs quietly.
///
/// The server refuses a filter it cannot parse with a `DomainError` code
/// 4024, 4019 or 4016, a filter without text, search, sort or include-nulls
/// with code 2002 (v1 412, v2 422 `ValidationFailed`), and a saved filter of
/// another user with `Forbidden`. One that is gone is a `NotFound` code
/// 11001.
abstract interface class SavedFilterRepository {
  /// Returns the new saved filter's pseudo project id. A blank title (after
  /// trimming) is an `ArgumentError` before any request.
  Future<int> create(SavedFilterDraft draft);

  /// Replaces title, description, filter and favourite with the draft's;
  /// fails like [create].
  Future<void> update(int pseudoProjectId, SavedFilterDraft draft);

  /// A saved filter that is gone already counts as deleted. Its list
  /// download goes too; when the Overview showed it, the Overview falls
  /// back to every open task.
  Future<void> delete(int pseudoProjectId);

  Future<void> setFavorite(int pseudoProjectId, {required bool favorite});

  /// The saved filter as the server has it now, also stored here: for an
  /// edit form while the stored definition is unknown.
  Future<SavedFilter> read(int pseudoProjectId);
}
