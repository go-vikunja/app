import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/tasks_dao.dart';
import 'package:vikunja_mobile/core/filters/filter_zone.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

/// A view's or a saved filter's filter as this device evaluates it, with
/// the server's rules: the filter text through the engine with the
/// include-nulls flag, and the search as the server applies a view's `s`.
final class LocalFilter {
  const new _(this._filter, this._search, {required this.onlyOpenTasks});

  /// Null when the device cannot evaluate [filter]: the engine refuses its
  /// text, or the text names `bucket_id`, which needs a board's download.
  static LocalFilter? compile(
    ViewFilter filter, {
    required tz.Location location,
    required DateTime now,
  }) {
    final expression = switch (parseTaskFilter(filter.filter)) {
      final FilterExpression parsed when !parsed.usesBucketId => parsed,
      _ => null,
    };
    if (expression == null) return null;
    final search = filter.search.trim();
    return LocalFilter._(
      expression.isEmpty
          ? null
          : expression.bind(
              FilterContext(
                now: now,
                location: location,
                includeNulls: filter.includeNulls,
              ),
            ),
      search.isEmpty ? null : search,
      onlyOpenTasks: expression.matchesOnlyOpenTasks,
    );
  }

  /// Whether [filter] narrows anything down: an empty one lists every task.
  static bool restricts(ViewFilter? filter) =>
      filter != null &&
      (filter.filter.isNotEmpty || filter.search.trim().isNotEmpty);

  final BoundFilter? _filter;
  final String? _search;

  /// No done task can match, so the candidates can leave them out.
  final bool onlyOpenTasks;

  bool matches(FilterableTask task) =>
      (_search == null || matchesTaskSearch(_search, task)) &&
      (_filter?.matches(task) ?? true);

  Set<int> matchingIds(Iterable<FilterRow> rows) => {
    for (final row in rows)
      if (matches(filterableTaskOf(row))) row.task.id,
  };
}

/// What the filter language reads of a stored task. Unset dates are null,
/// as the server's NULLs; priority and percent done are stored as 0 when
/// unset, which the server's include-nulls rule for numbers treats alike.
FilterableTask filterableTaskOf(FilterRow row) {
  final task = row.task;
  return FilterableTask(
    id: task.id,
    projectId: task.projectId,
    title: task.title,
    description: task.description,
    done: task.done,
    doneAt: task.doneAt,
    dueDate: task.dueDate,
    startDate: task.startDate,
    endDate: task.endDate,
    created: task.created,
    updated: task.updated,
    priority: task.priority,
    percentDone: task.percentDone,
    hexColor: task.hexColor,
    index: task.taskIndex,
    repeatAfterSeconds: task.repeatAfter,
    createdById: task.createdById ?? 0,
    createdByUsername: row.createdBy.isEmpty ? null : row.createdBy,
    labelIds: row.labelIds,
    assigneeUsernames: row.assignees,
    reminders: row.reminders,
  );
}

/// Evaluates filters over the account's database: the candidates of a
/// scope are loaded with what the language reads ([TasksDao.
/// loadFilterRowsInProject], [TasksDao.loadFilterRowsOfSavedFilters]),
/// then matched in Dart.
final class LocalFilters {
  new(this._db, {required this._now});

  final AppDatabase _db;
  final DateTime Function() _now;

  /// The user's timezone setting; empty while none is stored.
  Future<String> timezoneSetting() async => decodeUserSettings(
    (await _db.syncStateDao.readAll())[SyncStateKeys.userSettings],
  ).timezone;

  /// The ids of the project's tasks a view with [filter] lists; null when
  /// the filter does not restrict anything or the device cannot evaluate
  /// it.
  Future<Set<int>?> matchingInProject(
    int projectId,
    ViewFilter? filter, {
    required String timezoneSetting,
  }) async {
    if (filter == null || !LocalFilter.restricts(filter)) return null;
    final compiled = LocalFilter.compile(
      filter,
      location: locationForFilters([timezoneSetting]),
      now: _now(),
    );
    if (compiled == null) return null;
    return compiled.matchingIds(
      await _db.tasksDao.loadFilterRowsInProject(
        projectId,
        openOnly: compiled.onlyOpenTasks,
      ),
    );
  }

  /// [matchingInProject] for a kanban [view]; null also for a board whose
  /// columns come from filters, which only its download can fill.
  Future<Set<int>?> matchingOnBoard(
    int projectId,
    ProjectView? view, {
    required String timezoneSetting,
  }) async {
    if (view == null ||
        view.bucketConfigurationMode == BucketConfigurationMode.filter) {
      return null;
    }
    return await matchingInProject(
      projectId,
      view.filter,
      timezoneSetting: timezoneSetting,
    );
  }

  /// The ids of the tasks a saved filter with [definition] matches, in its
  /// scope (outside archived projects, favourite tasks anywhere), with
  /// relative dates in its own zone, else the user's setting; null when the
  /// device cannot evaluate it. With [openOnly] only the open ones: each
  /// task matches on its own, so the done ones need not be read.
  Future<Set<int>?> matchingForSavedFilter(
    SavedFilterDefinition definition, {
    required String timezoneSetting,
    bool openOnly = false,
  }) async {
    final compiled = compileSavedFilter(
      definition,
      timezoneSetting: timezoneSetting,
    );
    if (compiled == null) return null;
    return compiled.matchingIds(
      await _db.tasksDao.loadFilterRowsOfSavedFilters(
        openOnly: openOnly || compiled.onlyOpenTasks,
      ),
    );
  }

  /// The server never applies a saved filter's stored search to its tasks,
  /// so it is left out here too.
  LocalFilter? compileSavedFilter(
    SavedFilterDefinition definition, {
    required String timezoneSetting,
  }) => LocalFilter.compile(
    ViewFilter(
      filter: definition.filter.filter,
      includeNulls: definition.filter.includeNulls,
    ),
    location: locationForFilters([definition.timezone, timezoneSetting]),
    now: _now(),
  );

  Future<int?> countMatches(
    ViewFilter filter, {
    int? projectId,
    String timezone = '',
  }) async {
    final setting = await timezoneSetting();
    final compiled = LocalFilter.compile(
      projectId == null
          ? ViewFilter(filter: filter.filter, includeNulls: filter.includeNulls)
          : filter,
      location: locationForFilters([timezone, setting]),
      now: _now(),
    );
    if (compiled == null) return null;
    final rows = projectId == null
        ? await _db.tasksDao.loadFilterRowsOfSavedFilters(
            openOnly: compiled.onlyOpenTasks,
          )
        : await _db.tasksDao.loadFilterRowsInProject(
            projectId,
            openOnly: compiled.onlyOpenTasks,
          );
    return compiled.matchingIds(rows).length;
  }
}

/// Whether what [filter] matches changes with time alone (`due_date <
/// now`), so a list of it has to be evaluated again as the clock moves.
bool changesWithTime(ViewFilter? filter) =>
    filter != null &&
    switch (parseTaskFilter(filter.filter)) {
      final FilterExpression expression => expression.usesRelativeDates,
      FilterError() => false,
    };

/// Whether the device can evaluate a saved filter with [definition]
/// itself: known and accepted by the engine.
bool evaluatesLocally(SavedFilterDefinition? definition) =>
    definition != null &&
    LocalFilter.compile(
          ViewFilter(filter: definition.filter.filter),
          location: tz.UTC,
          now: DateTime.timestamp(),
        ) !=
        null;
