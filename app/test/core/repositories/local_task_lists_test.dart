import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
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
  final now = DateTime.utc(2026, 10, 13, 12);
  final monday = DateTime.utc(2026, 10, 12, 9);
  final friday = DateTime.utc(2026, 10, 16, 9);
  const myOpenTasks = SavedFilterRef(projectId: -14, title: 'My Open Tasks');
  final listView = sampleListView(id: 70, projectId: 7);
  final tasks = [
    sampleTask(id: 1, title: 'Undated', projectId: 7),
    sampleTask(id: 2, title: 'Friday', projectId: 7, due: friday),
    sampleTask(id: 3, title: 'Done', projectId: 7, done: true),
    sampleTask(id: 4, title: 'Archived', projectId: 8, due: monday),
    sampleTask(id: 5, title: 'Monday', projectId: 9, due: monday),
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
    repository = LocalTaskRepository(
      db,
      sync,
      sender,
      write,
      read: read,
      perPage: 2,
      now: () => now,
    );
    addTearDown(repository.dispose);
    final projects = [
      sampleProject(id: 7, title: 'Work', views: [listView]),
      sampleProject(id: 8, title: 'Old', archived: true),
      sampleProject(id: 9, title: 'Home'),
    ];
    await db.projectsDao.upsertAll(projects);
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
    read
      ..allProjects = projects
      ..allTasks = tasks;
  });

  Future<void> pickForOverview(int? pseudoId, {bool known = true}) =>
      db.syncStateDao.write({
        SyncStateKeys.userSettings: encodeUserSettings(
          UserSettings(filterIdUsedOnOverview: pseudoId),
        ),
        SyncStateKeys.savedFilters: known
            ? encodeSavedFilters([myOpenTasks])
            : null,
      });

  List<int> ids(Iterable<Task> tasks) => [for (final task in tasks) task.id];

  test('the active open tasks leave out archived projects', () async {
    expect(ids(await repository.watchActiveOpenTasks().first), [5, 2, 1]);
  });

  group('Overview', () {
    test('without a saved filter shows the active open tasks', () async {
      final overview = await repository.watchOverviewTasks().first;

      expect(ids(overview.tasks), [5, 2, 1]);
      expect(overview.filter, isNull);
      expect(overview.filterLoadedAt, isNull);
    });

    test("with the user's saved filter shows its download, open tasks by "
        'due date', () async {
      await pickForOverview(-14);
      await db.listSnapshotsDao.replace(overviewSnapshotKey(-14), {
        4: 0,
        2: 1,
        1: 2,
        3: 3,
      }, loadedAt: now);

      final overview = await repository.watchOverviewTasks().first;

      expect(overview.filter, myOpenTasks);
      expect(overview.filterLoadedAt, now);
      expect(ids(overview.tasks), [4, 2, 1]);
    });

    test('a filter never downloaded shows nothing yet', () async {
      await pickForOverview(-14);

      final overview = await repository.watchOverviewTasks().first;

      expect(overview.filter, myOpenTasks);
      expect(overview.filterLoadedAt, isNull);
      expect(overview.tasks, isEmpty);
    });

    test('a filter the project list no longer names falls back to the '
        'active open tasks', () async {
      await pickForOverview(-14, known: false);
      await db.listSnapshotsDao.replace(overviewSnapshotKey(-14), {
        4: 0,
      }, loadedAt: now);

      final overview = await repository.watchOverviewTasks().first;

      expect(overview.filter, isNull);
      expect(ids(overview.tasks), [5, 2, 1]);
    });

    test('follows the setting, and local done and deletes at once', () async {
      final seen = <OverviewTasks>[];
      final subscription = repository.watchOverviewTasks().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      await db.listSnapshotsDao.replace(overviewSnapshotKey(-14), {
        2: 0,
        1: 1,
        5: 2,
      }, loadedAt: now);
      await pumpEventQueue();

      await pickForOverview(-14);
      await pumpEventQueue();
      expect(seen.last.filter, myOpenTasks);
      expect(ids(seen.last.tasks), [5, 2, 1]);

      await repository.setDone(2, done: true);
      await repository.deleteTask(5);
      await repository.createTask(
        const NewTask(projectId: 7, title: 'Created here'),
      );
      await pumpEventQueue();
      expect(ids(seen.last.tasks), [1]);

      await pickForOverview(null);
      await pumpEventQueue();
      expect(seen.last.filter, isNull);
      expect(
        [for (final task in seen.last.tasks) task.title],
        ['Created here', 'Undated'],
      );
    });
  });

  group('project list', () {
    test("holds the project's tasks and the view's download", () async {
      await db.listSnapshotsDao.replace('view:70', {2: 1, 1: 2}, loadedAt: now);

      final source = await repository.watchProjectList(7, viewId: 70).first;

      expect(ids(source.projectTasks), [3, 2, 1]);
      expect(source.tasksById.keys.toSet(), {1, 2, 3});
      expect(source.snapshot.positions, {2: 1, 1: 2});
      expect(source.snapshot.loadedAt, now);
    });

    test('leaves the done tasks out when asked to', () async {
      final source = await repository
          .watchProjectList(7, viewId: 70, includeDone: false)
          .first;

      expect(ids(source.projectTasks), [2, 1]);
      expect(source.omitsDoneTasks, isTrue);
    });

    test('a project without a list view has no download', () async {
      final source = await repository.watchProjectList(7, viewId: 0).first;

      expect(ids(source.projectTasks), [3, 2, 1]);
      expect(source.snapshot.loadedAt, isNull);
    });

    test('a refresh syncs, then stores the view with its positions from '
        'every page', () async {
      read.viewPositions[70] = {1: 10, 2: 20, 3: 5};

      await repository.refreshProjectList(7, viewId: 70);

      expect(sync.refreshCalls, 1);
      final snapshot = await db.listSnapshotsDao.load('view:70');
      // The view filters done tasks out, as the server's List view does.
      expect(snapshot.positions, {1: 10, 2: 20});
      expect(snapshot.loadedAt, now);
      expect(read.requests, [
        'project 7 view 70 tasks (all) per_page=2 page=1',
      ]);
      expect(
        read.tasks.queries.single.sort.single.field,
        TaskSortField.position,
      );
    });

    test("a view's relative dates are rounded in the user's time zone "
        'setting, as the web asks for them', () async {
      read.viewPositions[70] = {1: 10};
      await repository.refreshProjectList(7, viewId: 70);
      expect(read.tasks.queries.last.filterTimezone, isNull);

      await db.syncStateDao.write({
        SyncStateKeys.userSettings: encodeUserSettings(
          const UserSettings(timezone: 'Europe/Berlin'),
        ),
      });
      await repository.refreshProjectList(7, viewId: 70);
      expect(read.tasks.queries.last.filterTimezone, 'Europe/Berlin');
    });

    test('a long view takes several pages', () async {
      final many = [
        for (var id = 10; id < 15; id++)
          sampleTask(id: id, title: 'Task $id', projectId: 7),
      ];
      read.allTasks = many;
      read.viewPositions[70] = {
        for (final task in many) task.id: 100.0 - task.id,
      };

      await repository.refreshProjectList(7, viewId: 70);

      expect((await db.listSnapshotsDao.load('view:70')).positions, {
        for (final task in many) task.id: 100.0 - task.id,
      });
      expect(read.requests, hasLength(3));
    });

    test('a reorder is queued for the view and shows at once; once sent, '
        'the download holds it', () async {
      await db.listSnapshotsDao.replace('view:70', {2: 1, 1: 2}, loadedAt: now);
      write.serverTasks.addAll({1: tasks[0], 2: tasks[1]});
      sender.pause();

      await repository.positionTask(1, viewId: 70, position: 0.5);

      var source = await repository.watchProjectList(7, viewId: 70).first;
      expect(source.queuedPositions, {1: 0.5});
      expect(source.snapshot.positions, {2: 1, 1: 2});
      expect(write.requests, isEmpty);

      await sender.resume();

      expect(write.requests, ['update 1', 'position 1 view 70 0.5']);
      source = await repository.watchProjectList(7, viewId: 70).first;
      expect(source.queuedPositions, isEmpty);
      expect(source.snapshot.taskIds, [1, 2]);
    });

    test('a refresh without a list view only syncs', () async {
      await repository.refreshProjectList(7, viewId: 0);

      expect(sync.refreshCalls, 1);
      expect(read.requests, isEmpty);
    });

    test('a failed sync or download passes through and keeps the previous '
        'download', () async {
      await db.listSnapshotsDao.replace('view:70', {1: 1}, loadedAt: monday);

      sync.error = const ServerFailure(502);
      await expectLater(
        repository.refreshProjectList(7, viewId: 70),
        throwsA(isA<ServerFailure>()),
      );
      expect(read.requests, isEmpty);

      sync.error = null;
      read.beforeRequest = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await expectLater(
        repository.refreshProjectList(7, viewId: 70),
        throwsA(isA<NetworkFailure>()),
      );
      final snapshot = await db.listSnapshotsDao.load('view:70');
      expect(snapshot.positions, {1: 1});
      expect(snapshot.loadedAt, monday);
    });
  });

  group('Favorites', () {
    setUp(() async {
      final child = sampleProject(id: 10, title: 'Old child', parent: 8);
      await db.projectsDao.upsertAll([child]);
      await db.tasksDao.upsertAll([
        sampleTask(id: 11, title: 'Undated', projectId: 7, favorite: true),
        sampleTask(
          id: 12,
          title: 'Friday',
          projectId: 9,
          due: friday,
          favorite: true,
        ),
        sampleTask(
          id: 13,
          title: 'Done',
          projectId: 7,
          done: true,
          favorite: true,
        ),
        sampleTask(
          id: 14,
          title: 'Archived',
          projectId: 8,
          due: monday,
          favorite: true,
        ),
        sampleTask(
          id: 15,
          title: 'Archived child',
          projectId: 10,
          favorite: true,
        ),
        sampleTask(
          id: 16,
          title: 'Monday',
          projectId: 7,
          due: monday,
          favorite: true,
        ),
      ], syncRunId: 'run');
    });

    test('are the open favourite tasks outside archived projects and their '
        'subprojects, by due date, then newest', () async {
      expect(ids(await repository.watchFavoriteTasks().first), [16, 12, 11]);
    });

    test('follow the favourites, done and deletes made here at once, and '
        'an archived project coming back', () async {
      final seen = <List<int>>[];
      final subscription = repository.watchFavoriteTasks().listen(
        (tasks) => seen.add(ids(tasks)),
      );
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repository.setFavorite(5, favorite: true);
      await repository.setFavorite(11, favorite: false);
      await repository.setDone(16, done: true);
      await repository.deleteTask(12);
      await pumpEventQueue();

      expect(seen.last, [5]);

      await db.projectsDao.upsertAll([sampleProject(id: 8, title: 'Old')]);
      await pumpEventQueue();

      expect(seen.last, [14, 5, 15]);
    });

    test('none at all is an empty list', () async {
      await repository.setFavorite(11, favorite: false);
      await repository.setFavorite(12, favorite: false);
      await repository.setFavorite(16, favorite: false);

      expect(await repository.watchFavoriteTasks().first, isEmpty);
    });
  });

  group('saved filter', () {
    const urgent = Project(id: -3, title: 'Urgent');
    const mine = Project(id: -14, title: 'My Open Tasks');
    const firstPage =
        'project -14 tasks done = false sort=id desc per_page=2 page=1';

    setUp(() {
      read
        ..pseudoProjects = [mine, urgent]
        ..savedFilterTasks[-14] = {1, 2, 3, 4, 5}
        ..savedFilterTasks[-3] = {2};
    });

    test('never downloaded has no tasks and no time', () async {
      final list = await repository.watchSavedFilterTasks(-14).first;

      expect(list.tasks, isEmpty);
      expect(list.loadedAt, isNull);
    });

    test("shows its download's open tasks by due date, then newest, and "
        'follows done and deletes made here at once', () async {
      await db.listSnapshotsDao.replace(savedFilterSnapshotKey(-14), {
        1: 0,
        2: 1,
        3: 2,
        4: 3,
      }, loadedAt: monday);
      final seen = <SavedFilterTasks>[];
      final subscription = repository
          .watchSavedFilterTasks(-14)
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      expect(ids(seen.last.tasks), [4, 2, 1]);
      expect(seen.last.loadedAt, monday);

      await repository.setDone(4, done: true);
      await repository.deleteTask(1);
      await pumpEventQueue();

      expect(ids(seen.last.tasks), [2]);
    });

    test('a refresh syncs, then downloads the open tasks from every page '
        'into its own snapshot', () async {
      await db.listSnapshotsDao.replace(overviewSnapshotKey(-14), {
        1: 0,
      }, loadedAt: monday);

      await repository.refreshSavedFilter(-14);

      expect(sync.refreshCalls, 1);
      expect(read.requests, [
        firstPage,
        firstPage.replaceFirst('page=1', 'page=2'),
      ]);
      final snapshot = await db.listSnapshotsDao.load(
        savedFilterSnapshotKey(-14),
      );
      expect(snapshot.taskIds, [5, 4, 2, 1]);
      expect(snapshot.loadedAt, now);
      // What the server matched shows, archived projects included.
      expect(ids((await repository.watchSavedFilterTasks(-14).first).tasks), [
        5,
        4,
        2,
        1,
      ]);
      expect(
        (await db.listSnapshotsDao.load(overviewSnapshotKey(-14))).taskIds,
        [1],
      );
    });

    test('each filter has its own download, rewritten with its time on '
        'every refresh', () async {
      await repository.refreshSavedFilter(-3);
      final later = now.add(const Duration(minutes: 10));
      final repository2 = LocalTaskRepository(
        db,
        sync,
        sender,
        write,
        read: read,
        now: () => later,
      );
      await repository2.refreshSavedFilter(-3);
      await repository.refreshSavedFilter(-14);

      final urgentList = await db.listSnapshotsDao.load(
        savedFilterSnapshotKey(-3),
      );
      expect(urgentList.taskIds, [2]);
      expect(urgentList.loadedAt, later);
      expect(
        (await db.listSnapshotsDao.load(savedFilterSnapshotKey(-14))).taskIds,
        [5, 4, 2, 1],
      );
    });

    test("relative dates are rounded in the user's time zone setting, as "
        'the web asks for them', () async {
      await repository.refreshSavedFilter(-3);
      expect(read.tasks.queries.last.filterTimezone, isNull);

      await db.syncStateDao.write({
        SyncStateKeys.userSettings: encodeUserSettings(
          const UserSettings(timezone: 'Europe/Berlin'),
        ),
      });
      await repository.refreshSavedFilter(-3);
      final query = read.tasks.queries.last;
      expect(query.filterTimezone, 'Europe/Berlin');
      expect(query.filter, 'done = false');
      expect(query.sort, TaskQuery.dueDateSort);
    });

    test('a failed sync or download passes through and keeps the previous '
        'download', () async {
      await db.listSnapshotsDao.replace(savedFilterSnapshotKey(-14), {
        1: 0,
      }, loadedAt: monday);

      sync.error = const ServerFailure(502);
      await expectLater(
        repository.refreshSavedFilter(-14),
        throwsA(isA<ServerFailure>()),
      );
      expect(read.requests, isEmpty);

      sync.error = null;
      read.beforeRequest = (request) async {
        if (request.endsWith('page=2')) {
          throw const NetworkFailure(NetworkProblem.unreachable);
        }
      };
      await expectLater(
        repository.refreshSavedFilter(-14),
        throwsA(isA<NetworkFailure>()),
      );
      read
        ..beforeRequest = null
        ..pseudoProjects = [urgent];
      await expectLater(
        repository.refreshSavedFilter(-14),
        throwsA(isA<NotFound>()),
      );
      final snapshot = await db.listSnapshotsDao.load(
        savedFilterSnapshotKey(-14),
      );
      expect(snapshot.taskIds, [1]);
      expect(snapshot.loadedAt, monday);
    });
  });
}
