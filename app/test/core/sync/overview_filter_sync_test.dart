import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
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
  var settings = const UserSettings();
  final base = DateTime.utc(2026, 10, 10, 9);
  final monday = DateTime.utc(2026, 10, 12, 9);
  final friday = DateTime.utc(2026, 10, 16, 9);
  const favorites = Project(id: Project.favoritesId, title: 'Favorites');
  const myOpenTasks = Project(id: -14, title: 'My Open Tasks');
  const urgentOnes = Project(id: -3, title: 'Urgent');
  const overviewRequest =
      'project -14 tasks done = false sort=id desc per_page=50 page=1';

  Task task(int id, {DateTime? due, bool done = false}) => sampleTask(
    id: id,
    title: 'Task $id',
    due: due,
    done: done,
    updated: base,
  );

  DefaultSyncEngine engine({bool headless = false}) {
    final engine = DefaultSyncEngine(
      db: db,
      client: client,
      perPage: 50,
      currentUser: () async => (user: me, settings: settings),
      now: () => now,
      headless: headless,
    );
    addTearDown(engine.dispose);
    return engine;
  }

  Future<List<SavedFilterRef>> storedFilters() async => decodeSavedFilters(
    (await db.syncStateDao.readAll())[SyncStateKeys.savedFilters],
  );

  Future<ListSnapshot> overviewSnapshot([int id = -14]) =>
      db.listSnapshotsDao.load(overviewSnapshotKey(id));

  setUp(() {
    db = testDatabase();
    now = DateTime.utc(2026, 10, 10, 12);
    settings = const UserSettings();
    client = FakeSyncClient()
      ..allProjects = [sampleProject(id: 1, title: 'Work')]
      ..pseudoProjects = [favorites, myOpenTasks]
      ..allTasks = [
        task(1),
        task(2, due: friday),
        task(3, due: monday),
        task(4, done: true),
        task(5),
      ]
      ..savedFilterTasks[-14] = {1, 2, 3, 4};
  });

  group('saved filters', () {
    test('a full run records them from the project list, without '
        'Favorites', () async {
      client.pseudoProjects = [favorites, myOpenTasks, urgentOnes];

      await engine().ensureInitialSync();

      expect(await storedFilters(), const [
        SavedFilterRef(projectId: -14, title: 'My Open Tasks'),
        SavedFilterRef(projectId: -3, title: 'Urgent'),
      ]);
      expect((await db.projectsDao.loadAll()).map((project) => project.id), [
        1,
      ]);
    });

    test('a refresh follows a rename and a removal', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      now = now.add(const Duration(hours: 1));

      client.pseudoProjects = [
        favorites,
        const Project(id: -14, title: 'Mine'),
      ];
      await sync.refresh();

      expect(await storedFilters(), const [
        SavedFilterRef(projectId: -14, title: 'Mine'),
      ]);

      client.pseudoProjects = [favorites];
      await sync.refresh();

      expect(await storedFilters(), isEmpty);
      expect(
        (await db.syncStateDao.readAll()).containsKey(
          SyncStateKeys.savedFilters,
        ),
        isFalse,
      );
    });

    test('are written only when they change', () async {
      const filters = [
        SavedFilterRef(projectId: -14, title: 'Mine', isFavorite: true),
      ];
      await storeSavedFilters(db, filters);
      var writes = 0;
      final subscription = db.tableUpdates().listen((_) => writes++);
      addTearDown(subscription.cancel);

      await storeSavedFilters(db, filters);
      await pumpEventQueue();

      expect(writes, 0);
      expect(await storedFilters(), filters);
    });

    test('every run records which are favourites', () async {
      client.pseudoProjects = [
        favorites,
        myOpenTasks,
        const Project(id: -3, title: 'Urgent', isFavorite: true),
      ];
      final sync = engine();

      await sync.ensureInitialSync();

      expect(await storedFilters(), const [
        SavedFilterRef(projectId: -14, title: 'My Open Tasks'),
        SavedFilterRef(projectId: -3, title: 'Urgent', isFavorite: true),
      ]);

      client.pseudoProjects = [
        favorites,
        const Project(id: -14, title: 'My Open Tasks', isFavorite: true),
        urgentOnes,
      ];
      now = now.add(const Duration(hours: 1));
      await sync.refresh();

      expect(await storedFilters(), const [
        SavedFilterRef(
          projectId: -14,
          title: 'My Open Tasks',
          isFavorite: true,
        ),
        SavedFilterRef(projectId: -3, title: 'Urgent'),
      ]);
    });

    test('filters stored before the favourite flag read as no favourite '
        'and are rewritten by the next run', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      await db.syncStateDao.write({
        SyncStateKeys.savedFilters:
            '[{"project_id": -14, "title": "My Open Tasks"}, '
            '{"project_id": -3, "title": "Urgent", "is_favorite": "yes"}]',
      });

      expect(await storedFilters(), const [
        SavedFilterRef(projectId: -14, title: 'My Open Tasks'),
        SavedFilterRef(projectId: -3, title: 'Urgent'),
      ]);

      now = now.add(const Duration(hours: 1));
      await sync.refresh();

      expect(
        (await db.syncStateDao.readAll())[SyncStateKeys.savedFilters],
        '[{"project_id":-14,"title":"My Open Tasks","is_favorite":false}]',
      );
    });

    test('the downloads of filters the list no longer names go, in full and '
        'incremental runs; the others and the Overview stay', () async {
      client.pseudoProjects = [favorites, myOpenTasks, urgentOnes];
      settings = const UserSettings(filterIdUsedOnOverview: -14);
      final sync = engine();
      await sync.ensureInitialSync();
      for (final id in [-14, -3, -99]) {
        await db.listSnapshotsDao.replace(savedFilterSnapshotKey(id), {
          1: 0,
        }, loadedAt: now);
      }
      await db.listSnapshotsDao.replace('view:70', {1: 0}, loadedAt: now);
      Future<DateTime?> loaded(int id) async =>
          (await db.listSnapshotsDao.load(savedFilterSnapshotKey(id))).loadedAt;

      now = now.add(const Duration(hours: 1));
      await sync.refresh();

      // -99 was never listed: a download that finished after its filter
      // went goes with the next run although the list did not change.
      expect(await loaded(-99), isNull);
      expect(await loaded(-14), isNotNull);
      expect(await loaded(-3), isNotNull);
      expect((await overviewSnapshot()).loadedAt, isNotNull);

      client.pseudoProjects = [favorites, myOpenTasks];
      await sync.refresh();

      expect(await loaded(-3), isNull);
      expect(await loaded(-14), isNotNull);
      expect((await overviewSnapshot()).loadedAt, isNotNull);

      client.pseudoProjects = [favorites];
      await sync.fullResync();

      expect(await loaded(-14), isNull);
      expect((await db.listSnapshotsDao.load('view:70')).loadedAt, isNotNull);
    });

    test('a list that pages repeats them on every page', () async {
      client
        ..allProjects = [
          for (var id = 1; id <= 5; id++) sampleProject(id: id, title: '$id'),
        ]
        ..pseudoProjects = [favorites, myOpenTasks];
      final sync = DefaultSyncEngine(
        db: db,
        client: client,
        perPage: 2,
        currentUser: () async => (user: me, settings: settings),
        now: () => now,
      );
      addTearDown(sync.dispose);

      await sync.ensureInitialSync();

      expect(await storedFilters(), const [
        SavedFilterRef(projectId: -14, title: 'My Open Tasks'),
      ]);
    });
  });

  group('Overview filter', () {
    test('nothing is downloaded while the user picked none', () async {
      await engine().ensureInitialSync();

      expect(client.requests.where((r) => r.startsWith('project -')), isEmpty);
      expect((await overviewSnapshot()).loadedAt, isNull);
    });

    test("a full run downloads the picked filter's open tasks after the "
        'tasks, by due date', () async {
      settings = const UserSettings(filterIdUsedOnOverview: -14);

      await engine().ensureInitialSync();

      expect(client.requests.where((r) => r.startsWith('project -')), [
        overviewRequest,
      ]);
      final query = client.tasks.queries.last;
      expect(query.filter, 'done = false');
      expect(query.sort.map((sort) => (sort.field, sort.descending)), [
        (TaskSortField.dueDate, false),
        (TaskSortField.id, true),
      ]);
      final snapshot = await overviewSnapshot();
      expect(snapshot.taskIds, [3, 2, 1]);
      expect(snapshot.loadedAt, now);
      final lastTaskPage = client.requests.lastIndexWhere(
        (r) => r.startsWith('tasks '),
      );
      expect(
        client.requests.indexOf(overviewRequest),
        greaterThan(lastTaskPage),
      );
    });

    test('a refresh downloads it again, and a background run too', () async {
      settings = const UserSettings(filterIdUsedOnOverview: -14);
      await engine().ensureInitialSync();
      client.savedFilterTasks[-14] = {1, 5};
      now = now.add(const Duration(hours: 1));
      client.requests.clear();

      await engine().refresh();

      expect(client.requests.last, overviewRequest);
      expect((await overviewSnapshot()).taskIds, [5, 1]);
      expect((await overviewSnapshot()).loadedAt, now);

      client.savedFilterTasks[-14] = {5};
      now = now.add(const Duration(hours: 1));
      client.requests.clear();
      await engine(headless: true).refresh();

      expect(client.requests.last, overviewRequest);
      expect((await overviewSnapshot()).taskIds, [5]);
    });

    test('its request counts in the refresh, which logs them', () async {
      settings = const UserSettings(filterIdUsedOnOverview: -14);
      await engine().ensureInitialSync();
      now = now.add(const Duration(hours: 1));
      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      addTearDown(() => Logger.root.level = Level.INFO);
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);

      await engine().refresh();

      expect(records.map((r) => r.message), contains(endsWith(': 5 requests')));
      expect(
        records.where((r) => r.level >= Level.INFO).map((r) => r.message),
        everyElement(isNot(contains('My Open Tasks'))),
      );
    });

    test('an unchanged result is not written again', () async {
      settings = const UserSettings(filterIdUsedOnOverview: -14);
      await engine().ensureInitialSync();
      final first = now;
      now = now.add(const Duration(hours: 1));

      await engine().refresh();

      expect((await overviewSnapshot()).loadedAt, first);
    });

    test('a failed download is logged and the run completes with the '
        'previous one', () async {
      settings = const UserSettings(filterIdUsedOnOverview: -14);
      await engine().ensureInitialSync();
      now = now.add(const Duration(hours: 1));
      client.beforeRequest = (request) async {
        if (request.startsWith('project -14')) {
          throw const ServerFailure(500);
        }
      };
      final sync = engine();

      await sync.refresh();
      await sync.fullResync();

      expect(sync.currentStatus, SyncIdle(lastSyncedAt: now));
      expect((await overviewSnapshot()).taskIds, [3, 2, 1]);
    });

    test('a filter the project list no longer names is not downloaded, and '
        'unpicking one drops its download', () async {
      settings = const UserSettings(filterIdUsedOnOverview: -14);
      await engine().ensureInitialSync();
      now = now.add(const Duration(hours: 1));

      client.pseudoProjects = [favorites];
      client.requests.clear();
      await engine().refresh();

      expect(client.requests.where((r) => r.startsWith('project -')), isEmpty);
      expect((await overviewSnapshot()).loadedAt, isNull);
    });

    test('picking another filter replaces the download', () async {
      client
        ..pseudoProjects = [favorites, myOpenTasks, urgentOnes]
        ..savedFilterTasks[-3] = {5};
      settings = const UserSettings(filterIdUsedOnOverview: -14);
      await engine().ensureInitialSync();

      settings = const UserSettings(filterIdUsedOnOverview: -3);
      now = now.add(const Duration(hours: 1));
      await engine().refresh();

      expect((await overviewSnapshot(-3)).taskIds, [5]);
      expect((await overviewSnapshot()).loadedAt, isNull);
    });
  });

  test('a full resync keeps the list preferences and the view '
      'downloads', () async {
    final sync = engine();
    await sync.ensureInitialSync();
    final preferences = LocalListPreferences(db);
    await preferences.rememberView(1, 70);
    await db.listSnapshotsDao.replace('view:70', {1: 1}, loadedAt: now);
    now = now.add(const Duration(hours: 1));

    await sync.fullResync();

    expect(await preferences.lastViewOf(1), 70);
    expect((await db.listSnapshotsDao.load('view:70')).positions, {1: 1});
  });
}
