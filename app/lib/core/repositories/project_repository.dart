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

  void dispose();
}
