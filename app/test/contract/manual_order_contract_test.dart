@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/features/projects/application/list_moves.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

typedef _Tree = ({int parent, int first, int second, int loose});

/// The writes are paced, so the SQLite server keeps up with the files
/// running in parallel.
Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

void main() {
  group(
    'manual ordering against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late Seeder seeder;
      late int projectId;
      late int viewId;
      final treeOf = <ApiVersion, _Tree>{};

      Future<int> create(String path, Map<String, Object?> body) async {
        final id = await seeder.create(path, body);
        await _pace();
        return id;
      }

      Future<List<int>> serverOrder() async {
        final v2 = connection.apiBaseUri(ApiVersion.v2);
        final response = await despiteWriteRaces(
          () => dio.getUri<Map<String, Object?>>(
            v2.replace(
              path: '${v2.path}/projects/$projectId/views/$viewId/tasks',
              queryParameters: {'per_page': '50'},
            ),
            options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
          ),
        );
        return [
          for (final item in response.data!['items']! as List<Object?>)
            (item! as Map<String, Object?>)['id']! as int,
        ];
      }

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        user = await registerAndLogin(dio, connection);
        seeder = Seeder(dio, connection, user);

        projectId = await create('/projects', {'title': 'Order'});
        final project = await seeder.get('/projects/$projectId');
        viewId =
            (project['views']! as List<Object?>)
                    .cast<Map<String, Object?>>()
                    .firstWhere((view) => view['view_kind'] == 'list')['id']!
                as int;
        for (var number = 1; number <= 6; number++) {
          await create('/projects/$projectId/tasks', {'title': 'Task $number'});
        }
        await create('/projects/$projectId/tasks', {
          'title': 'Hidden done',
          'done': true,
        });

        for (final version in ApiVersion.values) {
          final name = version.pathSegment;
          final parent = await create('/projects', {'title': 'Parent $name'});
          final first = await create('/projects', {
            'title': 'First $name',
            'parent_project_id': parent,
            'description': '<p>Kept</p>',
            'hex_color': '4caf50',
            'identifier': 'F${user.id}${version.index}',
          });
          await seeder.patch('/projects/$first', {'is_favorite': true});
          await _pace();
          treeOf[version] = (
            parent: parent,
            first: first,
            second: await create('/projects', {
              'title': 'Second $name',
              'parent_project_id': parent,
            }),
            loose: await create('/projects', {'title': 'Loose $name'}),
          );
        }
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          late AppDatabase db;
          late DefaultSyncEngine engine;
          late VikunjaReadClient reads;
          late LocalTaskRepository tasks;
          late LocalProjectRepository projects;

          setUpAll(() async {
            final only = onlyApiVersion(connection, apiVersion);
            final authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            reads = createReadClient(dio: authenticated, connection: only);
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
            final sender = OutboxSender(
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

          Future<void> sendAll() async {
            for (var attempt = 1; ; attempt++) {
              final blocked = await tasks.sendPendingChanges();
              if (blocked == null) return;
              if (attempt == 5) fail('the outbox stays blocked by $blocked');
              await Future<void>.delayed(Duration(seconds: attempt));
            }
          }

          Future<ListSnapshot> snapshot() async =>
              (await tasks.watchProjectList(projectId, viewId: viewId).first)
                  .snapshot;

          test('a reorder drained by the outbox leaves the local list in the '
              "server's order, before and after the next download", () async {
            await tasks.refreshProjectList(projectId, viewId: viewId);
            final before = await snapshot();
            final ids = before.taskIds.toList();
            expect(ids, await serverOrder());
            final positions = before.positions;

            await tasks.positionTask(
              ids.last,
              viewId: viewId,
              position: calculateItemPosition(
                positions[ids[0]],
                positions[ids[1]],
              ),
            );
            await tasks.positionTask(
              ids.first,
              viewId: viewId,
              position: calculateItemPosition(
                positions[ids[ids.length - 2]],
                null,
              ),
            );
            await sendAll();
            await _pace();

            final expected = [
              ids.last,
              ...ids.sublist(1, ids.length - 1),
              ids.first,
            ];
            final source = await tasks
                .watchProjectList(projectId, viewId: viewId)
                .first;
            expect(source.queuedPositions, isEmpty);
            expect(source.snapshot.taskIds, expected);
            expect(await serverOrder(), expected);

            await tasks.refreshProjectList(projectId, viewId: viewId);
            expect((await snapshot()).taskIds, expected);
          });

          test('a task added after the download, with a task moved above it '
              'as the list plans it, ends where it was dropped, here and on '
              'the server', () async {
            await tasks.refreshProjectList(projectId, viewId: viewId);
            await tasks.createTask(
              NewTask(
                projectId: projectId,
                title: 'Added ${apiVersion.pathSegment}',
              ),
            );
            await sendAll();
            await _pace();
            final view = (await db.projectsDao.loadAll())
                .firstWhere((project) => project.id == projectId)
                .views
                .firstWhere((view) => view.id == viewId);
            Future<(ProjectListSource, List<ProjectListRow>)> shown() async {
              final source = await tasks
                  .watchProjectList(projectId, viewId: viewId)
                  .first;
              final model = buildProjectListModel(
                source,
                kind: classifyViewFilter(view.filter),
                preferences: const ViewPreferences(),
              );
              return (source, model.rows);
            }

            List<int> ids(List<ProjectListRow> rows) => [
              for (final row in rows) row.task.id,
            ];

            final (source, rows) = await shown();
            final added = rows.first.task.id;
            expect(source.snapshot.positions, isNot(contains(added)));
            final moved = rows.last.task.id;
            final positions = planListMove(
              listGroupsOf(rows, effectivePositionsOf(source)),
              moved,
              0,
            )!;
            expect(positions.keys, [added, moved]);
            for (final MapEntry(key: taskId, value: position)
                in positions.entries) {
              await tasks.positionTask(
                taskId,
                viewId: viewId,
                position: position,
              );
            }
            final expected = [moved, ...ids(rows).where((id) => id != moved)];
            expect(ids((await shown()).$2), expected);

            await sendAll();
            await _pace();
            expect(ids((await shown()).$2), expected);
            expect(await serverOrder(), expected);
            await tasks.refreshProjectList(projectId, viewId: viewId);
            expect(ids((await shown()).$2), expected);
          });

          test(
            'a reorder, a nest and an un-nest leave the local projects '
            'equal to the server after the sync, every other field kept',
            () async {
              final tree = treeOf[apiVersion]!;
              Future<Project> local(int id) async =>
                  (await db.projectsDao.loadAll()).firstWhere(
                    (p) => p.id == id,
                  );
              Future<void> expectServerAfterSync(Iterable<int> ids) async {
                await engine.refresh();
                for (final id in ids) {
                  expect(await local(id), await reads.projects.read(id));
                }
              }

              final second = await local(tree.second);
              await projects.moveProject(
                tree.first,
                position: calculateItemPosition(second.position, null),
                parentProjectId: tree.parent,
              );
              await _pace();
              expect(
                (await local(tree.first)).position,
                second.position + 65536,
              );
              await expectServerAfterSync([tree.first, tree.second]);

              final moved = await local(tree.first);
              await projects.moveProject(
                tree.loose,
                position: calculateItemPosition(moved.position, null),
                parentProjectId: tree.parent,
              );
              await _pace();
              expect((await local(tree.loose)).parentProjectId, tree.parent);
              await expectServerAfterSync([tree.loose]);

              final topLevel = [
                for (final project in await db.projectsDao.loadAll())
                  if (project.isTopLevel) project,
              ];
              await projects.moveProject(
                tree.loose,
                position: calculateItemPosition(topLevel.last.position, null),
                parentProjectId: 0,
              );
              await _pace();
              await expectServerAfterSync([
                tree.loose,
                tree.first,
                tree.parent,
              ]);

              final kept = await local(tree.first);
              expect(kept.title, 'First ${apiVersion.pathSegment}');
              expect(kept.description, '<p>Kept</p>');
              expect(kept.hexColor, '4caf50');
              expect(kept.identifier, 'F${user.id}${apiVersion.index}');
              expect(kept.isFavorite, isTrue);
              expect(kept.parentProjectId, tree.parent);
              expect((await local(tree.loose)).isTopLevel, isTrue);
            },
          );

          test('a cycle is refused and changes nothing here', () async {
            final tree = treeOf[apiVersion]!;
            final parent = (await db.projectsDao.loadAll()).firstWhere(
              (p) => p.id == tree.parent,
            );

            await expectLater(
              projects.moveProject(
                tree.parent,
                position: parent.position,
                parentProjectId: tree.second,
              ),
              throwsA(isA<DomainError>().having((f) => f.code, 'code', 3011)),
            );

            expect(
              (await db.projectsDao.loadAll()).firstWhere(
                (p) => p.id == tree.parent,
              ),
              parent,
            );
          });
        });
      }
    },
  );
}
