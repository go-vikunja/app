@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

// A fresh user owns the server's default Inbox plus the two seeded
// projects: "Live" with 80 open and 40 done tasks (ten of them labelled
// alpha, one assigned to the user) and "Archived" with 55 open and 5 done
// tasks, archived after seeding so GET /tasks leaves them out. Both task
// lists are longer than a page, so the keyset cursor is exercised on
// /tasks and on /projects/{id}/tasks.
typedef _Seed = ({
  int liveId,
  int archivedId,
  int alphaId,
  int assignedId,
  List<int> archivedTaskIds,
});

const _liveOpen = 80;
const _liveDone = 40;
const _archivedOpen = 55;
const _archivedDone = 5;
const _labelled = 10;

Future<_Seed> _seed(Seeder seeder, TestUser user) async {
  final liveId = await seeder.create('/projects', {'title': 'Live'});
  final archivedId = await seeder.create('/projects', {'title': 'Archived'});
  final alphaId = await seeder.create('/labels', {
    'title': 'alpha',
    'hex_color': 'e8323c',
  });
  await seeder.create('/labels', {'title': 'beta'});
  final liveTaskIds = <int>[];
  for (var i = 1; i <= _liveOpen + _liveDone; i++) {
    liveTaskIds.add(
      await seeder.create('/projects/$liveId/tasks', {
        'title': 'Task $i',
        'done': i > _liveOpen,
        if (i % 7 == 0)
          'due_date': DateTime.utc(2026, 11, 1 + i % 28).toIso8601String(),
      }),
    );
  }
  for (final taskId in liveTaskIds.take(_labelled)) {
    await seeder.post('/tasks/$taskId/labels', {'label_id': alphaId});
  }
  final assignedId = liveTaskIds.first;
  await seeder.post('/tasks/$assignedId/assignees', {'user_id': user.id});
  final archivedTaskIds = <int>[];
  for (var i = 1; i <= _archivedOpen + _archivedDone; i++) {
    archivedTaskIds.add(
      await seeder.create('/projects/$archivedId/tasks', {
        'title': 'Archived task $i',
        'done': i > _archivedOpen,
      }),
    );
  }
  await seeder.patch('/projects/$archivedId', {'is_archived': true});
  return (
    liveId: liveId,
    archivedId: archivedId,
    alphaId: alphaId,
    assignedId: assignedId,
    archivedTaskIds: archivedTaskIds,
  );
}

void main() {
  group('initial sync against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;
    late TestUser user;
    late _Seed seed;

    setUpAll(() async {
      dio = contractDio();
      connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
      user = await registerAndLogin(dio, connection);
      seed = await _seed(Seeder(dio, connection, user), user);
    });

    tearDownAll(() => dio.close(force: true));

    for (final apiVersion in ApiVersion.values) {
      test('pulls the whole account over ${apiVersion.pathSegment}', () async {
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
        final perPage = only.info.maxItemsPerPage;
        expect(_archivedOpen, greaterThan(perPage));
        final db = testDatabase();
        final engine = DefaultSyncEngine(
          db: db,
          client: createReadClient(dio: authenticated, connection: only),
          perPage: only.info.maxItemsPerPage,
          currentUser: AccountApi(authenticated, only).currentUserWithSettings,
        );
        addTearDown(engine.dispose);
        final seen = <SyncStatus>[];
        final subscription = engine.status.listen(seen.add);
        addTearDown(subscription.cancel);

        await engine.ensureInitialSync();

        expect(seen.first, const SyncNeverRun());
        expect(seen.last, isA<SyncIdle>());
        final running = seen.whereType<SyncRunning>().toList();
        expect(running.map((s) => s.phase).toSet(), {
          SyncPhase.account,
          SyncPhase.projects,
          SyncPhase.labels,
          SyncPhase.tasks,
          SyncPhase.archivedTasks,
          SyncPhase.finishing,
        });
        expect(
          running.where((s) => s.phase == SyncPhase.tasks).map((s) => s.total),
          everyElement(_liveOpen + _liveDone),
        );

        final projects = await db.projectsDao.loadAll();
        expect(projects.map((p) => p.title), ['Inbox', 'Live', 'Archived']);
        expect(projects.every((p) => !p.isPseudo), isTrue);
        expect(projects.map((p) => p.isArchived), [false, false, true]);
        expect(projects.map((p) => p.views.length), everyElement(4));
        expect(projects.map((p) => p.owner?.id), everyElement(user.id));
        expect(projects.map((p) => p.updated), everyElement(isNotNull));

        final labels = await db.labelsDao.loadAll();
        expect(labels.map((l) => l.title), ['alpha', 'beta']);
        expect(labels.first.hexColor, 'e8323c');
        expect(labels.first.createdBy?.id, user.id);

        final users = await db.usersDao.loadAll();
        expect(users.map((u) => u.id), [user.id]);
        expect(users.single.username, user.username);

        expect(
          await db.tasksDao.count(),
          _liveOpen + _liveDone + _archivedOpen + _archivedDone,
        );
        final open = await db.tasksDao.loadOpenTasks();
        expect(open, hasLength(_liveOpen + _archivedOpen));
        expect(open.every((t) => !t.done), isTrue);
        final dated = open.takeWhile((t) => t.dueDate != null).toList();
        expect(dated, isNotEmpty);
        expect(
          open.skip(dated.length).map((t) => t.dueDate),
          everyElement(isNull),
        );
        expect(
          open.where((t) => t.labels.any((l) => l.id == seed.alphaId)),
          hasLength(_labelled),
        );
        final assigned = (await db.tasksDao.find(seed.assignedId))!;
        expect(assigned.assignees.map((u) => u.id), [user.id]);
        expect(assigned.createdBy?.id, user.id);
        expect(assigned.updated, isNotNull);
        expect(assigned.identifier, isNotEmpty);

        final archived = await projectTasksIn(db, seed.archivedId);
        expect(archived, hasLength(_archivedOpen + _archivedDone));
        expect(archived.map((t) => t.id).toSet(), seed.archivedTaskIds.toSet());
        expect(archived.where((t) => t.done), hasLength(_archivedDone));
        // The open list of the archived project spans two pages: the second
        // request continues after the highest id of the first page, so the
        // server honoured both the filter and sort_by=id on this endpoint.
        final openIds = seed.archivedTaskIds.take(_archivedOpen).toList()
          ..sort();
        final archivedFilters = [
          for (final uri in requests)
            if (uri.path.endsWith('/projects/${seed.archivedId}/tasks'))
              uri.queryParameters['filter'],
        ];
        expect(archivedFilters, [
          'done = false && id > 0',
          'done = false && id > ${openIds[perPage - 1]}',
          'done = true && id > 0',
        ]);
        final liveDone = await projectTasksIn(db, seed.liveId);
        expect(liveDone, hasLength(_liveOpen + _liveDone));
        expect(
          await projectTasksIn(db, seed.liveId, showDone: false),
          hasLength(_liveOpen),
        );
        // Last run, last full run, the watermark, the user's settings and
        // the saved filter every new user gets; no checkpoint.
        final state = await db.syncStateDao.readAll();
        expect(state.keys.toSet(), {
          SyncStateKeys.lastSyncedAt,
          SyncStateKeys.lastFullSyncAt,
          SyncStateKeys.watermark,
          SyncStateKeys.userSettings,
          SyncStateKeys.savedFilters,
        });
        expect(decodeSavedFilters(state[SyncStateKeys.savedFilters]), [
          isA<SavedFilterRef>()
              .having((f) => f.projectId, 'pseudo project', lessThan(-1))
              .having((f) => f.title, 'title', 'My Open Tasks')
              .having(
                (f) => f.definition?.filter.filter,
                'filter',
                startsWith('done = false && assignees = '),
              ),
        ]);
        expect(
          decodeUserSettings(state[SyncStateKeys.userSettings]),
          isA<UserSettings>()
              .having((s) => s.defaultProjectId, 'default project', isNotNull)
              .having(
                (s) => s.quickAddMagicMode,
                'mode',
                QuickAddMagicMode.vikunja,
              ),
        );

        // A second run changes nothing.
        await engine.refresh();
        expect(
          await db.tasksDao.count(),
          _liveOpen + _liveDone + _archivedOpen + _archivedDone,
        );
      });
    }
  });
}
