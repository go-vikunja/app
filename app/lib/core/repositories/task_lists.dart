import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// A saved filter as the project list names it: [projectId] is its pseudo
/// project id (-2 or lower).
@immutable
final class SavedFilterRef {
  const new({
    required this.projectId,
    required this.title,
    this.isFavorite = false,
  });

  final int projectId;
  final String title;
  final bool isFavorite;

  @override
  bool operator ==(Object other) =>
      other is SavedFilterRef &&
      other.projectId == projectId &&
      other.title == title &&
      other.isFavorite == isFavorite;

  @override
  int get hashCode => Object.hash(projectId, title, isFavorite);
}

/// A saved filter's open tasks as of its last download (null: never
/// downloaded, and [tasks] stays empty until the first one), with this
/// device's changes on top: a task done or deleted here leaves at once.
@immutable
final class SavedFilterTasks {
  const new({this.tasks = const [], this.loadedAt});

  /// Nearest due date first (none last), then newest first.
  final List<Task> tasks;
  final DateTime? loadedAt;
}

@immutable
final class OverviewTasks {
  const new({this.tasks = const [], this.filter, this.filterLoadedAt});

  /// Open tasks, nearest due date first (none last), then newest first.
  final List<Task> tasks;

  /// The saved filter the user picked for the Overview on the web, while
  /// it exists; null when the Overview shows every open task outside
  /// archived projects.
  final SavedFilterRef? filter;

  /// When the filter's tasks were last downloaded. Null with a [filter]
  /// means never, and [tasks] stays empty until the first download.
  final DateTime? filterLoadedAt;
}

/// The tasks a list held on the server and their positions in it, as of
/// [loadedAt] (null: never downloaded).
@immutable
final class ListSnapshot {
  const new({this.positions = const {}, this.loadedAt});

  final Map<int, double> positions;
  final DateTime? loadedAt;

  Iterable<int> get taskIds => positions.keys;
}

@immutable
final class ProjectListSource {
  const new({
    this.projectTasks = const [],
    this.tasksById = const {},
    this.snapshot = const ListSnapshot(),
    this.omitsDoneTasks = false,
  });

  /// The project's tasks: every one, or without the done ones the view's
  /// last download does not have when the source was asked for that.
  final List<Task> projectTasks;

  /// The project's tasks and every task reachable from them as a subtask,
  /// in any project: what `buildTaskTree` looks children up in.
  final Map<int, Task> tasksById;

  /// The view's last download.
  final ListSnapshot snapshot;

  /// The project has done tasks that [projectTasks] leaves out.
  final bool omitsDoneTasks;
}
