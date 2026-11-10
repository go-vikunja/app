import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/settings/current_user_store.dart';
import 'package:vikunja_mobile/core/sync/archived_projects.dart';
import 'package:vikunja_mobile/core/sync/incremental_run.dart';
import 'package:vikunja_mobile/core/sync/list_downloads.dart';
import 'package:vikunja_mobile/core/sync/newest_updated.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/stable_pages.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/sync/task_filters.dart';

final _log = Logger('SyncEngine');

/// `GET /user`, which the read client does not cover.
typedef CurrentUserSource = Future<UserWithSettings> Function();

/// The same read with the profile, which a run then stores too.
typedef CurrentProfileSource = Future<UserWithProfile> Function();

typedef _CurrentUser = ({
  User user,
  UserProfile? profile,
  UserSettings settings,
});

/// The sync of one account. Every run first stores the current user, their
/// settings and profile (`GET /user`). A full run goes account → projects →
/// labels → tasks → archived projects' tasks → finishing: tasks are pulled
/// keyset by id (`id > lastId`, sorted by id, one page per request), open
/// ones first, every page is checkpointed in `sync_state` so a killed app
/// resumes where it stopped, and tasks the run did not return are purged at
/// the end, after the Overview's saved filter is downloaded
/// (`downloadOverviewFilter`). A refresh is an [IncrementalRun] from the
/// stored watermark, unless no full run completed within
/// [fullResyncInterval]. Runs are serialized: a call joins the run in
/// progress, except that a full run asked for during an incremental one
/// follows it, and so does a refresh after a write.
///
/// Engines of the same account in other isolates (a background run, a
/// notification action) share the database, so a run first takes the
/// account's lease in `sync_state` and renews it as it goes: a full run
/// purges every task it did not mark, and would otherwise delete the ones
/// another run marked meanwhile. The app's engine waits for a lease
/// another isolate holds, a [headless] one ends its run without syncing;
/// the winner adopts the stored state the other run left. A run that finds
/// its lease taken (it stalled past [leaseDuration]) stops quietly, and
/// purges nothing.
///
/// The first status event arrives once the stored state has been read; the
/// stream replays the current status to every subscriber after that.
final class DefaultSyncEngine implements SyncEngine {
  new({
    required this._db,
    required this._client,
    required int perPage,
    CurrentUserSource? currentUser,
    CurrentProfileSource? currentUserWithProfile,
    DateTime Function()? now,
    this.headless = false,
    Future<void> Function(Duration duration)? delay,
  }) : _perPage = perPage,
       _currentUser = _currentUserOf(currentUserWithProfile, currentUser),
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed {
    if (perPage < 1) throw ArgumentError.value(perPage, 'perPage');
    _ready = _restore();
  }

  final AppDatabase _db;
  final VikunjaReadClient _client;
  final int _perPage;
  final Future<_CurrentUser> Function()? _currentUser;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _delay;

  /// In a container the OS started without the app: a refresh is always
  /// incremental once a run has completed, because a background run has
  /// seconds to minutes and the daily full pull would start over every
  /// time (the app runs it when it is in front), and a run another isolate
  /// holds is not waited for.
  final bool headless;
  final _random = Random();
  late final String _leaseOwner = _newRunId();
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

  /// Longer than any gap between two renewals (a page request with its
  /// timeouts); a lease past it belongs to a run that died.
  static const leaseDuration = Duration(minutes: 3);

  /// How often the app's engine looks again while another isolate syncs.
  static const leasePoll = Duration(seconds: 2);

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
  var _currentStarted = false;
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
    return await _join(
      () => _leased(
        () async => _lastSyncedAt == null ? await _runFull(resume: true) : null,
      ),
      full: true,
    );
  }

  /// What a run stored in another isolate meanwhile is adopted with the
  /// lease; a full pull that became due while waiting for it runs instead.
  @override
  Future<void> refresh() => _refresh(afterWrite: false);

  @override
  Future<void> refreshAfterWrite() => _refresh(afterWrite: true);

  Future<void> _refresh({required bool afterWrite}) async {
    await _ensureRestored();
    final full = !_canRunIncrementally;
    return await _join(
      () => _leased(
        () => full || !_canRunIncrementally
            ? _runFull(resume: false)
            : _runIncremental(),
      ),
      full: full,
      afterWrite: afterWrite,
    );
  }

  @override
  Future<void> fullResync() async {
    await _ensureRestored();
    return await _join(
      () => _leased(() => _runFull(resume: false)),
      full: true,
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _changes.close();
  }

  /// Not before the first run completed, not from a state written before
  /// incremental sync existed, and, unless [headless], not once the last
  /// full run is a day old.
  bool get _canRunIncrementally {
    if (_lastSyncedAt == null || _watermark == null) return false;
    final lastFull = _lastFullSyncAt;
    if (lastFull == null) return false;
    return headless || _now().toUtc().difference(lastFull) < fullResyncInterval;
  }

  Future<void> _leased(Future<void> Function() run) async {
    try {
      if (!await _acquireLease()) return;
    } on _Disposed {
      return;
    }
    try {
      await run();
    } finally {
      await _releaseLease();
    }
  }

  /// False when a [headless] engine finds the lease held elsewhere.
  Future<bool> _acquireLease() async {
    var waited = false;
    while (true) {
      _checkDisposed();
      final taken = await _db.transaction(() async {
        final state = await _db.syncStateDao.readAll();
        if (_heldElsewhere(state)) return false;
        await _db.syncStateDao.write(_leaseState());
        _adopt(state);
        return true;
      });
      if (taken) return true;
      if (headless) {
        _log.info('Another sync of this account is running; not this one');
        return false;
      }
      if (!waited) _log.info('Waiting for a sync of this account elsewhere');
      waited = true;
      await _delay(leasePoll);
    }
  }

  /// Inside the transaction of a write that belongs to the run: renews the
  /// lease, or ends the run when another one has taken it.
  Future<void> _holdLease() async {
    final state = await _db.syncStateDao.readAll();
    if (_heldElsewhere(state)) throw const _LeaseLost();
    await _db.syncStateDao.write(_leaseState());
  }

  Future<void> _releaseLease() async {
    try {
      await _db.transaction(() async {
        final state = await _db.syncStateDao.readAll();
        if (_SyncLease.parse(state[SyncStateKeys.syncLease])?.owner !=
            _leaseOwner) {
          return;
        }
        await _db.syncStateDao.write({SyncStateKeys.syncLease: null});
      });
    } on Object catch (error) {
      // Disposed with its database: the lease runs out by itself.
      _log.fine('Sync lease not released: ${error.runtimeType}');
    }
  }

  /// A lease further ahead than one [leaseDuration] was written by a clock
  /// that has gone back since, and counts as run out.
  bool _heldElsewhere(Map<String, String> state) {
    final lease = _SyncLease.parse(state[SyncStateKeys.syncLease]);
    if (lease == null || lease.owner == _leaseOwner) return false;
    final now = _now().toUtc();
    return lease.until.isAfter(now) &&
        !lease.until.isAfter(now.add(leaseDuration));
  }

  Map<String, String> _leaseState() => {
    SyncStateKeys.syncLease: _SyncLease(
      owner: _leaseOwner,
      until: _now().toUtc().add(leaseDuration),
    ).encode(),
  };

  /// The state as the last run of any isolate left it.
  void _adopt(Map<String, String> state) {
    _lastSyncedAt = _stored(state, SyncStateKeys.lastSyncedAt);
    _lastFullSyncAt = _stored(state, SyncStateKeys.lastFullSyncAt);
    _watermark = _stored(state, SyncStateKeys.watermark);
    _checkpoint = SyncCheckpoint.fromState(state);
  }

  /// A full run joins only a full run: joining an incremental one would
  /// resolve without the full pull, so it waits for that run instead,
  /// whatever its outcome. [afterWrite] joins only a run that has not
  /// started yet.
  Future<void> _join(
    Future<void> Function() start, {
    required bool full,
    bool afterWrite = false,
  }) {
    if (_current case final running?
        when (!full || _currentIsFull) && !(afterWrite && _currentStarted)) {
      return running;
    }
    final previous = _current;
    late final Future<void> run;
    run = (previous ?? Future<void>.value())
        .then<void>((_) {}, onError: (Object _) {})
        .then((_) {
          if (identical(_current, run)) _currentStarted = true;
          return start();
        })
        .whenComplete(() {
          if (identical(_current, run)) _current = null;
        });
    _current = run;
    _currentIsFull = full;
    _currentStarted = false;
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

  /// [withProfile] wins; [withoutProfile] leaves the stored profile alone.
  static Future<_CurrentUser> Function()? _currentUserOf(
    CurrentProfileSource? withProfile,
    CurrentUserSource? withoutProfile,
  ) {
    if (withProfile != null) {
      return () async {
        final (:user, :profile, :settings) = await withProfile();
        return (user: user, profile: profile, settings: settings);
      };
    }
    if (withoutProfile != null) {
      return () async {
        final (:user, :settings) = await withoutProfile();
        return (user: user, profile: null, settings: settings);
      };
    }
    return null;
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
      now: _now,
      checkActive: _checkDisposed,
      keepLease: () => _db.transaction(_holdLease),
      report: (phase, {done = 0, total}) => _emit(
        SyncRunning(phase: phase, done: done, total: total, initial: false),
      ),
      newestUpdated: _newestUpdatedTracker(),
    );
    _log.info('Starting incremental sync run $runId from ${_watermark!}');
    await _guarded(runId, () => run.phase.name, () async {
      if (_currentUser != null) {
        _emit(
          const SyncRunning(phase: SyncPhase.account, done: 0, initial: false),
        );
        await _storeCurrentUser();
      }
      await run.execute();
      _checkDisposed();
      final finishedAt = _now().toUtc();
      _emit(
        const SyncRunning(phase: SyncPhase.finishing, done: 0, initial: false),
      );
      await _db.transaction(() async {
        await _holdLease();
        await _writeCompletion(
          finishedAt,
          full: false,
          newest: run.newestUpdated,
        );
      });
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
    } on _LeaseLost {
      _log.info('Sync run $runId stopped: another run took over');
      _emit(switch (_lastSyncedAt) {
        final at? => SyncIdle(lastSyncedAt: at),
        null => const SyncNeverRun(),
      });
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
    await _storeCurrentUser();
    return await _advance(checkpoint, SyncPhase.projects);
  }

  /// The user joins the known people, so `@me` resolves offline; the
  /// settings and the profile change on the web at any time, so every run
  /// reads them. What is unchanged is not written, so the lists on screen
  /// are not reloaded.
  Future<void> _storeCurrentUser() async {
    final currentUser = _currentUser;
    if (currentUser == null) return;
    final (:user, :profile, :settings) = await currentUser();
    _checkDisposed();
    await storeCurrentUser(
      _db,
      user: user,
      settings: settings,
      profile: profile,
    );
  }

  /// All pages, archived projects included, in one list; the pseudo projects
  /// (Favorites, saved filters) repeat on every page and are not stored as
  /// projects, only the saved filters' names.
  Future<SyncCheckpoint> _syncProjects(SyncCheckpoint checkpoint) async {
    var current = checkpoint;
    final pseudo = <Project>[];
    final byId = await collectPages<Project>(
      fetch: (page) async {
        _checkDisposed();
        // A walk that starts over starts at page 1.
        if (page == 1) pseudo.clear();
        await _db.transaction(_holdLease);
        return await _client.projects.list(
          page: page,
          perPage: _perPage,
          includeArchived: true,
        );
      },
      idOf: (project) => project.id,
      skip: (project) {
        if (project.isPseudo) pseudo.add(project);
        return project.isPseudo;
      },
      onPage: (collected, page) {
        current = current.copyWith(done: collected.length, total: page.total);
        _report(current);
      },
    );
    _checkDisposed();
    await _db.transaction(() async {
      await _db.projectsDao.upsertAll(byId.values);
      await _db.projectsDao.purgeNotIn(byId.keys);
      await _db.kanbanDao.removeGoneViews();
      await storeSavedFilters(_db, savedFiltersIn(pseudo));
    });
    _log.info('Sync run ${current.runId}: ${byId.length} projects');
    await fetchSavedFilterDefinitions(
      db: _db,
      client: _client,
      runId: current.runId,
      request: (send) async {
        _checkDisposed();
        await _db.transaction(_holdLease);
        return await send();
      },
    );
    _checkDisposed();
    return await _advance(current, SyncPhase.labels);
  }

  Future<SyncCheckpoint> _syncLabels(SyncCheckpoint checkpoint) async {
    var current = checkpoint;
    final byId = await collectPages<Label>(
      fetch: (page) async {
        _checkDisposed();
        await _db.transaction(_holdLease);
        return await _client.labels.list(page: page, perPage: _perPage);
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
  /// clock plays no part. Tasks of archived projects cannot change. That
  /// newest `updated` is also the watermark, not what the pass reads: it
  /// walks by id, so a later page can lie above an edit to an id it has
  /// passed, or one made before a resumed pass started.
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
    final newest = _newestUpdatedTracker()
      ..addAll([checkpoint.newestUpdatedAtStart]);
    await downloadOverviewFilter(
      db: _db,
      client: _client,
      perPage: _perPage,
      runId: checkpoint.runId,
      now: _now,
      request: (send) async {
        _checkDisposed();
        await _db.transaction(_holdLease);
        return await send();
      },
    );
    _checkDisposed();
    final finishedAt = _now().toUtc();
    final purged = await _db.transaction(() async {
      await _holdLease();
      final purged = await _db.tasksDao.purgeNotInRun(caughtUp.runId);
      await _writeCompletion(finishedAt, full: true, newest: newest);
      return purged;
    });
    _log.info('Sync run ${checkpoint.runId} done, $purged tasks purged');
    _emit(SyncIdle(lastSyncedAt: finishedAt));
  }

  NewestUpdated _newestUpdatedTracker() =>
      NewestUpdated(now: _now, tolerance: clockTolerance);

  /// The watermark is the [newest] `updated` the run read on `GET /tasks`
  /// in `(updated, id)` order, for a full run the newest when its task
  /// phase began; the next incremental run starts [catchUpOverlap] below
  /// it. An incremental run never lowers it, a full run sets it afresh, so
  /// a value a fast clock once stored goes with the daily full pull.
  Future<void> _writeCompletion(
    DateTime finishedAt, {
    required bool full,
    required NewestUpdated newest,
  }) async {
    if (newest.aheadOfClock case final ahead?) {
      _log.warning(
        'A task updated at $ahead lies ahead of the clock; the watermark '
        'leaves it out',
      );
    }
    final watermark = [
      if (!full) _watermark,
      newest.value,
      watermarkFloor,
    ].nonNulls.reduce((a, b) => a.isAfter(b) ? a : b);
    await _db.syncStateDao.write({
      ...SyncCheckpoint.cleared,
      SyncStateKeys.pendingWholePull: null,
      SyncStateKeys.lastSyncedAt: finishedAt.toIso8601String(),
      if (full) SyncStateKeys.lastFullSyncAt: finishedAt.toIso8601String(),
      if (full) SyncStateKeys.unexplainedTotals: null,
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
          expand: TaskFilters.commentState,
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
      await _db.tasksDao.upsertAll(
        items,
        syncRunId: current.runId,
        withCommentState: true,
      );
      current = current.copyWith(
        lastId: previousId,
        done: current.done + items.length,
      );
      await _save(current);
      if (report) _report(current);
      if (items.length < page.perPage && !page.hasMore) return current;
    }
  }

  /// The newest task `updated` the server has within [clockTolerance] of
  /// the device clock: everything that changes from now on lies above it.
  /// A row further ahead, from a server clock that once ran fast, would put
  /// the catch-up pass and the watermark above every real change. Null for
  /// an account without such live tasks.
  Future<DateTime?> _newestUpdated() async {
    _checkDisposed();
    final page = await _client.tasks.list(
      TaskQuery(
        filter: TaskFilters.updatedUntil(_now().toUtc().add(clockTolerance)),
        sort: TaskFilters.byUpdatedDescending,
        perPage: 1,
      ),
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
    await _db.transaction(() async {
      await _holdLease();
      await _db.syncStateDao.write(checkpoint.toState());
    });
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

/// Ends a run quietly whose lease another run took.
final class _LeaseLost implements Exception {
  const new();
}

final class _SyncLease {
  const new({required this.owner, required this.until});

  final String owner;
  final DateTime until;

  static _SyncLease? parse(String? raw) {
    if (raw == null) return null;
    try {
      if (jsonDecode(raw) case {
        'owner': final String owner,
        'until': final String until,
      }) {
        final at = DateTime.tryParse(until);
        if (at != null) return _SyncLease(owner: owner, until: at.toUtc());
      }
    } on FormatException {
      // Falls through: an unreadable lease holds nothing.
    }
    return null;
  }

  String encode() =>
      jsonEncode({'owner': owner, 'until': until.toIso8601String()});
}
