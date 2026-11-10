@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/sync/archived_projects.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/core/sync/task_filters.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

// Every API version gets a user of its own, so that the tasks changed within
// the overlap window stay below two pages and the no-change refresh has a
// known request budget. "Live" holds 34 open and 6 done tasks, every tenth
// labelled alpha and every fifteenth beta; "Soon archived" holds three.
typedef _Seed = ({
  int liveId,
  int soonArchivedId,
  int alphaId,
  int betaId,
  List<int> liveTaskIds,
  List<int> soonArchivedTaskIds,
});

// Small enough that everything changed within the overlap window fits one
// page of the server's size, which keeps the no-change refresh at four
// requests.
const _liveTasks = 40;
const _liveOpen = 34;
const _soonArchivedTasks = 3;

Future<_Seed> _seed(Seeder seeder) async {
  final liveId = await seeder.create('/projects', {'title': 'Live'});
  final soonArchivedId = await seeder.create('/projects', {
    'title': 'Soon archived',
  });
  final alphaId = await seeder.create('/labels', {'title': 'alpha'});
  final betaId = await seeder.create('/labels', {'title': 'beta'});
  final liveTaskIds = <int>[];
  for (var i = 1; i <= _liveTasks; i++) {
    final id = await seeder.create('/projects/$liveId/tasks', {
      'title': 'Task $i',
      'done': i > _liveOpen,
    });
    liveTaskIds.add(id);
    if (i % 10 == 0) {
      await seeder.post('/tasks/$id/labels', {'label_id': alphaId});
    }
    if (i % 15 == 0) {
      await seeder.post('/tasks/$id/labels', {'label_id': betaId});
    }
  }
  final soonArchivedTaskIds = [
    for (var i = 1; i <= _soonArchivedTasks; i++)
      await seeder.create('/projects/$soonArchivedId/tasks', {
        'title': 'Soon $i',
      }),
  ];
  return (
    liveId: liveId,
    soonArchivedId: soonArchivedId,
    alphaId: alphaId,
    betaId: betaId,
    liveTaskIds: liveTaskIds,
    soonArchivedTaskIds: soonArchivedTaskIds,
  );
}

final _keysetContinuation = RegExp(
  r"^\(updated > '([^']+)'\) \|\| \(updated > '([^']+)' && id > (\d+)\)$",
);

typedef _Exchange = ({Uri uri, List<Object?> items});

/// A server timestamp at the second, like the engine's filter values.
DateTime _second(Object? rfc3339) {
  final moment = DateTime.parse(rfc3339! as String).toUtc();
  return DateTime.utc(
    moment.year,
    moment.month,
    moment.day,
    moment.hour,
    moment.minute,
    moment.second,
  );
}

bool _isDelta(Uri uri) =>
    uri.path.endsWith('/tasks') &&
    !uri.path.contains('/projects/') &&
    uri.queryParameters.containsKey('filter');

void main() {
  group(
    'incremental sync against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        test("mirrors the web's changes after one refresh over "
            '${apiVersion.pathSegment}', () async {
          final user = await registerAndLogin(dio, connection);
          final seeder = Seeder(dio, connection, user);
          final seed = await _seed(seeder);
          final only = onlyApiVersion(connection, apiVersion);
          final requests = <Uri>[];
          // v2 answers with an envelope, v1 with a bare array.
          final exchanges = <_Exchange>[];
          final authenticated = createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
            interceptors: [
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  requests.add(options.uri);
                  handler.next(options);
                },
                onResponse: (response, handler) {
                  final items = switch (response.data) {
                    {'items': final List<Object?> items} => items,
                    final List<Object?> items => items,
                    _ => const <Object?>[],
                  };
                  exchanges.add((
                    uri: response.requestOptions.uri,
                    items: items,
                  ));
                  handler.next(response);
                },
              ),
            ],
          );
          final client = createReadClient(dio: authenticated, connection: only);
          final currentUser = AccountApi(
            authenticated,
            only,
          ).currentUserWithSettings;
          final db = testDatabase();
          // Five per page, so the delta of the seed spans many keyset pages.
          final log = <String>[];
          final logging = Logger('SyncEngine').onRecord.listen(
            (record) => log.add('${record.level.name} ${record.message}'),
          );
          addTearDown(logging.cancel);
          final engine = DefaultSyncEngine(
            db: db,
            client: client,
            perPage: 5,
            currentUser: currentUser,
          );
          addTearDown(engine.dispose);

          await engine.ensureInitialSync();

          expect(await db.tasksDao.count(), _liveTasks + _soonArchivedTasks);
          final state = await db.syncStateDao.readAll();
          expect(state[SyncStateKeys.watermark], isNotNull);
          expect(state[SyncStateKeys.lastFullSyncAt], isNotNull);
          requests.clear();
          exchanges.clear();

          // What the web does meanwhile. The server refuses edits in an
          // archived project (3008), so the edit comes before the archive;
          // archiving bumps the project's `updated`, which routes the
          // delta through the project.
          final liveIds = seed.liveTaskIds;
          final createdIds = [
            await seeder.create('/projects/${seed.liveId}/tasks', {
              'title': 'Created 1',
            }),
            await seeder.create('/projects/${seed.liveId}/tasks', {
              'title': 'Created 2',
            }),
          ];
          await seeder.patch('/tasks/${liveIds[0]}', {
            'title': 'Task 1 edited',
          });
          await seeder.post('/tasks/${liveIds[0]}/labels', {
            'label_id': seed.alphaId,
          });
          await seeder.patch('/tasks/${liveIds[1]}', {'done': true});
          await seeder.delete('/tasks/${liveIds[2]}');
          await seeder.delete('/tasks/${liveIds[3]}');
          final targetId = await seeder.create('/projects', {
            'title': 'Target',
          });
          await seeder.patch('/tasks/${liveIds[4]}', {'project_id': targetId});
          final freshId = await seeder.create('/projects', {'title': 'Fresh'});
          final freshIds = [
            for (var i = 1; i <= 3; i++)
              await seeder.create('/projects/$freshId/tasks', {
                'title': 'Fresh $i',
              }),
          ];
          await seeder.patch('/tasks/${seed.soonArchivedTaskIds[0]}', {
            'title': 'Soon 1 edited',
          });
          await seeder.patch('/projects/${seed.soonArchivedId}', {
            'is_archived': true,
          });
          await seeder.delete('/labels/${seed.betaId}');
          await seeder.patch('/labels/${seed.alphaId}', {
            'title': 'alpha renamed',
          });

          await engine.refresh();

          printOnFailure(
            [
              ...log,
              for (final uri in requests) '${uri.path}?${uri.query}',
            ].join('\n'),
          );

          final projects = await db.projectsDao.loadAll();
          expect(projects.map((p) => p.title).toSet(), {
            'Inbox',
            'Live',
            'Soon archived',
            'Target',
            'Fresh',
          });
          expect(
            projects.singleWhere((p) => p.id == seed.soonArchivedId).isArchived,
            isTrue,
          );
          // Counts per project, against the server's own.
          for (final project in projects) {
            final page = await client.tasks.listInProject(
              project.id,
              const TaskQuery(perPage: 1),
            );
            expect(
              await db.tasksDao.countInProject(project.id),
              page.total ?? page.totalPages,
              reason: 'count of ${project.title}',
            );
          }
          expect(
            await db.tasksDao.countInProject(seed.liveId),
            _liveTasks + 2 - 2 - 1,
          );
          expect(await db.tasksDao.countInProject(targetId), 1);
          expect(await db.tasksDao.countInProject(freshId), 3);
          expect(
            await db.tasksDao.countInProject(seed.soonArchivedId),
            _soonArchivedTasks,
          );
          final edited = (await db.tasksDao.find(liveIds[0]))!;
          expect(edited.title, 'Task 1 edited');
          expect(edited.labels.map((l) => l.title), ['alpha renamed']);
          expect((await db.tasksDao.find(liveIds[1]))!.done, isTrue);
          expect(await db.tasksDao.find(liveIds[2]), isNull);
          expect(await db.tasksDao.find(liveIds[3]), isNull);
          expect((await db.tasksDao.find(liveIds[4]))!.projectId, targetId);
          for (final id in createdIds) {
            expect((await db.tasksDao.find(id))!.projectId, seed.liveId);
          }
          for (final id in freshIds) {
            expect((await db.tasksDao.find(id))!.projectId, freshId);
          }
          expect(
            (await db.tasksDao.find(seed.soonArchivedTaskIds[0]))!.title,
            'Soon 1 edited',
          );
          expect((await db.labelsDao.loadAll()).map((l) => l.title), [
            'alpha renamed',
          ]);
          // Task 15 carried beta, task 10 alpha; neither task was edited.
          expect((await db.tasksDao.find(liveIds[14]))!.labels, isEmpty);
          expect(
            (await db.tasksDao.find(liveIds[9]))!.labels.map((l) => l.title),
            ['alpha renamed'],
          );

          // The keyset over (updated, id) on this API version: the first
          // delta page from below the watermark, every later one with the
          // parenthesized continuation, all answered (a rejected filter
          // would have failed the run), sorted by updated then id.
          // The count probe asks /tasks without a filter.
          final deltaRequests = [
            for (final uri in requests)
              if (_isDelta(uri)) uri,
          ];
          final deltaFilters = [
            for (final uri in deltaRequests) uri.queryParameters['filter']!,
          ];
          expect(deltaFilters.first, startsWith("updated >= '"));
          expect(deltaFilters, hasLength(greaterThan(3)));
          expect(
            deltaFilters.skip(1),
            everyElement(matches(_keysetContinuation)),
          );
          for (final uri in deltaRequests) {
            expect(uri.queryParametersAll['sort_by'], ['updated', 'id']);
            expect(uri.queryParametersAll['order_by'], ['asc', 'asc']);
          }
          // Every continuation asks from the last item of the page before
          // it, and at least one page boundary fell inside a second: the
          // next page then opens with that second again, which is the tie
          // clause working on the live server (`>` on `U − 1 s` means
          // `>= U` there).
          final deltaPages = [
            for (final exchange in exchanges)
              if (_isDelta(exchange.uri)) exchange,
          ];
          expect(deltaPages, hasLength(deltaRequests.length));
          var tiesInsideASecond = 0;
          for (var i = 1; i < deltaPages.length; i++) {
            final filter = deltaPages[i].uri.queryParameters['filter']!;
            final match = _keysetContinuation.firstMatch(filter)!;
            final cursorSecond = DateTime.parse(match.group(1)!);
            final cursorId = int.parse(match.group(3)!);
            expect(
              DateTime.parse(match.group(2)!),
              cursorSecond.subtract(const Duration(seconds: 1)),
            );
            final before =
                deltaPages[i - 1].items.last! as Map<String, Object?>;
            expect(_second(before['updated']), cursorSecond);
            expect(before['id'], cursorId);
            final items = deltaPages[i].items;
            if (items.isNotEmpty) {
              final first = items.first! as Map<String, Object?>;
              expect(first['id'], isNot(cursorId));
              if (_second(first['updated']) == cursorSecond) {
                tiesInsideASecond++;
              }
            }
          }
          expect(
            tiesInsideASecond,
            greaterThan(0),
            reason: 'no delta page boundary fell inside one second',
          );
          bool asked(int projectId, bool Function(String? filter) test) =>
              requests.any(
                (uri) =>
                    uri.path.endsWith('/projects/$projectId/tasks') &&
                    test(uri.queryParameters['filter']),
              );
          expect(
            asked(seed.soonArchivedId, (f) => f!.startsWith("updated >= '")),
            isTrue,
            reason: 'the archived project gets its delta through the project',
          );
          expect(
            asked(freshId, (f) => f == 'id > 0'),
            isTrue,
            reason: 'a new project is pulled whole',
          );
          expect(
            asked(seed.liveId, (f) => f == 'id > 0'),
            isTrue,
            reason: 'two deletes make the count differ',
          );

          // Nothing changed, and long enough ago that nothing lies within
          // the overlap window any more: projects, labels, an empty delta
          // and the live count probe.
          final watermark = DateTime.parse(
            (await db.syncStateDao.readAll())[SyncStateKeys.watermark]!,
          );
          await db.syncStateDao.write({
            SyncStateKeys.watermark: watermark
                .add(DefaultSyncEngine.catchUpOverlap * 2)
                .toIso8601String(),
          });
          final quiet = DefaultSyncEngine(
            db: db,
            client: client,
            perPage: only.info.maxItemsPerPage,
            currentUser: currentUser,
          );
          addTearDown(quiet.dispose);
          requests.clear();

          await quiet.refresh();

          // Every run reads the user's settings first.
          expect(requests.map((uri) => uri.pathSegments.last), [
            'user',
            'projects',
            'labels',
            'tasks',
            'tasks',
          ]);
          expect(requests.last.queryParameters['per_page'], '1');
          expect(
            await db.tasksDao.count(),
            _liveTasks + 2 - 2 + 3 + _soonArchivedTasks,
          );
        });

        test('the newest `updated` up to a bound leaves out the tasks above '
            'it over ${apiVersion.pathSegment}', () async {
          final user = await registerAndLogin(dio, connection);
          final seeder = Seeder(dio, connection, user);
          final projectId = await seeder.create('/projects', {'title': 'P'});
          final firstId = await seeder.create('/projects/$projectId/tasks', {
            'title': 'First',
          });
          // The server's timestamps have second precision.
          await Future<void>.delayed(const Duration(milliseconds: 2100));
          final secondId = await seeder.create('/projects/$projectId/tasks', {
            'title': 'Second',
          });
          final only = onlyApiVersion(connection, apiVersion);
          final client = createReadClient(
            dio: createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            ),
            connection: only,
          );
          Future<Task?> newestUntil(DateTime bound) async =>
              (await client.tasks.list(
                TaskQuery(
                  filter: TaskFilters.updatedUntil(bound),
                  sort: TaskFilters.byUpdatedDescending,
                  perPage: 1,
                ),
              )).items.firstOrNull;

          final second = (await newestUntil(
            DateTime.now().toUtc().add(DefaultSyncEngine.clockTolerance),
          ))!;
          expect(second.id, secondId);
          final atSecond = await newestUntil(second.updated!);
          expect(atSecond?.id, secondId);
          final below = await newestUntil(
            second.updated!.subtract(const Duration(seconds: 1)),
          );
          expect(below?.id, firstId);
          expect(await newestUntil(DateTime.utc(2000)), isNull);
        });

        test('a favourite in an archived project counts on both sides, so '
            "no project's count is walked after the archive over "
            '${apiVersion.pathSegment}', () async {
          final user = await registerAndLogin(dio, connection);
          final seeder = Seeder(dio, connection, user);
          final liveId = await seeder.create('/projects', {'title': 'Live'});
          final starredId = await seeder.create('/projects', {
            'title': 'Starred',
          });
          final childId = await seeder.create('/projects', {
            'title': 'Starred child',
            'parent_project_id': starredId,
          });
          for (var i = 1; i <= 3; i++) {
            await seeder.create('/projects/$liveId/tasks', {
              'title': 'Live $i',
            });
          }
          await seeder.create('/projects/$starredId/tasks', {
            'title': 'Favourite',
            'is_favorite': true,
          });
          await seeder.create('/projects/$starredId/tasks', {'title': 'Plain'});
          await seeder.create('/projects/$childId/tasks', {
            'title': 'Done favourite below',
            'is_favorite': true,
            'done': true,
          });
          final only = onlyApiVersion(connection, apiVersion);
          final requests = <Uri>[];
          final authenticated = createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
            interceptors: [
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  requests.add(options.uri);
                  handler.next(options);
                },
              ),
            ],
          );
          final client = createReadClient(dio: authenticated, connection: only);
          final db = testDatabase();
          final engine = DefaultSyncEngine(
            db: db,
            client: client,
            perPage: only.info.maxItemsPerPage,
            currentUser: AccountApi(
              authenticated,
              only,
            ).currentUserWithSettings,
          );
          addTearDown(engine.dispose);
          await engine.ensureInitialSync();
          await seeder.patch('/projects/$starredId', {'is_archived': true});
          Iterable<Uri> countWalk() => requests.where(
            (uri) =>
                uri.path.contains('/projects/') &&
                uri.path.endsWith('/tasks') &&
                uri.queryParameters['per_page'] == '1',
          );
          requests.clear();

          await engine.refresh();

          printOnFailure(
            [for (final uri in requests) '${uri.path}?${uri.query}'].join('\n'),
          );
          expect(countWalk(), isEmpty);
          final archived = archivedProjectIds(await db.projectsDao.loadAll());
          expect(archived, unorderedEquals([starredId, childId]));
          final probe = await client.tasks.list(const TaskQuery(perPage: 1));
          expect(probe.total ?? probe.totalPages, 3 + 2);
          expect(await db.tasksDao.countAcrossProjects(archived), 3 + 2);
          requests.clear();

          await engine.refresh();

          expect(requests.map((uri) => uri.pathSegments.last), [
            'user',
            'projects',
            'labels',
            'tasks',
            'tasks',
          ]);
          expect(
            (await db.syncStateDao.readAll())[SyncStateKeys.unexplainedTotals],
            isNull,
          );
        });
      }
    },
  );
}
