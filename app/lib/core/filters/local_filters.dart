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
  const new _(
    this._filter,
    this._search, {
    required this.onlyOpenTasks,
    this._also,
  });

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

  /// What the server's tasks endpoint evaluates when a request with
  /// [request] (filter and include-nulls) meets the [own] filter of a view
  /// or, with [savedFilter], of a saved filter (`task_collection.go`): the
  /// texts ANDed as `(request) && (own)` with include-nulls if either asks,
  /// and the view's search. A saved filter whose own include-nulls is off
  /// keeps it off for its own conditions when the request turns it on: the
  /// request's text alone is evaluated with it then. Null when the device
  /// cannot evaluate either text.
  static LocalFilter? compileWithRequest(
    ViewFilter? own,
    ViewFilter request, {
    required tz.Location location,
    required DateTime now,
    bool savedFilter = false,
  }) {
    final base = own ?? const ViewFilter();
    LocalFilter? compiled(ViewFilter filter) =>
        compile(filter, location: location, now: now);
    if (request.filter.isEmpty) return compiled(base);
    if (base.filter.isEmpty) {
      return compiled(
        ViewFilter(
          filter: request.filter,
          search: base.search,
          includeNulls: base.includeNulls || request.includeNulls,
        ),
      );
    }
    if (savedFilter && request.includeNulls && !base.includeNulls) {
      final nullable = compiled(
        ViewFilter(filter: request.filter, includeNulls: true),
      );
      final rest = compiled(base);
      if (nullable == null || rest == null) return null;
      return LocalFilter._(
        nullable._filter,
        null,
        onlyOpenTasks: nullable.onlyOpenTasks || rest.onlyOpenTasks,
        also: rest,
      );
    }
    return compiled(
      ViewFilter(
        filter: '(${request.filter}) && (${base.filter})',
        search: base.search,
        includeNulls: base.includeNulls || request.includeNulls,
      ),
    );
  }

  /// Whether [filter] narrows anything down: an empty one lists every task.
  static bool restricts(ViewFilter? filter) =>
      filter != null &&
      (filter.filter.isNotEmpty || filter.search.trim().isNotEmpty);

  final BoundFilter? _filter;
  final String? _search;
  final LocalFilter? _also;

  /// No done task can match, so the candidates can leave them out.
  final bool onlyOpenTasks;

  bool matches(FilterableTask task) =>
      (_search == null || matchesTaskSearch(_search, task)) &&
      (_filter?.matches(task) ?? true) &&
      (_also?.matches(task) ?? true);

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
  /// it. With a [request] (a timeline's range), what the view's tasks
  /// endpoint answers to it: both filters, as
  /// [LocalFilter.compileWithRequest] combines them.
  Future<Set<int>?> matchingInProject(
    int projectId,
    ViewFilter? filter, {
    required String timezoneSetting,
    ViewFilter? request,
  }) async {
    final location = locationForFilters([timezoneSetting]);
    final LocalFilter? compiled;
    if (request != null && LocalFilter.restricts(request)) {
      compiled = LocalFilter.compileWithRequest(
        filter,
        request,
        location: location,
        now: _now(),
      );
    } else {
      if (filter == null || !LocalFilter.restricts(filter)) return null;
      compiled = LocalFilter.compile(filter, location: location, now: _now());
    }
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

/// Whether a view with [filter] lists what only the server can evaluate:
/// its filter restricts something, and the engine refuses it or it names
/// `bucket_id`. Such a view's tasks come from its download.
bool refusesViewFilter(ViewFilter? filter) =>
    LocalFilter.restricts(filter) &&
    LocalFilter.compile(filter!, location: tz.UTC, now: DateTime.timestamp()) ==
        null;

/// Whether [view]'s tasks are downloaded into its snapshot
/// (`downloadViewSnapshot`): a list view's for their positions, a table's
/// or Gantt view's only for a filter the device cannot evaluate, whose
/// answer only the server has. A kanban view has its board instead.
bool downloadsSnapshot(ProjectView view) => switch (view.kind) {
  ProjectViewKind.list => true,
  ProjectViewKind.table ||
  ProjectViewKind.gantt => refusesViewFilter(view.filter),
  ProjectViewKind.kanban => false,
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
