@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_project_view_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/recording_sync_engine.dart';
import '../helpers/sample_data.dart';
import '../helpers/test_database.dart';
import 'helpers.dart';

/// The writes are paced, so the SQLite server keeps up with the files
/// running in parallel.
Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

typedef _Contents = ({Map<String, String> exact, Map<String, String> stored});

/// The projects under [rootId] with their views, and their tasks, as [db]
/// holds them; `stored` without the projects' `updated`, which a write
/// leaves for the sync after it.
Future<_Contents> _contents(AppDatabase db, int rootId) async {
  final projects = await db.projectsDao.loadAll();
  final ids = subtreeIds(projects, rootId);
  final tasks = await db.select(db.tasks).get();
  Map<String, String> describe({required bool updated}) => {
    for (final p in projects)
      if (ids.contains(p.id))
        'project ${p.id}': [
          p.title,
          p.description,
          p.identifier,
          p.hexColor,
          'parent ${p.parentProjectId}',
          if (p.isArchived) 'archived',
          if (p.isFavorite) 'favourite',
          'at ${p.position}',
          if (updated) '${p.updated?.toIso8601String()}',
          for (final v in p.views)
            [
              'view ${v.id} ${v.title} ${v.kind.wireName} at ${v.position}',
              '${v.filter?.filter} ${v.bucketConfigurationMode.wireName}',
              'buckets ${v.defaultBucketId}/${v.doneBucketId}',
            ].join(' '),
        ].join(' | '),
    for (final t in tasks)
      if (ids.contains(t.projectId))
        'task ${t.id}':
            'in ${t.projectId} ${t.identifier} #${t.taskIndex} ${t.title} '
            '${t.done ? 'done' : 'open'}',
  };
  return (exact: describe(updated: true), stored: describe(updated: false));
}

void main() {
  group(
    'project management against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late Seeder seeder;

      setUpAll(() async {
        // A fresh sync goes into a second in-memory database.
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        addTearDown(
          () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
        );
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        user = await registerAndLogin(dio, connection);
        seeder = Seeder(dio, connection, user);
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          final name = apiVersion.pathSegment;
          late ServerConnection only;
          late Dio authenticated;
          late VikunjaReadClient reads;
          late AppDatabase db;
          late DefaultSyncEngine engine;
          // The repositories' sync after a write does nothing, so a check
          // right after it sees the write alone; [engine] syncs on purpose.
          late RecordingSyncEngine quiet;
          late LocalProjectRepository projects;
          late LocalProjectViewRepository views;
          late int rootId;
          late int gardenId;
          late int shedId;

          DefaultSyncEngine engineOn(AppDatabase db) => DefaultSyncEngine(
            db: db,
            client: reads,
            perPage: only.info.maxItemsPerPage,
            currentUser: AccountApi(
              authenticated,
              only,
            ).currentUserWithSettings,
          );

          setUpAll(() async {
            only = onlyApiVersion(connection, apiVersion);
            authenticated = createAuthenticatedDio(
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
            engine = engineOn(db);
            addTearDown(engine.dispose);
            quiet = RecordingSyncEngine();
            projects = LocalProjectRepository(db, quiet, writes);
            addTearDown(projects.dispose);
            views = LocalProjectViewRepository(
              db,
              quiet,
              writes,
              reads,
              perPage: only.info.maxItemsPerPage,
            );
            await engine.ensureInitialSync();
            rootId = await projects.createProject(
              NewProject(title: 'Root $name'),
            );
            await _pace();
          });

          Future<_Contents> freshSync() async {
            final fresh = testDatabase();
            final sync = engineOn(fresh);
            try {
              await sync.ensureInitialSync();
              return await _contents(fresh, rootId);
            } finally {
              await sync.dispose();
            }
          }

          /// Right after a write the database holds what a fresh sync
          /// stores, but the projects' `updated`; after the next sync
          /// everything.
          Future<void> expectLikeFreshSync() async {
            await _pace();
            final fresh = await freshSync();
            expect((await _contents(db, rootId)).stored, fresh.stored);
            await engine.refresh();
            expect((await _contents(db, rootId)).exact, fresh.exact);
          }

          Future<Project> local(int id) async =>
              (await db.projectsDao.loadProject(id))!;

          test('a new project with a parent and a colour', () async {
            gardenId = await projects.createProject(
              NewProject(
                title: 'Garden $name',
                parentProjectId: rootId,
                hexColor: 'ff851b',
              ),
            );

            final created = await local(gardenId);
            expect(created.parentProjectId, rootId);
            expect(created.views, hasLength(4));
            await expectLikeFreshSync();
          });

          test('an edit of title, colour and identifier, which renames the '
              'stored tasks', () async {
            for (final title in ['Water', 'Weed']) {
              await seeder.create('/projects/$gardenId/tasks', {
                'title': title,
              });
              await _pace();
            }
            await engine.refresh();
            final identifier = 'g${user.id}${apiVersion.index}';

            await projects.updateProject(
              gardenId,
              ProjectChanges(
                title: 'Beds $name',
                hexColor: '00db60',
                identifier: identifier,
              ),
            );

            expect(
              (await local(gardenId)).identifier,
              identifier.toUpperCase(),
            );
            await expectLikeFreshSync();

            await projects.updateProject(
              gardenId,
              const ProjectChanges(identifier: ''),
            );
            await expectLikeFreshSync();
          });

          test('a favourite and a new parent', () async {
            shedId = await projects.createProject(
              NewProject(title: 'Shed $name', parentProjectId: rootId),
            );
            await _pace();

            await projects.updateProject(
              shedId,
              ProjectChanges(isFavorite: true, parentProjectId: gardenId),
            );

            expect((await local(shedId)).parentProjectId, gardenId);
            await expectLikeFreshSync();
          });

          test('archiving cascades and so does unarchiving; the default '
              'project and a child under an archived parent are '
              'refused', () async {
            await projects.updateProject(
              gardenId,
              const ProjectChanges(isArchived: true),
            );

            expect((await local(shedId)).isArchived, isTrue);
            await expectLikeFreshSync();

            await expectLater(
              projects.updateProject(
                shedId,
                const ProjectChanges(isArchived: false),
              ),
              throwsA(isA<DomainError>().having((e) => e.code, 'code', 3016)),
            );

            await projects.updateProject(
              gardenId,
              const ProjectChanges(isArchived: false),
            );
            expect((await local(shedId)).isArchived, isFalse);
            await expectLikeFreshSync();

            final defaultProjectId = decodeUserSettings(
              (await db.syncStateDao.readAll())[SyncStateKeys.userSettings],
            ).defaultProjectId!;
            await expectLater(
              projects.updateProject(
                defaultProjectId,
                const ProjectChanges(isArchived: true),
              ),
              throwsA(isA<DomainError>().having((e) => e.code, 'code', 3013)),
            );
            expect((await local(defaultProjectId)).isArchived, isFalse);
          });

          test('views are created, edited, moved and deleted', () async {
            final doneId = await views.createView(
              gardenId,
              const ViewDraft(
                title: 'Done',
                kind: ProjectViewKind.list,
                filter: ViewFilter(filter: 'done = true'),
              ),
            );
            await expectLikeFreshSync();

            final sprintId = await views.createView(
              gardenId,
              const ViewDraft(title: 'Sprint', kind: ProjectViewKind.kanban),
            );
            final sprint = (await local(gardenId)).views
                .singleWhere((v) => v.id == sprintId);
            expect(
              sprint.bucketConfigurationMode,
              BucketConfigurationMode.manual,
            );
            await expectLikeFreshSync();

            await views.updateView(
              gardenId,
              doneId,
              const ViewDraft(title: 'Everything', kind: ProjectViewKind.list),
            );
            await expectLikeFreshSync();

            await views.moveView(gardenId, sprintId, toIndex: 0);
            expect((await local(gardenId)).views.first.id, sprintId);
            await expectLikeFreshSync();

            await views.deleteView(gardenId, doneId);
            await expectLikeFreshSync();

            await expectLater(
              views.createView(
                gardenId,
                const ViewDraft(
                  title: 'Broken',
                  kind: ProjectViewKind.list,
                  filter: ViewFilter(filter: '(('),
                ),
              ),
              throwsA(isA<DomainError>().having((e) => e.code, 'code', 4024)),
            );
            expect((await local(gardenId)).views, hasLength(5));
          });

          test('a move sends only the position: a title and a filter changed '
              'on the web since the last sync stay', () async {
            final sprintId = (await local(gardenId)).views
                .singleWhere((v) => v.title == 'Sprint')
                .id;
            final path = '/projects/$gardenId/views/$sprintId';
            await seeder.patch(path, {
              'title': 'Columns',
              'filter': {'filter': 'priority >= 3'},
            });
            await _pace();

            await views.moveView(gardenId, sprintId, toIndex: 1);

            final onServer = await seeder.get(path);
            expect(onServer['title'], 'Columns');
            expect(
              (onServer['filter']! as Map<String, Object?>)['filter'],
              'priority >= 3',
            );
            expect(onServer['bucket_configuration_mode'], 'manual');
            final stored = (await local(gardenId)).views[1];
            expect(stored.id, sprintId);
            expect(stored.title, 'Columns');
            await expectLikeFreshSync();
          });

          test(
            'a duplicate returns once its copy is stored with its tasks',
            () async {
              quiet.onRefreshAfterWrite = engine.refresh;
              addTearDown(() => quiet.onRefreshAfterWrite = null);

              final copyId = await projects.duplicateProject(
                gardenId,
                parentProjectId: rootId,
                copyShares: true,
              );

              final copy = await local(copyId);
              expect(copy.title, 'Beds $name - duplicate');
              expect(copy.parentProjectId, rootId);
              expect(
                [
                  for (final task in await projectTasksIn(db, copyId))
                    task.title,
                ]..sort(),
                ['Water', 'Weed'],
              );
              await _pace();
              expect(
                (await _contents(db, rootId)).exact,
                (await freshSync()).exact,
              );
            },
          );

          test('a delete purges the whole subtree with its tasks', () async {
            await seeder.create('/projects/$shedId/tasks', {'title': 'Rake'});
            await _pace();
            await engine.refresh();

            await projects.deleteProject(gardenId);

            final left = {
              for (final project in await db.projectsDao.loadAll()) project.id,
            };
            expect(left, isNot(contains(gardenId)));
            expect(left, isNot(contains(shedId)));
            expect(await projectTasksIn(db, gardenId), isEmpty);
            expect(await projectTasksIn(db, shedId), isEmpty);
            await expectLikeFreshSync();
          });
        });
      }
    },
  );
}
