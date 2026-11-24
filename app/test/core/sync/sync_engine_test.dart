import 'dart:async';

import 'package:drift/drift.dart'
    show
        BatchedStatements,
        QueryExecutor,
        QueryExecutorUser,
        SqlDialect,
        TableUpdateQuery,
        TransactionExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/settings/user_profile_json.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/incremental_run.dart';
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

  void archiveOnServer(int id) => client.allProjects = [
    for (final p in client.allProjects)
      if (p.id == id) p.copyWith(isArchived: true) else p,
  ];

  FakeSyncClient withoutPageCount() =>
      FakeSyncClient(reportsTotal: false, reportsPageCount: false)
        ..allProjects = [
          for (var id = 1; id <= 60; id++)
            sampleProject(
              id: id,
              title: 'P$id',
              archived: id == 57,
              position: id.toDouble(),
            ),
        ]
        ..pseudoProjects = [
          const Project(id: Project.favoritesId, title: 'Favorites'),
        ]
        ..allLabels = [
          for (var id = 101; id <= 160; id++) Label(id: id, title: 'L$id'),
        ]
        ..allTasks = [
          for (final task in liveTasks) task.copyWith(labels: const []),
          sampleTask(id: 5701, title: 'Archived 57', projectId: 57),
          sampleTask(
            id: 5702,
            title: 'Archived 57 done',
            projectId: 57,
            done: true,
          ),
        ];

  List<Task> openTasks(int count) => [
    for (var id = 1; id <= count; id++) sampleTask(id: id, title: '$id'),
  ];

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

    test('without a page count from the server every page of projects and '
        'labels is stored, an archived project past the first page with its '
        'tasks', () async {
      client = withoutPageCount();

      await engine().ensureInitialSync();

      expect(await db.projectsDao.loadAll(), hasLength(60));
      expect(await db.labelsDao.loadAll(), hasLength(60));
      expect(await db.tasksDao.countInProject(57), 2);
      expect(await db.tasksDao.count(), 152);
      // The third pages bring no new id: no more than the Favorites.
      expect(client.requests.where((r) => r.startsWith('projects page')), [
        'projects page 1 archived=true',
        'projects page 2 archived=true',
        'projects page 3 archived=true',
      ]);
      expect(client.requests.where((r) => r.startsWith('labels')), [
        'labels page 1',
        'labels page 2',
        'labels page 3',
      ]);
      expect(
        client.requests.where((r) => r.startsWith('tasks done = false &&')),
        [
          'tasks done = false && id > 0 per_page=50 page=1',
          'tasks done = false && id > 50 per_page=50 page=1',
          'tasks done = false && id > 100 per_page=50 page=1',
          'tasks done = false && id > 120 per_page=50 page=1',
        ],
      );
      expect(
        client.requests.where((r) => r.startsWith('tasks done = true &&')),
        [
          'tasks done = true && id > 0 per_page=50 page=1',
          'tasks done = true && id > 150 per_page=50 page=1',
        ],
      );
      expect(client.requests.where((r) => r.startsWith('project 57 tasks')), [
        'project 57 tasks done = false && id > 0 per_page=50 page=1',
        'project 57 tasks done = false && id > 5701 per_page=50 page=1',
        'project 57 tasks done = true && id > 0 per_page=50 page=1',
        'project 57 tasks done = true && id > 5702 per_page=50 page=1',
      ]);
    });

    test('a page of more tasks than a slice is stored and checkpointed slice '
        'by slice', () async {
      client = FakeSyncClient(maxPerPage: 1200)
        ..allProjects = projects
        ..allLabels = [urgent]
        ..allTasks = openTasks(1200);
      final sync = engine(perPage: 1200);
      final seen = record(sync);

      await sync.ensureInitialSync();

      expect(await db.tasksDao.count(), 1200);
      expect(
        seen
            .whereType<SyncRunning>()
            .where((s) => s.phase == SyncPhase.tasks)
            .map((s) => s.done),
        [0, 500, 1000, 1200],
      );
      expect(
        client.requests.where((r) => r.startsWith('tasks done = false &&')),
        [
          'tasks done = false && id > 0 per_page=1200 page=1',
          'tasks done = false && id > 1200 per_page=1200 page=1',
        ],
      );
    });

    test('a page of more tasks than one statement takes variables is stored, '
        'so the first sync completes', () async {
      client = FakeSyncClient(maxPerPage: 40000)
        ..allProjects = projects
        ..allLabels = [urgent]
        ..allTasks = openTasks(32767);
      final sync = engine(perPage: 40000);

      await sync.ensureInitialSync();

      expect(sync.currentStatus, SyncIdle(lastSyncedAt: now));
      expect(await db.tasksDao.count(), 32767);
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

    test('a project archived on the web during the first sync is read whole '
        'by the next sync', () async {
      client.beforeRequest = (request) async {
        if (request.startsWith('tasks done = false && id > 0')) {
          archiveOnServer(2);
        }
      };
      final sync = engine();
      await sync.ensureInitialSync();
      expect(await db.tasksDao.countInProject(2), 0);
      client.requests.clear();

      await sync.refresh();

      expect(client.requests.where((r) => r.startsWith('project 2 tasks')), [
        'project 2 tasks id > 0 per_page=50 page=1',
        'project 2 tasks id > 100 per_page=50 page=1',
      ]);
      expect(await db.tasksDao.countInProject(2), 60);
      expect(await db.tasksDao.count(), 155);
    });

    test('an archived project deleted since the project list goes with its '
        'tasks, and the run completes', () async {
      client.beforeRequest = (request) async {
        if (request.startsWith('project 3 tasks')) {
          client
            ..allProjects = projects.take(2).toList()
            ..allTasks = liveTasks;
        }
      };
      final sync = engine();

      await sync.ensureInitialSync();

      expect((await db.projectsDao.loadAll()).map((p) => p.id), [1, 2]);
      expect(await db.tasksDao.count(), 150);
      expect(await projectTasksIn(db, 3), isEmpty);
      expect(await projectTasksIn(db, 4), isEmpty);
      expect(
        client.requests.where((r) => r.startsWith('project 3 tasks')),
        hasLength(1),
      );
      expect(
        client.requests.where((r) => r.startsWith('project 4 tasks')),
        hasLength(1),
      );
      expect(sync.currentStatus, SyncIdle(lastSyncedAt: now));
      expect(SyncCheckpoint.fromState(await state()), isNull);
    });

    test('an archived project unshared since the project list goes the same '
        'way; a child still shared is pulled', () async {
      client.beforeRequest = (request) async {
        if (request.startsWith('project 3 tasks')) {
          client.forbiddenProjects.add(3);
        }
      };
      final sync = engine();

      await sync.ensureInitialSync();

      expect((await db.projectsDao.loadAll()).map((p) => p.id), [1, 2, 4]);
      expect(await db.tasksDao.findAll([201, 202, 203]), isEmpty);
      expect((await db.tasksDao.findAll([301, 302])).keys, {301, 302});
      expect(sync.currentStatus, SyncIdle(lastSyncedAt: now));
    });

    test('an archived project whose task list answers not found without a '
        'code fails the run and keeps the project', () async {
      client.beforeRequest = (request) async {
        if (request.startsWith('project 3 tasks')) throw const NotFound();
      };

      await expectLater(engine().ensureInitialSync(), throwsA(isA<NotFound>()));

      expect((await db.projectsDao.loadAll()).map((p) => p.id), contains(3));
      final checkpoint = SyncCheckpoint.fromState(await state())!;
      expect(checkpoint.phase, SyncPhase.archivedTasks);
      expect(checkpoint.archivedProjectId, 3);
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

    test('without a count from the server the task phase shows no total, and '
        'a resumed run neither counts nor probes again', () async {
      client = withoutPageCount()
        ..beforeRequest = (request) async {
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

      final tasks = seen.whereType<SyncRunning>().where(
        (s) => s.phase == SyncPhase.tasks,
      );
      expect(tasks.map((s) => s.done), [0, 50]);
      expect(tasks.map((s) => s.total), everyElement(isNull));
      final requests = client.requests.length;

      client.beforeRequest = null;
      final resumed = engine();
      final seenResumed = record(resumed);
      await resumed.ensureInitialSync();

      expect(
        client.requests.skip(requests).first,
        'tasks done = false && id > 50 per_page=50 page=1',
      );
      final resumedTasks = seenResumed.whereType<SyncRunning>().where(
        (s) => s.phase == SyncPhase.tasks,
      );
      expect(resumedTasks.map((s) => s.done), contains(100));
      expect(resumedTasks.map((s) => s.total), everyElement(isNull));
      expect(resumed.currentStatus, SyncIdle(lastSyncedAt: now));
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

    test('a run stopped inside a page resumes after the last slice it '
        'stored', () async {
      client = FakeSyncClient(maxPerPage: 1200)
        ..allProjects = projects
        ..allLabels = [urgent]
        ..allTasks = openTasks(1200);
      final sync = engine(perPage: 1200);
      final subscription = sync.status.listen((status) {
        if (status is SyncRunning &&
            status.phase == SyncPhase.tasks &&
            status.done == 500) {
          scheduleMicrotask(() => unawaited(sync.dispose()));
        }
      });
      addTearDown(subscription.cancel);

      await sync.ensureInitialSync();

      final checkpoint = SyncCheckpoint.fromState(await state())!;
      expect(checkpoint.lastId, 500);
      expect(checkpoint.done, 500);
      final requests = client.requests.length;

      await engine(perPage: 1200).ensureInitialSync();

      expect(
        client.requests
            .skip(requests)
            .firstWhere((r) => r.startsWith('tasks ')),
        'tasks done = false && id > 500 per_page=1200 page=1',
      );
      expect(await db.tasksDao.count(), 1200);
      expect(SyncCheckpoint.fromState(await state()), isNull);
    });

    test('a first sync stopped in an archived project deleted since '
        'completes on Retry', () async {
      client.beforeRequest = (request) async {
        if (request.startsWith('project 3 tasks done = true')) {
          throw const NetworkFailure(NetworkProblem.timeout);
        }
      };
      await expectLater(
        engine().ensureInitialSync(),
        throwsA(isA<NetworkFailure>()),
      );
      expect((await db.tasksDao.findAll([201, 203])).keys, {201, 203});
      client
        ..beforeRequest = null
        ..allProjects = projects.take(2).toList()
        ..allTasks = liveTasks;
      final requests = client.requests.length;

      final resumed = engine();
      await resumed.ensureInitialSync();

      final after = client.requests.skip(requests).toList();
      expect(
        after.first,
        'project 3 tasks done = true && id > 0 per_page=50 page=1',
      );
      expect(after.where((r) => r.startsWith('projects page')), isEmpty);
      expect(await db.tasksDao.findAll([201, 203]), isEmpty);
      expect(await db.tasksDao.count(), 150);
      expect(resumed.currentStatus, SyncIdle(lastSyncedAt: now));
      expect(SyncCheckpoint.fromState(await state()), isNull);
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

    test('without a page count keeps the projects and labels past the first '
        'page and still purges the ones the server no longer has', () async {
      client = withoutPageCount();
      final sync = engine();
      await sync.ensureInitialSync();
      client
        ..allProjects = [
          for (final p in client.allProjects)
            if (p.id != 7) p,
        ]
        ..allLabels = [
          for (final label in client.allLabels)
            if (label.id != 107) label,
        ];
      now = now.add(const Duration(hours: 1));

      await sync.fullResync();

      final ids = (await db.projectsDao.loadAll()).map((p) => p.id).toSet();
      expect(ids, hasLength(59));
      expect(ids, isNot(contains(7)));
      expect(ids, containsAll([for (var id = 51; id <= 60; id++) id]));
      final labels = (await db.labelsDao.loadAll()).map((l) => l.id).toSet();
      expect(labels, hasLength(59));
      expect(labels, isNot(contains(107)));
    });

    test('without a page count projects deleted between two pages leave the '
        'ones that move up into the first page alone, with their '
        'tasks', () async {
      client = withoutPageCount();
      final sync = engine();
      await sync.ensureInitialSync();
      // Seven projects of the first page go while the second is asked for,
      // so 51 to 57 move up into the page already read.
      client.beforeRequest = (request) async {
        if (request == 'projects page 2 archived=true' &&
            client.allProjects.any((p) => p.id == 5)) {
          client.allProjects = [
            for (final p in client.allProjects)
              if (p.id < 5 || p.id > 11) p,
          ];
        }
      };
      now = now.add(const Duration(hours: 1));

      await sync.fullResync();

      final ids = (await db.projectsDao.loadAll()).map((p) => p.id).toSet();
      expect(ids, containsAll([for (var id = 51; id <= 57; id++) id]));
      expect(await db.tasksDao.countInProject(57), 2);
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

  group('daily full run', () {
    const fullPull = 'tasks done = false && id > 0 ';

    Future<int> countTaskWrites(Future<void> Function() body) async {
      var writes = 0;
      final subscription = db
          .tableUpdates(TableUpdateQuery.onAllTables([db.tasks]))
          .listen((_) => writes++);
      addTearDown(subscription.cancel);
      await body();
      await pumpEventQueue();
      return writes;
    }

    /// The daily full run stops after its first page of open tasks.
    Future<void> stopAfterFirstPage(DefaultSyncEngine sync) async {
      now = now.add(const Duration(days: 1, hours: 1));
      client.beforeRequest = (request) async {
        if (request.startsWith(RegExp('tasks done = false && id > [1-9]'))) {
          throw const NetworkFailure(NetworkProblem.timeout);
        }
      };
      await expectLater(sync.refresh(), throwsA(isA<NetworkFailure>()));
      client.beforeRequest = null;
    }

    /// The daily full run stops after the first page of its catch-up pass.
    Future<void> stopInCatchUp(DefaultSyncEngine sync) async {
      now = now.add(const Duration(days: 1, hours: 1));
      client.beforeRequest = (request) async {
        if (request.startsWith(
          RegExp("^tasks updated >= '[^']+' && id > [1-9]"),
        )) {
          throw const NetworkFailure(NetworkProblem.timeout);
        }
      };
      await expectLater(sync.refresh(), throwsA(isA<NetworkFailure>()));
      client.beforeRequest = null;
    }

    void moveOnServer(Set<int> ids, {required int to}) => client.allTasks = [
      for (final task in client.allTasks)
        if (ids.contains(task.id)) task.copyWith(projectId: to) else task,
    ];

    test('a run that finds nothing new writes no task, and keeps them all '
        'for the purge', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      now = now.add(const Duration(days: 1, hours: 1));

      final writes = await countTaskWrites(sync.refresh);

      expect(writes, 0);
      expect(await db.tasksDao.count(), 155);
      final runs = (await db.select(db.tasks).get())
          .map((row) => row.syncRunId)
          .toSet();
      expect(runs, hasLength(1));
      expect(
        DateTime.parse((await state())[SyncStateKeys.lastFullSyncAt]!),
        now,
      );
    });

    test('a changed task is written', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      client.allTasks = [
        for (final task in client.allTasks)
          if (task.id == 7) sampleTask(id: 7, title: 'Renamed') else task,
      ];
      now = now.add(const Duration(days: 1, hours: 1));

      final writes = await countTaskWrites(sync.refresh);

      expect(writes, greaterThan(0));
      expect((await db.tasksDao.find(7))!.title, 'Renamed');
    });

    test('related tasks the server nests without identifier, comment count '
        'and unread flag leave an unchanged pair alone; a removed relation '
        'is written', () async {
      Task nested(int id) => Task(
        id: id,
        title: 'Open $id',
        projectId: id.isEven ? 2 : 1,
        index: id,
      );
      List<Task> related({required bool withRelation}) => [
        for (final task in client.allTasks)
          switch (task.id) {
            13 => task.copyWith(
              commentCount: 2,
              isUnread: true,
              relatedTasks: {
                if (withRelation) TaskRelationKind.subtask: [nested(14)],
              },
            ),
            14 => task.copyWith(
              commentCount: 1,
              relatedTasks: {
                if (withRelation) TaskRelationKind.parentTask: [nested(13)],
              },
            ),
            _ => task,
          },
      ];
      client.allTasks = related(withRelation: true);
      final sync = engine();
      await sync.ensureInitialSync();
      now = now.add(const Duration(days: 1, hours: 1));

      expect(await countTaskWrites(sync.refresh), 0);
      final parent = (await db.tasksDao.find(13))!;
      expect(parent.relatedTasks[TaskRelationKind.subtask]!.single.id, 14);

      client.allTasks = related(withRelation: false);
      now = now.add(const Duration(days: 1, hours: 1));
      expect(await countTaskWrites(sync.refresh), greaterThan(0));
      expect((await db.tasksDao.find(13))!.relatedTasks, isEmpty);
      expect((await db.tasksDao.find(14))!.relatedTasks, isEmpty);
    });

    test('a refresh the user starts stays incremental when the full run is '
        'due; the next timed refresh runs it', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      final firstFull = (await state())[SyncStateKeys.lastFullSyncAt];
      now = now.add(const Duration(days: 1, hours: 1));
      final requests = client.requests.length;

      await sync.refreshInNewRun();
      await sync.refreshAfterWrite();

      final after = client.requests.skip(requests);
      expect(after.where((r) => r.startsWith(fullPull)), isEmpty);
      expect((await state())[SyncStateKeys.lastFullSyncAt], firstFull);
      expect(DateTime.parse((await state())[SyncStateKeys.lastSyncedAt]!), now);

      await sync.refresh();
      expect(
        client.requests.skip(requests).where((r) => r.startsWith(fullPull)),
        hasLength(1),
      );
    });

    test('a last full run that lies ahead of a clock set back since is '
        'due', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      now = now.subtract(const Duration(hours: 2));
      final requests = client.requests.length;

      await sync.refresh();

      expect(
        client.requests.skip(requests).where((r) => r.startsWith(fullPull)),
        hasLength(1),
      );
      expect(
        DateTime.parse((await state())[SyncStateKeys.lastFullSyncAt]!),
        now,
      );
    });

    test('a write during a full run queues an incremental run, so '
        'everything is pulled once', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      now = now.add(const Duration(days: 1, hours: 1));
      final requests = client.requests.length;
      final gate = RequestGate()..pattern = 'projects page 1';
      client.beforeRequest = gate.call;

      final full = sync.refresh();
      while (!gate.isHolding) {
        await pumpEventQueue();
      }
      final queued = sync.refresh();
      final afterWrite = sync.refreshAfterWrite();
      client.beforeRequest = null;
      gate.release();
      await Future.wait([full, queued, afterWrite]);

      expect(
        client.requests.skip(requests).where((r) => r.startsWith(fullPull)),
        hasLength(1),
      );
    });

    test('a stopped full run continues from its checkpoint, also after an '
        'incremental run', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      await stopAfterFirstPage(sync);
      await sync.refreshInNewRun();
      expect(SyncCheckpoint.fromState(await state())?.lastId, 50);
      final requests = client.requests.length;

      await sync.refresh();

      final after = client.requests.skip(requests).toList();
      expect(after.where((r) => r.startsWith('projects')), isEmpty);
      expect(
        after.where((r) => r.startsWith('tasks done = false')).first,
        'tasks done = false && id > 50 per_page=50 page=1',
      );
      expect(await db.tasksDao.count(), 155);
      expect(SyncCheckpoint.fromState(await state()), isNull);
    });

    test('a stopped daily full run resumes past an archived project unshared '
        'since, instead of failing until another sync runs', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      await stopAfterFirstPage(sync);
      client.forbiddenProjects.add(3);

      await sync.refresh();

      expect(
        DateTime.parse((await state())[SyncStateKeys.lastFullSyncAt]!),
        now,
      );
      expect(SyncCheckpoint.fromState(await state()), isNull);
      expect((await db.projectsDao.loadAll()).map((p) => p.id), [1, 2, 4]);
      expect(await db.tasksDao.findAll([201, 202, 203]), isEmpty);
      expect(await db.tasksDao.count(), 152);
    });

    test('a project shared or un-archived meanwhile has a stopped full run '
        'start over, so its tasks below the cursor stay', () async {
      // Open tasks 10 and 12 lie in the archived project 3, and 20 and 22
      // in project 5, which is not shared yet.
      moveOnServer({10, 12}, to: 3);
      moveOnServer({20, 22}, to: 5);
      final unshared = client.allTasks;
      client.allTasks = [
        for (final task in unshared)
          if (task.projectId != 5) task,
      ];
      final sync = engine();
      await sync.ensureInitialSync();
      await stopAfterFirstPage(sync);
      client
        ..allProjects = [
          for (final project in projects)
            if (project.id == 3)
              project.copyWith(isArchived: false)
            else
              project,
          sampleProject(id: 5, title: 'Shared', position: 5),
        ]
        ..allTasks = unshared;
      await sync.refreshInNewRun();
      expect(SyncCheckpoint.fromState(await state()), isNull);

      await sync.refresh();

      expect(await db.tasksDao.findAll([10, 12, 20, 22]), hasLength(4));
      expect(await db.tasksDao.count(), 155);
    });

    test('a project no longer archived through its parent has a stopped '
        'full run start over too', () async {
      // Open tasks 10 and 12 lie in project 4, a child of the archived 3.
      moveOnServer({10, 12}, to: 4);
      final sync = engine();
      await sync.ensureInitialSync();
      await stopAfterFirstPage(sync);
      // Project 3 is no longer shared; its child 4 still is.
      client
        ..allProjects = [
          for (final project in projects)
            if (project.id != 3) project,
        ]
        ..allTasks = [
          for (final task in client.allTasks)
            if (task.projectId != 3) task,
        ];
      await sync.refreshInNewRun();

      await sync.refresh();

      expect(await db.tasksDao.findAll([10, 12]), hasLength(2));
    });

    test('a project un-archived in the app has a stopped full run start '
        'over too', () async {
      moveOnServer({10, 12}, to: 3);
      final sync = engine();
      await sync.ensureInitialSync();
      await stopAfterFirstPage(sync);
      client.allProjects = [
        for (final project in projects)
          if (project.id == 3) project.copyWith(isArchived: false) else project,
      ];
      // What the project repository stores from the server's answer.
      await db.transaction(() async {
        final cascaded = await db.projectsDao.setArchived(3, archived: false);
        await pullWholeOnNextRun(db, cascaded);
      });

      await sync.refresh();

      expect(await db.tasksDao.findAll([10, 12]), hasLength(2));
    });

    test('a project archived on the web during the run is read whole by the '
        'next sync, which brings back the tasks the run purged', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      now = now.add(const Duration(days: 1, hours: 1));
      client.beforeRequest = (request) async {
        if (request.startsWith('tasks done = false && id > 50')) {
          archiveOnServer(2);
        }
      };

      await sync.refresh();
      expect(await db.tasksDao.countInProject(2), 25);

      await sync.refreshInNewRun();

      expect(await db.tasksDao.countInProject(2), 60);
      expect(await db.tasksDao.count(), 155);
    });

    test('a project archived on the web has a stopped full run start over '
        'too, so the tasks its task phase no longer saw stay', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      now = now.add(const Duration(days: 1, hours: 1));
      client.beforeRequest = (request) async {
        if (request.startsWith('tasks done = false && id > 50')) {
          archiveOnServer(2);
        }
        if (request.startsWith('tasks updated >=')) {
          throw const NetworkFailure(NetworkProblem.timeout);
        }
      };
      await expectLater(sync.refresh(), throwsA(isA<NetworkFailure>()));
      expect(
        SyncCheckpoint.fromState(await state())?.phase,
        SyncPhase.finishing,
      );
      expect(await db.tasksDao.countInProject(2), 60);
      client.beforeRequest = null;
      await sync.refreshInNewRun();
      expect(SyncCheckpoint.fromState(await state()), isNull);

      await sync.refresh();

      expect(
        DateTime.parse((await state())[SyncStateKeys.lastFullSyncAt]!),
        now,
      );
      expect(await db.tasksDao.countInProject(2), 60);
      expect(await db.tasksDao.count(), 155);
      expect(SyncCheckpoint.fromState(await state()), isNull);
    });

    test('a resumed full run keeps the watermark of the incremental runs '
        'since it began', () async {
      client.allTasks = [
        for (final task in client.allTasks)
          if (task.id == 1)
            task.copyWith(updated: now.subtract(const Duration(days: 2)))
          else
            task,
      ];
      final sync = engine();
      await sync.ensureInitialSync();
      await stopAfterFirstPage(sync);
      now = now.add(const Duration(minutes: 10));
      final edited = now.subtract(const Duration(minutes: 1));
      client.allTasks = [
        for (final task in client.allTasks)
          if (task.id == 7)
            task.copyWith(title: 'Renamed', updated: edited)
          else
            task,
      ];
      await sync.refreshInNewRun();
      expect(DateTime.parse((await state())[SyncStateKeys.watermark]!), edited);

      await sync.refresh();

      expect(SyncCheckpoint.fromState(await state()), isNull);
      expect(DateTime.parse((await state())[SyncStateKeys.watermark]!), edited);
    });

    test('a resumed full run keeps a task an incremental run stored below its '
        'catch-up cursor, and the relation edits that name it', () async {
      final updated = now.subtract(const Duration(minutes: 1));
      client.allTasks = [
        for (final task in client.allTasks) task.copyWith(updated: updated),
      ];
      final sync = engine();
      await sync.ensureInitialSync();
      await stopInCatchUp(sync);
      final stopped = SyncCheckpoint.fromState(await state());
      expect((stopped?.phase, stopped?.lastId), (SyncPhase.finishing, 50));
      now = now.add(const Duration(minutes: 10));
      client.allTasks = [
        for (final task in client.allTasks)
          if (task.id == 7)
            task.copyWith(
              title: 'Renamed',
              updated: now.subtract(const Duration(minutes: 1)),
            )
          else
            task,
      ];
      await sync.refreshInNewRun();
      final relation = RelationChange(
        added: {const TaskRelationRef(TaskRelationKind.related, 7)},
      );
      await db.outboxDao.queueUpdate(
        8,
        TaskChanges(relations: relation),
        now: now,
      );

      await sync.refresh();

      expect(SyncCheckpoint.fromState(await state()), isNull);
      expect((await db.tasksDao.find(7))!.title, 'Renamed');
      final queued = decodeTaskChanges(
        (await db.tasksDao.findRow(8))!.pendingChanges!,
      );
      expect(
        queued.relations?.added,
        contains(const TaskRelationRef(TaskRelationKind.related, 7)),
      );
      expect(await db.tasksDao.count(), 155);
    });

    test('a resumed full run keeps a task whose unread flag an incremental run '
        'stored while it was stopped', () async {
      client.allTasks = [
        for (final task in client.allTasks)
          if (task.id == 7)
            task.copyWith(updated: now.subtract(const Duration(minutes: 1)))
          else
            task,
      ];
      final sync = engine();
      await sync.ensureInitialSync();
      // The stopped run's catch-up pass then starts above task 7.
      client.allTasks = [
        for (final task in client.allTasks)
          if (task.id == 9)
            task.copyWith(
              title: 'Renamed',
              updated: now.add(const Duration(days: 1)),
            )
          else
            task,
      ];
      await stopAfterFirstPage(sync);
      final stopped = SyncCheckpoint.fromState(await state());
      expect((stopped?.phase, stopped?.lastId), (SyncPhase.tasks, 50));
      now = now.add(const Duration(minutes: 10));
      client.allTasks = [
        for (final task in client.allTasks)
          if (task.id == 7) task.copyWith(isUnread: true) else task,
      ];
      await sync.refreshInNewRun();
      expect((await db.tasksDao.find(7))!.isUnread, isTrue);

      await sync.refresh();

      expect(SyncCheckpoint.fromState(await state()), isNull);
      expect((await db.tasksDao.find(7))!.isUnread, isTrue);
      expect(await db.tasksDao.count(), 155);
    });

    test('a full run stopped more than a day ago starts over', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      await stopAfterFirstPage(sync);
      now = now.add(const Duration(days: 1, hours: 1));
      final requests = client.requests.length;

      await sync.refresh();

      final after = client.requests.skip(requests);
      expect(after.where((r) => r.startsWith('projects page')), isNotEmpty);
      expect(after.where((r) => r.startsWith(fullPull)), hasLength(1));
      expect(await db.tasksDao.count(), 155);
    });
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
