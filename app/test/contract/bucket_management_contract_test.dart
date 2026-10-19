@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/kanban_dao.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/sync/list_downloads.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

/// The writes are paced, so the SQLite server keeps up with the files
/// running in parallel.
Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

void main() {
  group('buckets against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;
    late TestUser user;
    late Seeder seeder;

    setUpAll(() async {
      // The fresh downloads go into a second in-memory database.
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
        late AppDatabase db;
        late VikunjaReadClient reads;
        late VikunjaWriteClient writes;
        late DefaultSyncEngine engine;
        late LocalTaskRepository tasks;
        late LocalBucketRepository buckets;
        late int perPage;
        late int projectId;
        late int viewId;
        late int todoId;
        late int doingId;
        late int doneId;
        late int reviewId;
        late int openTask;
        late int doingTask;
        late int doneTask;

        Future<int> task(String title, [Map<String, Object?>? more]) async {
          final id = await seeder.create('/projects/$projectId/tasks', {
            'title': title,
            ...?more,
          });
          await _pace();
          return id;
        }

        setUpAll(() async {
          projectId = await seeder.create('/projects', {
            'title': 'Columns ${apiVersion.pathSegment}',
          });
          await _pace();
          final project = await seeder.get('/projects/$projectId');
          final kanban = (project['views']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .firstWhere((view) => view['view_kind'] == 'kanban');
          viewId = kanban['id']! as int;
          todoId = kanban['default_bucket_id']! as int;
          doneId = kanban['done_bucket_id']! as int;
          doingId =
              ((await seeder.get(
                        '/projects/$projectId/views/$viewId/buckets',
                      ))['items']!
                      as List<Object?>)
                  .cast<Map<String, Object?>>()
                  .map((bucket) => bucket['id']! as int)
                  .firstWhere((id) => id != todoId && id != doneId);
          openTask = await task('Open');
          await task('Open too');
          doingTask = await task('Doing');
          await seeder.put(
            '/projects/$projectId/views/$viewId/buckets/$doingId/tasks',
            {'task_id': doingTask},
          );
          await _pace();
          doneTask = await task('Done', {'done': true});

          final only = onlyApiVersion(connection, apiVersion);
          perPage = only.info.maxItemsPerPage;
          final authenticated = createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
          );
          reads = createReadClient(dio: authenticated, connection: only);
          writes = createWriteClient(dio: authenticated, connection: only);
          db = testDatabase();
          engine = DefaultSyncEngine(
            db: db,
            client: reads,
            perPage: perPage,
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
            perPage: perPage,
          );
          addTearDown(tasks.dispose);
          // No quiet download after a change: the board must be right
          // from the write-through alone.
          buckets = LocalBucketRepository(
            db,
            writes,
            refreshBoard: (_, _) async {},
          );
          await engine.ensureInitialSync();
          await tasks.refreshBoard(projectId, viewId);
        });

        Future<StoredBoard> freshDownload() async {
          final fresh = testDatabase();
          await downloadBoard(
            db: fresh,
            client: reads,
            perPage: perPage,
            projectId: projectId,
            viewId: viewId,
            now: DateTime.now,
          );
          return await fresh.kanbanDao.load(viewId);
        }

        Future<({int done, int defaultId})> serverView() async {
          final view = await seeder.get('/projects/$projectId/views/$viewId');
          return (
            done: view['done_bucket_id']! as int,
            defaultId: view['default_bucket_id']! as int,
          );
        }

        Future<void> expectLikeFreshDownload() async {
          final local = await db.kanbanDao.load(viewId);
          final fresh = await freshDownload();
          expect(local.buckets, fresh.buckets);
          expect(local.slots, fresh.slots);
          final view = await db.projectsDao.loadView(viewId);
          final server = await serverView();
          expect(
            (done: view?.doneBucketId, defaultId: view?.defaultBucketId),
            (done: server.done, defaultId: server.defaultId),
          );
        }

        Future<List<int>> localOrder() async => [
          for (final bucket in await db.kanbanDao.buckets(viewId)) bucket.id,
        ];

        Future<List<int>> shownIn(int bucketId) async {
          final source = await db.tasksDao.loadBoard(projectId, viewId);
          final column = buildBoard(
            view: source.view!,
            buckets: source.buckets,
            snapshot: source.snapshot,
            loadedAt: source.loadedAt,
            projectTasks: source.projectTasks,
            queued: source.queued,
          ).singleWhere((column) => column.bucket.id == bucketId);
          return [for (final task in column.tasks) task.id];
        }

        Future<void> act(Future<void> Function() action) async {
          await despiteWriteRaces(action);
          await _pace();
        }

        /// A new column in front that new tasks go to.
        Future<int> defaultInFront(String title) async {
          await act(() => buckets.create(projectId, viewId, title));
          final id = (await db.kanbanDao.buckets(viewId)).last.id;
          await act(() => buckets.move(projectId, viewId, id, toIndex: 0));
          await act(() => buckets.setDefaultBucket(projectId, viewId, id));
          return id;
        }

        test('a created column lands rightmost, empty', () async {
          await act(() => buckets.create(projectId, viewId, ' Review '));

          final stored = await db.kanbanDao.buckets(viewId);
          reviewId = stored.last.id;
          expect(await localOrder(), [todoId, doingId, doneId, reviewId]);
          expect(stored.last.title, 'Review');
          expect(stored.last.count, 0);
          await expectLikeFreshDownload();
        });

        test('a rename and a limit keep the other fields', () async {
          await act(
            () => buckets.rename(projectId, viewId, doingId, 'In progress'),
          );
          await expectLikeFreshDownload();

          await act(() => buckets.setLimit(projectId, viewId, doingId, 1));

          final doing = (await db.kanbanDao.buckets(viewId))[1];
          expect(
            (doing.title, doing.limit, doing.count),
            ('In progress', 1, 1),
          );
          await expectLikeFreshDownload();
        });

        test('a move to the front reorders the board', () async {
          await act(
            () => buckets.move(projectId, viewId, reviewId, toIndex: 0),
          );

          expect(await localOrder(), [reviewId, todoId, doingId, doneId]);
          await expectLikeFreshDownload();
        });

        test('a move in front of a column another client left at position 0 '
            'goes below it', () async {
          final todo = (await db.kanbanDao.buckets(viewId))
              .singleWhere((bucket) => bucket.id == todoId);
          // An update without a position stores 0, as other clients send.
          await seeder.put(
            '/projects/$projectId/views/$viewId/buckets/$todoId',
            {'title': todo.title},
          );
          await _pace();
          await tasks.refreshBoard(projectId, viewId);
          expect(await localOrder(), [todoId, reviewId, doingId, doneId]);

          await act(
            () => buckets.move(projectId, viewId, reviewId, toIndex: 0),
          );

          expect(await localOrder(), [reviewId, todoId, doingId, doneId]);
          await expectLikeFreshDownload();
        });

        test('the done and default column are set and cleared without '
            'changing the view or any task', () async {
          await act(() => buckets.setDoneBucket(projectId, viewId, doingId));
          await expectLikeFreshDownload();
          await act(() => buckets.setDoneBucket(projectId, viewId, null));
          await expectLikeFreshDownload();
          await act(() => buckets.setDefaultBucket(projectId, viewId, doneId));
          await expectLikeFreshDownload();
          await act(() => buckets.setDefaultBucket(projectId, viewId, null));
          await expectLikeFreshDownload();
          await act(() => buckets.setDoneBucket(projectId, viewId, doneId));
          await expectLikeFreshDownload();

          final view = await seeder.get('/projects/$projectId/views/$viewId');
          expect(view['view_kind'], 'kanban');
          expect(view['bucket_configuration_mode'], 'manual');
          expect(view['title'], 'Kanban');
          final doing = await seeder.get('/tasks/$doingTask');
          expect(doing['done'], isFalse);
          final done = await seeder.get('/tasks/$doneTask');
          expect(done['done'], isTrue);
        });

        test('deleting a column moves its tasks to the leftmost while no '
            'default is set', () async {
          await act(() => buckets.delete(projectId, viewId, doingId));

          expect(await localOrder(), [reviewId, todoId, doneId]);
          expect(
            (await db.kanbanDao.load(viewId)).slots[doingTask]?.bucketId,
            reviewId,
          );
          await expectLikeFreshDownload();
        });

        test('deleting the leftmost column with tasks while no default is '
            'set makes the next one the default first, so the tasks stay on '
            'the board', () async {
          await act(() => buckets.delete(projectId, viewId, reviewId));

          expect(await localOrder(), [todoId, doneId]);
          expect((await serverView()).defaultId, todoId);
          final fresh = await freshDownload();
          expect(fresh.slots[doingTask]?.bucketId, todoId);
          expect(fresh.slots[openTask]?.bucketId, todoId);
          expect(fresh.buckets.first.count, 3);
          await expectLikeFreshDownload();
        });

        test('deleting the default leftmost column holding only a task synced '
            'after the board download makes the next one the default first, '
            'so the task stays on the board', () async {
          final inboxId = await defaultInFront('Inbox');
          final added = await task('Added after the download');
          await engine.refresh();
          expect(await shownIn(inboxId), [added]);

          await act(() => buckets.delete(projectId, viewId, inboxId));

          expect((await serverView()).defaultId, todoId);
          expect((await freshDownload()).slots[added]?.bucketId, todoId);
          expect(await shownIn(todoId), contains(added));
          await tasks.refreshBoard(projectId, viewId);
          await expectLikeFreshDownload();
        });

        test('deleting the default leftmost column that looks empty here '
            'while it holds a task created elsewhere checks with a board '
            'download first, so the task stays on the board', () async {
          final inboxId = await defaultInFront('Inbox 2');
          final elsewhere = await task('Created elsewhere');
          final downloads = <Future<void>>[];
          final checking = LocalBucketRepository(
            db,
            writes,
            refreshBoard: (projectId, viewId) {
              final download = tasks.refreshBoard(projectId, viewId);
              downloads.add(download);
              return download;
            },
          );

          await act(() => checking.delete(projectId, viewId, inboxId));
          await Future.wait(downloads);

          expect((await serverView()).defaultId, todoId);
          expect((await freshDownload()).slots[elsewhere]?.bucketId, todoId);
          await expectLikeFreshDownload();
        });

        test('deleting the done column clears it, its tasks stay done in the '
            'default; the last column stays', () async {
          await act(() => buckets.delete(projectId, viewId, doneId));

          expect((await serverView()).done, 0);
          expect(
            (await db.kanbanDao.load(viewId)).slots[doneTask]?.bucketId,
            todoId,
          );
          expect((await seeder.get('/tasks/$doneTask'))['done'], isTrue);
          await expectLikeFreshDownload();

          await expectLater(
            buckets.delete(projectId, viewId, todoId),
            throwsA(isA<DomainError>().having((f) => f.code, 'code', 10003)),
          );
          expect(await localOrder(), [todoId]);
          await expectLikeFreshDownload();
        });
      });
    }
  });
}
