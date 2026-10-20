import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

/// Projects as this device knows them. The stream carries the local state;
/// the first subscription fills it, and a failed first load is the stream's
/// error. [refresh] throws the `VikunjaFailure` and leaves the stale data in
/// the stream.
abstract interface class ProjectRepository {
  Stream<List<Project>> watchAll();

  Future<void> refresh();

  /// From the local state, without a network call.
  Project? find(int id);

  /// The saved filters the last project sync saw, by title.
  Stream<List<SavedFilterRef>> watchSavedFilters();

  /// Moves the project to [position] under [parentProjectId] (0: the top
  /// level) on the server, online and without the outbox; once answered,
  /// the stored project follows at once and a sync runs quietly. Throws the
  /// `VikunjaFailure` (offline a `NetworkFailure`) and changes nothing
  /// then. A [position] below 0.1 is an `ArgumentError` before any request:
  /// the server would renumber every sibling, at the top level those of
  /// every user.
  Future<void> moveProject(
    int projectId, {
    required double position,
    required int parentProjectId,
  });

  /// The writes below are online and never queued, like [moveProject]: the
  /// server's answer goes into the database at once, then a sync runs
  /// quietly; a failure (offline a `NetworkFailure`) changes nothing here.
  ///
  /// Returns the new project's id once it is stored with its views. A blank
  /// title (after trimming) is an `ArgumentError` before any request.
  Future<int> createProject(NewProject project);

  /// Sends only the set fields, nothing for none; a title is trimmed (blank
  /// is an `ArgumentError`), an identifier too (more than 10 characters is
  /// an `ArgumentError`). The stored tasks of the project take a new
  /// identifier at once, the server's are renamed without a trace a sync
  /// could see. Archiving cascades to every stored descendant, unarchiving
  /// too. Refused before any request, as the server would: archiving the
  /// user's default project (`DomainError` code 3013), unarchiving under an
  /// archived parent (code 3016). A [ProjectChanges.position] is ignored:
  /// a project stored below 0.1 is sent a position of 0.1 or more between
  /// its neighbours with the changes, else the server would renumber its
  /// siblings, and the answered position is stored.
  Future<void> updateProject(int projectId, ProjectChanges changes);

  /// The server deletes the project's whole subtree with its tasks; here
  /// the subtree goes with its tasks (also those with unsent changes, whose
  /// queued ops go too: they would fail), views, boards, list snapshots and
  /// list preferences.
  Future<void> deleteProject(int projectId);

  /// Returns the copy's id once a sync has stored it with its tasks; when
  /// that sync fails, the copy is stored without them and the next one
  /// brings them. A pseudo project is an `ArgumentError`.
  Future<int> duplicateProject(
    int projectId, {
    required int parentProjectId,
    required bool copyShares,
  });

  void dispose();
}
