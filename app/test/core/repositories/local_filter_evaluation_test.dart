import 'dart:async';
import 'dart:math' show min;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_search.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

void main() {
  late AppDatabase db;
  late RecordingSyncEngine sync;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late OutboxSender sender;
  late LocalTaskRepository repository;
  late StreamController<void> clockTicks;
  final now = DateTime.utc(2026, 10, 20, 8);
  var clock = now;
  final monday = DateTime.utc(2026, 10, 19, 9);
  const alice = User(id: 7, username: 'alice', name: 'Alice');
  const urgent = Label(id: 1, title: 'Urgent');

  ProjectView view(
    int id, {
    int projectId = 7,
    String filter = '',
    String search = '',
  }) => sampleListView(
    id: id,
    projectId: projectId,
    filter: filter,
    search: search,
  );

  const kanban = ProjectView(
    id: 80,
    projectId: 7,
    title: 'Kanban',
    kind: ProjectViewKind.kanban,
    bucketConfigurationMode: BucketConfigurationMode.manual,
    filter: ViewFilter(filter: 'priority >= 3'),
  );
  final tasks = [
    sampleTask(
      id: 1,
      title: 'Report',
      projectId: 7,
      priority: TaskPriority.urgent,
      labels: [urgent],
    ),
    sampleTask(id: 2, title: 'Plan', projectId: 7, priority: TaskPriority.low),
    sampleTask(
      id: 3,
      title: 'Report done',
      projectId: 7,
      priority: TaskPriority.doNow,
      done: true,
    ),
    sampleTask(id: 4, title: 'Old', projectId: 8, priority: TaskPriority.doNow),
    sampleTask(
      id: 5,
      title: 'Home',
      projectId: 9,
      priority: TaskPriority.high,
      due: monday,
      assignees: [alice],
    ),
    sampleTask(
      id: 6,
      title: 'Favourite old',
      projectId: 10,
      priority: TaskPriority.urgent,
      favorite: true,
    ),
  ];

  setUp(() async {
    db = testDatabase();
    sync = RecordingSyncEngine();
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient();
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: sync,
      now: () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    clock = now;
    clockTicks = StreamController<void>.broadcast();
    addTearDown(clockTicks.close);
    repository = LocalTaskRepository(
      db,
      sync,
      sender,
      write,
      read: read,
      now: () => clock,
      clockTicks: clockTicks.stream,
    );
    addTearDown(repository.dispose);
    final projects = [
      sampleProject(
        id: 7,
        title: 'Work',
        views: [
          view(70, filter: 'priority >= 3'),
          view(71, filter: 'done = false'),
          view(72, filter: 'bucket_id = 1'),
          view(73, search: 'report'),
          view(74, filter: 'priority = abc'),
          view(75),
          kanban,
        ],
      ),
      sampleProject(
        id: 8,
        title: 'Old',
        archived: true,
        views: [view(90, projectId: 8, filter: 'priority >= 3')],
      ),
      sampleProject(id: 9, title: 'Home'),
      sampleProject(id: 10, title: 'Under old', parent: 8),
    ];
    await db.projectsDao.upsertAll(projects);
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
    read
      ..allProjects = projects
      ..allTasks = tasks;
  });

  List<int> ids(Iterable<Task> tasks) => [for (final task in tasks) task.id];

  Future<ProjectListSource> list(
    int viewId, {
    int projectId = 7,
    bool includeDone = false,
  }) => repository
      .watchProjectList(projectId, viewId: viewId, includeDone: includeDone)
      .first;

  Future<void> storeFilter(
    String filter, {
    int pseudoProjectId = -14,
    bool known = true,
    bool includeNulls = false,
  }) => storeSavedFilters(db, [
    SavedFilterRef(
      projectId: pseudoProjectId,
      title: 'Mine',
      definition: known
          ? SavedFilterDefinition(
              filter: ViewFilter(filter: filter, includeNulls: includeNulls),
            )
          : null,
    ),
  ]);

  Future<void> settings(UserSettings settings) => db.syncStateDao.write({
    SyncStateKeys.userSettings: encodeUserSettings(settings),
  });

  group('a list view', () {
    test("matches its filter on the project's tasks, done ones included, and "
        'loads the done matches', () async {
      final source = await list(70);

      expect(source.matchingIds, {1, 3});
      expect(ids(source.projectTasks), [3, 2, 1]);
      expect(source.omitsDoneTasks, isFalse);
    });

    test('done = false matches the open tasks', () async {
      final source = await list(71);

      expect(source.matchingIds, {1, 2});
      expect(ids(source.projectTasks), [2, 1]);
      expect(source.omitsDoneTasks, isTrue);
    });

    test("applies the view's search like the server", () async {
      expect((await list(73)).matchingIds, {1, 3});
    });

    test('a view without a filter, one the engine refuses and one naming '
        'bucket_id leave it to the snapshot', () async {
      expect((await list(75)).matchingIds, isNull);
      expect((await list(74)).matchingIds, isNull);
      expect((await list(72)).matchingIds, isNull);
      expect((await list(0)).matchingIds, isNull);
    });

    test("an archived project's view covers its tasks", () async {
      expect((await list(90, projectId: 8)).matchingIds, {4});
    });

    test('a change made here enters and leaves the list at once', () async {
      final seen = <ProjectListSource>[];
      final subscription = repository
          .watchProjectList(7, viewId: 70, includeDone: false)
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen.last.matchingIds, {1, 3});

      await repository.updateTask(2, const TaskChanges(priority: 5));
      await repository.updateTask(1, const TaskChanges(priority: 1));
      await pumpEventQueue();

      expect(seen.last.matchingIds, {2, 3});
    });

    test("a change of the view's filter is evaluated at once", () async {
      final seen = <ProjectListSource>[];
      final subscription = repository
          .watchProjectList(7, viewId: 75)
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen.last.matchingIds, isNull);

      await db.projectsDao.putView(view(75, filter: 'done = true'));
      await pumpEventQueue();

      expect(seen.last.matchingIds, {3});
    });
  });

  group('a board', () {
    test('matches its filter and, never downloaded, loads the done '
        'matches', () async {
      final source = await repository.watchBoard(7, 80).first;

      expect(source.matchingIds, {1, 3});
      expect(ids(source.projectTasks), containsAll([1, 3]));
    });

    test('after a download loads only the done matches it can show', () async {
      await db.kanbanDao.replaceBoard(
        80,
        buckets: const [Bucket(id: 1, viewId: 80, title: 'To do', position: 1)],
        slots: const {1: (bucketId: 1, position: 1)},
        loadedPages: const {},
        loadedAt: now,
      );

      final source = await repository.watchBoard(7, 80).first;

      expect(source.matchingIds, {1, 3});
      expect(ids(source.projectTasks), isNot(contains(3)));
    });

    test('a filter-mode board is the download alone', () async {
      await db.projectsDao.putView(
        ProjectView(
          id: 80,
          projectId: 7,
          title: 'Kanban',
          kind: ProjectViewKind.kanban,
          bucketConfigurationMode: BucketConfigurationMode.filter,
          filter: kanban.filter,
        ),
      );

      expect((await repository.watchBoard(7, 80).first).matchingIds, isNull);
    });
  });

  group('a saved filter', () {
    test('with a known definition lists its open matches outside archived '
        'projects, favourites included, by due date', () async {
      await storeFilter('priority >= 3');

      final list = await repository.watchSavedFilterTasks(-14).first;

      expect(list.evaluation, FilterEvaluation.local);
      expect(list.loadedAt, isNull);
      expect(ids(list.tasks), [5, 6, 1]);
    });

    test('by username and label id', () async {
      await storeFilter('assignees = alice || labels in 1');

      expect(ids((await repository.watchSavedFilterTasks(-14).first).tasks), [
        5,
        1,
      ]);
    });

    test('by reminders, one of which must lie in the whole range, and by '
        'creator', () async {
      await db.tasksDao.upsertAll([
        sampleTask(
          id: 30,
          title: 'Two reminders',
          projectId: 9,
          reminders: [
            TaskReminder(reminder: DateTime.utc(2026, 10, 20, 22, 30)),
            TaskReminder(reminder: DateTime.utc(2026, 10, 25, 8)),
          ],
          createdBy: alice,
        ),
      ], syncRunId: 'run');

      await storeFilter(
        'reminders > 2026-10-21T00:00:00Z && reminders < 2026-10-24T00:00:00Z',
      );
      expect(
        (await repository.watchSavedFilterTasks(-14).first).tasks,
        isEmpty,
      );

      await storeFilter(
        'reminders > 2026-10-20T00:00:00Z && reminders < 2026-10-21T00:00:00Z',
      );
      expect(ids((await repository.watchSavedFilterTasks(-14).first).tasks), [
        30,
      ]);

      await storeFilter('created_by = alice');
      expect(ids((await repository.watchSavedFilterTasks(-14).first).tasks), [
        30,
      ]);
    });

    test('an unknown definition and one the engine refuses use the '
        'download', () async {
      await db.listSnapshotsDao.replace(savedFilterSnapshotKey(-14), {
        2: 0,
      }, loadedAt: now);

      await storeFilter('', known: false);
      var list = await repository.watchSavedFilterTasks(-14).first;
      expect(list.evaluation, FilterEvaluation.snapshot);
      expect(ids(list.tasks), [2]);
      expect(list.loadedAt, now);

      await storeFilter('done = yes');
      list = await repository.watchSavedFilterTasks(-14).first;
      expect(list.evaluation, FilterEvaluation.snapshot);
    });

    test('a refresh syncs and downloads only a filter the device cannot '
        'evaluate', () async {
      read
        ..pseudoProjects = [const Project(id: -14, title: 'Mine')]
        ..savedFilterTasks[-14] = {2};
      await storeFilter('priority >= 3');

      await repository.refreshSavedFilter(-14);
      expect(sync.refreshCalls, 1);
      expect(read.requests, isEmpty);

      await storeFilter('done = yes');
      await repository.refreshSavedFilter(-14);
      expect(read.requests, hasLength(1));
      expect(
        (await db.listSnapshotsDao.load(savedFilterSnapshotKey(-14))).taskIds,
        [2],
      );
    });

    test('follows a change of its definition and of the tasks', () async {
      await storeFilter('priority >= 3');
      final seen = <SavedFilterTasks>[];
      final subscription = repository
          .watchSavedFilterTasks(-14)
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(ids(seen.last.tasks), [5, 6, 1]);

      await repository.setDone(5, done: true);
      await pumpEventQueue();
      expect(ids(seen.last.tasks), [6, 1]);

      await storeFilter('priority = 1');
      await pumpEventQueue();
      expect(ids(seen.last.tasks), [2]);
    });

    test("rounds relative dates in the user's timezone setting", () async {
      await db.tasksDao.upsertAll([
        sampleTask(
          id: 20,
          title: 'Late on the 20th',
          projectId: 9,
          due: DateTime.utc(2026, 10, 20, 22, 30),
        ),
        sampleTask(
          id: 21,
          title: 'Late on the 19th',
          projectId: 9,
          due: DateTime.utc(2026, 10, 19, 22, 30),
        ),
      ], syncRunId: 'run');
      await storeFilter('due_date >= now/d && due_date < now/d+1d');

      await settings(const UserSettings(timezone: 'UTC'));
      expect(ids((await repository.watchSavedFilterTasks(-14).first).tasks), [
        20,
      ]);

      await settings(const UserSettings(timezone: 'Europe/Berlin'));
      expect(ids((await repository.watchSavedFilterTasks(-14).first).tasks), [
        21,
      ]);
    });
  });

  group('the Overview', () {
    test("evaluates the saved filter's definition here", () async {
      await storeFilter('priority >= 3');
      await settings(const UserSettings(filterIdUsedOnOverview: -14));

      final overview = await repository.watchOverviewTasks().first;

      expect(overview.filter?.projectId, -14);
      expect(overview.filterEvaluation, FilterEvaluation.local);
      expect(ids(overview.tasks), [5, 6, 1]);
    });

    test('include-nulls lets the tasks without a value in', () async {
      await db.tasksDao.upsertAll([
        sampleTask(id: 22, title: 'No date', projectId: 9),
      ], syncRunId: 'run');
      await storeFilter('due_date < 2026-10-20', includeNulls: true);
      await settings(const UserSettings(filterIdUsedOnOverview: -14));

      final overview = await repository.watchOverviewTasks().first;

      expect(ids(overview.tasks), [5, 22, 6, 2, 1]);
    });
  });

  group('a label opened from the search', () {
    test("lists its open tasks in a saved filter's scope, favourites in "
        'archived projects included', () async {
      await db.tasksDao.upsertAll([
        sampleTask(
          id: 40,
          title: 'Urgent favourite in an archived project',
          projectId: 8,
          labels: const [urgent],
          favorite: true,
        ),
        sampleTask(
          id: 41,
          title: 'Urgent in an archived project',
          projectId: 8,
          labels: const [urgent],
        ),
        sampleTask(
          id: 42,
          title: 'Urgent and done',
          projectId: 9,
          labels: const [urgent],
          done: true,
        ),
      ], syncRunId: 'run');

      expect(ids(await repository.watchLabelTasks(1).first), [40, 1]);
    });
  });

  group('a saved filter for open tasks', () {
    test('reads only the open candidates when asked to', () async {
      final filters = LocalFilters(db, now: () => now);
      const definition = SavedFilterDefinition(
        filter: ViewFilter(filter: 'priority >= 3'),
      );

      expect(
        await filters.matchingForSavedFilter(definition, timezoneSetting: ''),
        {1, 3, 5, 6},
      );
      expect(
        await filters.matchingForSavedFilter(
          definition,
          timezoneSetting: '',
          openOnly: true,
        ),
        {1, 5, 6},
      );
      expect(await db.tasksDao.loadOpenTasksAmong({1, 3}), [
        isA<Task>().having((task) => task.id, 'id', 1),
      ]);
    });
  });

  group('a filter with a relative date is evaluated again as time '
      'passes', () {
    const today = 'due_date >= now/d && due_date < now/d+1d';
    final tonight = sampleTask(
      id: 20,
      title: 'Tonight',
      projectId: 7,
      due: DateTime.utc(2026, 10, 20, 22, 30),
    );
    final tomorrow = sampleTask(
      id: 21,
      title: 'Tomorrow morning',
      projectId: 7,
      due: DateTime.utc(2026, 10, 21, 10),
    );
    final soon = sampleTask(
      id: 22,
      title: 'In an hour',
      projectId: 7,
      due: DateTime.utc(2026, 10, 20, 9),
    );

    setUp(() async {
      await db.tasksDao.upsertAll([tonight, tomorrow, soon], syncRunId: 'run');
      await settings(
        const UserSettings(timezone: 'UTC', filterIdUsedOnOverview: -14),
      );
    });

    Future<List<T>> watching<T>(Stream<T> stream) async {
      final seen = <T>[];
      final subscription = stream.listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      return seen;
    }

    Future<void> tick(DateTime to) async {
      clock = to;
      clockTicks.add(null);
      await pumpEventQueue();
    }

    test('the Overview moves past midnight without a write', () async {
      await storeFilter(today);
      final seen = await watching(repository.watchOverviewTasks());
      expect(ids(seen.last.tasks), [22, 20]);

      await tick(DateTime.utc(2026, 10, 21, 7));

      expect(ids(seen.last.tasks), [21]);
    });

    test('a smart list moves to the next day, and stays quiet while its '
        'tasks stay the same', () async {
      await storeFilter(today);
      final seen = await watching(repository.watchSavedFilterTasks(-14));
      expect(ids(seen.last.tasks), [22, 20]);

      await tick(DateTime.utc(2026, 10, 20, 8, 1));
      expect(seen, hasLength(1));

      await tick(DateTime.utc(2026, 10, 21, 7));
      expect(ids(seen.last.tasks), [21]);
    });

    test('a list view and a board pick up a task once it is overdue', () async {
      await db.projectsDao.putView(view(76, filter: 'due_date < now'));
      await db.projectsDao.putView(
        const ProjectView(
          id: 81,
          projectId: 7,
          title: 'Overdue board',
          kind: ProjectViewKind.kanban,
          bucketConfigurationMode: BucketConfigurationMode.manual,
          filter: ViewFilter(filter: 'due_date < now'),
        ),
      );
      final list = await watching(
        repository.watchProjectList(7, viewId: 76, includeDone: false),
      );
      final board = await watching(repository.watchBoard(7, 81));
      expect(list.last.matchingIds, isEmpty);
      expect(board.last.matchingIds, isEmpty);

      await tick(DateTime.utc(2026, 10, 20, 9, 30));

      expect(list.last.matchingIds, {22});
      expect(board.last.matchingIds, {22});
    });

    test('a filter without one is not evaluated again on a tick', () async {
      final seen = await watching(
        repository.watchProjectList(7, viewId: 70, includeDone: false),
      );
      expect(seen, hasLength(1));

      await tick(DateTime.utc(2026, 10, 21, 7));

      expect(seen, hasLength(1));
    });
  });

  group('the count of a filter builder', () {
    test('counts in the project or in the scope of a saved filter, null '
        'for a filter the engine refuses', () async {
      final search = LocalTaskSearch(db, now: () => now);

      expect(
        await search.countMatches(
          const ViewFilter(filter: 'priority >= 3'),
          projectId: 7,
        ),
        2,
      );
      expect(
        await search.countMatches(const ViewFilter(filter: 'priority >= 3')),
        4,
      );
      expect(
        await search.countMatches(const ViewFilter(filter: 'done = yes')),
        isNull,
      );
      expect(
        await search.countMatches(const ViewFilter(filter: 'bucket_id = 3')),
        isNull,
      );
    });
  });

  test('5000 tasks of a project are evaluated in under 300 ms', () async {
    await db.labelsDao.upsertAll([urgent]);
    await db.tasksDao.upsertAll([
      for (var id = 1000; id < 6000; id++)
        sampleTask(
          id: id,
          title: 'Bulk $id',
          projectId: 11,
          done: id.isEven,
          priority: TaskPriority.fromValue(id % 6),
          due: id % 3 == 0 ? monday.add(Duration(hours: id % 500)) : null,
          labels: id % 5 == 0 ? const [urgent] : const [],
          assignees: id % 7 == 0 ? const [alice] : const [],
        ),
    ], syncRunId: 'run');
    final filters = LocalFilters(db, now: () => now);
    const filter = ViewFilter(
      filter:
          'priority >= 3 && (labels in 1 || assignees = alice) || '
          'due_date < now/d+7d',
      includeNulls: true,
    );
    await filters.matchingInProject(11, filter, timezoneSetting: 'UTC');

    // The fastest of five runs, as a single one on a busy CI runner took
    // three times the test machine's 50 ms. 300 ms leaves that runner room
    // and still fails a query per task, which takes over 500 ms in all.
    final runs = <int>[];
    Set<int>? matching;
    for (var run = 0; run < 5; run++) {
      final watch = Stopwatch()..start();
      matching = await filters.matchingInProject(
        11,
        filter,
        timezoneSetting: 'Europe/Berlin',
      );
      runs.add(watch.elapsedMilliseconds);
    }
    final fastest = runs.reduce(min);

    // The number the step reports.
    // ignore: avoid_print
    print('Evaluated 5000 tasks in $fastest ms, the fastest of $runs');
    expect(matching, isNotEmpty);
    expect(fastest, lessThan(300));
  });
}
