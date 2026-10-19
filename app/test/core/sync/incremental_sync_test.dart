import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/sync/task_filters.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeSyncClient client;
  late DateTime now;
  // `GET /user` carries the email, which is not stored: an unchanged user
  // must not count as a change.
  const me = User(
    id: 7,
    username: 'alice',
    name: 'Alice',
    email: 'alice@example.com',
  );
  var settings = const UserSettings(defaultProjectId: 2);
  const urgent = Label(id: 3, title: 'urgent');
  const later = Label(id: 4, title: 'later');
  // Everything was last changed at 9:00 except task 30 at 9:30, the
  // watermark; the changes under test happen at 12:00, server time.
  final base = DateTime.utc(2026, 10, 10, 9);
  final newest = DateTime.utc(2026, 10, 10, 9, 30);
  final edited = DateTime.utc(2026, 10, 10, 12);
  const since = "updated >= '2026-10-10T09:28:00Z'";

  Project project({
    required int id,
    required String title,
    int parent = 0,
    bool archived = false,
    DateTime? updated,
  }) => Project(
    id: id,
    title: title,
    parentProjectId: parent,
    position: id.toDouble(),
    isArchived: archived,
    updated: updated ?? base,
  );

  Task task({
    required int id,
    required String title,
    int projectId = 1,
    bool done = false,
    List<Label> labels = const [],
    DateTime? updated,
  }) => sampleTask(
    id: id,
    title: title,
    projectId: projectId,
    done: done,
    labels: labels,
    updated: updated ?? base,
  );

  // Projects 1 and 2 are live, 3 is archived and 4 is a live child of 3.
  // Project 1 holds the odd task ids up to 29 and the done tasks, 2 the
  // even ones; every fifth task is urgent, every seventh later.
  List<Project> projects() => [
    project(id: 1, title: 'Work'),
    project(id: 2, title: 'Home'),
    project(id: 3, title: 'Old', archived: true),
    project(id: 4, title: 'Old child', parent: 3),
  ];
  List<Task> tasks() => [
    for (var id = 1; id <= 30; id++)
      task(
        id: id,
        title: 'Task $id',
        projectId: id.isEven ? 2 : 1,
        labels: [if (id % 5 == 0) urgent, if (id % 7 == 0) later],
        updated: id == 30 ? newest : null,
      ),
    for (var id = 31; id <= 35; id++)
      task(id: id, title: 'Done $id', done: true),
    task(id: 201, title: 'Archived 201', projectId: 3),
    task(id: 202, title: 'Archived 202', projectId: 3, done: true),
    task(id: 301, title: 'Child 301', projectId: 4),
  ];
  const taskCount = 38;

  void replaceTask(
    int id, {
    String? title,
    int? projectId,
    bool? done,
    List<Label>? labels,
    DateTime? updated,
  }) {
    client.allTasks = [
      for (final t in client.allTasks)
        if (t.id == id)
          task(
            id: id,
            title: title ?? t.title,
            projectId: projectId ?? t.projectId,
            done: done ?? t.done,
            labels: labels ?? t.labels,
            updated: updated ?? edited,
          )
        else
          t,
    ];
  }

  void replaceProject(
    int id, {
    bool? archived,
    DateTime? updated,
    bool remove = false,
  }) {
    client.allProjects = [
      for (final p in client.allProjects)
        if (p.id != id)
          p
        else if (!remove)
          project(
            id: id,
            title: p.title,
            parent: p.parentProjectId,
            archived: archived ?? p.isArchived,
            updated: updated ?? edited,
          ),
    ];
  }

  /// A task edit bumps its project on the server.
  void touchProjects(List<int> ids) => ids.forEach(replaceProject);

  DefaultSyncEngine engine({int perPage = 50}) {
    final engine = DefaultSyncEngine(
      db: db,
      client: client,
      perPage: perPage,
      currentUser: () async => (user: me, settings: settings),
      now: () => now,
    );
    addTearDown(engine.dispose);
    return engine;
  }

  /// An engine whose account was pulled at 12:00; the refresh under test
  /// runs an hour later.
  Future<DefaultSyncEngine> synced({int perPage = 50}) async {
    final sync = engine(perPage: perPage);
    await sync.ensureInitialSync();
    client.requests.clear();
    client.tasks.queries.clear();
    now = DateTime.utc(2026, 10, 10, 13);
    return sync;
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

  Iterable<String> requestsFor(String prefix) =>
      client.requests.where((r) => r.startsWith(prefix));

  List<LogRecord> captureLog() {
    final records = <LogRecord>[];
    Logger.root.level = Level.ALL;
    addTearDown(() => Logger.root.level = Level.INFO);
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    return records;
  }

  /// What a refresh that finds nothing costs.
  const quietRun = [
    'projects page 1 archived=true',
    'labels page 1',
    'tasks $since per_page=50 page=1',
    'tasks (all) per_page=1 page=1',
  ];

  setUp(() {
    db = testDatabase();
    now = DateTime.utc(2026, 10, 10, 12);
    settings = const UserSettings(defaultProjectId: 2);
    client = FakeSyncClient()
      ..allProjects = projects()
      ..pseudoProjects = [
        const Project(id: Project.favoritesId, title: 'Favorites'),
      ]
      ..allLabels = [urgent, later]
      ..allTasks = tasks();
  });

  test('the initial sync stores the watermark and the full-run time', () async {
    await engine().ensureInitialSync();

    expect(await state(), {
      SyncStateKeys.lastSyncedAt: now.toIso8601String(),
      SyncStateKeys.lastFullSyncAt: now.toIso8601String(),
      SyncStateKeys.watermark: newest.toIso8601String(),
    });
  });

  group('refresh', () {
    test('pulls edits and new tasks from below the watermark and probes the '
        'live count once', () async {
      final sync = await synced();
      replaceTask(3, title: 'Task 3 edited');
      client.allTasks.add(
        task(id: 500, title: 'New', projectId: 2, updated: edited),
      );
      touchProjects([1, 2]);
      final seen = record(sync);

      await sync.refresh();

      expect((await db.tasksDao.find(3))!.title, 'Task 3 edited');
      expect((await db.tasksDao.find(500))!.projectId, 2);
      expect(await db.tasksDao.count(), taskCount + 1);
      expect(client.requests, [
        'projects page 1 archived=true',
        'labels page 1',
        'tasks $since per_page=50 page=1',
        'tasks (all) per_page=1 page=1',
      ]);
      final delta = client.tasks.queries.singleWhere(
        (q) => q.filter?.startsWith('updated') ?? false,
      );
      expect(delta.sort, TaskFilters.byUpdatedThenId);
      expect(delta.page, 1);
      final running = seen.whereType<SyncRunning>().toList();
      expect(running.every((s) => !s.initial), isTrue);
      expect(running.map((s) => s.phase).toSet(), {
        SyncPhase.account,
        SyncPhase.projects,
        SyncPhase.labels,
        SyncPhase.delta,
        SyncPhase.reconcile,
        SyncPhase.finishing,
      });
      final indices = [for (final s in running) s.phase.index];
      expect(indices, List.of(indices)..sort());
      // Task 30 from the overlap, the edit and the new task.
      expect(
        running.where((s) => s.phase == SyncPhase.delta).map((s) => s.done),
        [0, 3],
      );
      expect(
        running
            .where((s) => s.phase == SyncPhase.reconcile)
            .map((s) => (s.done, s.total)),
        [(0, 0)],
      );
      expect(seen.last, SyncIdle(lastSyncedAt: now));
      expect(await state(), {
        SyncStateKeys.lastSyncedAt: now.toIso8601String(),
        SyncStateKeys.lastFullSyncAt: DateTime.utc(
          2026,
          10,
          10,
          12,
        ).toIso8601String(),
        SyncStateKeys.watermark: edited.toIso8601String(),
      });
    });

    test('without changes it costs four requests, which are logged', () async {
      final sync = await synced();
      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      addTearDown(() => Logger.root.level = Level.INFO);
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final before = await db.tasksDao.loadOpenTasks();

      await sync.refresh();

      expect(client.requests, [
        'projects page 1 archived=true',
        'labels page 1',
        'tasks $since per_page=50 page=1',
        'tasks (all) per_page=1 page=1',
      ]);
      expect(await db.tasksDao.loadOpenTasks(), before);
      expect(
        records.where((r) => r.level == Level.FINE).map((r) => r.message),
        contains(endsWith(': 4 requests')),
      );
      expect(
        (await state())[SyncStateKeys.watermark],
        newest.toIso8601String(),
      );
    });

    test('reads the user and the settings again first', () async {
      final sync = await synced();
      settings = const UserSettings(
        quickAddMagicMode: QuickAddMagicMode.disabled,
        quickAddDefaultReminders: [Duration(hours: -1)],
      );
      final seen = record(sync);

      await sync.refresh();

      final stored = await db.syncStateDao.readAll();
      expect(decodeUserSettings(stored[SyncStateKeys.userSettings]), settings);
      expect(client.requests, quietRun);
      expect(
        seen.whereType<SyncRunning>().first,
        const SyncRunning(phase: SyncPhase.account, done: 0, initial: false),
      );
    });

    test('a failing user read fails the refresh before the projects', () async {
      final sync = DefaultSyncEngine(
        db: db,
        client: client,
        perPage: 50,
        currentUser: () async =>
            throw const NetworkFailure(NetworkProblem.timeout),
        now: () => now,
      );
      addTearDown(sync.dispose);
      await engine().ensureInitialSync();
      client.requests.clear();
      now = DateTime.utc(2026, 10, 10, 13);

      await expectLater(sync.refresh(), throwsA(isA<NetworkFailure>()));

      expect(client.requests, isEmpty);
      expect(sync.currentStatus, isA<SyncFailed>());
    });

    test('reports the projects phase before its first request', () async {
      final sync = await synced();
      final gate = RequestGate()..pattern = 'projects page 1';
      SyncStatus? atFirstRequest;
      client.beforeRequest = (request) {
        atFirstRequest ??= sync.currentStatus;
        return gate.call(request);
      };

      final run = sync.refresh();
      while (!gate.isHolding) {
        await pumpEventQueue();
      }

      const started = SyncRunning(
        phase: SyncPhase.projects,
        done: 0,
        initial: false,
      );
      expect(sync.currentStatus, started);
      expect(atFirstRequest, started);
      gate.release();
      await run;
    });

    test('without changes nothing is written, so the lists on screen are '
        'not reloaded', () async {
      final sync = await synced();
      var projectLoads = 0;
      var labelLoads = 0;
      var taskLoads = 0;
      final subscriptions = [
        db.projectsDao.watchAll().listen((_) => projectLoads++),
        db.labelsDao.watchAll().listen((_) => labelLoads++),
        db.tasksDao.watchOpenTasks().listen((_) => taskLoads++),
      ];
      addTearDown(() async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      });
      while (projectLoads + labelLoads + taskLoads < 3) {
        await pumpEventQueue();
      }

      await sync.refresh();
      await pumpEventQueue(times: 50);

      expect(client.requests, quietRun);
      expect((projectLoads, labelLoads, taskLoads), (1, 1, 1));
    });

    test(
      'a favourite toggle, which bumps no updated, is still written',
      () async {
        final sync = await synced();
        client.allProjects = [
          for (final p in client.allProjects)
            if (p.id == 1)
              Project(
                id: 1,
                title: p.title,
                position: p.position,
                isFavorite: true,
                updated: p.updated,
              )
            else
              p,
        ];

        await sync.refresh();

        final work = (await db.projectsDao.loadAll()).singleWhere(
          (p) => p.id == 1,
        );
        expect(work.isFavorite, isTrue);
      },
    );

    // An update answer lists the reminders from before the server merged
    // those a date change put on one instant, with the `updated` of the
    // stored task.
    test('reminders the server merged without a newer updated replace the '
        'local ones', () async {
      final sync = await synced();
      const onTheDay = TaskReminder(relativeTo: ReminderRelativeTo.dueDate);
      const dayBefore = TaskReminder(
        relativePeriod: Duration(days: -1),
        relativeTo: ReminderRelativeTo.dueDate,
      );
      final answered = sampleTask(
        id: 30,
        title: 'Task 30',
        projectId: 2,
        reminders: const [onTheDay, dayBefore],
        updated: newest,
      );
      await db.tasksDao.upsertAll([answered]);
      client.allTasks = [
        for (final t in client.allTasks)
          if (t.id == 30)
            sampleTask(
              id: 30,
              title: 'Task 30',
              projectId: 2,
              reminders: const [dayBefore],
              updated: newest,
            )
          else
            t,
      ];

      await sync.refresh();

      expect((await db.tasksDao.find(30))!.reminders, [dayBefore]);
    });

    test('continues a page boundary inside one second by id', () async {
      final sync = await synced(perPage: 4);
      for (var id = 1; id <= 10; id++) {
        replaceTask(id, title: 'Edited $id');
      }
      touchProjects([1, 2]);

      await sync.refresh();

      // Task 30 from the overlap comes first, the ten edits share a second.
      const tie =
          "(updated > '2026-10-10T12:00:00Z') || "
          "(updated > '2026-10-10T11:59:59Z' && id > ";
      expect(requestsFor('tasks'), [
        'tasks $since per_page=4 page=1',
        'tasks ${tie}3) per_page=4 page=1',
        'tasks ${tie}7) per_page=4 page=1',
        'tasks (all) per_page=1 page=1',
      ]);
      for (var id = 1; id <= 10; id++) {
        expect((await db.tasksDao.find(id))!.title, 'Edited $id');
      }
      expect(await db.tasksDao.count(), taskCount);
    });

    test('a moved task changes its project without a reconcile', () async {
      final sync = await synced();
      replaceTask(5, projectId: 2);
      touchProjects([1, 2]);

      await sync.refresh();

      expect((await db.tasksDao.find(5))!.projectId, 2);
      expect(
        (await projectTasksIn(db, 1)).map((t) => t.id),
        isNot(contains(5)),
      );
      expect(await db.tasksDao.countInProject(2), 16);
      expect(requestsFor('project '), isEmpty);
    });

    test(
      'a new project is pulled whole, old task timestamps included',
      () async {
        final sync = await synced();
        client
          ..allProjects.add(project(id: 9, title: 'Fresh', updated: edited))
          ..allTasks.addAll([
            task(id: 901, title: 'Fresh 901', projectId: 9),
            task(id: 902, title: 'Fresh 902', projectId: 9, done: true),
          ]);

        await sync.refresh();

        expect((await db.projectsDao.loadAll()).map((p) => p.id), [
          1,
          2,
          3,
          4,
          9,
        ]);
        expect((await projectTasksIn(db, 9)).map((t) => t.id), [902, 901]);
        expect(requestsFor('project 9 tasks'), [
          'project 9 tasks id > 0 per_page=50 page=1',
        ]);
      },
    );

    test('an un-archived project is pulled whole', () async {
      final sync = await synced();
      replaceProject(3, archived: false);
      client.allTasks.add(task(id: 203, title: 'Archived 203', projectId: 3));

      await sync.refresh();

      final old = (await db.projectsDao.loadAll()).singleWhere(
        (p) => p.id == 3,
      );
      expect(old.isArchived, isFalse);
      expect((await projectTasksIn(db, 3)).map((t) => t.id), [203, 202, 201]);
      expect(requestsFor('project 3 tasks'), [
        'project 3 tasks id > 0 per_page=50 page=1',
      ]);
      expect(requestsFor('project 4 tasks'), isEmpty);
    });

    test('a new archived project left behind by a failed run is pulled '
        'whole by the next one', () async {
      final sync = await synced();
      client
        ..allProjects.add(
          project(
            id: 9,
            title: 'Shared archived',
            archived: true,
            updated: edited,
          ),
        )
        ..allTasks.addAll([
          task(id: 901, title: 'Old 901', projectId: 9),
          task(id: 902, title: 'Old 902', projectId: 9, done: true),
        ])
        ..beforeRequest = (request) async {
          if (request.startsWith('tasks')) {
            throw const NetworkFailure(NetworkProblem.timeout);
          }
        };
      await expectLater(sync.refresh(), throwsA(isA<NetworkFailure>()));
      expect((await state())[SyncStateKeys.pendingWholePull], '9');
      expect(await db.tasksDao.countInProject(9), 0);
      client
        ..beforeRequest = null
        ..requests.clear();

      await sync.refresh();

      expect((await projectTasksIn(db, 9)).map((t) => t.id), [902, 901]);
      expect(requestsFor('project 9 tasks'), [
        'project 9 tasks id > 0 per_page=50 page=1',
      ]);
      expect(await state(), isNot(contains(SyncStateKeys.pendingWholePull)));
    });

    test(
      'an archived project that changed gets its delta through the project',
      () async {
        final sync = await synced();
        replaceTask(201, title: 'Archived edited');
        touchProjects([3]);

        await sync.refresh();

        expect((await db.tasksDao.find(201))!.title, 'Archived edited');
        expect(requestsFor('project 3 tasks'), [
          'project 3 tasks $since per_page=50 page=1',
        ]);
        expect(requestsFor('tasks'), [
          'tasks $since per_page=50 page=1',
          'tasks (all) per_page=1 page=1',
        ]);
      },
    );

    test('a task edited and its project archived inside the second the last '
        'sync saw it get the delta through the project', () async {
      // Project 2 was live and last touched in the watermark's second; the
      // edit and the archive follow inside that second, after the list was
      // fetched, so its `updated` stays.
      replaceProject(2, updated: newest);
      final sync = await synced();
      replaceTask(2, title: 'Edited late', updated: newest);
      replaceProject(2, archived: true, updated: newest);

      await sync.refresh();

      expect((await db.tasksDao.find(2))!.title, 'Edited late');
      expect(requestsFor('project 2 tasks'), [
        'project 2 tasks $since per_page=50 page=1',
      ]);
    });

    test('archiving a parent takes its children along: they get the delta '
        'too', () async {
      // Project 4 is the child of 3; both become live, then 3 is archived
      // again after an edit in 4.
      replaceProject(3, archived: false, updated: base);
      final sync = await synced();
      replaceTask(301, title: 'Child edited');
      replaceProject(3, archived: true);

      await sync.refresh();

      expect((await db.tasksDao.find(301))!.title, 'Child edited');
      expect(requestsFor('project 4 tasks'), [
        'project 4 tasks $since per_page=50 page=1',
      ]);
    });

    test('after a project was archived, a quiet refresh costs the usual four '
        'requests', () async {
      final sync = await synced();
      replaceProject(2, archived: true);
      await sync.refresh();
      expect(requestsFor('project 2 tasks'), [
        'project 2 tasks $since per_page=50 page=1',
      ]);
      client.requests.clear();

      await sync.refresh();

      expect(client.requests, quietRun);
    });

    test('a removed project goes with its tasks', () async {
      final sync = await synced();
      replaceProject(2, remove: true);
      client.allTasks.removeWhere((t) => t.projectId == 2);

      await sync.refresh();

      expect((await db.projectsDao.loadAll()).map((p) => p.id), [1, 3, 4]);
      expect(await db.tasksDao.count(), taskCount - 15);
      expect(await db.tasksDao.find(10), isNull);
      expect(requestsFor('project '), isEmpty);
    });

    test('the downloads of views that are gone go, in an incremental and in '
        'a full run', () async {
      Project work(List<ProjectView> views) => Project(
        id: 1,
        title: 'Work',
        position: 1,
        updated: base,
        views: views,
      );
      final list = sampleListView(id: 10, projectId: 1);
      final board = sampleKanbanView(id: 11, projectId: 1);
      client.allProjects = [
        work([list, board]),
        ...projects().skip(1),
      ];
      final sync = await synced();
      Future<void> download() async {
        await db.listSnapshotsDao.replace('view:10', {1: 1}, loadedAt: now);
        await db.kanbanDao.replaceBoard(
          11,
          buckets: const [
            Bucket(id: 5, viewId: 11, title: 'To-Do', position: 1),
          ],
          slots: const {1: (bucketId: 5, position: 1)},
          loadedPages: const {},
          loadedAt: now,
        );
      }

      await download();
      client.allProjects = [
        work([list]),
        ...projects().skip(1),
      ];
      await sync.refresh();

      expect((await db.kanbanDao.load(11)).buckets, isEmpty);
      expect((await db.listSnapshotsDao.load('view:11')).loadedAt, isNull);
      expect((await db.listSnapshotsDao.load('view:10')).loadedAt, now);

      client.allProjects = [
        work([list, board]),
        ...projects().skip(1),
      ];
      await sync.refresh();
      await download();
      client.allProjects = projects().skip(1).toList();
      await sync.fullResync();

      expect((await db.kanbanDao.load(11)).buckets, isEmpty);
      expect((await db.listSnapshotsDao.load('view:10')).loadedAt, isNull);
    });

    test('a deleted label leaves its tasks and a renamed one shows on them '
        'without the tasks changing', () async {
      final sync = await synced();
      const critical = Label(id: 3, title: 'critical');
      client.allLabels = [critical];
      for (final id in [5, 10, 15, 20, 25, 30]) {
        replaceTask(id, labels: const [critical], updated: base);
      }
      for (final id in [7, 14, 21, 28]) {
        replaceTask(id, labels: const [], updated: base);
      }

      await sync.refresh();

      expect(await db.labelsDao.loadAll(), [critical]);
      expect((await db.tasksDao.find(5))!.labels, [critical]);
      expect((await db.tasksDao.find(7))!.labels, isEmpty);
      expect(requestsFor('tasks'), [
        'tasks $since per_page=50 page=1',
        'tasks (all) per_page=1 page=1',
      ]);
    });

    test('a deleted task is found by the live count, located by project and '
        'purged; a project whose count matches is not reconciled', () async {
      final sync = await synced();
      client.allTasks.removeWhere((t) => t.id == 9);
      // The project's updated stays: the deletion happened within the second
      // the initial sync saw.
      final seen = record(sync);

      await sync.refresh();

      expect(await db.tasksDao.find(9), isNull);
      expect(await db.tasksDao.count(), taskCount - 1);
      expect(requestsFor('project '), [
        'project 1 tasks (all) per_page=1 page=1',
        'project 1 tasks id > 0 per_page=50 page=1',
        'project 2 tasks (all) per_page=1 page=1',
      ]);
      expect(
        seen
            .whereType<SyncRunning>()
            .where((s) => s.phase == SyncPhase.reconcile)
            .map((s) => (s.done, s.total)),
        [(0, 0), (1, 2), (2, 2)],
      );
    });

    test('a reconcile pages by id and purges after the last page', () async {
      final sync = await synced(perPage: 4);
      client.allTasks.removeWhere((t) => t.id == 1 || t.id == 29);
      touchProjects([1]);

      await sync.refresh();

      expect(await db.tasksDao.countInProject(1), 13 + 5);
      expect(await db.tasksDao.find(1), isNull);
      expect(await db.tasksDao.find(29), isNull);
      expect(requestsFor('project 1 tasks'), [
        'project 1 tasks (all) per_page=1 page=1',
        'project 1 tasks id > 0 per_page=4 page=1',
        'project 1 tasks id > 9 per_page=4 page=1',
        'project 1 tasks id > 17 per_page=4 page=1',
        'project 1 tasks id > 25 per_page=4 page=1',
        'project 1 tasks id > 33 per_page=4 page=1',
      ]);
    });

    test('a project gone since the list is purged on not found', () async {
      final sync = await synced();
      client.allTasks.removeWhere((t) => t.id == 10);
      client.beforeRequest = (request) async {
        if (request.startsWith('project 2 tasks')) {
          replaceProject(2, remove: true);
        }
      };

      await sync.refresh();

      expect((await db.projectsDao.loadAll()).map((p) => p.id), [1, 3, 4]);
      expect(await db.tasksDao.countInProject(2), 0);
      expect(sync.currentStatus, SyncIdle(lastSyncedAt: now));
    });

    test('a project unshared since the list answers forbidden and is purged '
        'the same way', () async {
      final sync = await synced();
      client.allTasks.removeWhere((t) => t.id == 10);
      client.beforeRequest = (request) async {
        if (request.startsWith('project 2 tasks')) {
          client.forbiddenProjects.add(2);
        }
      };

      await sync.refresh();

      expect((await db.projectsDao.loadAll()).map((p) => p.id), [1, 3, 4]);
      expect(await db.tasksDao.countInProject(2), 0);
      expect(sync.currentStatus, SyncIdle(lastSyncedAt: now));
    });

    test('a project deleted between two pages of the list makes the walk '
        'start over instead of purging the shifted one', () async {
      client.allProjects = [
        for (var id = 1; id <= 60; id++) project(id: id, title: 'P$id'),
      ];
      final sync = await synced();
      var deleted = false;
      client.beforeRequest = (request) async {
        if (request == 'projects page 2 archived=true' && !deleted) {
          deleted = true;
          replaceProject(3, remove: true);
          client.allTasks.removeWhere((t) => t.projectId == 3);
        }
      };

      await sync.refresh();

      expect(requestsFor('projects page'), [
        'projects page 1 archived=true',
        'projects page 2 archived=true',
        'projects page 1 archived=true',
        'projects page 2 archived=true',
      ]);
      final ids = (await db.projectsDao.loadAll()).map((p) => p.id).toList();
      expect(ids, hasLength(59));
      expect(ids, isNot(contains(3)));
      expect(ids, contains(51));
      expect(requestsFor('project '), isEmpty);
    });

    test('a label deleted between two pages of the list keeps the shifted '
        'one on its tasks', () async {
      final many = [
        for (var id = 1; id <= 60; id++)
          switch (id) {
            3 => urgent,
            4 => later,
            _ => Label(id: id, title: 'L$id'),
          },
      ];
      client
        ..allLabels = many
        ..allTasks = [
          for (final t in tasks())
            if (t.id == 1)
              task(id: 1, title: 'Task 1', labels: [many[50]])
            else
              t,
        ];
      final sync = await synced();
      var deleted = false;
      client.beforeRequest = (request) async {
        if (request == 'labels page 2' && !deleted) {
          deleted = true;
          client.allLabels = [
            for (final l in client.allLabels)
              if (l.id != 2) l,
          ];
        }
      };

      await sync.refresh();

      expect(requestsFor('labels'), [
        'labels page 1',
        'labels page 2',
        'labels page 1',
        'labels page 2',
      ]);
      final ids = (await db.labelsDao.loadAll()).map((l) => l.id).toList();
      expect(ids, hasLength(59));
      expect(ids, isNot(contains(2)));
      expect((await db.tasksDao.find(1))!.labels.map((l) => l.id), [51]);
    });

    test('a list that keeps changing while it is paged fails the run '
        'without purging', () async {
      client.allProjects = [
        for (var id = 1; id <= 60; id++) project(id: id, title: 'P$id'),
      ];
      final sync = await synced();
      var next = 5;
      client.beforeRequest = (request) async {
        if (request == 'projects page 2 archived=true') {
          replaceProject(next++, remove: true);
        }
      };

      await expectLater(sync.refresh(), throwsA(isA<UnexpectedResponse>()));

      expect(requestsFor('projects page'), hasLength(6));
      expect(await db.projectsDao.loadAll(), hasLength(60));
    });

    test('a failure keeps the watermark, the rows and the last time', () async {
      final sync = await synced();
      replaceTask(3, title: 'Task 3 edited');
      client.beforeRequest = (request) async {
        if (request.startsWith('tasks')) {
          throw const NetworkFailure(NetworkProblem.timeout);
        }
      };
      final seen = record(sync);

      await expectLater(sync.refresh(), throwsA(isA<NetworkFailure>()));

      expect(
        seen.last,
        isA<SyncFailed>()
            .having((s) => s.failure, 'failure', isA<NetworkFailure>())
            .having(
              (s) => s.lastSyncedAt,
              'lastSyncedAt',
              DateTime.utc(2026, 10, 10, 12),
            ),
      );
      expect((await db.tasksDao.find(3))!.title, 'Task 3');
      expect(await state(), {
        SyncStateKeys.lastSyncedAt: DateTime.utc(
          2026,
          10,
          10,
          12,
        ).toIso8601String(),
        SyncStateKeys.lastFullSyncAt: DateTime.utc(
          2026,
          10,
          10,
          12,
        ).toIso8601String(),
        SyncStateKeys.watermark: newest.toIso8601String(),
      });
    });

    test('a reconcile cut off before its last page purges nothing', () async {
      final sync = await synced(perPage: 4);
      client.allTasks.removeWhere((t) => t.id == 9 || t.id == 11);
      touchProjects([1]);
      client.beforeRequest = (request) async {
        if (request.startsWith('project 1 tasks id > 7')) {
          throw const ServerFailure(503);
        }
      };

      await expectLater(sync.refresh(), throwsA(isA<ServerFailure>()));

      expect(await db.tasksDao.count(), taskCount);
      expect(await db.tasksDao.find(9), isNotNull);
      expect(
        (await state())[SyncStateKeys.watermark],
        newest.toIso8601String(),
      );
    });

    test(
      'a page not sorted by updated and id fails before it is stored',
      () async {
        final sync = await synced();
        replaceTask(3, title: 'Task 3 edited');
        // Newest first by id puts task 500 before 3 within the same second.
        client.allTasks.add(task(id: 500, title: 'New', updated: edited));
        client.tasks.ignoresSort = true;

        await expectLater(sync.refresh(), throwsA(isA<UnexpectedResponse>()));

        expect((await db.tasksDao.find(3))!.title, 'Task 3');
        expect(requestsFor('tasks'), hasLength(1));
      },
    );

    test('runs a full resync once the last one is a day old', () async {
      final sync = await synced();
      now = DateTime.utc(2026, 10, 11, 12, 0, 1);

      await sync.refresh();

      expect(client.requests, contains('tasks done = false per_page=1 page=1'));
      expect(requestsFor('tasks $since per_page'), isEmpty);
      expect(
        (await state())[SyncStateKeys.lastFullSyncAt],
        now.toIso8601String(),
      );
    });

    test('runs a full resync over a state without a watermark', () async {
      await synced();
      await db.syncStateDao.write({
        SyncStateKeys.watermark: null,
        SyncStateKeys.lastFullSyncAt: null,
      });
      final sync = engine();
      client.requests.clear();

      await sync.refresh();

      expect(client.requests, contains('tasks done = false per_page=1 page=1'));
      expect(
        (await state())[SyncStateKeys.watermark],
        newest.toIso8601String(),
      );
    });

    test('a task updated ahead of the clock is stored but does not move the '
        'watermark past the clock', () async {
      final sync = await synced();
      final records = captureLog();
      final ahead = now.add(const Duration(days: 3));
      client.allTasks.add(
        task(id: 600, title: 'From the future', projectId: 2, updated: ahead),
      );
      replaceTask(3, title: 'Task 3 edited');
      touchProjects([1, 2]);

      await sync.refresh();

      expect((await db.tasksDao.find(600))!.updated, ahead);
      expect(
        (await state())[SyncStateKeys.watermark],
        edited.toIso8601String(),
      );
      expect(
        records.where((r) => r.level == Level.WARNING).map((r) => r.message),
        contains(contains('ahead of the clock')),
      );
    });

    test('a full resync sets the watermark afresh, so one that lies in the '
        'future goes', () async {
      await synced();
      await db.syncStateDao.write({
        SyncStateKeys.watermark: DateTime.utc(2099).toIso8601String(),
      });
      final sync = engine();

      await sync.fullResync();

      expect(
        (await state())[SyncStateKeys.watermark],
        newest.toIso8601String(),
      );
    });

    test('a full resync asked for during an incremental run follows it, '
        'even when that one fails', () async {
      final sync = await synced();
      final gate = RequestGate()..pattern = 'labels';
      client.beforeRequest = (request) async {
        await gate.call(request);
        if (request.startsWith('labels')) throw const ServerFailure(503);
      };
      final incremental = sync.refresh();
      while (!gate.isHolding) {
        await pumpEventQueue();
      }
      final full = sync.fullResync();
      await pumpEventQueue();
      expect(requestsFor('tasks done = false per_page=1'), isEmpty);

      client.beforeRequest = null;
      gate.release();
      await expectLater(incremental, throwsA(isA<ServerFailure>()));
      await full;

      expect(requestsFor('tasks done = false per_page=1'), hasLength(1));
      expect(requestsFor('tasks $since per_page'), isEmpty);
      expect(requestsFor('projects page'), hasLength(2));
      expect(sync.currentStatus, SyncIdle(lastSyncedAt: now));
      expect(
        (await state())[SyncStateKeys.lastFullSyncAt],
        now.toIso8601String(),
      );
    });

    test('concurrent calls join one incremental run', () async {
      final sync = await synced();
      final gate = RequestGate()..pattern = 'projects page 1';
      client.beforeRequest = gate.call;

      final first = sync.refresh();
      final second = sync.refresh();
      while (!gate.isHolding) {
        await pumpEventQueue();
      }
      gate.release();
      await Future.wait([first, second]);

      expect(requestsFor('projects page'), hasLength(1));
      expect(requestsFor('tasks'), hasLength(2));
    });

    test('dispose ends an incremental run quietly', () async {
      final sync = await synced();
      final gate = RequestGate()..pattern = 'labels';
      client.beforeRequest = gate.call;
      final run = sync.refresh();
      while (!gate.isHolding) {
        await pumpEventQueue();
      }

      await sync.dispose();
      gate.release();
      await run;

      expect(requestsFor('tasks'), isEmpty);
      expect(
        (await state())[SyncStateKeys.lastSyncedAt],
        DateTime.utc(2026, 10, 10, 12).toIso8601String(),
      );
    });
  });

  group('without totals from the server (v1)', () {
    setUp(() {
      client = FakeSyncClient(reportsTotal: false)
        ..allProjects = projects()
        ..pseudoProjects = [
          const Project(id: Project.favoritesId, title: 'Favorites'),
        ]
        ..allLabels = [urgent, later]
        ..allTasks = tasks();
    });

    test('a deleted task is found by the page counts and purged', () async {
      final sync = await synced();
      client.allTasks.removeWhere((t) => t.id == 9);

      await sync.refresh();

      expect(await db.tasksDao.find(9), isNull);
      expect(await db.tasksDao.count(), taskCount - 1);
      expect(requestsFor('project '), [
        'project 1 tasks (all) per_page=1 page=1',
        'project 1 tasks id > 0 per_page=50 page=1',
        'project 2 tasks (all) per_page=1 page=1',
      ]);
    });

    test('without changes the page counts match and nothing is '
        'reconciled', () async {
      final sync = await synced();

      await sync.refresh();

      expect(client.requests, quietRun);
      expect(await db.tasksDao.count(), taskCount);
    });
  });

  test('a full resync after incremental runs purges by its run id', () async {
    final sync = await synced();
    replaceTask(3, title: 'Task 3 edited');
    touchProjects([1]);
    await sync.refresh();
    // Gone on the server without any project noticing.
    client.allTasks.removeWhere((t) => t.id == 4);
    final runIds = (await db.select(db.tasks).get()).map((r) => r.syncRunId);
    expect(runIds.toSet(), hasLength(2));

    await sync.fullResync();

    expect(await db.tasksDao.find(4), isNull);
    expect(await db.tasksDao.count(), taskCount - 1);
    final after = (await db.select(db.tasks).get()).map((r) => r.syncRunId);
    expect(after.toSet(), hasLength(1));
    expect(
      (await state())[SyncStateKeys.lastFullSyncAt],
      now.toIso8601String(),
    );
  });
}
