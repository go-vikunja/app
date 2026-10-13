import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
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
  await db.listSnapshotsDao.removeAll(overviewSnapshotPrefix, keep: key);
  _log.info('Sync run $runId: Overview filter, ${tasks.length} tasks');
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
  final zone = decodeUserSettings(
    (await db.syncStateDao.readAll())[SyncStateKeys.userSettings],
  ).timezone;
  final tasks = await collectPages<Task>(
    fetch: (page) => client.tasks.listInView(
      projectId,
      viewId,
      TaskQuery(
        sort: const [TaskSort(TaskSortField.position)],
        page: page,
        perPage: perPage,
        filterTimezone: zone.isEmpty ? null : zone,
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

bool _sameOrder(Map<int, double> a, Map<int, double> b) {
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in b.entries) {
    if (a[key] != value) return false;
  }
  return true;
}
