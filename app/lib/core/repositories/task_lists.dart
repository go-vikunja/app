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
    this.description = '',
    this.updated,
    this.definition,
  });

  final int projectId;
  final String title;
  final bool isFavorite;
  final String description;

  /// The pseudo project's `updated` in the last project list: the saved
  /// filter's own.
  final DateTime? updated;

  /// What the filter matches, as `GET /filters/{id}` last answered; null
  /// while unknown here (never read, or the read failed).
  final SavedFilterDefinition? definition;

  int get filterId => -projectId - 1;

  @override
  bool operator ==(Object other) =>
      other is SavedFilterRef &&
      other.projectId == projectId &&
      other.title == title &&
      other.isFavorite == isFavorite &&
      other.description == description &&
      other.updated == updated &&
      other.definition == definition;

  @override
  int get hashCode => Object.hash(
    projectId,
    title,
    isFavorite,
    description,
    updated,
    definition,
  );
}

/// The part of a saved filter the project list leaves out.
@immutable
final class SavedFilterDefinition {
  const new({required this.filter, this.timezone = '', this.updated});

  final ViewFilter filter;

  /// Empty: the user's timezone setting applies.
  final String timezone;

  /// The saved filter's `updated` when it was read; a project list naming
  /// another one means it changed since.
  final DateTime? updated;

  @override
  bool operator ==(Object other) =>
      other is SavedFilterDefinition &&
      other.filter == filter &&
      other.timezone == timezone &&
      other.updated == updated;

  @override
  int get hashCode => Object.hash(filter, timezone, updated);
}

/// Who decided which tasks a filtered list holds.
enum FilterEvaluation {
  /// This device, from the local tasks with the filter engine: a change
  /// made here shows at once, offline too.
  local,

  /// The server, as of the list's last download: the filter is unknown
  /// here, the engine refuses it, or it needs a board (`bucket_id`).
  snapshot,
}

/// A saved filter's open tasks: evaluated here ([FilterEvaluation.local]),
/// or as of its last download ([loadedAt] null: never downloaded, and
/// [tasks] stays empty until the first one) with this device's changes on
/// top: a task done or deleted here leaves at once.
@immutable
final class SavedFilterTasks {
  const new({
    this.tasks = const [],
    this.loadedAt,
    this.evaluation = FilterEvaluation.snapshot,
  });

  /// Nearest due date first (none last), then newest first.
  final List<Task> tasks;

  /// Null under [FilterEvaluation.local].
  final DateTime? loadedAt;
  final FilterEvaluation evaluation;
}

@immutable
final class OverviewTasks {
  const new({
    this.tasks = const [],
    this.filter,
    this.filterLoadedAt,
    this.filterEvaluation = FilterEvaluation.snapshot,
  });

  /// Open tasks, nearest due date first (none last), then newest first.
  final List<Task> tasks;

  /// The saved filter the user picked for the Overview on the web, while
  /// it exists; null when the Overview shows every open task outside
  /// archived projects.
  final SavedFilterRef? filter;

  /// When the filter's tasks were last downloaded. Null with a [filter]
  /// under [FilterEvaluation.snapshot] means never, and [tasks] stays empty
  /// until the first download.
  final DateTime? filterLoadedAt;

  /// How the [filter]'s tasks were picked; meaningless without one.
  final FilterEvaluation filterEvaluation;
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
    this.queuedPositions = const {},
    this.matchingIds,
  });

  /// The project's tasks: every one, or without the done ones the view's
  /// last download does not have when the source was asked for that; the
  /// done ones in [matchingIds] are always there.
  final List<Task> projectTasks;

  /// The project's tasks and every task reachable from them as a subtask,
  /// in any project: what `buildTaskTree` looks children up in.
  final Map<int, Task> tasksById;

  /// The view's last download.
  final ListSnapshot snapshot;

  /// The project has done tasks that [projectTasks] leaves out.
  final bool omitsDoneTasks;

  /// The positions queued for this view and not yet sent, by task id; they
  /// win over the [snapshot]'s in the manual order.
  final Map<int, double> queuedPositions;

  /// The tasks of [projectTasks] the view's filter and search match,
  /// evaluated here with the server's rules (the project's tasks only,
  /// archived project included). Null when the view has neither, and when
  /// the device cannot evaluate them (the engine refuses the filter, or it
  /// names `bucket_id`): the [snapshot] decides then. Under a request
  /// filter (`TaskRepository.watchProjectList`) never null.
  final Set<int>? matchingIds;
}

typedef BoardSlot = ({int bucketId, double position});

/// How many of a project's own tasks there are, and how many are done.
typedef ProjectProgress = ({int done, int total});

/// What a kanban view's board is built from (`buildBoard`): the view's
/// columns and the cards they held as of the last board download
/// ([loadedAt] null: never downloaded), the project's tasks as this device
/// knows them, and the placements it has queued for the view.
@immutable
final class BoardSource {
  const new({
    this.view,
    this.buckets = const [],
    this.snapshot = const {},
    this.loadedAt,
    this.projectTasks = const [],
    this.queued = const {},
    this.movedHere = const {},
    this.queuedDoneChanges = const {},
    this.matchingIds,
  });

  /// Null while the view is not stored here.
  final ProjectView? view;

  /// As downloaded, in bucket position order.
  final List<Bucket> buckets;

  /// Each downloaded card's bucket and position, by task id; the task may
  /// be missing here.
  final Map<int, BoardSlot> snapshot;
  final DateTime? loadedAt;

  /// The project's open tasks, and the done ones the board can show: those
  /// in [snapshot], created here or with queued changes, and those created
  /// or changed after [loadedAt]. Newest first.
  final List<Task> projectTasks;

  /// The placements queued for this view and not yet sent, by task id.
  final Map<int, BucketPlacement> queued;

  /// The tasks of [projectTasks] whose move into the project is not sent
  /// yet, which no download can list.
  final Set<int> movedHere;

  /// The tasks of [projectTasks] whose done change is not sent yet: the
  /// board moves them into or out of the done bucket as the server will.
  final Set<int> queuedDoneChanges;

  /// The tasks of [projectTasks] the view's filter and search match, as
  /// for `ProjectListSource.matchingIds`; [projectTasks] then holds every
  /// matching task, done or not. Null without a filter, for a filter-mode
  /// board, and when the device cannot evaluate the filter.
  final Set<int>? matchingIds;
}
