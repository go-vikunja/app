@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/recording_sync_engine.dart';
import '../helpers/test_database.dart';
import 'helpers.dart';

Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

// Two users: the creator of the labels, and another who sees one of them on
// a task shared with them.
void main() {
  group(
    'label management against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser creator;
      late TestUser other;

      setUpAll(() async {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        addTearDown(
          () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
        );
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        creator = await registerAndLogin(dio, connection);
        other = await registerAndLogin(dio, connection);
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          final name = apiVersion.pathSegment;
          late ServerConnection only;
          late AppDatabase db;
          late DefaultSyncEngine engine;
          late RecordingSyncEngine quiet;
          late LocalLabelRepository labels;
          late Seeder seeder;
          late int projectId;
          late int taskId;

          Dio authenticatedAs(TestUser user) => createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
          );

          LocalLabelRepository repositoryOf(TestUser user, AppDatabase db) {
            final authenticated = authenticatedAs(user);
            return LocalLabelRepository(
              db,
              createWriteClient(dio: authenticated, connection: only),
              createReadClient(dio: authenticated, connection: only),
              sync: quiet,
            );
          }

          setUpAll(() async {
            only = onlyApiVersion(connection, apiVersion);
            seeder = Seeder(dio, connection, creator);
            projectId = await seeder.create('/projects', {
              'title': 'Labels over $name',
            });
            await _pace();
            taskId = await seeder.create('/projects/$projectId/tasks', {
              'title': 'Labelled',
            });
            await _pace();
            await seeder.post('/projects/$projectId/users', {
              'username': other.username,
              'permission': 1,
            });
            await _pace();
          });

          setUp(() async {
            db = testDatabase();
            addTearDown(db.close);
            quiet = RecordingSyncEngine();
            labels = repositoryOf(creator, db);
            final authenticated = authenticatedAs(creator);
            engine = DefaultSyncEngine(
              db: db,
              client: createReadClient(dio: authenticated, connection: only),
              perPage: only.info.maxItemsPerPage,
              currentUser: AccountApi(
                authenticated,
                only,
              ).currentUserWithSettings,
            );
            addTearDown(engine.dispose);
          });

          test('a change stores the answer and leaves the rest of the label '
              'as it was', () async {
            final created = await labels.create(
              NewLabel(title: 'errand $name', hexColor: 'ffbe0b'),
            );
            await _pace();
            await seeder.post('/tasks/$taskId/labels', {
              'label_id': created.id,
            });
            await _pace();
            await engine.ensureInitialSync();
            expect(isOwnLabel(created, creator.id), isTrue);

            final renamed = await labels.update(
              created.id,
              LabelChanges(title: 'errands $name'),
            );
            await _pace();

            expect(renamed.title, 'errands $name');
            expect(renamed.hexColor, 'ffbe0b');
            final stored = (await db.labelsDao.loadAll()).singleWhere(
              (label) => label.id == created.id,
            );
            expect(stored.title, 'errands $name');
            expect(stored.createdBy?.id, creator.id);
            expect(quiet.refreshAfterWriteCalls, 1);

            final recoloured = await labels.update(
              created.id,
              const LabelChanges(
                description: '<p>Outside the house</p>',
                hexColor: '',
              ),
            );
            await _pace();
            expect(recoloured.title, 'errands $name');
            expect(recoloured.hexColor, '');
            expect(recoloured.description, '<p>Outside the house</p>');

            await engine.refresh();
            final synced = (await db.labelsDao.loadAll()).singleWhere(
              (label) => label.id == created.id,
            );
            expect(
              (synced.title, synced.description, synced.hexColor),
              (recoloured.title, recoloured.description, recoloured.hexColor),
            );
            expect(
              (await db.tasksDao.find(taskId))!.labels.single.title,
              'errands $name',
            );
          });

          test("another user's label is refused for them and stays", () async {
            final created = await labels.create(NewLabel(title: 'mine $name'));
            await _pace();
            await seeder.post('/tasks/$taskId/labels', {
              'label_id': created.id,
            });
            await _pace();
            final theirs = testDatabase();
            addTearDown(theirs.close);
            final otherLabels = repositoryOf(other, theirs);
            await theirs.labelsDao.upsertAll([created]);

            await expectLater(
              otherLabels.update(
                created.id,
                const LabelChanges(title: 'taken over'),
              ),
              throwsA(isA<Forbidden>()),
            );
            await expectLater(
              otherLabels.delete(created.id),
              throwsA(isA<Forbidden>()),
            );
            expect(
              (await theirs.labelsDao.loadAll()).single.title,
              'mine $name',
            );
            expect(isOwnLabel(created, other.id), isFalse);
            await _pace();
          });

          test('a delete takes the label off its tasks here and on the '
              'server, and one gone already counts as deleted', () async {
            final created = await labels.create(NewLabel(title: 'gone $name'));
            await _pace();
            await seeder.post('/tasks/$taskId/labels', {
              'label_id': created.id,
            });
            await _pace();
            await engine.ensureInitialSync();
            expect(
              (await db.tasksDao.find(taskId))!.labels.map((label) => label.id),
              contains(created.id),
            );

            await labels.delete(created.id);
            await _pace();

            expect(
              (await db.labelsDao.loadAll()).map((label) => label.id),
              isNot(contains(created.id)),
            );
            expect(
              (await db.tasksDao.find(taskId))!.labels.map((label) => label.id),
              isNot(contains(created.id)),
            );
            final task = await seeder.get('/tasks/$taskId');
            expect([
              for (final label in (task['labels'] as List<Object?>?) ?? [])
                (label! as Map<String, Object?>)['id'],
            ], isNot(contains(created.id)));

            await labels.delete(created.id);
            await _pace();

            await expectLater(
              labels.update(created.id, const LabelChanges(title: 'back')),
              throwsA(isA<NotFound>().having((f) => f.code, 'code', 8002)),
            );
          });

          test(
            'a label titled with a number is found, not made twice',
            () async {
              final title = '${2026 + apiVersion.index}';
              final first = await labels.create(NewLabel(title: title));
              await _pace();
              final fresh = testDatabase();
              addTearDown(fresh.close);

              final found = await repositoryOf(
                creator,
                fresh,
              ).findOrCreate(NewLabel(title: title));

              expect(found.id, first.id);
            },
          );
        });
      }
    },
  );
}
