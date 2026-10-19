import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/stable_pages.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

final _log = Logger('SyncEngine');

typedef PageRequest = Future<Page<Task>> Function(
  Future<Page<Task>> Function() send,
);

Future<Page<Task>> _direct(Future<Page<Task>> Function() send) => send();

/// The open tasks of the saved filter the Overview shows, when the user
/// picked one the last project list named, into its snapshot (`GET
/// /projects/{pseudo}/tasks`, the web's Home request). The snapshot is
/// rewritten only when its tasks or their order changed, so an unchanged
/// filter leaves the lists on screen alone; the snapshots of other filters
/// go. Every request goes through [request]. A failed download is logged,
/// not thrown: the Overview keeps the previous one.
Future<void> downloadOverviewFilter({
  required AppDatabase db,
  required VikunjaReadClient client,
  required int perPage,
  required String runId,
  required DateTime Function() now,
  PageRequest request = _direct,
}) async {
  final filter = overviewFilterIn(await db.syncStateDao.readAll());
  if (filter == null) {
    await db.listSnapshotsDao.removeAll(overviewSnapshotPrefix);
    return;
  }
  final key = overviewSnapshotKey(filter.projectId);
  final Map<int, Task> tasks;
  try {
    tasks = await collectPages<Task>(
      fetch: (page) => request(
        () => client.tasks.listInProject(
          filter.projectId,
          TaskQuery(
            filter: 'done = false',
            sort: TaskQuery.dueDateSort,
            page: page,
            perPage: perPage,
          ),
        ),
      ),
      idOf: (task) => task.id,
    );
  } on VikunjaFailure catch (failure) {
    _log.warning(
      'Sync run $runId: the Overview filter was not downloaded: '
      '${failure.runtimeType}',
    );
    return;
  }
  final positions = {
    for (final (index, id) in tasks.keys.indexed) id: index.toDouble(),
  };
  final stored = await db.listSnapshotsDao.load(key);
  if (stored.loadedAt == null || !_sameOrder(stored.positions, positions)) {
    await db.listSnapshotsDao.replace(key, positions, loadedAt: now().toUtc());
  }
  await db.listSnapshotsDao.removeAll(overviewSnapshotPrefix, keep: {key});
  _log.info('Sync run $runId: Overview filter, ${tasks.length} tasks');
}

/// A saved filter's open tasks, all pages, into its snapshot: the
/// Overview's request, with relative dates in the filter rounded in the
/// user's time zone setting as the web asks for them. Always rewritten, so
/// its `loadedAt` says when the list was last checked. Throws the
/// download's `VikunjaFailure`; the previous snapshot stays then.
Future<void> downloadSavedFilter({
  required AppDatabase db,
  required VikunjaReadClient client,
  required int perPage,
  required int pseudoProjectId,
  required DateTime Function() now,
}) async {
  final zone = await _timezoneSetting(db);
  final tasks = await collectPages<Task>(
    fetch: (page) => client.tasks.listInProject(
      pseudoProjectId,
      TaskQuery(
        filter: 'done = false',
        sort: TaskQuery.dueDateSort,
        page: page,
        perPage: perPage,
        filterTimezone: zone,
      ),
    ),
    idOf: (task) => task.id,
  );
  await db.listSnapshotsDao.replace(savedFilterSnapshotKey(pseudoProjectId), {
    for (final (index, id) in tasks.keys.indexed) id: index.toDouble(),
  }, loadedAt: now().toUtc());
  _log.fine('Saved filter $pseudoProjectId: ${tasks.length} tasks');
}

/// A view's tasks with their positions in it, all pages, sorted by
/// position like the web's List view, into the view's snapshot. Relative
/// dates in the view's filter are rounded in the user's time zone setting,
/// as the web asks for them. Throws the download's `VikunjaFailure`; the
/// previous snapshot stays then.
Future<void> downloadViewSnapshot({
  required AppDatabase db,
  required VikunjaReadClient client,
  required int perPage,
  required int projectId,
  required int viewId,
  required DateTime Function() now,
}) async {
  final zone = await _timezoneSetting(db);
  final tasks = await collectPages<Task>(
    fetch: (page) => client.tasks.listInView(
      projectId,
      viewId,
      TaskQuery(
        sort: const [TaskSort(TaskSortField.position)],
        page: page,
        perPage: perPage,
        filterTimezone: zone,
      ),
    ),
    idOf: (task) => task.id,
  );
  await db.listSnapshotsDao.replace(
    listKeyFor(projectId: projectId, viewId: viewId),
    {for (final task in tasks.values) task.id: task.position},
    loadedAt: now().toUtc(),
  );
  _log.fine('View $viewId of project $projectId: ${tasks.length} tasks');
}

/// The server's cap on a board's page size, per bucket.
const _boardPageLimit = 50;

/// A kanban view's board into its buckets and snapshot, in one write: one
/// board request (the first page of every bucket), then for every bucket
/// of which more pages were loaded before, those pages again, so the
/// cards the user scrolled to stay. A card the server lists in two buckets
/// (a filter-mode board) stays in the first. Relative dates in the view's
/// filter are rounded in the user's time zone setting. Throws the
/// download's `VikunjaFailure`; the previous board stays then.
Future<void> downloadBoard({
  required AppDatabase db,
  required VikunjaReadClient client,
  required int perPage,
  required int projectId,
  required int viewId,
  required DateTime Function() now,
}) async {
  final zone = await _timezoneSetting(db);
  final size = _boardPageSize(perPage);
  final loadedBefore = await db.kanbanDao.loadedPages(viewId);
  final columns = await client.buckets.board(
    projectId,
    viewId,
    perPage: size,
    filterTimezone: zone,
  );
  final slots = <int, BoardSlot>{};
  final loadedPages = <int, int>{};
  for (final column in columns) {
    final bucket = column.bucket;
    void take(Iterable<Task> cards) {
      for (final task in cards) {
        slots.putIfAbsent(
          task.id,
          () => (bucketId: bucket.id, position: task.position),
        );
      }
    }

    take(column.tasks);
    var pages = 1;
    final wanted = loadedBefore[bucket.id] ?? 1;
    while (pages < wanted && bucket.count > pages * size) {
      final page = await client.buckets.bucketTasks(
        projectId,
        viewId,
        bucket.id,
        page: pages + 1,
        perPage: size,
        filterTimezone: zone,
      );
      pages++;
      take(page.items);
      if (page.items.isEmpty) break;
    }
    loadedPages[bucket.id] = pages;
  }
  await db.kanbanDao.replaceBoard(
    viewId,
    buckets: [for (final column in columns) column.bucket],
    slots: slots,
    loadedPages: loadedPages,
    loadedAt: now().toUtc(),
  );
  _log.fine(
    'Board $viewId of project $projectId: ${columns.length} buckets, '
    '${slots.length} cards',
  );
}

/// The next page of one bucket's cards onto the board. Nothing happens
/// while the board has not been downloaded or no longer has the bucket.
/// Throws the download's `VikunjaFailure`.
Future<void> downloadNextBucketPage({
  required AppDatabase db,
  required VikunjaReadClient client,
  required int perPage,
  required int projectId,
  required int viewId,
  required int bucketId,
}) async {
  final loaded = (await db.kanbanDao.loadedPages(viewId))[bucketId];
  if (loaded == null) return;
  final size = _boardPageSize(perPage);
  final page = await client.buckets.bucketTasks(
    projectId,
    viewId,
    bucketId,
    page: loaded + 1,
    perPage: size,
    filterTimezone: await _timezoneSetting(db),
  );
  await db.kanbanDao.appendToBucket(
    viewId,
    bucketId,
    positions: {for (final task in page.items) task.id: task.position},
    loadedPages: loaded + 1,
    count: page.total,
    last: page.items.length < size,
  );
  _log.fine(
    'Bucket $bucketId of board $viewId: page ${loaded + 1}, '
    '${page.items.length} cards',
  );
}

int _boardPageSize(int perPage) =>
    perPage < 1 || perPage > _boardPageLimit ? _boardPageLimit : perPage;

/// Null while the user has none stored.
Future<String?> _timezoneSetting(AppDatabase db) async {
  final zone = decodeUserSettings(
    (await db.syncStateDao.readAll())[SyncStateKeys.userSettings],
  ).timezone;
  return zone.isEmpty ? null : zone;
}

bool _sameOrder(Map<int, double> a, Map<int, double> b) {
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in b.entries) {
    if (a[key] != value) return false;
  }
  return true;
}
