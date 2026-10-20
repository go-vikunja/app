import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
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
  final first = DateTime.utc(2026, 10, 19, 9);
  final second = DateTime.utc(2026, 10, 20, 9);
  const favorites = Project(id: Project.favoritesId, title: 'Favorites');
  const mine = ViewFilter(filter: 'done = false && assignees = alice');

  Project pseudo(int id, String title, DateTime updated) => Project(
    id: id,
    title: title,
    description: 'About $title',
    updated: updated,
  );

  SavedFilter definition(
    int id,
    String title,
    DateTime updated,
    ViewFilter filter,
  ) => SavedFilter(id: id, title: title, filter: filter, updated: updated);

  DefaultSyncEngine engine() {
    final engine = DefaultSyncEngine(
      db: db,
      client: client,
      perPage: 50,
      currentUser: () async => (user: me, settings: settings),
      now: () => now,
    );
    addTearDown(engine.dispose);
    return engine;
  }

  Future<List<SavedFilterRef>> stored() async => decodeSavedFilters(
    (await db.syncStateDao.readAll())[SyncStateKeys.savedFilters],
  );

  List<String> definitionReads() => [
    for (final request in client.requests)
      if (request.startsWith('filter ')) request,
  ];

  setUp(() {
    db = testDatabase();
    now = DateTime.utc(2026, 10, 20, 12);
    settings = const UserSettings();
    client = FakeSyncClient()
      ..allProjects = [sampleProject(id: 1, title: 'Work')]
      ..pseudoProjects = [favorites, pseudo(-14, 'My Open Tasks', first)]
      ..savedFilterDefinitions[13] = definition(
        13,
        'My Open Tasks',
        first,
        mine,
      );
  });

  group('the stored list', () {
    test('keeps the definition, description and updated across an encode '
        'and a decode', () {
      final filters = [
        SavedFilterRef(
          projectId: -14,
          title: 'Mine',
          isFavorite: true,
          description: 'Assigned to me',
          updated: first,
          definition: SavedFilterDefinition(
            filter: const ViewFilter(
              filter: 'done = false',
              search: 'x',
              sortBy: ['due_date'],
              orderBy: ['asc'],
              includeNulls: true,
            ),
            timezone: 'Europe/Berlin',
            updated: first,
          ),
        ),
        const SavedFilterRef(projectId: -3, title: 'Plain'),
      ];

      expect(decodeSavedFilters(encodeSavedFilters(filters)), filters);
    });

    test('an entry stored before definitions reads with none; one that cannot '
        'be read reads as unknown', () {
      expect(
        decodeSavedFilters(
          '[{"project_id": -14, "title": "Mine", "is_favorite": true}, '
          '{"project_id": -3, "title": "Odd", "definition": {"filter": 5}}, '
          '{"project_id": -4, "title": "Odd too", "updated": "never"}]',
        ),
        const [
          SavedFilterRef(projectId: -14, title: 'Mine', isFavorite: true),
          SavedFilterRef(projectId: -3, title: 'Odd'),
          SavedFilterRef(projectId: -4, title: 'Odd too'),
        ],
      );
    });

    test('a definition is outdated when the list names another second', () {
      SavedFilterRef ref(DateTime? listed, DateTime? read) => SavedFilterRef(
        projectId: -14,
        title: 'Mine',
        updated: listed,
        definition: read == null
            ? null
            : SavedFilterDefinition(filter: mine, updated: read),
      );

      expect(needsDefinition(ref(first, null)), isTrue);
      expect(needsDefinition(ref(first, first)), isFalse);
      expect(
        needsDefinition(
          ref(first, first.add(const Duration(milliseconds: 700))),
        ),
        isFalse,
      );
      expect(needsDefinition(ref(second, first)), isTrue);
      expect(needsDefinition(ref(null, null)), isTrue);
      expect(needsDefinition(ref(null, first)), isTrue);
    });

    test('a project list keeps the stored definitions of the filters it '
        'names', () async {
      final known = SavedFilterDefinition(filter: mine, updated: first);
      await storeSavedFilters(db, [
        SavedFilterRef(projectId: -14, title: 'Mine', definition: known),
      ]);

      await storeSavedFilters(db, [
        SavedFilterRef(projectId: -14, title: 'Renamed', updated: second),
        const SavedFilterRef(projectId: -3, title: 'New'),
      ]);

      expect(await stored(), [
        SavedFilterRef(
          projectId: -14,
          title: 'Renamed',
          updated: second,
          definition: known,
        ),
        const SavedFilterRef(projectId: -3, title: 'New'),
      ]);
    });
  });

  group('the sync', () {
    test('a full run reads the definition of every saved filter, after the '
        'project list', () async {
      client
        ..pseudoProjects = [
          favorites,
          pseudo(-14, 'My Open Tasks', first),
          pseudo(-3, 'Urgent', first),
        ]
        ..savedFilterDefinitions[2] = definition(
          2,
          'Urgent',
          first,
          const ViewFilter(filter: 'priority >= 4', includeNulls: true),
        );

      await engine().ensureInitialSync();

      expect(definitionReads(), ['filter 13', 'filter 2']);
      final projectList = client.requests.indexWhere(
        (r) => r.startsWith('projects page'),
      );
      expect(client.requests.indexOf('filter 2'), greaterThan(projectList));
      expect(await stored(), [
        SavedFilterRef(
          projectId: -14,
          title: 'My Open Tasks',
          description: 'About My Open Tasks',
          updated: first,
          definition: SavedFilterDefinition(filter: mine, updated: first),
        ),
        SavedFilterRef(
          projectId: -3,
          title: 'Urgent',
          description: 'About Urgent',
          updated: first,
          definition: SavedFilterDefinition(
            filter: const ViewFilter(
              filter: 'priority >= 4',
              includeNulls: true,
            ),
            updated: first,
          ),
        ),
      ]);
    });

    test('a refresh reads only the definitions whose updated changed, and '
        'drops the filters gone', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      now = now.add(const Duration(hours: 1));
      client.requests.clear();

      await sync.refresh();
      expect(definitionReads(), isEmpty);

      const changed = ViewFilter(filter: 'done = false');
      client
        ..pseudoProjects = [favorites, pseudo(-14, 'Mine', second)]
        ..savedFilterDefinitions[13] = definition(13, 'Mine', second, changed);
      await sync.refresh();

      expect(definitionReads(), ['filter 13']);
      expect(
        (await stored()).single.definition,
        SavedFilterDefinition(filter: changed, updated: second),
      );

      client.pseudoProjects = [favorites];
      await sync.refresh();
      expect(await stored(), isEmpty);
    });

    test('a failed read keeps the previous definition and is tried again '
        'by the next run', () async {
      final sync = engine();
      await sync.ensureInitialSync();
      now = now.add(const Duration(hours: 1));
      client
        ..pseudoProjects = [favorites, pseudo(-14, 'My Open Tasks', second)]
        ..beforeRequest = (request) async {
          if (request == 'filter 13') throw const ServerFailure(500);
        };

      await sync.refresh();

      expect(sync.currentStatus, SyncIdle(lastSyncedAt: now));
      final kept = (await stored()).single;
      expect(kept.updated, second);
      expect(
        kept.definition,
        SavedFilterDefinition(filter: mine, updated: first),
      );
      expect(needsDefinition(kept), isTrue);

      client
        ..beforeRequest = null
        ..savedFilterDefinitions[13] = definition(
          13,
          'My Open Tasks',
          second,
          mine,
        )
        ..requests.clear();
      await sync.refresh();

      expect(definitionReads(), ['filter 13']);
      expect(needsDefinition((await stored()).single), isFalse);
    });

    test('a filter that cannot be read stays without a definition', () async {
      client.savedFilterDefinitions.clear();

      await engine().ensureInitialSync();

      expect(await stored(), [
        SavedFilterRef(
          projectId: -14,
          title: 'My Open Tasks',
          description: 'About My Open Tasks',
          updated: first,
        ),
      ]);
    });

    test('with the definition known, the Overview filter is not downloaded '
        'and a download left from before goes', () async {
      settings = const UserSettings(filterIdUsedOnOverview: -14);
      await db.listSnapshotsDao.replace(overviewSnapshotKey(-14), {
        1: 0,
      }, loadedAt: now);

      await engine().ensureInitialSync();

      expect(client.requests.where((r) => r.startsWith('project -')), isEmpty);
      expect(
        (await db.listSnapshotsDao.load(overviewSnapshotKey(-14))).loadedAt,
        isNull,
      );
    });

    test('the list download of a saved filter goes once its definition is '
        'known and evaluable; one the device cannot evaluate keeps '
        'its', () async {
      client
        ..pseudoProjects = [
          favorites,
          pseudo(-14, 'My Open Tasks', first),
          pseudo(-3, 'Column', first),
        ]
        ..savedFilterDefinitions[2] = definition(
          2,
          'Column',
          first,
          const ViewFilter(filter: 'bucket_id = 4'),
        );
      final sync = engine();
      await sync.ensureInitialSync();
      for (final id in [-14, -3]) {
        await db.listSnapshotsDao.replace(savedFilterSnapshotKey(id), {
          1: 0,
        }, loadedAt: now);
      }
      Future<DateTime?> loaded(int id) async =>
          (await db.listSnapshotsDao.load(savedFilterSnapshotKey(id))).loadedAt;

      now = now.add(const Duration(hours: 1));
      await sync.refresh();

      expect(await loaded(-14), isNull);
      expect(await loaded(-3), isNotNull);
    });

    test('with an unknown definition, the Overview filter is downloaded as '
        'before', () async {
      settings = const UserSettings(filterIdUsedOnOverview: -14);
      client
        ..savedFilterDefinitions.clear()
        ..savedFilterTasks[-14] = {};

      await engine().ensureInitialSync();

      expect(client.requests.where((r) => r.startsWith('project -14')), [
        'project -14 tasks done = false sort=id desc per_page=50 page=1',
      ]);
    });
  });
}
