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
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

/// A column as `<bucket id>: <count> <task ids in order>`.
String _column(int bucketId, int count, Iterable<int> taskIds) =>
    '$bucketId: $count ${taskIds.join(',')}';

typedef _ServerTask = ({int bucketId, double position, bool done});

/// The writes are paced, so the SQLite server keeps up with the files
/// running in parallel.
Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

void main() {
  group('kanban against the local Docker server', skip: contractSkip, () {
    late Dio dio;
    late ServerConnection connection;
    late TestUser user;
    late Seeder seeder;
    late int projectId;
    late int viewId;
    late int todoId;
    late int doingId;
    late int doneId;
    final tasksOf = <ApiVersion, List<int>>{};

    Future<int> task(String title, [Map<String, Object?>? more]) async {
      final id = await seeder.create('/projects/$projectId/tasks', {
        'title': title,
        ...?more,
      });
      await _pace();
      return id;
    }

    Future<void> move(int taskId, int bucketId) async {
      await seeder.put(
        '/projects/$projectId/views/$viewId/buckets/$bucketId/tasks',
        {'task_id': taskId},
      );
      await _pace();
    }

    Future<List<String>> serverBoard() async {
      final board = await seeder.get(
        '/projects/$projectId/views/$viewId/buckets/tasks',
      );
      return [
        for (final bucket
            in (board['items']! as List<Object?>).cast<Map<String, Object?>>())
          _column(bucket['id']! as int, bucket['count']! as int, [
            for (final task
                in (bucket['tasks'] as List<Object?>? ?? const [])
                    .cast<Map<String, Object?>>())
              task['id']! as int,
          ]),
      ];
    }

    Future<_ServerTask> serverTask(int taskId) async {
      for (final bucket
          in ((await seeder.get(
                    '/projects/$projectId/views/$viewId/buckets/tasks',
                  ))['items']!
                  as List<Object?>)
              .cast<Map<String, Object?>>()) {
        for (final task
            in (bucket['tasks'] as List<Object?>? ?? const [])
                .cast<Map<String, Object?>>()) {
          if (task['id'] == taskId) {
            return (
              bucketId: bucket['id']! as int,
              position: (task['position']! as num).toDouble(),
              done: task['done']! as bool,
            );
          }
        }
      }
      throw StateError('task $taskId is on no bucket');
    }

    setUpAll(() async {
      dio = contractDio();
      connection = await DioServerConnector(dio)
          .connect('http://localhost:$contractServerPort');
      user = await registerAndLogin(dio, connection);
      seeder = Seeder(dio, connection, user);

      projectId = await seeder.create('/projects', {'title': 'Board'});
      await _pace();
      final project = await seeder.get('/projects/$projectId');
      final kanban = (project['views']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .firstWhere((view) => view['view_kind'] == 'kanban');
      viewId = kanban['id']! as int;
      todoId = kanban['default_bucket_id']! as int;
      doneId = kanban['done_bucket_id']! as int;
      final buckets =
          (await seeder.get(
                '/projects/$projectId/views/$viewId/buckets',
              ))['items']!
              as List<Object?>;
      doingId = buckets
          .cast<Map<String, Object?>>()
          .map((bucket) => bucket['id']! as int)
          .firstWhere((id) => id != todoId && id != doneId);

      for (final version in ApiVersion.values) {
        tasksOf[version] = [
          await task('Stays ${version.pathSegment}'),
          await task('Moves ${version.pathSegment}'),
          await task('Gets done ${version.pathSegment}'),
        ];
      }
      final doing = await task('Doing already');
      await move(doing, doingId);
      await task('Done already', {'done': true});
    });

    tearDownAll(() => dio.close(force: true));

    for (final apiVersion in ApiVersion.values) {
      group('over ${apiVersion.pathSegment}', () {
        late AppDatabase db;
        late LocalTaskRepository tasks;

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
          final engine = DefaultSyncEngine(
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
          await engine.ensureInitialSync();
        });

        Future<List<BoardColumn>> localBoard() async {
          final source = await tasks.watchBoard(projectId, viewId).first;
          return buildBoard(
            view: source.view!,
            buckets: source.buckets,
            snapshot: source.snapshot,
            loadedAt: source.loadedAt,
            projectTasks: source.projectTasks,
            queued: source.queued,
            movedHere: source.movedHere,
            queuedDoneChanges: source.queuedDoneChanges,
          );
        }

        Future<void> sendAll() async {
          for (var attempt = 1; ; attempt++) {
            final blocked = await tasks.sendPendingChanges();
            if (blocked == null) return;
            if (attempt == 5) fail('the outbox stays blocked by $blocked');
            await Future<void>.delayed(Duration(seconds: attempt));
          }
        }

        test("the local board equals the server's", () async {
          await tasks.refreshBoard(projectId, viewId);

          final local = await localBoard();
          final server = await serverBoard();
          expect([
            for (final column in local)
              _column(column.bucket.id, column.shownCount, [
                for (final task in column.tasks) task.id,
              ]),
          ], server);
          expect(
            [for (final column in local) column.bucket.id],
            [todoId, doingId, doneId],
          );
          expect(local.every((column) => !column.hasMore), isTrue);
        });

        test('a placement drained by the outbox moves and positions the '
            'task on the server, and the board keeps it there', () async {
          await tasks.refreshBoard(projectId, viewId);
          final moving = tasksOf[apiVersion]![1];
          final doing = (await localBoard()).firstWhere(
            (column) => column.bucket.id == doingId,
          );
          final position = calculateItemPosition(
            null,
            doing.tasks.first.position,
          );

          await tasks.placeTask(
            moving,
            viewId: viewId,
            placement: BucketPlacement(bucketId: doingId, position: position),
          );
          await sendAll();
          await _pace();

          // Positions are view-wide: one equal to a card's in another
          // bucket is spread by the server.
          final onServer = await serverTask(moving);
          expect(onServer.bucketId, doingId);
          expect(onServer.done, isFalse);
          expect(onServer.position, lessThan(doing.tasks.first.position));
          final local = await localBoard();
          final column = local.firstWhere((c) => c.bucket.id == doingId);
          expect(column.tasks.first.id, moving);
          expect(
            (await tasks.watchBoard(projectId, viewId).first).queued,
            isEmpty,
          );

          await tasks.refreshBoard(projectId, viewId);
          final refreshed = await localBoard();
          expect(
            refreshed.firstWhere((c) => c.bucket.id == doingId).tasks.first.id,
            moving,
          );
        });

        test('a drop into the done bucket marks the task done there', () async {
          await tasks.refreshBoard(projectId, viewId);
          final finishing = tasksOf[apiVersion]![2];
          final done = (await localBoard()).firstWhere(
            (column) => column.bucket.id == doneId,
          );

          await tasks.placeTask(
            finishing,
            viewId: viewId,
            placement: BucketPlacement(
              bucketId: doneId,
              position: calculateItemPosition(
                null,
                done.tasks.firstOrNull?.position,
              ),
            ),
            done: true,
          );
          expect(
            (await localBoard())
                .firstWhere((c) => c.bucket.id == doneId)
                .tasks
                .map((task) => task.id),
            contains(finishing),
          );
          await sendAll();
          await _pace();

          final onServer = await serverTask(finishing);
          expect(onServer.bucketId, doneId);
          expect(onServer.done, isTrue);
          final task = await tasks.watchTask(finishing).first;
          expect(task?.done, isTrue);
          expect(task?.doneAt, isNotNull);
        });
      });
    }
  });
}
