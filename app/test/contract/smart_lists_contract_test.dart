@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

const _zone = 'Europe/Berlin';

List<int> _ids(Iterable<Task> tasks) => [for (final task in tasks) task.id];

void main() {
  group('smart lists against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;
    late TestUser user;
    late Seeder seeder;
    late int soonPseudoId;
    late int myOpenTasksPseudoId;
    late List<int> mineOpen;
    late int notMine;
    late int archivedFavorite;

    Future<List<Map<String, Object?>>> v2Items(
      String path,
      Map<String, Object> query,
    ) async {
      final v2 = connection.apiBaseUri(ApiVersion.v2);
      final response = await despiteWriteRaces(
        () => dio.getUri<Map<String, Object?>>(
          v2.replace(path: '${v2.path}$path', queryParameters: query),
          options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
        ),
      );
      return [
        for (final item in response.data!['items']! as List<Object?>)
          item! as Map<String, Object?>,
      ];
    }

    Future<List<int>> serverOpenTasks(int projectId) async => [
      for (final item in await v2Items('/projects/$projectId/tasks', {
        'filter': 'done = false',
        'filter_timezone': _zone,
        'sort_by': ['due_date', 'id'],
        'order_by': ['asc', 'desc'],
        'per_page': '50',
      }))
        item['id']! as int,
    ];

    Future<T> paced<T>(Future<T> Function() write) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return await write();
    }

    Future<int> task(
      int projectId,
      String title, [
      Map<String, Object?>? more,
    ]) => paced(
      () => seeder.create('/projects/$projectId/tasks', {
        'title': title,
        ...?more,
      }),
    );

    Future<void> assignMe(int taskId) => paced(
      () => seeder.post('/tasks/$taskId/assignees', {'user_id': user.id}),
    );

    setUpAll(() async {
      dio = contractDio();
      connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
      user = await registerAndLogin(dio, connection);
      seeder = Seeder(dio, connection, user);
      final now = DateTime.now().toUtc();
      String due(Duration offset) => now.add(offset).toIso8601String();

      final smartId = await paced(
        () => seeder.create('/projects', {'title': 'Smart'}),
      );
      final archiveId = await paced(
        () => seeder.create('/projects', {'title': 'Archive'}),
      );
      final soon = await task(smartId, 'Mine soon', {
        'due_date': due(const Duration(hours: 2)),
      });
      final later = await task(smartId, 'Mine in 3 days', {
        'due_date': due(const Duration(days: 3)),
      });
      final undated = await task(smartId, 'Mine undated');
      final done = await task(smartId, 'Mine done', {'done': true});
      await task(smartId, 'In 10 days', {
        'due_date': due(const Duration(days: 10)),
      });
      notMine = await task(smartId, 'Not mine', {
        'due_date': due(const Duration(hours: 1)),
      });
      for (final id in [soon, later, undated, done]) {
        await assignMe(id);
      }
      mineOpen = [soon, later, undated];
      archivedFavorite = await task(archiveId, 'Archived favourite', {
        'is_favorite': true,
      });
      await paced(
        () => seeder.patch('/projects/$archiveId', {'is_archived': true}),
      );

      final filterId = await paced(
        () => seeder.create('/filters', {
          'title': 'Due this week or so',
          'filters': {
            'filter': 'done = false && due_date < now/d+7d',
            'filter_include_nulls': false,
          },
          'is_favorite': true,
        }),
      );
      soonPseudoId = -filterId - 1;
      final projects = await v2Items('/projects', {'per_page': '50'});
      myOpenTasksPseudoId = projects
          .where((project) => project['title'] == 'My Open Tasks')
          .map((project) => project['id']! as int)
          .single;

      // The web's way since 2.x: a merge patch of the changed keys only.
      await paced(
        () => seeder.patch('/user/settings/general', {
          'timezone': _zone,
          'frontend_settings': {
            'date_display': 'yyyy/mm/dd',
            'time_format': '12h',
            'color_schema': 'light',
            'default_view': 'list',
          },
        }),
      );
    });

    tearDownAll(() => dio.close(force: true));

    for (final apiVersion in ApiVersion.values) {
      group('synced over ${apiVersion.pathSegment}', () {
        late AppDatabase db;
        late DefaultSyncEngine engine;
        late OutboxSender sender;
        late LocalTaskRepository tasks;
        late LocalProjectRepository projects;

        setUpAll(() async {
          final only = onlyApiVersion(connection, apiVersion);
          final authenticated = createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
          );
          final reads = createReadClient(dio: authenticated, connection: only);
          final writes = createWriteClient(
            dio: authenticated,
            connection: only,
          );
          db = testDatabase();
          engine = DefaultSyncEngine(
            db: db,
            client: reads,
            perPage: only.info.maxItemsPerPage,
            currentUser: AccountApi(
              authenticated,
              only,
            ).currentUserWithSettings,
          );
          addTearDown(engine.dispose);
          sender = OutboxSender(
            db: db,
            writeClient: writes,
            readClient: reads,
            sync: engine,
          );
          addTearDown(sender.dispose);
          tasks = LocalTaskRepository(
            db,
            engine,
            sender,
            writes,
            read: reads,
            perPage: only.info.maxItemsPerPage,
          );
          addTearDown(tasks.dispose);
          projects = LocalProjectRepository(db, engine, writes);
          addTearDown(projects.dispose);
          await engine.ensureInitialSync();
        });

        test('the display settings the web saved are stored', () async {
          final settings = decodeUserSettings(
            (await db.syncStateDao.readAll())[SyncStateKeys.userSettings],
          );

          expect(settings.dateDisplay, DateDisplay.yearMonthDaySlashed);
          expect(settings.timeFormat, TimeFormat.twelveHour);
          expect(settings.colorSchema, ColorSchema.light);
          expect(settings.defaultViewKind, ProjectViewKind.list);
          expect(settings.timezone, _zone);
        });

        test('the saved filters come by title with their favourite '
            'flag', () async {
          final filters = await projects.watchSavedFilters().first;

          expect(
            [for (final filter in filters) filter.projectId],
            [soonPseudoId, myOpenTasksPseudoId],
          );
          expect(
            [for (final filter in filters) filter.isFavorite],
            [true, false],
          );
        });

        test("a saved filter's tasks match the server's, relative dates "
            'included', () async {
          for (final (pseudoId, expected) in [
            (myOpenTasksPseudoId, mineOpen),
            (soonPseudoId, [notMine, mineOpen[0], mineOpen[1]]),
          ]) {
            await tasks.refreshSavedFilter(pseudoId);
            final list = await tasks.watchSavedFilterTasks(pseudoId).first;

            // The sync read the definitions, so the device evaluates them.
            expect(list.evaluation, FilterEvaluation.local);
            expect(_ids(list.tasks), await serverOpenTasks(pseudoId));
            expect(_ids(list.tasks), expected);
          }
        });

        test('a task marked as favourite here is a favourite on the server '
            'too; archived projects stay out here', () async {
          await tasks.setFavorite(notMine, favorite: true);
          expect(await tasks.sendPendingChanges(), isNull);
          await engine.refresh();

          final favorites = await tasks.watchFavoriteTasks().first;
          final server = await serverOpenTasks(Project.favoritesId);

          expect(_ids(favorites), [notMine]);
          // The server's Favorites keep archived projects' tasks; the app
          // leaves them out like its Overview.
          expect(server, [notMine, archivedFavorite]);
          expect(
            (await db.syncStateDao.readAll())[SyncStateKeys.savedFilters],
            isNot(contains('"project_id":-1,')),
          );
        });
      });
    }
  });
}
