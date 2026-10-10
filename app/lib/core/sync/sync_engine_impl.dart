import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/sync/archived_projects.dart';
import 'package:vikunja_mobile/core/sync/incremental_run.dart';
import 'package:vikunja_mobile/core/sync/stable_pages.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/sync/task_filters.dart';

final _log = Logger('SyncEngine');

/// `GET /user`, which the read client does not cover.
typedef CurrentUserSource = Future<User> Function();

/// The sync of one account. A full run goes account → projects → labels →
/// tasks → archived projects' tasks → finishing: tasks are pulled keyset by
/// id (`id > lastId`, sorted by id, one page per request), open ones first,
/// every page is checkpointed in `sync_state` so a killed app resumes where
/// it stopped, and tasks the run did not return are purged at the end. A
/// refresh is an [IncrementalRun] from the stored watermark, unless no full
/// run completed within [fullResyncInterval]. Runs are serialized: a call
/// joins the run in progress, except that a full run asked for during an
/// incremental one follows it.
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

  /// Changes that landed during a run, with the server's commit lag: the
  /// catch-up pass of a full run and the start of an incremental run reach
  /// this far back.
  static const catchUpOverlap = Duration(seconds: 120);

  /// A refresh runs a full pull instead once the last one is this old.
  static const fullResyncInterval = Duration(hours: 24);

  /// How far ahead of the device clock a server `updated` may lie and still
  /// move the watermark: a row from a server whose clock once ran fast would
  /// otherwise put every delta in the future for good.
  static const clockTolerance = Duration(hours: 1);

  /// The watermark of an account without tasks: an incremental run then
  /// asks for everything, which is nothing.
  static final watermarkFloor = DateTime.utc(1970);

  late Future<void> _ready;
  SyncStatus _status = const SyncNeverRun();
  var _restored = false;
  VikunjaFailure? _restoreFailure;
  DateTime? _lastSyncedAt;
  DateTime? _lastFullSyncAt;
  DateTime? _watermark;
  SyncCheckpoint? _checkpoint;
  Future<void>? _current;
  var _currentIsFull = false;
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
    return await _join(() => _runFull(resume: true), full: true);
  }

  @override
  Future<void> refresh() async {
    await _ensureRestored();
    final full = !_canRunIncrementally;
    return await _join(
      full ? () => _runFull(resume: false) : _runIncremental,
      full: full,
    );
  }

  @override
  Future<void> fullResync() async {
    await _ensureRestored();
    return await _join(() => _runFull(resume: false), full: true);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _changes.close();
  }

  /// Not before the first run completed, not from a state written before
  /// incremental sync existed, and not once the last full run is a day old.
  bool get _canRunIncrementally {
    if (_lastSyncedAt == null || _watermark == null) return false;
    final lastFull = _lastFullSyncAt;
    if (lastFull == null) return false;
    return _now().toUtc().difference(lastFull) < fullResyncInterval;
  }

  /// A full run joins only a full run: joining an incremental one would
  /// resolve without the full pull, so it waits for that run instead,
  /// whatever its outcome.
  Future<void> _join(Future<void> Function() start, {required bool full}) {
    if (_current case final running? when !full || _currentIsFull) {
      return running;
    }
    final previous = _current;
    late final Future<void> run;
    run = (previous ?? Future<void>.value())
        .then<void>((_) {}, onError: (Object _) {})
        .then((_) => start())
        .whenComplete(() {
          if (identical(_current, run)) _current = null;
        });
    _current = run;
    _currentIsFull = full;
    return run;
  }

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
      _lastSyncedAt = _stored(state, SyncStateKeys.lastSyncedAt);
      _lastFullSyncAt = _stored(state, SyncStateKeys.lastFullSyncAt);
      _watermark = _stored(state, SyncStateKeys.watermark);
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

  static DateTime? _stored(Map<String, String> state, String key) =>
      DateTime.tryParse(state[key] ?? '')?.toUtc();

  Future<void> _runIncremental() async {
    final runId = _newRunId();
    final run = IncrementalRun(
      db: _db,
      client: _client,
      perPage: _perPage,
      runId: runId,
      since: _watermark!.subtract(catchUpOverlap),
      checkActive: _checkDisposed,
      report: (phase, {done = 0, total}) => _emit(
        SyncRunning(phase: phase, done: done, total: total, initial: false),
      ),
    );
    _log.info('Starting incremental sync run $runId from ${_watermark!}');
    await _guarded(runId, () => run.phase.name, () async {
      await run.execute();
      _checkDisposed();
      final finishedAt = _now().toUtc();
      _emit(
        const SyncRunning(phase: SyncPhase.finishing, done: 0, initial: false),
      );
      await _writeCompletion(finishedAt, full: false);
      _log.info('Sync run $runId done');
      _emit(SyncIdle(lastSyncedAt: finishedAt));
    });
  }

  Future<void> _runFull({required bool resume}) async {
    var checkpoint =
        (resume ? _checkpoint : null) ??
        SyncCheckpoint(runId: _newRunId(), phase: SyncPhase.account);
    _log.info(
      '${resume && _checkpoint != null ? 'Resuming' : 'Starting'} '
      'sync run ${checkpoint.runId} at ${checkpoint.phase.name}',
    );
    await _guarded(checkpoint.runId, () => checkpoint.phase.name, () async {
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
    });
  }

  Future<void> _guarded(
    String runId,
    String Function() phaseName,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } on _Disposed {
      return;
    } on VikunjaFailure catch (failure) {
      _fail(failure, runId, phaseName());
      rethrow;
    } on Object catch (error) {
      // Never a server answer; the type is enough to find the cause.
      _fail(
        UnexpectedResponse(null, message: '${error.runtimeType}'),
        runId,
        phaseName(),
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
    var current = checkpoint;
    final byId = await collectPages<Project>(
      fetch: (page) {
        _checkDisposed();
        return _client.projects.list(
          page: page,
          perPage: _perPage,
          includeArchived: true,
        );
      },
      idOf: (project) => project.id,
      skip: (project) => project.isPseudo,
      onPage: (collected, page) {
        current = current.copyWith(done: collected.length, total: page.total);
        _report(current);
      },
    );
    _checkDisposed();
    await _db.transaction(() async {
      await _db.projectsDao.upsertAll(byId.values);
      await _db.projectsDao.purgeNotIn(byId.keys);
    });
    _log.info('Sync run ${current.runId}: ${byId.length} projects');
    return await _advance(current, SyncPhase.labels);
  }

  Future<SyncCheckpoint> _syncLabels(SyncCheckpoint checkpoint) async {
    var current = checkpoint;
    final byId = await collectPages<Label>(
      fetch: (page) {
        _checkDisposed();
        return _client.labels.list(page: page, perPage: _perPage);
      },
      idOf: (label) => label.id,
      onPage: (collected, page) {
        current = current.copyWith(done: collected.length, total: page.total);
        _report(current);
      },
    );
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
      current = current.copyWith(
        total: await _countTasks(),
        newestUpdatedAtStart: await _newestUpdated(),
      );
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
    final archived = archivedProjectIds(await _db.projectsDao.loadAll());
    for (final projectId in archived) {
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
  /// be purged as gone. Such a change lies above the newest `updated` the
  /// server had when the task phase began, a server time, so the device
  /// clock plays no part. Tasks of archived projects cannot change.
  Future<void> _finish(SyncCheckpoint checkpoint) async {
    _report(checkpoint);
    final since = switch (checkpoint.newestUpdatedAtStart) {
      final newest? => newest.subtract(catchUpOverlap),
      null => watermarkFloor,
    };
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
      await _writeCompletion(finishedAt, full: true);
      return purged;
    });
    _log.info('Sync run ${checkpoint.runId} done, $purged tasks purged');
    _emit(SyncIdle(lastSyncedAt: finishedAt));
  }

  /// The watermark is the newest `updated` the database holds within
  /// [clockTolerance] of the device clock; the next incremental run starts
  /// [catchUpOverlap] below it. An incremental run never lowers it, a full
  /// run sets it afresh, so a value a fast clock once stored goes with the
  /// daily full pull.
  Future<void> _writeCompletion(
    DateTime finishedAt, {
    required bool full,
  }) async {
    final bound = finishedAt.add(clockTolerance);
    final newest = await _db.tasksDao.maxUpdated(notAfter: bound);
    final beyond = await _db.tasksDao.maxUpdated();
    if (beyond != null && beyond.isAfter(bound)) {
      _log.warning(
        'A task updated at $beyond lies ahead of the clock; the watermark '
        'stays below $bound',
      );
    }
    final watermark = [
      if (!full) _watermark,
      newest,
      watermarkFloor,
    ].nonNulls.reduce((a, b) => a.isAfter(b) ? a : b);
    await _db.syncStateDao.write({
      ...SyncCheckpoint.cleared,
      SyncStateKeys.pendingWholePull: null,
      SyncStateKeys.lastSyncedAt: finishedAt.toIso8601String(),
      if (full) SyncStateKeys.lastFullSyncAt: finishedAt.toIso8601String(),
      SyncStateKeys.watermark: watermark.toIso8601String(),
    });
    _lastSyncedAt = finishedAt;
    if (full) _lastFullSyncAt = finishedAt;
    _watermark = watermark;
    _checkpoint = null;
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
      final since? => TaskFilters.updatedSince(since),
      null => checkpoint.doneFilter.filter,
    };
    var current = checkpoint;
    while (true) {
      _checkDisposed();
      final page = await fetch(
        TaskQuery(
          filter: '$filter && ${TaskFilters.after(current.lastId)}',
          sort: TaskFilters.byId,
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

  /// The newest task `updated` the server has: everything that changes from
  /// now on lies above it. Null for an account without live tasks.
  Future<DateTime?> _newestUpdated() async {
    _checkDisposed();
    final page = await _client.tasks.list(
      const TaskQuery(sort: TaskFilters.byUpdatedDescending, perPage: 1),
    );
    return page.items.firstOrNull?.updated;
  }

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

  void _fail(VikunjaFailure failure, String runId, String phaseName) {
    _log.warning(
      'Sync run $runId failed at $phaseName: ${failure.runtimeType}',
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
