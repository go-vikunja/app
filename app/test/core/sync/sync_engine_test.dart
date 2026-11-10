import 'package:drift/drift.dart'
    show
        BatchedStatements,
        QueryExecutor,
        QueryExecutorUser,
        SqlDialect,
        TransactionExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/settings/user_profile_json.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeSyncClient client;
  late DateTime now;
  const me = User(id: 7, username: 'alice', name: 'Alice');
  var settings = const UserSettings(defaultProjectId: 2);
  const urgent = Label(id: 3, title: 'urgent');
  const later = Label(id: 4, title: 'later');

  // Projects 1 and 2 are live, 3 is archived and 4 is a live child of 3, so
  // /tasks leaves the tasks of 3 and 4 out.
  final projects = [
    sampleProject(id: 1, title: 'Work', position: 1),
    sampleProject(id: 2, title: 'Home', position: 2),
    sampleProject(id: 3, title: 'Old', archived: true, position: 3),
    sampleProject(id: 4, title: 'Old child', parent: 3, position: 4),
  ];
  final liveTasks = [
    for (var id = 1; id <= 120; id++)
      sampleTask(
        id: id,
        title: 'Open $id',
        projectId: id.isEven ? 2 : 1,
        labels: id % 5 == 0 ? const [urgent] : const [],
        assignees: id == 5 ? const [me] : const [],
      ),
    for (var id = 121; id <= 150; id++)
      sampleTask(id: id, title: 'Done $id', done: true),
  ];
  final archivedTasks = [
    sampleTask(id: 201, title: 'Archived open', projectId: 3),
    sampleTask(id: 202, title: 'Archived done', projectId: 3, done: true),
    sampleTask(id: 203, title: 'Archived open 2', projectId: 3),
    sampleTask(id: 301, title: 'Child open', projectId: 4),
    sampleTask(id: 302, title: 'Child done', projectId: 4, done: true),
  ];

  DefaultSyncEngine engine({int perPage = 50, bool withUser = true}) {
    final engine = DefaultSyncEngine(
      db: db,
      client: client,
      perPage: perPage,
      currentUser: withUser ? () async => (user: me, settings: settings) : null,
      now: () => now,
    );
    addTearDown(engine.dispose);
    return engine;
  }

  List<SyncStatus> record(DefaultSyncEngine engine) {
    final seen = <SyncStatus>[];
    final subscription = engine.status.listen(seen.add);
    addTearDown(subscription.cancel);
    return seen;
  }

  // The settings every run stores have tests of their own.
  Future<Map<String, String>> state() async =>
      (await db.syncStateDao.readAll())..remove(SyncStateKeys.userSettings);

  setUp(() {
    db = testDatabase();
    now = DateTime.utc(2026, 10, 10, 12);
    settings = const UserSettings(defaultProjectId: 2);
    client = FakeSyncClient()
      ..allProjects = projects
      ..pseudoProjects = [
        const Project(id: Project.favoritesId, title: 'Favorites'),
      ]
      ..allLabels = [urgent, later]
      ..allTasks = [...liveTasks, ...archivedTasks];
  });

  group('initial sync', () {
    test('pulls everything in phases and reports progress', () async {
      final sync = engine();
      final seen = record(sync);

      await sync.ensureInitialSync();

      expect(await db.usersDao.loadAll(), [me]);
      expect((await db.projectsDao.loadAll()).map((p) => p.id), [1, 2, 3, 4]);
      expect(await db.labelsDao.loadAll(), [urgent, later]);
      expect(await db.tasksDao.count(), 155);
      final open = await db.tasksDao.loadOpenTasks();
      expect(open, hasLength(123));
      expect(open.where((t) => t.labels.isNotEmpty), hasLength(24));
      expect(open.singleWhere((t) => t.id == 5).assignees, [me]);
      expect((await projectTasksIn(db, 3)).map((t) => t.id), [203, 202, 201]);
      expect((await projectTasksIn(db, 4)).map((t) => t.id), [302, 301]);

      expect(seen.first, const SyncNeverRun());
      final running = seen.whereType<SyncRunning>().toList();
      expect(running.map((s) => s.phase).toSet(), fullRunPhases);
      expect(running.every((s) => s.initial), isTrue);
      final phases = [for (final s in running) s.phase];
      expect(phases, orderedPhases(phases));
      final tasks = running.where((s) => s.phase == SyncPhase.tasks).toList();
      expect(tasks.map((s) => s.done), [0, 50, 100, 120, 150]);
      expect(tasks.map((s) => s.total), everyElement(150));
      // Single-step phases get the indeterminate bar, not "0 of 1".
      expect(
        running.where((s) => s.phase == SyncPhase.account).map((s) => s.total),
        everyElement(isNull),
      );
      expect(
        running
            .singleWhere((s) => s.phase == SyncPhase.projects && s.done == 4)
            .total,
        4,
      );
      expect(seen.last, SyncIdle(lastSyncedAt: now));
      expect(sync.currentStatus, SyncIdle(lastSyncedAt: now));
      // The sample tasks carry no `updated`, so the watermark is the floor.
      expect(await state(), {
        SyncStateKeys.lastSyncedAt: now.toIso8601String(),
        SyncStateKeys.lastFullSyncAt: now.toIso8601String(),
        SyncStateKeys.watermark: DateTime.utc(1970).toIso8601String(),
      });
    });

    test(
      'pages tasks keyset by id, open first, one page per request',
      () async {
        await engine().ensureInitialSync();

        // The third request finds the newest `updated` the server has up to
        // an hour ahead of the clock, the bound of the last one: the pass
        // over what changed during the run, before the purge. The sample
        // tasks carry none, so the bound is the floor.
        const catchUp = "tasks updated >= '1970-01-01T00:00:00Z' && id > 0";
        const probe =
            "tasks updated <= '2026-10-10T13:00:00Z' sort=updated desc "
            'per_page=1 page=1';
        expect(client.requests.where((r) => r.startsWith('tasks ')), [
          'tasks done = false per_page=1 page=1',
          'tasks done = true per_page=1 page=1',
          probe,
          'tasks done = false && id > 0 per_page=50 page=1',
          'tasks done = false && id > 50 per_page=50 page=1',
          'tasks done = false && id > 100 per_page=50 page=1',
          'tasks done = true && id > 0 per_page=50 page=1',
          '$catchUp per_page=50 page=1',
        ]);
        expect(client.requests.where((r) => r.startsWith('project 3 tasks')), [
          'project 3 tasks done = false && id > 0 per_page=50 page=1',
          'project 3 tasks done = true && id > 0 per_page=50 page=1',
        ]);
        expect(
          client.requests.where((r) => r.startsWith('project 4 tasks')),
          hasLength(2),
        );
        expect(client.requests.where((r) => r.startsWith('projects page')), [
          'projects page 1 archived=true',
        ]);
        expect(client.requests.where((r) => r.startsWith('labels')), [
          'labels page 1',
        ]);
        for (final query in client.tasks.queries.where((q) => q.perPage != 1)) {
          expect(query.sort, const [TaskSort(TaskSortField.id)]);
          expect(query.page, 1);
        }
      },
    );

    test('follows the page size the server applies', () async {
      client = FakeSyncClient(maxPerPage: 20)
        ..allProjects = projects
        ..allLabels = [urgent]
        ..allTasks = liveTasks;

      await engine().ensureInitialSync();

      expect(await db.tasksDao.count(), 150);
      // 120 open tasks fill six pages of 20; the seventh request is empty.
      expect(
        client.requests.where((r) => r.startsWith('tasks done = false &&')),
        hasLength(7),
      );
    });

    test('a page that fills exactly asks once more', () async {
      client.allTasks = [
        for (var id = 1; id <= 100; id++) sampleTask(id: id, title: '$id'),
      ];

      await engine().ensureInitialSync();

      expect(await db.tasksDao.count(), 100);
      expect(
        client.requests.where((r) => r.startsWith('tasks done = false &&')),
        hasLength(3),
      );
    });

    test(
      'without totals from the server only the task count is known',
      () async {
        client = FakeSyncClient(reportsTotal: false)
          ..allProjects = projects
          ..allLabels = [urgent]
          ..allTasks = liveTasks;
        final sync = engine();
        final seen = record(sync);

        await sync.ensureInitialSync();

        final running = seen.whereType<SyncRunning>();
        expect(
          running
              .where((s) => s.phase == SyncPhase.projects)
              .map((s) => s.total),
          everyElement(isNull),
        );
        expect(
          running.where((s) => s.phase == SyncPhase.tasks).map((s) => s.total),
          everyElement(150),
        );
      },
    );

    test('a project deleted between two pages of the list makes the walk '
        'start over instead of taking the shifted one for removed', () async {
      client
        ..allProjects = [
          for (var id = 1; id <= 60; id++)
            sampleProject(id: id, title: 'P$id', position: id.toDouble()),
        ]
        ..allTasks = liveTasks;
      var deleted = false;
      client.beforeRequest = (request) async {
        if (request == 'projects page 2 archived=true' && !deleted) {
          deleted = true;
          client.allProjects = [
            for (final p in client.allProjects)
              if (p.id != 3) p,
          ];
        }
      };

      await engine().ensureInitialSync();

      expect(client.requests.where((r) => r.startsWith('projects page')), [
        'projects page 1 archived=true',
        'projects page 2 archived=true',
        'projects page 1 archived=true',
        'projects page 2 archived=true',
      ]);
      final ids = (await db.projectsDao.loadAll()).map((p) => p.id).toList();
      expect(ids, hasLength(59));
      expect(ids, isNot(contains(3)));
      expect(ids, contains(51));
    });

    test('the account phase stores the user settings', () async {
      settings = const UserSettings(
        defaultProjectId: 2,
        weekStart: 1,
        quickAddMagicMode: QuickAddMagicMode.todoist,
        quickAddDefaultReminders: [Duration(minutes: -30)],
      );

      await engine().ensureInitialSync();

      final stored = await db.syncStateDao.readAll();
      expect(decodeUserSettings(stored[SyncStateKeys.userSettings]), settings);
    });

    test('the account phase stores the profile when the source reads it, '
        'and a source without it leaves the stored one', () async {
      final profile = UserProfile(
        id: me.id,
        username: me.username,
        name: 'Me Renamed',
        isLocalUser: false,
        authProvider: 'ldap',
        updated: now,
        deletionScheduledAt: now.add(const Duration(days: 3)),
      );
      final withProfile = DefaultSyncEngine(
        db: db,
        client: client,
        perPage: 50,
        currentUserWithProfile: () async => (
          user: User(id: me.id, username: me.username, name: 'Me Renamed'),
          profile: profile,
          settings: settings,
        ),
        now: () => now,
      );
      addTearDown(withProfile.dispose);

      await withProfile.ensureInitialSync();
      final stored = await db.syncStateDao.readAll();
      expect(decodeUserProfile(stored[SyncStateKeys.userProfile]), profile);

      await engine().fullResync();
      expect(
        decodeUserProfile(
          (await db.syncStateDao.readAll())[SyncStateKeys.userProfile],
        ),
        profile,
      );
    });

    test('a failing user read fails the run before the projects', () async {
      final sync = DefaultSyncEngine(
        db: db,
        client: client,
        perPage: 50,
        currentUser: () async =>
            throw const NetworkFailure(NetworkProblem.unreachable),
        now: () => now,
      );
      addTearDown(sync.dispose);

      await expectLater(
        sync.ensureInitialSync(),
        throwsA(isA<NetworkFailure>()),
      );

      expect(client.requests, isEmpty);
      expect(
        (await db.syncStateDao.readAll())[SyncStateKeys.userSettings],
        isNull,
      );
    });

    test('works without a current user source', () async {
      await engine(withUser: false).ensureInitialSync();

      expect(await db.usersDao.loadAll(), [me]);
      expect(client.requests.first, 'projects page 1 archived=true');
    });

    test('is a no-op once the account is synced', () async {
      await engine().ensureInitialSync();
      final requests = client.requests.length;

      final again = engine();
      final seen = record(again);
      await again.ensureInitialSync();

      expect(client.requests, hasLength(requests));
      expect(seen, [SyncIdle(lastSyncedAt: now)]);
    });
  });

  group('status stream', () {
    test('replays the restored status and every later one', () async {
      await db.syncStateDao.write({
        SyncStateKeys.lastSyncedAt: '2026-10-09T08:00:00.000Z',
      });
      final sync = engine();
      final early = record(sync);
      await pumpEventQueue();
      final late = record(sync);
      await pumpEventQueue();

      expect(early, [SyncIdle(lastSyncedAt: DateTime.utc(2026, 10, 9, 8))]);
      expect(late, early);
      expect(sync.currentStatus, early.single);

      await sync.refresh();

      expect(early.last, SyncIdle(lastSyncedAt: now));
      expect(late.last, early.last);
      expect(early.whereType<SyncRunning>().every((s) => !s.initial), isTrue);
    });
  });

  group('resume', () {
    test('a failed run keeps its checkpoint and continues there', () async {
      client.beforeRequest = (request) async {
        if (request.startsWith('tasks done = false && id > 50')) {
          throw const NetworkFailure(NetworkProblem.timeout);
        }
      };
      final sync = engine();
      final seen = record(sync);

      await expectLater(
        sync.ensureInitialSync(),
        throwsA(isA<NetworkFailure>()),
      );

      expect(
        seen.last,
        isA<SyncFailed>()
            .having((s) => s.failure, 'failure', isA<NetworkFailure>())
            .having((s) => s.lastSyncedAt, 'lastSyncedAt', isNull),
      );
      expect(await db.tasksDao.count(), 50);
      final checkpoint = SyncCheckpoint.fromState(await state())!;
      expect(checkpoint.phase, SyncPhase.tasks);
      expect(checkpoint.lastId, 50);
      expect(checkpoint.done, 50);
      expect(checkpoint.total, 150);
      final requests = client.requests.length;

      client.beforeRequest = null;
      final resumed = engine();
      final seenResumed = record(resumed);
      await resumed.ensureInitialSync();

      expect(seenResumed.first, const SyncNeverRun());
      expect(
        client.requests.skip(requests).first,
        'tasks done = false && id > 50 per_page=50 page=1',
      );
      expect(
        client.requests.skip(requests).where((r) => r.startsWith('projects')),
        isEmpty,
      );
      expect(seenResumed.whereType<SyncRunning>().take(2).map((s) => s.done), [
        50,
        100,
      ]);
      expect(await db.tasksDao.count(), 155);
      expect(resumed.currentStatus, SyncIdle(lastSyncedAt: now));
      expect(SyncCheckpoint.fromState(await state()), isNull);
    });

    test('a run cut off by dispose resumes with the same run id', () async {
      final gate = RequestGate()..pattern = 'project 3 tasks done = true';
      client.beforeRequest = gate.call;
      final sync = engine();
      final cut = sync.ensureInitialSync();
      while (!gate.isHolding) {
        await pumpEventQueue();
      }
      final before = SyncCheckpoint.fromState(await state())!;
      expect(before.phase, SyncPhase.archivedTasks);
      expect(before.archivedProjectId, 3);

      await sync.dispose();
      gate.release();
      await cut;

      client.beforeRequest = null;
      final requests = client.requests.length;
      await engine().ensureInitialSync();

      final after = client.requests.skip(requests).toList();
      expect(
        after.first,
        'project 3 tasks done = true && id > 0 per_page=50 page=1',
      );
      expect(after.where((r) => r.startsWith('tasks done')), isEmpty);
      expect(await db.tasksDao.count(), 155);
      final ids = (await db.tasksDao.loadOpenTasks()).map((t) => t.id);
      expect(ids, contains(1));
      expect(ids, contains(201));
    });
  });

  group('full resync', () {
    test('re-pulls and purges what the server no longer returns', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      final firstRunId = (await db.select(db.tasks).get()).first.syncRunId;
      client
        ..allProjects = projects.where((p) => p.id != 2).toList()
        ..allLabels = [later]
        ..allTasks = [
          // A deleted label is gone from the tasks that carried it as well.
          for (final task in client.allTasks)
            if (task.id != 10 && task.id != 201 && task.projectId != 2)
              sampleTask(
                id: task.id,
                title: task.title,
                projectId: task.projectId,
                done: task.done,
              ),
          sampleTask(id: 500, title: 'New', labels: const [later]),
        ];
      now = now.add(const Duration(hours: 1));
      final seen = record(sync);

      await sync.fullResync();

      expect((await db.projectsDao.loadAll()).map((p) => p.id), [1, 3, 4]);
      expect(await db.labelsDao.loadAll(), [later]);
      // Project 2 took its 60 tasks (task 10 among them) with it.
      expect(await db.tasksDao.count(), 155 - 60 - 1 + 1);
      expect(await db.tasksDao.find(10), isNull);
      expect(await db.tasksDao.find(201), isNull);
      expect((await db.tasksDao.find(500))!.labels, [later]);
      expect((await db.tasksDao.find(15))!.labels, isEmpty);
      final rows = await db.select(db.tasks).get();
      expect(rows.map((r) => r.syncRunId).toSet(), hasLength(1));
      expect(rows.first.syncRunId, isNot(firstRunId));
      expect(seen.whereType<SyncRunning>().every((s) => !s.initial), isTrue);
      expect(seen.last, SyncIdle(lastSyncedAt: now));
    });

    test(
      'a failure keeps the data and reports the last successful time',
      () async {
        final sync = engine();
        await sync.ensureInitialSync();
        final syncedAt = now;
        now = now.add(const Duration(hours: 1));
        client.beforeRequest = (request) async {
          if (request.startsWith('labels')) throw const ServerFailure(503);
        };
        final seen = record(sync);

        await expectLater(sync.fullResync(), throwsA(isA<ServerFailure>()));

        expect(
          seen.last,
          isA<SyncFailed>()
              .having((s) => s.failure, 'failure', isA<ServerFailure>())
              .having((s) => s.lastSyncedAt, 'lastSyncedAt', syncedAt),
        );
        expect(await db.tasksDao.count(), 155);
        expect(await db.labelsDao.loadAll(), [urgent, later]);
        final checkpoint = SyncCheckpoint.fromState(await state())!;
        expect(checkpoint.phase, SyncPhase.labels);
        expect(
          (await state())[SyncStateKeys.lastSyncedAt],
          syncedAt.toIso8601String(),
        );
      },
    );

    test('concurrent calls join one run', () async {
      final gate = RequestGate()..pattern = 'projects page 1';
      client.beforeRequest = gate.call;
      final sync = engine();

      final first = sync.refresh();
      final second = sync.refresh();
      final third = sync.ensureInitialSync();
      while (!gate.isHolding) {
        await pumpEventQueue();
      }
      gate.release();
      await Future.wait([first, second, third]);

      expect(
        client.requests.where((r) => r.startsWith('projects page')),
        hasLength(1),
      );
      expect(await db.tasksDao.count(), 155);

      client.beforeRequest = null;
      await sync.refresh();
      expect(
        client.requests.where((r) => r.startsWith('projects page')),
        hasLength(2),
      );
    });

    test(
      'a server that ignores the cursor is an unexpected response',
      () async {
        client.tasks.ignoresCursor = true;

        await expectLater(
          engine().ensureInitialSync(),
          throwsA(isA<UnexpectedResponse>()),
        );
        expect(
          client.requests.where((r) => r.startsWith('tasks done = false &&')),
          hasLength(2),
        );
      },
    );

    test('a page not sorted by id is an unexpected response before anything of '
        'it is stored', () async {
      client.tasks.ignoresSort = true;

      await expectLater(
        engine().ensureInitialSync(),
        throwsA(isA<UnexpectedResponse>()),
      );

      expect(await db.tasksDao.count(), 0);
      expect(
        client.requests.where((r) => r.startsWith('tasks done = false &&')),
        hasLength(1),
      );
    });

    test(
      "the catch-up pass is bounded by the server's newest updated, so a "
      'device clock ahead of the server cannot make it miss a flip',
      () async {
        final monday = DateTime.utc(2026, 10, 5, 9);
        client.allTasks = [
          for (final task in client.allTasks)
            sampleTask(
              id: task.id,
              title: task.title,
              projectId: task.projectId,
              done: task.done,
              updated: monday,
            ),
        ];
        // The device clock is five minutes ahead of the server.
        now = DateTime.utc(2026, 10, 10, 12, 5);
        client.beforeRequest = (request) async {
          if (request.startsWith('tasks done = true && id > 0')) {
            client.allTasks = [
              for (final task in client.allTasks)
                if (task.id == 121)
                  sampleTask(
                    id: 121,
                    title: 'Reopened',
                    updated: DateTime.utc(2026, 10, 10, 12, 0, 30),
                  )
                else
                  task,
            ];
          }
        };

        await engine().ensureInitialSync();

        expect(
          client.requests,
          contains(
            "tasks updated >= '2026-10-05T08:58:00Z' && id > 0 "
            'per_page=50 page=1',
          ),
        );
        expect((await db.tasksDao.find(121))!.title, 'Reopened');
        expect(await db.tasksDao.count(), 155);
      },
    );

    test(
      'a task reopened during the run is caught up before the purge',
      () async {
        client.beforeRequest = (request) async {
          // The open pass passed id 121 long ago; by the time the done pass
          // starts, the task is open again, so neither pass returns it.
          if (request.startsWith('tasks done = true && id > 0')) {
            client.allTasks = [
              for (final task in client.allTasks)
                if (task.id == 121)
                  sampleTask(id: 121, title: 'Reopened', updated: now)
                else
                  task,
            ];
          }
        };

        await engine().ensureInitialSync();

        final reopened = (await db.tasksDao.find(121))!;
        expect(reopened.done, isFalse);
        expect(reopened.title, 'Reopened');
        expect(await db.tasksDao.count(), 155);
        expect(
          client.requests.where((r) => r.startsWith('tasks updated >=')),
          hasLength(1),
        );
      },
    );
  });

  group('restore', () {
    test(
      'a database that cannot be read is a failed run until a retry reads it',
      () async {
        final executor = FlakyExecutor(NativeDatabase.memory())..failing = true;
        db = AppDatabase(executor);
        addTearDown(db.close);
        final sync = engine();
        final seen = record(sync);
        await pumpEventQueue();

        expect(seen, [
          isA<SyncFailed>()
              .having((s) => s.failure, 'failure', isA<UnexpectedResponse>())
              .having((s) => s.lastSyncedAt, 'lastSyncedAt', isNull),
        ]);
        expect(sync.currentStatus, isA<SyncFailed>());
        // The call reads the state again before giving up.
        await expectLater(
          sync.ensureInitialSync(),
          throwsA(isA<UnexpectedResponse>()),
        );
        expect(client.requests, isEmpty);
        expect(seen, hasLength(2));
        expect(seen[1], isA<SyncFailed>());

        executor.failing = false;
        await sync.ensureInitialSync();

        expect(seen[2], const SyncNeverRun());
        expect(sync.currentStatus, SyncIdle(lastSyncedAt: now));
        expect(await db.tasksDao.count(), 155);
      },
    );
  });

  test('dispose ends a run quietly', () async {
    final gate = RequestGate()..pattern = 'labels';
    client.beforeRequest = gate.call;
    final sync = engine();
    final seen = record(sync);
    final run = sync.refresh();
    while (!gate.isHolding) {
      await pumpEventQueue();
    }

    await sync.dispose();
    gate.release();
    await run;

    expect(seen.last, isA<SyncRunning>());
    expect(client.requests.where((r) => r.startsWith('tasks')), isEmpty);
  });
}

const Set<SyncPhase> fullRunPhases = {
  SyncPhase.account,
  SyncPhase.projects,
  SyncPhase.labels,
  SyncPhase.tasks,
  SyncPhase.archivedTasks,
  SyncPhase.finishing,
};

/// The phases in the order the engine runs them, with repeats.
List<SyncPhase> orderedPhases(List<SyncPhase> phases) {
  final sorted = List.of(phases)..sort((a, b) => a.index.compareTo(b.index));
  return sorted;
}

/// A database that cannot be opened while [failing] is set.
final class FlakyExecutor extends QueryExecutor {
  new(this._inner);

  final QueryExecutor _inner;
  bool failing = false;

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    if (failing) throw StateError('unreadable database');
    return await _inner.ensureOpen(user);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) => _inner.runSelect(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      _inner.runInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _inner.runUpdate(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _inner.runDelete(statement, args);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _inner.runCustom(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _inner.runBatched(statements);

  @override
  TransactionExecutor beginTransaction() => _inner.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _inner.beginExclusive();

  @override
  Future<void> close() => _inner.close();
}
