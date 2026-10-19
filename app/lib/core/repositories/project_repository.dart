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

  void dispose();
}
