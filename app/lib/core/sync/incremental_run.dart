import 'package:flutter/foundation.dart' show setEquals;
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/chunks.dart';
import 'package:vikunja_mobile/core/sync/archived_projects.dart';
import 'package:vikunja_mobile/core/sync/gone_projects.dart';
import 'package:vikunja_mobile/core/sync/list_downloads.dart';
import 'package:vikunja_mobile/core/sync/newest_updated.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/stable_pages.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/sync/task_filters.dart';

final _log = Logger('SyncEngine');

typedef SyncProgress = void Function(SyncPhase phase, {int done, int? total});

/// Has the next incremental run pull the projects' tasks whole, as it does
/// for projects new to this device, or archived or un-archived elsewhere
/// since its last run: for projects the app stored itself from a write's
/// answer, which the run then finds unchanged. A completed run clears the
/// mark, a full one pulls everything anyway, unless the mark was made after
/// the run started, also in a resumed run's first part; a stopped full run
/// starts over (see [IncrementalRun]), one under way saves its checkpoint
/// again.
Future<void> pullWholeOnNextRun(AppDatabase db, Set<int> projectIds) =>
    db.transaction(() async {
      final state = await db.syncStateDao.readAll();
      final ids = {
        ...IncrementalRun._parseIds(state[SyncStateKeys.pendingWholePull]),
        ...projectIds,
      };
      final marks = int.tryParse(state[SyncStateKeys.wholePullMarks] ?? '');
      await db.syncStateDao.write({
        ...SyncCheckpoint.cleared,
        SyncStateKeys.pendingWholePull: (ids.toList()..sort()).join(','),
        SyncStateKeys.wholePullMarks: '${(marks ?? 0) + 1}',
      });
    });

typedef _ProjectDiff = ({
  List<int> all,
  Set<int> archived,
  List<int> pulledWhole,
  List<int> archivedChanged,
});

/// One incremental pull. The project list is diffed against the local one
/// (removed projects are purged with their tasks), labels are re-pulled,
/// and the tasks changed since `since` come by keyset over `(updated, id)`
/// from `GET /tasks`, plus `GET /projects/{id}/tasks` for archived projects
/// that changed. New, un-archived and newly archived projects are pulled
/// whole. A deleted task leaves no trace, so the server's count of
/// `GET /tasks` is compared with the local one of the same scope; only when
/// they differ are the live projects counted one by one and the mismatching
/// ones reconciled by id. A project's `updated` is not the trigger for that:
/// it has second precision and misses a change within the second a sync
/// last saw. A project's tasks are purged only once its ids are complete, so
/// a failed run never deletes. Rows that equal the local ones are not
/// written, so a run that finds nothing new leaves the database's watchers
/// alone. Last comes the Overview's saved filter, see
/// `downloadOverviewFilter`.
final class IncrementalRun {
  new({
    required this._db,
    required this._client,
    required this._perPage,
    required this.runId,
    required this._since,
    required this._now,
    required this._checkActive,
    required this._keepLease,
    required this._report,
    required this.newestUpdated,
  });

  final AppDatabase _db;
  final VikunjaReadClient _client;
  final int _perPage;
  final DateTime _since;
  final DateTime Function() _now;
  final void Function() _checkActive;

  /// Before every request and inside a purge's transaction: renews the
  /// run's hold on the account, or throws when it has lost it.
  final Future<void> Function() _keepLease;
  final SyncProgress _report;

  final String runId;
  int requests = 0;
  SyncPhase phase = SyncPhase.projects;

  /// For the watermark, fed by the `GET /tasks` delta pages alone, the walk
  /// the next run continues: the run's later reads and the rows other code
  /// writes meanwhile can lie above changes that walk has not seen.
  final NewestUpdated newestUpdated;

  Future<void> execute() async {
    _report(SyncPhase.projects);
    final diff = await _syncProjects();
    await fetchSavedFilterDefinitions(
      db: _db,
      client: _client,
      runId: runId,
      request: _request,
    );
    await _syncLabels();
    phase = SyncPhase.delta;
    _report(SyncPhase.delta);
    var pulled = await _pullDelta(
      _client.tasks.list,
      done: 0,
      newest: newestUpdated,
    );
    final pulledWhole = diff.pulledWhole.toSet();
    final gone = <int>{};
    for (final id in diff.archivedChanged) {
      if (pulledWhole.contains(id)) continue;
      await _inProject(id, gone, () async {
        pulled = await _pullDelta(
          (query) => _client.tasks.listInProject(id, query),
          done: pulled,
        );
      });
    }
    phase = SyncPhase.reconcile;
    final whole = diff.pulledWhole;
    var examined = 0;
    _report(SyncPhase.reconcile, total: whole.length);
    for (final id in whole) {
      await _inProject(id, gone, () => _reconcile(id));
      _report(SyncPhase.reconcile, done: ++examined, total: whole.length);
    }
    if (await _totalsToWalk(diff.archived) case (:final remember)) {
      final live = [
        for (final id in diff.all)
          if (!diff.archived.contains(id) && !pulledWhole.contains(id)) id,
      ];
      final total = whole.length + live.length;
      final goneBefore = gone.length;
      var settled = true;
      for (final id in live) {
        await _inProject(id, gone, () async {
          if (!await _countDiffers(id)) return;
          final (:purged, :kept) = await _reconcile(id);
          if (purged > 0 || kept > 0) settled = false;
        });
        _report(SyncPhase.reconcile, done: ++examined, total: total);
      }
      if (remember != null && settled && gone.length == goneBefore) {
        await _db.transaction(() async {
          await _keepLease();
          await _db.syncStateDao.write({
            SyncStateKeys.unexplainedTotals: remember,
          });
        });
      }
    }
    await downloadOverviewFilter(
      db: _db,
      client: _client,
      perPage: _perPage,
      runId: runId,
      now: _now,
      request: _request,
    );
    _log.fine('Sync run $runId: $requests requests');
  }

  /// All pages, archived projects included; pseudo projects repeat on every
  /// page and are skipped, only the saved filters' names are kept. One the
  /// server no longer lists is gone with its tasks. Added, un-archived and
  /// newly archived projects (itself or through a parent) are pulled whole,
  /// and so are the ones a failed run left pending: archiving takes the
  /// tasks out of `GET /tasks` without bumping their `updated`, so a full
  /// run that read the project as live may have purged them or never stored
  /// them (decision log: Sync). An archived project whose `updated` differs
  /// gets its delta through the project. Only rows that differ from the
  /// local ones are written.
  ///
  /// A project pulled whole or no longer archived (itself or through a
  /// parent) clears a stopped full run's checkpoint with the project rows:
  /// that run may have passed the project's tasks while they were out of
  /// its reach, or read it as live and passed it in its archived phase, and
  /// continuing it would purge them.
  Future<_ProjectDiff> _syncProjects() async {
    final local = {for (final p in await _db.projectsDao.loadAll()) p.id: p};
    final pendingBefore = _parseIds(
      (await _db.syncStateDao.readAll())[SyncStateKeys.pendingWholePull],
    );
    final pseudo = <Project>[];
    final remote = await collectPages<Project>(
      fetch: (page) {
        // A walk that starts over starts at page 1.
        if (page == 1) pseudo.clear();
        return _request(
          () => _client.projects.list(
            page: page,
            perPage: _perPage,
            includeArchived: true,
          ),
        );
      },
      idOf: (project) => project.id,
      skip: (project) {
        if (project.isPseudo) pseudo.add(project);
        return project.isPseudo;
      },
      onPage: (collected, page) => _report(
        SyncPhase.projects,
        done: collected.length,
        total: page.total,
      ),
      stored: local.keys,
    );
    final removed = [
      for (final id in local.keys)
        if (!remote.containsKey(id)) id,
    ];
    final archivedBefore = archivedProjectIds(local.values).toSet();
    final archived = archivedProjectIds(remote.values).toSet();
    final pulledWhole = <int>{
      for (final id in pendingBefore)
        if (remote.containsKey(id)) id,
    };
    final archivedChanged = <int>[];
    final changed = <Project>[];
    for (final project in remote.values) {
      final before = local[project.id];
      final archivedNow = archived.contains(project.id);
      if (before == null ||
          (before.isArchived && !project.isArchived) ||
          (archivedNow && !archivedBefore.contains(project.id))) {
        pulledWhole.add(project.id);
      } else if (archivedNow && !_sameMoment(before.updated, project.updated)) {
        archivedChanged.add(project.id);
      }
      if (before == null || !_sameProject(before, project)) {
        changed.add(project);
      }
    }
    final restartsFullRun =
        pulledWhole.isNotEmpty ||
        archivedBefore.any(
          (id) => remote.containsKey(id) && !archived.contains(id),
        );
    await _db.transaction(() async {
      await _keepLease();
      if (restartsFullRun) await _db.syncStateDao.write(SyncCheckpoint.cleared);
      if (changed.isNotEmpty) await _db.projectsDao.upsertAll(changed);
      await storeSavedFilters(_db, savedFiltersIn(pseudo));
      if (removed.isNotEmpty) {
        await _db.projectsDao.purge(removed);
        await _db.tasksDao.purgeInProjects(removed);
      }
      await _db.kanbanDao.removeGoneViews();
      final stored = _parseIds(
        (await _db.syncStateDao.readAll())[SyncStateKeys.pendingWholePull],
      );
      // Marked by a write while the projects were read: the next run's.
      final pending = {...pulledWhole, ...stored.difference(pendingBefore)};
      if (!setEquals(pending, stored)) {
        await _db.syncStateDao.write({
          SyncStateKeys.pendingWholePull: pending.isEmpty
              ? null
              : (pending.toList()..sort()).join(','),
        });
      }
    });
    _log.info(
      'Sync run $runId: ${remote.length} projects, ${changed.length} '
      'written, ${removed.length} removed, ${pulledWhole.length} to pull '
      'whole, ${archivedChanged.length} archived changed',
    );
    return (
      all: remote.keys.toList()..sort(),
      archived: archived,
      pulledWhole: pulledWhole.toList()..sort(),
      archivedChanged: archivedChanged..sort(),
    );
  }

  Future<void> _syncLabels() async {
    phase = SyncPhase.labels;
    final local = {for (final l in await _db.labelsDao.loadAll()) l.id: l};
    final remappedBefore = await _db.labelsDao.remappedServerIds();
    final byId = await collectPages<Label>(
      fetch: (page) =>
          _request(() => _client.labels.list(page: page, perPage: _perPage)),
      idOf: (label) => label.id,
      onPage: (collected, page) =>
          _report(SyncPhase.labels, done: collected.length, total: page.total),
      stored: [
        for (final id in local.keys)
          if (id > 0) id,
      ],
    );
    final changed = [
      for (final label in byId.values)
        if (!_sameLabel(local[label.id], label)) label,
    ];
    await _db.transaction(() async {
      await _keepLease();
      if (changed.isNotEmpty) await _db.labelsDao.upsertAll(changed);
      await _db.labelsDao.purgeNotIn(byId.keys, remappedBefore: remappedBefore);
    });
  }

  /// Everything changed since [_since], one page per request, sorted by
  /// `(updated, id)` and continued after the last item of each page. A page
  /// in any other order would make the cursor skip tasks, so it fails the
  /// run before it is stored.
  Future<int> _pullDelta(
    Future<Page<Task>> Function(TaskQuery query) fetch, {
    required int done,
    NewestUpdated? newest,
  }) async {
    var filter = TaskFilters.updatedSince(_since);
    (DateTime, int)? cursor;
    var count = done;
    while (true) {
      final page = await _request(
        () => fetch(
          TaskQuery(
            filter: filter,
            sort: TaskFilters.byUpdatedThenId,
            perPage: _perPage,
            expand: TaskFilters.commentState,
          ),
        ),
      );
      final items = page.items;
      if (items.isEmpty) return count;
      for (final item in items) {
        final updated = item.updated;
        if (updated == null) {
          throw UnexpectedResponse(
            null,
            message: 'task ${item.id} without updated',
          );
        }
        final position = (updated, item.id);
        if (cursor != null && !_follows(position, cursor)) {
          throw UnexpectedResponse(
            null,
            message: 'tasks after $filter not sorted by updated, id',
          );
        }
        cursor = position;
      }
      await _upsertChanged(items);
      newest?.addTasks(items);
      count += items.length;
      _report(SyncPhase.delta, done: count);
      if (endsKeysetWalk(page)) return count;
      filter = TaskFilters.updatedAfter(cursor!.$1, cursor.$2);
    }
  }

  /// The server's total of `GET /tasks` and the local one of that scope
  /// (`TasksDao.countAcrossProjects`), `remote,local`, when they differ and
  /// the live projects are to be walked; the walk keeps it (`remember`) when
  /// it settled nothing. Null when they match, or when a walk at these very
  /// totals purged nothing, found no project gone and kept no task for
  /// another write of its run: walking again could not settle what it left,
  /// so it is not walked on every run. Such are a favourite in an archived
  /// project, which no walk reaches (deleted on the server right before its
  /// project was archived, a toggle the server refused there), and a task
  /// kept for its queued op, such as an edit refused because the web deleted
  /// the task, until it is discarded. Other totals forget them. A count the
  /// server did not report never matches and is never kept: only a walk can
  /// find a delete then (decision log: Sync).
  Future<({String? remember})?> _totalsToWalk(Set<int> archived) async {
    final page = await _request(
      () => _client.tasks.list(const TaskQuery(perPage: 1)),
    );
    final remote = page.total ?? page.totalPages;
    final local = await _db.tasksDao.countAcrossProjects(archived);
    final totals = remote == null ? null : '$remote,$local';
    final unexplained = (await _db.syncStateDao
        .readAll())[SyncStateKeys.unexplainedTotals];
    if (unexplained != null && unexplained != totals) {
      await _db.syncStateDao.write({SyncStateKeys.unexplainedTotals: null});
    }
    if (remote == local) return null;
    final walked = totals != null && unexplained == totals;
    _log.info(
      'Sync run $runId: ${remote ?? 'an unreported number of'} tasks on the '
      'server and $local here'
      '${walked ? ', which a walk over the projects did not explain' : ''}',
    );
    return walked ? null : (remember: totals);
  }

  /// `per_page=1` reports the count: `total` on v2, the page count on v1;
  /// one the server did not report counts as differing.
  Future<bool> _countDiffers(int projectId) async {
    final page = await _request(
      () => _client.tasks.listInProject(projectId, const TaskQuery(perPage: 1)),
    );
    final remote = page.total ?? page.totalPages;
    if (remote == null) return true;
    final local = await _db.tasksDao.countInProject(projectId);
    if (remote != local) {
      _log.info(
        'Sync run $runId: project $projectId has $remote tasks on the '
        'server and $local here',
      );
    }
    return remote != local;
  }

  /// Every task of the project by id, done ones included, upserted as they
  /// arrive; the local tasks the server did not return go at the end, except
  /// those another write stored during the run, which it reports as kept.
  Future<({int purged, int kept})> _reconcile(int projectId) async {
    final seen = <int>{};
    var lastId = 0;
    while (true) {
      final page = await _request(
        () => _client.tasks.listInProject(
          projectId,
          TaskQuery(
            filter: TaskFilters.after(lastId),
            sort: TaskFilters.byId,
            perPage: _perPage,
            expand: TaskFilters.commentState,
          ),
        ),
      );
      final items = page.items;
      if (items.isEmpty) break;
      for (final item in items) {
        if (item.id <= lastId) {
          throw UnexpectedResponse(
            null,
            message:
                'tasks of project $projectId after id $lastId not '
                'sorted by id',
          );
        }
        lastId = item.id;
      }
      await _upsertChanged(items);
      seen.addAll(items.map((task) => task.id));
      if (endsKeysetWalk(page)) break;
    }
    final result = await _db.transaction(() async {
      await _keepLease();
      return await _db.tasksDao.purgeInProjectExcept(
        projectId,
        seen,
        runId: runId,
      );
    });
    _log.info(
      'Sync run $runId: project $projectId reconciled, ${seen.length} tasks, '
      '${result.purged} purged, ${result.kept} kept for another write',
    );
    return result;
  }

  /// Every change bumps a task's `updated` (asynchronously for comments,
  /// attachments, relations and assignees, which the overlap re-reads), so
  /// a row equal to the local one has nothing new. A relation change bumps
  /// only the task it was made on; the upsert of that task corrects the
  /// inverse edges of the other one. Reminders are compared
  /// too: a date change can make the server merge reminders without a
  /// newer `updated` than the answer the row took them from. In slices of
  /// [sqlChunkSize] tasks, as the full run stores a page (decision log:
  /// Sync).
  Future<void> _upsertChanged(List<Task> items) async {
    for (final slice in chunksOf(items)) {
      _checkActive();
      final local = await _db.tasksDao.findAll(slice.map((task) => task.id));
      final changed = [
        for (final task in slice)
          if (!_unchanged(local[task.id], task)) task,
      ];
      if (changed.isNotEmpty) {
        await _db.tasksDao.upsertAll(
          changed,
          syncRunId: runId,
          withCommentState: true,
        );
      }
    }
  }

  /// The project's task requests; a project found gone ([meansProjectGone])
  /// goes with its tasks and is not asked again in this run.
  Future<void> _inProject(
    int projectId,
    Set<int> gone,
    Future<void> Function() body,
  ) async {
    if (gone.contains(projectId)) return;
    try {
      await body();
    } on VikunjaFailure catch (failure) {
      if (!meansProjectGone(failure)) rethrow;
      gone.add(projectId);
      await purgeGoneProject(
        _db,
        projectId,
        runId: runId,
        holdLease: _keepLease,
      );
    }
  }

  Future<T> _request<T>(Future<T> Function() send) async {
    _checkActive();
    await _keepLease();
    _checkActive();
    requests++;
    final response = await send();
    _checkActive();
    return response;
  }

  static bool _unchanged(Task? stored, Task incoming) =>
      stored != null &&
      stored == incoming &&
      sameReminders(stored.reminders, incoming.reminders);

  static Set<int> _parseIds(String? csv) => {
    for (final part in csv?.split(',') ?? const <String>[]) ?int.tryParse(part),
  };

  static bool _follows((DateTime, int) a, (DateTime, int) b) =>
      a.$1.isAfter(b.$1) || (a.$1.isAtSameMomentAs(b.$1) && a.$2 > b.$2);

  static bool _sameMoment(DateTime? a, DateTime? b) => switch ((a, b)) {
    (null, null) => true,
    (final a?, final b?) => a.isAtSameMomentAs(b),
    _ => false,
  };

  /// Value equality plus the owner and the views, which `==` leaves out.
  static bool _sameProject(Project a, Project b) =>
      a == b && a.owner?.id == b.owner?.id && _sameViews(a.views, b.views);

  static bool _sameViews(List<ProjectView> a, List<ProjectView> b) {
    if (a.length != b.length) return false;
    final byId = {for (final view in b) view.id: view};
    return a.every((view) => byId[view.id] == view);
  }

  static bool _sameLabel(Label? before, Label label) =>
      before == label && before?.createdBy?.id == label.createdBy?.id;
}
