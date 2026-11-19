@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/recording_sync_engine.dart';
import '../helpers/test_database.dart';
import 'helpers.dart';

Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

/// The real write client, whose label creates fail before they leave the
/// device while [offline], and whose next [loseNextCreate] creates reach
/// the server but lose their answer.
final class _FlakyLabelWrites implements VikunjaWriteClient {
  new(this._real);

  final VikunjaWriteClient _real;
  bool offline = false;
  int loseNextCreate = 0;

  @override
  late final LabelsWritePort labels = _FlakyLabels(this);

  @override
  TasksWritePort get tasks => _real.tasks;

  @override
  AttachmentsWritePort get attachments => _real.attachments;

  @override
  CommentsWritePort get comments => _real.comments;

  @override
  ReactionsWritePort get reactions => _real.reactions;

  @override
  NotificationsWritePort get notifications => _real.notifications;

  @override
  SubscriptionsWritePort get subscriptions => _real.subscriptions;

  @override
  BucketsWritePort get buckets => _real.buckets;

  @override
  ProjectViewsWritePort get views => _real.views;

  @override
  ProjectsWritePort get projects => _real.projects;

  @override
  SavedFiltersPort get savedFilters => _real.savedFilters;
}

final class _FlakyLabels implements LabelsWritePort {
  new(this._client);

  final _FlakyLabelWrites _client;

  @override
  Future<Label> create(NewLabel label) async {
    if (_client.offline) {
      throw const NetworkFailure(NetworkProblem.unreachable);
    }
    final created = await _client._real.labels.create(label);
    if (_client.loseNextCreate > 0) {
      _client.loseNextCreate--;
      throw const NetworkFailure(NetworkProblem.timeout);
    }
    return created;
  }

  @override
  Future<Label> update(int id, LabelChanges changes) =>
      _client._real.labels.update(id, changes);

  @override
  Future<void> delete(int id) => _client._real.labels.delete(id);
}

typedef _Labels = ({
  LocalLabelRepository labels,
  OutboxSender sender,
  AppDatabase db,
});

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
          late _Labels mine;
          late LocalLabelRepository labels;
          late Seeder seeder;
          late int projectId;
          late int taskId;

          Dio authenticatedAs(TestUser user) => createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
          );

          /// [user]'s labels on [db], with an outbox sender as the app has.
          _Labels repositoryOf(
            TestUser user,
            AppDatabase db, {
            VikunjaWriteClient Function(VikunjaWriteClient real)? wrap,
          }) {
            final authenticated = authenticatedAs(user);
            final real = createWriteClient(
              dio: authenticated,
              connection: only,
            );
            final writes = wrap?.call(real) ?? real;
            final sender = OutboxSender(
              db: db,
              writeClient: writes,
              readClient: createReadClient(
                dio: authenticated,
                connection: only,
              ),
              sync: quiet,
              currentUserId: () => user.id,
            );
            addTearDown(sender.dispose);
            return (
              labels: LocalLabelRepository(
                db,
                writes,
                outbox: sender,
                sync: quiet,
                currentUser: () => User(id: user.id, username: user.username),
              ),
              sender: sender,
              db: db,
            );
          }

          /// Created on the device, then sent: the label as the server
          /// answered, under its id.
          Future<Label> createdOnServer(_Labels of, NewLabel label) async {
            final local = await of.labels.create(label);
            expect(local.id, isNegative);
            await of.sender.drain();
            final id = await of.db.labelsDao.resolveId(local.id);
            expect(id, isPositive);
            return (await of.db.labelsDao.find(id))!;
          }

          /// The ids of the server's labels titled [title], as [user] sees
          /// them.
          Future<List<int>> serverLabelsTitled(
            TestUser user,
            String title,
          ) async {
            final all = await createReadClient(
              dio: authenticatedAs(user),
              connection: only,
            ).labels.listAll();
            return [
              for (final label in all)
                if (label.title == title) label.id,
            ];
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
            mine = repositoryOf(creator, db);
            labels = mine.labels;
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
            final created = await createdOnServer(
              mine,
              NewLabel(title: 'errand $name', hexColor: 'ffbe0b'),
            );
            await _pace();
            await seeder.post('/tasks/$taskId/labels', {
              'label_id': created.id,
            });
            await _pace();
            await engine.ensureInitialSync();
            expect(isOwnLabel(created, creator.id), isTrue);
            final syncsBefore = quiet.refreshAfterWriteCalls;

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
            expect(quiet.refreshAfterWriteCalls, syncsBefore + 1);

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
            final created = await createdOnServer(
              mine,
              NewLabel(title: 'mine $name'),
            );
            await _pace();
            await seeder.post('/tasks/$taskId/labels', {
              'label_id': created.id,
            });
            await _pace();
            final theirs = testDatabase();
            addTearDown(theirs.close);
            final otherLabels = repositoryOf(other, theirs).labels;
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
            final created = await createdOnServer(
              mine,
              NewLabel(title: 'gone $name'),
            );
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

          test('a label titled with a number is found, not made twice: '
              'findOrCreate on a device without it adopts it', () async {
            final title = '${2026 + apiVersion.index}';
            final first = await createdOnServer(mine, NewLabel(title: title));
            await _pace();
            final fresh = testDatabase();
            addTearDown(fresh.close);
            final elsewhere = repositoryOf(creator, fresh);

            final found = await elsewhere.labels.findOrCreate(
              NewLabel(title: title),
            );
            await elsewhere.sender.drain();

            expect(await fresh.labelsDao.resolveId(found.id), first.id);
            expect(await serverLabelsTitled(creator, title), [first.id]);
          });

          test('a label created offline and attached to a task goes once '
              'online, then its attach under the server id', () async {
            await engine.ensureInitialSync();
            late _FlakyLabelWrites flaky;
            final offline = repositoryOf(
              creator,
              db,
              wrap: (real) => flaky = _FlakyLabelWrites(real)..offline = true,
            );
            final title = 'offline $name';

            final local = await offline.labels.create(NewLabel(title: title));
            await db.outboxDao.queueUpdate(
              taskId,
              TaskChanges(labels: IdSetChange(added: {local.id})),
              now: DateTime.now(),
            );
            await offline.sender.drain();
            expect(local.id, isNegative);
            expect(
              (await db.tasksDao.find(taskId))!.labels.map((label) => label.id),
              contains(local.id),
            );
            expect(await serverLabelsTitled(creator, title), isEmpty);

            flaky.offline = false;
            await offline.sender.sendNow();
            await _pace();

            final serverId = await db.labelsDao.resolveId(local.id);
            expect(await serverLabelsTitled(creator, title), [serverId]);
            final task = await seeder.get('/tasks/$taskId');
            expect([
              for (final label in (task['labels'] as List<Object?>?) ?? [])
                (label! as Map<String, Object?>)['id'],
            ], contains(serverId));
            expect(await db.outboxDao.count(), 0);
          });

          test('a create whose answer was lost is adopted on the next '
              'attempt, not made twice', () async {
            late _FlakyLabelWrites flaky;
            final losing = repositoryOf(
              creator,
              db,
              wrap: (real) =>
                  flaky = _FlakyLabelWrites(real)..loseNextCreate = 1,
            );
            final title = 'lost answer $name';

            final local = await losing.labels.create(NewLabel(title: title));
            await losing.sender.drain();
            expect(await db.labelsDao.resolveId(local.id), local.id);
            expect((await db.outboxDao.all()).single.sentAt, isNotNull);
            expect(flaky.loseNextCreate, 0);

            await losing.sender.sendNow();
            await _pace();

            final adopted = await serverLabelsTitled(creator, title);
            expect(adopted, hasLength(1));
            expect(await db.labelsDao.resolveId(local.id), adopted.single);
            expect(await db.outboxDao.count(), 0);
          });
        });
      }
    },
  );
}
