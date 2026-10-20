import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

/// Searching and counting over the account's local data: offline and
/// without a request.
abstract interface class TaskSearch {
  /// What [query] finds, again whenever the local data changes; an empty
  /// or blank query finds nothing, once the search is ready. Tasks match
  /// by a substring of the title or of the description's text ignoring
  /// case, by `#12` (index 12 in any project) and by an identifier like
  /// `PROJ-12`; projects, saved filters and labels by a substring of the
  /// title or of the description's text. Archived projects and their tasks
  /// are left out, except favourite tasks, as in the server's `GET /tasks`.
  Stream<SearchResults> watch(String query);

  /// How many tasks [filter] (its text, search and include-nulls flag)
  /// matches here: those of the project [projectId] (archived included),
  /// as a view of it would list them, or without one those a saved filter
  /// would (outside archived projects, favourite tasks included). Relative
  /// dates are rounded in [timezone], else in the user's timezone setting,
  /// else in the device's zone. Null when the device cannot evaluate the
  /// filter: the engine refuses it, or it names `bucket_id`.
  Future<int?> countMatches(
    ViewFilter filter, {
    int? projectId,
    String timezone = '',
  });
}

@immutable
final class SearchResults {
  const new({
    this.query = '',
    this.tasks = const [],
    this.taskCount = 0,
    this.projects = const [],
    this.savedFilters = const [],
    this.labels = const [],
  });

  /// The query as given.
  final String query;

  /// Open tasks before done ones, then nearest due date first (none last),
  /// then newest first; at most [maxTasks].
  final List<Task> tasks;

  /// Every matching task, also those beyond [tasks].
  final int taskCount;

  /// By title, ignoring case and accents.
  final List<Project> projects;
  final List<SavedFilterRef> savedFilters;
  final List<Label> labels;

  static const maxTasks = 100;

  bool get isEmpty =>
      taskCount == 0 &&
      projects.isEmpty &&
      savedFilters.isEmpty &&
      labels.isEmpty;
}
