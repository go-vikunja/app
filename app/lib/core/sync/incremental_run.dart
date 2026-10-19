import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/sync/archived_projects.dart';
import 'package:vikunja_mobile/core/sync/list_downloads.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/stable_pages.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/sync/task_filters.dart';

final _log = Logger('SyncEngine');

typedef SyncProgress = void Function(SyncPhase phase, {int done, int? total});

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
/// that changed. New and un-archived projects are pulled whole. A deleted
/// task leaves no trace, so the server's count of live tasks is compared
/// with the local one; only when they differ are the live projects counted
/// one by one and the mismatching ones reconciled by id. A project's
/// `updated` is not the trigger for that: it has second precision and misses
/// a change within the second a sync last saw. A project's tasks are purged
/// only once its ids are complete, so a failed run never deletes. Rows that
/// equal the local ones are not written, so a run that finds nothing new
/// leaves the database's watchers alone. Last comes the Overview's saved
/// filter, see `downloadOverviewFilter`.
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
  });

  final AppDatabase _db;
  final VikunjaReadClient _client;
  final int _perPage;
  final DateTime _since;
  final DateTime Function() _now;
  final void Function() _checkActive;

  /// Before every request: renews the run's hold on the account, or throws
  /// when another run has taken it.
  final Future<void> Function() _keepLease;
  final SyncProgress _report;

  final String runId;
  int requests = 0;
  SyncPhase phase = SyncPhase.projects;

  Future<void> execute() async {
    _report(SyncPhase.projects);
    final diff = await _syncProjects();
    await _syncLabels();
    phase = SyncPhase.delta;
    _report(SyncPhase.delta);
    var pulled = await _pullDelta(_client.tasks.list, done: 0);
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
    if (await _liveCountDiffers(diff.archived)) {
      final live = [
        for (final id in diff.all)
          if (!diff.archived.contains(id) && !pulledWhole.contains(id)) id,
      ];
      final total = whole.length + live.length;
      for (final id in live) {
        await _inProject(id, gone, () async {
          if (await _countDiffers(id)) await _reconcile(id);
        });
        _report(SyncPhase.reconcile, done: ++examined, total: total);
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
  /// server no longer lists is gone with its tasks. Added and un-archived
  /// projects are pulled whole, and so are the ones a failed run left
  /// pending; an archived project whose `updated` differs, or that is newly
  /// archived (itself or through a parent, which takes its tasks out of
  /// `GET /tasks`), gets its delta through the project. Only rows that
  /// differ from the local ones are written.
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
      if (before == null) {
        pulledWhole.add(project.id);
      } else if (before.isArchived && !project.isArchived) {
        pulledWhole.add(project.id);
      } else if (archived.contains(project.id) &&
          (!_sameMoment(before.updated, project.updated) ||
              !archivedBefore.contains(project.id))) {
        archivedChanged.add(project.id);
      }
      if (before == null || !_sameProject(before, project)) {
        changed.add(project);
      }
    }
    await _db.transaction(() async {
      if (changed.isNotEmpty) await _db.projectsDao.upsertAll(changed);
      await storeSavedFilters(_db, savedFiltersIn(pseudo));
      if (removed.isNotEmpty) {
        await _db.projectsDao.purge(removed);
        await _db.tasksDao.purgeInProjects(removed);
      }
      await _db.kanbanDao.removeGoneViews();
      if (!setEquals(pulledWhole, pendingBefore)) {
        await _db.syncStateDao.write({
          SyncStateKeys.pendingWholePull: pulledWhole.isEmpty
              ? null
              : (pulledWhole.toList()..sort()).join(','),
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
    final byId = await collectPages<Label>(
      fetch: (page) =>
          _request(() => _client.labels.list(page: page, perPage: _perPage)),
      idOf: (label) => label.id,
      onPage: (collected, page) =>
          _report(SyncPhase.labels, done: collected.length, total: page.total),
    );
    final changed = [
      for (final label in byId.values)
        if (!_sameLabel(local[label.id], label)) label,
    ];
    await _db.transaction(() async {
      if (changed.isNotEmpty) await _db.labelsDao.upsertAll(changed);
      await _db.labelsDao.purgeNotIn(byId.keys);
    });
  }

  /// Everything changed since [_since], one page per request, sorted by
  /// `(updated, id)` and continued after the last item of each page. A page
  /// in any other order would make the cursor skip tasks, so it fails the
  /// run before it is stored.
  Future<int> _pullDelta(
    Future<Page<Task>> Function(TaskQuery query) fetch, {
    required int done,
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
      count += items.length;
      _report(SyncPhase.delta, done: count);
      if (items.length < page.perPage && !page.hasMore) return count;
      filter = TaskFilters.updatedAfter(cursor!.$1, cursor.$2);
    }
  }

  /// `GET /tasks` counts the tasks of every project that is not archived,
  /// which is what the local rows outside [archived] mirror.
  Future<bool> _liveCountDiffers(Set<int> archived) async {
    final page = await _request(
      () => _client.tasks.list(const TaskQuery(perPage: 1)),
    );
    final remote = page.total ?? page.totalPages;
    final local = await _db.tasksDao.countNotInProjects(archived);
    if (remote != local) {
      _log.info(
        'Sync run $runId: $remote live tasks on the server and $local here',
      );
    }
    return remote != local;
  }

  /// `per_page=1` reports the count: `total` on v2, the page count on v1.
  Future<bool> _countDiffers(int projectId) async {
    final page = await _request(
      () => _client.tasks.listInProject(projectId, const TaskQuery(perPage: 1)),
    );
    final remote = page.total ?? page.totalPages;
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
  /// arrive; the local tasks the server did not return go at the end.
  Future<void> _reconcile(int projectId) async {
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
      if (items.length < page.perPage && !page.hasMore) break;
    }
    final purged = await _db.tasksDao.purgeInProjectExcept(projectId, seen);
    _log.info(
      'Sync run $runId: project $projectId reconciled, ${seen.length} tasks, '
      '$purged purged',
    );
  }

  /// Every change bumps a task's `updated` (asynchronously for comments,
  /// attachments, relations and assignees, which the overlap re-reads), so
  /// a row equal to the local one has nothing new. A relation change bumps
  /// only the task it was made on; the upsert of that task corrects the
  /// inverse edges of the other one. Reminders are compared
  /// too: a date change can make the server merge reminders without a
  /// newer `updated` than the answer the row took them from.
  Future<void> _upsertChanged(List<Task> items) async {
    final local = await _db.tasksDao.findAll(items.map((task) => task.id));
    final changed = [
      for (final task in items)
        if (!_unchanged(local[task.id], task)) task,
    ];
    if (changed.isNotEmpty) {
      await _db.tasksDao.upsertAll(changed, syncRunId: runId);
    }
  }

  /// A project that answers "not found" (3001) was deleted since the
  /// project list, one that answers "forbidden" (7003) was unshared; both
  /// go with their tasks. A missing route is not that.
  Future<void> _inProject(
    int projectId,
    Set<int> gone,
    Future<void> Function() body,
  ) async {
    if (gone.contains(projectId)) return;
    try {
      await body();
    } on VikunjaFailure catch (failure) {
      if (!_projectGone(failure)) rethrow;
      gone.add(projectId);
      await _db.transaction(() async {
        await _db.projectsDao.purge([projectId]);
        await _db.tasksDao.purgeInProjects([projectId]);
      });
      _log.info('Sync run $runId: project $projectId is gone, purged');
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

  static bool _projectGone(VikunjaFailure failure) => switch (failure) {
    NotFound(routeAbsent: false) => true,
    Forbidden(code: int()) => true,
    _ => false,
  };

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
    return a.every((x) {
      final y = byId[x.id];
      return y != null &&
          x.projectId == y.projectId &&
          x.title == y.title &&
          x.kind == y.kind &&
          x.position == y.position &&
          x.bucketConfigurationMode == y.bucketConfigurationMode &&
          x.defaultBucketId == y.defaultBucketId &&
          x.doneBucketId == y.doneBucketId &&
          _sameFilter(x.filter, y.filter);
    });
  }

  static bool _sameFilter(ViewFilter? a, ViewFilter? b) => switch ((a, b)) {
    (null, null) => true,
    (final a?, final b?) =>
      a.filter == b.filter &&
          a.search == b.search &&
          listEquals(a.sortBy, b.sortBy) &&
          listEquals(a.orderBy, b.orderBy) &&
          a.includeNulls == b.includeNulls,
    _ => false,
  };

  static bool _sameLabel(Label? before, Label label) =>
      before == label && before?.createdBy?.id == label.createdBy?.id;
}
