import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

final _log = Logger('SyncEngine');

/// `GET /user`, which the read client does not cover.
typedef CurrentUserSource = Future<User> Function();

/// The full pull of one account: account → projects → labels → tasks →
/// archived projects' tasks → finishing. Tasks are pulled keyset by id
/// (`id > lastId`, sorted by id, one page per request), open ones first, and
/// every page is checkpointed in `sync_state`, so a killed app resumes where
/// it stopped. Projects and labels are purged against the full list; tasks
/// are marked with the run id and purged at the end.
///
/// The first status event arrives once the stored state has been read; the
/// stream replays the current status to every subscriber after that.
final class DefaultSyncEngine implements SyncEngine {
  new({
    required this._db,
    required this._client,
    required int perPage,
    this._currentUser,
    DateTime Function()? now,
  }) : _perPage = perPage,
       _now = now ?? DateTime.now {
    if (perPage < 1) throw ArgumentError.value(perPage, 'perPage');
    _ready = _restore();
  }

  final AppDatabase _db;
  final VikunjaReadClient _client;
  final int _perPage;
  final CurrentUserSource? _currentUser;
  final DateTime Function() _now;
  final _random = Random();
  // Synchronous, so a status has reached its subscribers once the run's
  // future resolves.
  final _changes = StreamController<SyncStatus>.broadcast(sync: true);

  /// Changes that landed during the run, with the server's commit lag.
  static const catchUpOverlap = Duration(seconds: 120);

  late Future<void> _ready;
  SyncStatus _status = const SyncNeverRun();
  var _restored = false;
  VikunjaFailure? _restoreFailure;
  DateTime? _lastSyncedAt;
  SyncCheckpoint? _checkpoint;
  Future<void>? _current;
  var _disposed = false;

  @override
  Stream<SyncStatus> get status => Stream.multi((subscriber) {
    final subscription = _changes.stream.listen(
      subscriber.addSync,
      onError: subscriber.addErrorSync,
    );
    subscriber.onCancel = subscription.cancel;
    // Before the restore, the first event is the restored status itself.
    if (_restored) subscriber.add(_status);
  });

  @override
  SyncStatus get currentStatus => _status;

  @override
  Future<void> ensureInitialSync() async {
    await _ensureRestored();
    if (_lastSyncedAt != null) return;
    return await _join(() => _run(resume: true));
  }

  @override
  Future<void> refresh() async {
    await _ensureRestored();
    return await _join(() => _run(resume: false));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _changes.close();
  }

  Future<void> _join(Future<void> Function() start) =>
      _current ??= start().whenComplete(() => _current = null);

  /// A stored state that could not be read is retried here, so Retry on the
  /// first-sync screen covers it; a second failure is the caller's.
  Future<void> _ensureRestored() async {
    await _ready;
    if (_restoreFailure == null) return;
    await (_ready = _restore());
    if (_restoreFailure case final failure?) throw failure;
  }

  /// Never fails: nobody awaits the first call. A database that cannot be
  /// read is reported as a failed run without a last sync.
  Future<void> _restore() async {
    try {
      final state = await _db.syncStateDao.readAll();
      _lastSyncedAt = DateTime.tryParse(state[SyncStateKeys.lastSyncedAt] ?? '')
          ?.toUtc();
      _checkpoint = SyncCheckpoint.fromState(state);
      _restoreFailure = null;
      _emit(switch (_lastSyncedAt) {
        final at? => SyncIdle(lastSyncedAt: at),
        null => const SyncNeverRun(),
      });
    } on Object catch (error) {
      _log.warning('Could not read the sync state: ${error.runtimeType}');
      final failure = UnexpectedResponse(null, message: '${error.runtimeType}');
      _restoreFailure = failure;
      _emit(SyncFailed(failure: failure, lastSyncedAt: null));
    } finally {
      _restored = true;
    }
  }

  Future<void> _run({required bool resume}) async {
    var checkpoint =
        (resume ? _checkpoint : null) ??
        SyncCheckpoint(
          runId: _newRunId(),
          startedAt: _now().toUtc(),
          phase: SyncPhase.account,
        );
    _log.info(
      '${resume && _checkpoint != null ? 'Resuming' : 'Starting'} '
      'sync run ${checkpoint.runId} at ${checkpoint.phase.name}',
    );
    try {
      await _save(checkpoint);
      if (checkpoint.phase == SyncPhase.account) {
        checkpoint = await _syncAccount(checkpoint);
      }
      if (checkpoint.phase == SyncPhase.projects) {
        checkpoint = await _syncProjects(checkpoint);
      }
      if (checkpoint.phase == SyncPhase.labels) {
        checkpoint = await _syncLabels(checkpoint);
      }
      if (checkpoint.phase == SyncPhase.tasks) {
        checkpoint = await _syncTasks(checkpoint);
      }
      if (checkpoint.phase == SyncPhase.archivedTasks) {
        checkpoint = await _syncArchivedTasks(checkpoint);
      }
      await _finish(checkpoint);
    } on _Disposed {
      return;
    } on VikunjaFailure catch (failure) {
      _fail(failure, checkpoint);
      rethrow;
    } on Object catch (error) {
      // Never a server answer; the type is enough to find the cause.
      _fail(
        UnexpectedResponse(null, message: '${error.runtimeType}'),
        checkpoint,
      );
      rethrow;
    }
  }

  Future<SyncCheckpoint> _syncAccount(SyncCheckpoint checkpoint) async {
    _report(checkpoint);
    if (_currentUser case final currentUser?) {
      final user = await currentUser();
      _checkDisposed();
      await _db.usersDao.upsertAll([user]);
    }
    return await _advance(checkpoint, SyncPhase.projects);
  }

  /// All pages, archived projects included, in one list; the pseudo projects
  /// (Favorites, saved filters) repeat on every page and are skipped.
  Future<SyncCheckpoint> _syncProjects(SyncCheckpoint checkpoint) async {
    final byId = <int, Project>{};
    var current = checkpoint;
    for (var page = 1; ; page++) {
      _checkDisposed();
      final result = await _client.projects.list(
        page: page,
        perPage: _perPage,
        includeArchived: true,
      );
      for (final project in result.items) {
        if (!project.isPseudo) byId.putIfAbsent(project.id, () => project);
      }
      current = current.copyWith(done: byId.length, total: result.total);
      _report(current);
      if (!result.hasMore) break;
    }
    _checkDisposed();
    await _db.transaction(() async {
      await _db.projectsDao.upsertAll(byId.values);
      await _db.projectsDao.purgeNotIn(byId.keys);
    });
    _log.info('Sync run ${current.runId}: ${byId.length} projects');
    return await _advance(current, SyncPhase.labels);
  }

  Future<SyncCheckpoint> _syncLabels(SyncCheckpoint checkpoint) async {
    final byId = <int, Label>{};
    var current = checkpoint;
    for (var page = 1; ; page++) {
      _checkDisposed();
      final result = await _client.labels.list(page: page, perPage: _perPage);
      for (final label in result.items) {
        byId.putIfAbsent(label.id, () => label);
      }
      current = current.copyWith(done: byId.length, total: result.total);
      _report(current);
      if (!result.hasMore) break;
    }
    _checkDisposed();
    await _db.transaction(() async {
      await _db.labelsDao.upsertAll(byId.values);
      await _db.labelsDao.purgeNotIn(byId.keys);
    });
    _log.info('Sync run ${current.runId}: ${byId.length} labels');
    return await _advance(current, SyncPhase.tasks, report: false);
  }

  Future<SyncCheckpoint> _syncTasks(SyncCheckpoint checkpoint) async {
    var current = checkpoint;
    if (current.total == null) {
      current = current.copyWith(total: await _countTasks());
      await _save(current);
    }
    _report(current);
    current = await _pullBothFilters(
      current,
      (query) => _client.tasks.list(query),
    );
    _log.info('Sync run ${current.runId}: ${current.done} tasks');
    return await _advance(current, SyncPhase.archivedTasks);
  }

  /// `GET /tasks` leaves out the tasks of archived projects, so those come
  /// through their project, including the children of an archived parent.
  Future<SyncCheckpoint> _syncArchivedTasks(SyncCheckpoint checkpoint) async {
    var current = checkpoint;
    for (final projectId in await _archivedProjectIds()) {
      if (projectId < current.archivedProjectId) continue;
      if (projectId != current.archivedProjectId) {
        current = current.copyWith(
          archivedProjectId: projectId,
          doneFilter: DoneFilter.open,
          lastId: 0,
        );
        await _save(current);
      }
      current = await _pullBothFilters(
        current,
        (query) => _client.tasks.listInProject(projectId, query),
      );
    }
    _log.info('Sync run ${current.runId}: ${current.done} archived tasks');
    return await _advance(current, SyncPhase.finishing);
  }

  /// Before the purge, one more pass over what changed while the run was
  /// going: a task reopened after the open pass had passed its id, and
  /// completed again after the done pass had, is in neither list and would
  /// be purged as gone. Tasks of archived projects cannot change.
  Future<void> _finish(SyncCheckpoint checkpoint) async {
    _report(checkpoint);
    final since = (checkpoint.startedAt ?? _now().toUtc()).subtract(
      catchUpOverlap,
    );
    final caughtUp = await _pullKeyset(
      checkpoint,
      (query) => _client.tasks.list(query),
      changedSince: since,
      report: false,
    );
    _checkDisposed();
    final finishedAt = _now().toUtc();
    final purged = await _db.transaction(() async {
      final purged = await _db.tasksDao.purgeNotInRun(caughtUp.runId);
      await _db.syncStateDao.write({
        ...SyncCheckpoint.cleared,
        SyncStateKeys.lastSyncedAt: finishedAt.toIso8601String(),
      });
      return purged;
    });
    _lastSyncedAt = finishedAt;
    _checkpoint = null;
    _log.info('Sync run ${checkpoint.runId} done, $purged tasks purged');
    _emit(SyncIdle(lastSyncedAt: finishedAt));
  }

  Future<SyncCheckpoint> _pullBothFilters(
    SyncCheckpoint checkpoint,
    Future<Page<Task>> Function(TaskQuery query) fetch,
  ) async {
    var current = checkpoint;
    for (final filter in DoneFilter.values) {
      if (filter.index < current.doneFilter.index) continue;
      if (filter != current.doneFilter) {
        current = current.copyWith(doneFilter: filter, lastId: 0);
        await _save(current);
      }
      current = await _pullKeyset(current, fetch);
    }
    return current;
  }

  /// One page per request, `id > lastId` sorted by id, until a page is short
  /// and the server reports no more. The page size is the server's, which
  /// caps `per_page` silently. With [changedSince] the filter is `updated`
  /// from then on instead of the done flag.
  Future<SyncCheckpoint> _pullKeyset(
    SyncCheckpoint checkpoint,
    Future<Page<Task>> Function(TaskQuery query) fetch, {
    DateTime? changedSince,
    bool report = true,
  }) async {
    final filter = switch (changedSince) {
      final since? => "updated >= '${_rfc3339(since)}'",
      null => checkpoint.doneFilter.filter,
    };
    var current = checkpoint;
    while (true) {
      _checkDisposed();
      final page = await fetch(
        TaskQuery(
          filter: '$filter && id > ${current.lastId}',
          sort: const [TaskSort(TaskSortField.id)],
          perPage: _perPage,
        ),
      );
      _checkDisposed();
      final items = page.items;
      if (items.isEmpty) return current;
      // The cursor is only sound when the page is ascending by id; a page
      // in any other order would skip ids, and the purge would delete them.
      var previousId = current.lastId;
      for (final item in items) {
        if (item.id <= previousId) {
          throw UnexpectedResponse(
            null,
            message: 'tasks after id ${current.lastId} not sorted by id',
          );
        }
        previousId = item.id;
      }
      await _db.tasksDao.upsertAll(items, syncRunId: current.runId);
      current = current.copyWith(
        lastId: previousId,
        done: current.done + items.length,
      );
      await _save(current);
      if (report) _report(current);
      if (items.length < page.perPage && !page.hasMore) return current;
    }
  }

  /// Second precision, like the server's timestamps.
  static String _rfc3339(DateTime moment) =>
      '${moment.toUtc().toIso8601String().substring(0, 19)}Z';

  /// One request per filter with `per_page=1`, whose page count is the item
  /// count on both API versions.
  Future<int> _countTasks() async {
    var total = 0;
    for (final filter in DoneFilter.values) {
      _checkDisposed();
      final page = await _client.tasks.list(
        TaskQuery(filter: filter.filter, perPage: 1),
      );
      total += page.total ?? page.totalPages;
    }
    return total;
  }

  /// Archived projects and their descendants, ascending.
  Future<List<int>> _archivedProjectIds() async {
    final projects = await _db.projectsDao.loadAll();
    final parentOf = {for (final p in projects) p.id: p.parentProjectId};
    final archived = {
      for (final p in projects)
        if (p.isArchived) p.id,
    };
    bool isArchived(int id) {
      final seen = <int>{};
      for (var current = id; seen.add(current); current = parentOf[current]!) {
        if (archived.contains(current)) return true;
        if (!parentOf.containsKey(current)) return false;
      }
      return false;
    }

    return [
      for (final p in projects)
        if (isArchived(p.id)) p.id,
    ]..sort();
  }

  /// The task phase reports itself once it knows its total.
  Future<SyncCheckpoint> _advance(
    SyncCheckpoint checkpoint,
    SyncPhase next, {
    bool report = true,
  }) async {
    final advanced = checkpoint.advanceTo(next);
    await _save(advanced);
    if (report) _report(advanced);
    return advanced;
  }

  Future<void> _save(SyncCheckpoint checkpoint) async {
    _checkDisposed();
    await _db.syncStateDao.write(checkpoint.toState());
    _checkpoint = checkpoint;
  }

  void _report(SyncCheckpoint checkpoint) => _emit(
    SyncRunning(
      phase: checkpoint.phase,
      done: checkpoint.done,
      total: checkpoint.total,
      initial: _lastSyncedAt == null,
    ),
  );

  void _fail(VikunjaFailure failure, SyncCheckpoint checkpoint) {
    _log.warning(
      'Sync run ${checkpoint.runId} failed at ${checkpoint.phase.name}: '
      '${failure.runtimeType}',
    );
    _emit(SyncFailed(failure: failure, lastSyncedAt: _lastSyncedAt));
  }

  void _emit(SyncStatus status) {
    if (_disposed) return;
    _status = status;
    _changes.add(status);
  }

  void _checkDisposed() {
    if (_disposed) throw const _Disposed();
  }

  String _newRunId() {
    final time = _now().toUtc().millisecondsSinceEpoch.toRadixString(36);
    final nonce = _random.nextInt(1 << 32).toRadixString(36);
    return '$time-$nonce';
  }
}

/// Ends a run quietly after `dispose()`.
final class _Disposed implements Exception {
  const new();
}
