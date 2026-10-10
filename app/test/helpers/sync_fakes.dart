import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

/// Replays [current] to every subscriber when it has one, then forwards
/// [updates].
Stream<T> _replaying<T>(T? Function() current, Stream<T> updates) {
  late StreamController<T> controller;
  StreamSubscription<T>? subscription;
  controller = StreamController<T>(
    onListen: () {
      if (current() case final value?) controller.add(value);
      subscription = updates.listen(controller.add, onDone: controller.close);
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}

/// A sync engine whose runs are what the handlers do: nothing by default,
/// a thrown `VikunjaFailure` fails the run, anything else thrown is an
/// `UnexpectedResponse` like in the real engine. A run holds the status at
/// `SyncRunning` until the handler completes; [emit] reports progress. With
/// `restored` false the status stream stays silent until the first [emit],
/// like an engine that has not read its stored state yet.
final class FakeSyncEngine implements SyncEngine {
  new({
    SyncStatus initialStatus = const SyncNeverRun(),
    this._restored = true,
    DateTime Function()? clock,
  }) : _status = initialStatus,
       _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _changes = StreamController<SyncStatus>.broadcast();
  SyncStatus _status;
  bool _restored;
  Future<void>? _running;

  Future<void> Function()? onRefresh;
  Future<void> Function()? onEnsureInitialSync;
  int refreshCalls = 0;
  int ensureInitialSyncCalls = 0;
  bool disposed = false;

  @override
  SyncStatus get currentStatus => _status;

  @override
  Stream<SyncStatus> get status =>
      _replaying(() => _restored ? _status : null, _changes.stream);

  void emit(SyncStatus status) {
    _status = status;
    _restored = true;
    if (!_changes.isClosed) _changes.add(status);
  }

  @override
  Future<void> ensureInitialSync() {
    ensureInitialSyncCalls++;
    if (_status
        case SyncIdle() ||
            SyncRunning(initial: false) ||
            SyncFailed(lastSyncedAt: DateTime())) {
      return Future.value();
    }
    return _run(initial: true, handler: onEnsureInitialSync);
  }

  @override
  Future<void> refresh() {
    refreshCalls++;
    final initial = switch (_status) {
      SyncNeverRun() || SyncFailed(lastSyncedAt: null) => true,
      SyncRunning(:final initial) => initial,
      _ => false,
    };
    return _run(initial: initial, handler: onRefresh);
  }

  Future<void> _run({
    required bool initial,
    required Future<void> Function()? handler,
  }) => _running ??= _runOnce(
    initial: initial,
    handler: handler,
  ).whenComplete(() => _running = null);

  Future<void> _runOnce({
    required bool initial,
    required Future<void> Function()? handler,
  }) async {
    final lastSyncedAt = switch (_status) {
      SyncIdle(:final lastSyncedAt) => lastSyncedAt,
      SyncFailed(:final lastSyncedAt) => lastSyncedAt,
      _ => null,
    };
    emit(SyncRunning(phase: SyncPhase.account, done: 0, initial: initial));
    try {
      await handler?.call();
    } on VikunjaFailure catch (failure) {
      emit(SyncFailed(failure: failure, lastSyncedAt: lastSyncedAt));
      rethrow;
    } on Object catch (error) {
      emit(
        SyncFailed(
          failure: UnexpectedResponse(null, message: '${error.runtimeType}'),
          lastSyncedAt: lastSyncedAt,
        ),
      );
      rethrow;
    }
    emit(SyncIdle(lastSyncedAt: _clock()));
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _changes.close();
  }
}

/// Projects as a local database would hold them; [all] replaces the list for
/// every watcher, like a sync writing the database.
final class FakeProjectRepository implements ProjectRepository {
  new(this._engine);

  final FakeSyncEngine _engine;
  final _changes = StreamController<List<Project>>.broadcast();
  List<Project> _all = const [];
  bool disposed = false;

  List<Project> get all => _all;

  set all(List<Project> projects) {
    _all = List.unmodifiable(projects);
    if (!_changes.isClosed) _changes.add(_all);
  }

  @override
  Stream<List<Project>> watchAll() => _replaying(() => _all, _changes.stream);

  @override
  Future<void> refresh() => _engine.refresh();

  @override
  Project? find(int id) {
    for (final project in _all) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(_changes.close());
  }
}

/// Tasks as a local database would hold them, with the DAO orders: open
/// tasks by due date (nulls last) then newest first, project tasks by
/// position then newest first.
final class FakeTaskRepository implements TaskRepository {
  new(this._engine);

  final FakeSyncEngine _engine;
  final _changes = StreamController<List<Task>>.broadcast();
  List<Task> _all = const [];
  bool disposed = false;

  /// What `watchProjectTasks` reports; a local list never has more.
  bool hasMore = false;
  Future<void> Function()? onLoadMore;
  int loadMoreCalls = 0;

  List<Task> get all => _all;

  set all(List<Task> tasks) {
    _all = List.unmodifiable(tasks);
    if (!_changes.isClosed) _changes.add(_all);
  }

  List<Task> get openTasks {
    final open = [
      for (final task in _all)
        if (!task.done) task,
    ];
    return open..sort((a, b) {
      final byDue = switch ((a.dueDate, b.dueDate)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final a?, final b?) => a.compareTo(b),
      };
      return byDue != 0 ? byDue : b.id.compareTo(a.id);
    });
  }

  List<Task> projectTasks(int projectId, {required bool showDone}) {
    final tasks = [
      for (final task in _all)
        if (task.projectId == projectId && (showDone || !task.done)) task,
    ];
    return tasks..sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0 ? byPosition : b.id.compareTo(a.id);
    });
  }

  @override
  Stream<List<Task>> watchOpenTasks() =>
      _replaying(() => _all, _changes.stream).map((_) => openTasks);

  @override
  Stream<PagedList<Task>> watchProjectTasks(
    int projectId, {
    required bool showDone,
  }) => _replaying(() => _all, _changes.stream).map(
    (_) => PagedList(
      items: projectTasks(projectId, showDone: showDone),
      hasMore: hasMore,
    ),
  );

  @override
  Future<void> refreshOpenTasks() => _engine.refresh();

  @override
  Future<void> refreshProjectTasks(int projectId, {required bool showDone}) =>
      _engine.refresh();

  @override
  Future<void> loadMoreProjectTasks(int projectId, {required bool showDone}) {
    loadMoreCalls++;
    return onLoadMore?.call() ?? Future.value();
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(_changes.close());
  }
}

final class FakeAccountDatabaseFiles implements AccountDatabaseFiles {
  final List<String> deleted = [];

  @override
  Future<String> pathFor(String accountId) async =>
      '/support/accounts/$accountId/vikunja.db';

  @override
  Future<void> deleteFor(String accountId) async => deleted.add(accountId);
}

/// One account's local data: an engine and the repositories over it.
final class AccountDataFakes {
  new({required DateTime now, SyncStatus? status}) {
    engine = FakeSyncEngine(
      initialStatus: status ?? SyncIdle(lastSyncedAt: now),
      clock: () => now,
    );
    projects = FakeProjectRepository(engine);
    tasks = FakeTaskRepository(engine);
  }

  late final FakeSyncEngine engine;
  late final FakeProjectRepository projects;
  late final FakeTaskRepository tasks;
}

/// The data layer under the screens, without a database: every account
/// shares [engine], [projects] and [tasks] unless [accounts] has its own
/// entry. The account starts as synced just now, so the quiet sync at start
/// stays out of the way unless a test asks for it.
final class SyncFakes {
  new({DateTime? now, SyncStatus? status})
    : shared = AccountDataFakes(now: now ?? DateTime.now(), status: status);

  final AccountDataFakes shared;
  final accounts = <String, AccountDataFakes>{};
  final files = FakeAccountDatabaseFiles();

  FakeSyncEngine get engine => shared.engine;
  FakeProjectRepository get projects => shared.projects;
  FakeTaskRepository get tasks => shared.tasks;

  AccountDataFakes forAccount(String accountId) =>
      accounts[accountId] ?? shared;

  List<Override> get overrides => [
    accountDatabaseFilesProvider.overrideWithValue(files),
    syncEngineProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).engine,
    ),
    accountProjectRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).projects,
    ),
    accountTaskRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).tasks,
    ),
  ];
}
