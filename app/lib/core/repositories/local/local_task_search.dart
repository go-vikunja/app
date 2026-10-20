import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/filters/search_index.dart';
import 'package:vikunja_mobile/core/repositories/local/shared_latest.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_search.dart';
import 'package:vikunja_mobile/core/sync/archived_projects.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

/// The search over the account's database. The folded index is built once
/// per change of the tasks, projects, labels or saved filters, from the
/// previous one, and shared by every query; only the tasks shown are
/// loaded whole.
final class LocalTaskSearch implements TaskSearch {
  new(this._db, {DateTime Function()? now})
    : _filters = LocalFilters(_db, now: now ?? DateTime.now);

  final AppDatabase _db;
  final LocalFilters _filters;
  SearchIndex? _lastIndex;

  // The sync writes its checkpoints to the same table as the saved
  // filters, so only that key is watched there.
  late final SharedLatest<SearchIndex> _index = SharedLatest(
    () => switchLatest(
      _db.syncStateDao.watchValue(SyncStateKeys.savedFilters).distinct(),
      (savedFilters) => _db.watchTables({
        _db.tasks,
        _db.projects,
        _db.labels,
      }, () => _buildIndex(decodeSavedFilters(savedFilters))),
    ),
  );

  Future<SearchIndex> _buildIndex(List<SavedFilterRef> savedFilters) async {
    final projects = await _db.projectsDao.loadAll();
    return _lastIndex = SearchIndex.build(
      tasks: await _db.tasksDao.loadSearchableTasks(),
      projects: projects,
      archivedProjectIds: archivedProjectIds(projects).toSet(),
      savedFilters: savedFilters,
      labels: await _db.labelsDao.loadAll(),
      previous: _lastIndex,
    );
  }

  /// An empty query finds nothing once the index is built: watching it
  /// builds the index before the first character is typed.
  @override
  Stream<SearchResults> watch(String query) {
    if (query.trim().isEmpty) {
      return _index.stream.map((_) => SearchResults(query: query));
    }
    return _index.stream.asyncMap((index) async {
      final found = index.search(query);
      final shown = found.tasks.take(SearchResults.maxTasks).toList();
      final loaded = await _db.tasksDao.findAll([
        for (final task in shown) task.id,
      ]);
      return SearchResults(
        query: query,
        tasks: [for (final task in shown) ?loaded[task.id]],
        taskCount: found.tasks.length,
        projects: found.projects,
        savedFilters: found.savedFilters,
        labels: found.labels,
      );
    });
  }

  @override
  Future<int?> countMatches(
    ViewFilter filter, {
    int? projectId,
    String timezone = '',
  }) => _filters.countMatches(filter, projectId: projectId, timezone: timezone);
}
