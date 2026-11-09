@Tags(['contract'])
@Timeout(Duration(minutes: 4))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Per API version one project whose Kanban view has the default To-Do,
// Doing and Done; the tasks A, B, C and D are created in that order, so
// To-Do lists D, C, B, A (every new task goes on top, at half the lowest
// position of the view: 8192 to 65536, which the positions sent here avoid,
// because the server spreads equal positions). The tests run in order and
// build on each other: B and A move to Doing and swap places, C moves to
// Done, Doing gets a limit of two, a filter-mode view splits the tasks by
// done, and a repeating task E is moved into Done.
typedef _Seed = ({
  int projectId,
  int viewId,
  int toDo,
  int doing,
  int done,
  int a,
  int b,
  int c,
  int d,
});

const _pace = Duration(milliseconds: 500);

void main() {
  group('kanban on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;

        Uri at(ApiVersion apiVersion, String path) {
          final base = connection.apiBaseUri(apiVersion);
          return base.replace(path: '${base.path}$path');
        }

        Future<Map<String, Object?>> send(
          String method,
          ApiVersion apiVersion,
          String path,
          Map<String, Object?> body,
        ) async {
          try {
            final response = await despiteWriteRaces(
              () => dio.requestUri<Map<String, Object?>>(
                at(apiVersion, path),
                data: body,
                options: Options(
                  method: method,
                  headers: {'Authorization': 'Bearer ${user.jwt}'},
                ),
              ),
            );
            await Future<void>.delayed(_pace);
            return response.data ?? const {};
          } on DioException catch (error) {
            throw StateError(
              '$method $path failed with ${error.response?.statusCode}: '
              '${error.response?.data}',
            );
          }
        }

        Dio authorized(ServerConnection only) => createAuthenticatedDio(
          base: dio,
          connection: only,
          tokens: StaticJwt(user.jwt),
        );

        BucketsPort buckets(ApiVersion apiVersion) {
          final only = onlyVersion(connection, apiVersion);
          return createReadClient(
            dio: authorized(only),
            connection: only,
          ).buckets;
        }

        TasksWritePort writes(ApiVersion apiVersion) {
          final only = onlyVersion(connection, apiVersion);
          return RetryingTasksWrites(
            createWriteClient(dio: authorized(only), connection: only).tasks,
          );
        }

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          user = await registerAndLogin(dio, connection);
        });

        tearDownAll(() => dio.close(force: true));

        for (final apiVersion in ApiVersion.values) {
          group(apiVersion.pathSegment, () {
            late _Seed seed;

            Future<List<BoardBucket>> board({int perPage = 50}) => patiently(
              () =>
                  buckets(apiVersion)
                      .board(seed.projectId, seed.viewId, perPage: perPage),
            );

            Future<Task> place(
              int taskId,
              int bucketId, {
              double? position,
            }) async {
              final task = await writes(apiVersion).update(
                taskId,
                TaskChanges(
                  kanban: {
                    seed.viewId: BucketPlacement(
                      bucketId: bucketId,
                      position: position,
                    ),
                  },
                ),
              );
              await Future<void>.delayed(_pace);
              return task;
            }

            List<int> idsIn(List<BoardBucket> board, int bucketId) => [
              for (final task
                  in board
                      .singleWhere((column) => column.bucket.id == bucketId)
                      .tasks)
                task.id,
            ];

            setUpAll(() async {
              final project = await send('POST', ApiVersion.v2, '/projects', {
                'title': 'Kanban contract ${apiVersion.pathSegment}',
              });
              final projectId = project['id']! as int;
              final views = await patiently(
                () => createReadClient(
                  dio: authorized(connection),
                  connection: connection,
                ).projects.read(projectId),
              ).then((project) => project.views);
              final kanban = views.firstWhere(
                (view) => view.kind == ProjectViewKind.kanban,
              );
              Future<int> create(String title) async {
                final created = await send(
                  'POST',
                  ApiVersion.v2,
                  '/projects/$projectId/tasks',
                  {'title': title},
                );
                return created['id']! as int;
              }

              final a = await create('A');
              final b = await create('B');
              final c = await create('C');
              final d = await create('D');
              final columns = await patiently(
                () => buckets(apiVersion).board(projectId, kanban.id),
              );
              int bucketTitled(String title) => columns
                  .singleWhere((column) => column.bucket.title == title)
                  .bucket
                  .id;
              seed = (
                projectId: projectId,
                viewId: kanban.id,
                toDo: bucketTitled('To-Do'),
                doing: bucketTitled('Doing'),
                done: bucketTitled('Done'),
                a: a,
                b: b,
                c: c,
                d: d,
              );
              expect(kanban.defaultBucketId, seed.toDo);
              expect(kanban.doneBucketId, seed.done);
            });

            test('the board pages every bucket on its own and counts all '
                'its tasks', () async {
              final columns = await board(perPage: 2);

              expect(
                [for (final column in columns) column.bucket.title],
                ['To-Do', 'Doing', 'Done'],
              );
              final toDo = columns.first;
              expect(toDo.bucket.count, 4);
              expect(
                [for (final task in toDo.tasks) task.id],
                [seed.d, seed.c],
              );
              expect(
                toDo.tasks.every((task) => task.bucketId == seed.toDo),
                isTrue,
              );
              expect(
                toDo.tasks.first.position,
                lessThan(toDo.tasks.last.position),
              );
              expect(columns[1].tasks, isEmpty);
              expect(columns[1].bucket.count, 0);
            });

            test('the next page of a bucket carries the bucket of the '
                'request', () async {
              final page = await patiently(
                () => buckets(apiVersion).bucketTasks(
                  seed.projectId,
                  seed.viewId,
                  seed.toDo,
                  page: 2,
                  perPage: 2,
                ),
              );

              expect(
                [for (final task in page.items) task.id],
                [seed.b, seed.a],
              );
              expect(
                page.items.every((task) => task.bucketId == seed.toDo),
                isTrue,
              );
              expect(page.hasMore, isFalse);
            });

            test('a placement moves the task and sets its position', () async {
              await place(seed.b, seed.doing, position: 100000);
              await place(seed.a, seed.doing, position: 200000);
              var columns = await board();

              expect(idsIn(columns, seed.doing), [seed.b, seed.a]);
              expect(idsIn(columns, seed.toDo), [seed.d, seed.c]);
              expect(
                [for (final task in columns[1].tasks) task.position],
                [100000, 200000],
              );

              // Within the bucket the move changes nothing, the position
              // reorders.
              await place(seed.a, seed.doing, position: 50000);
              columns = await board();
              expect(idsIn(columns, seed.doing), [seed.a, seed.b]);
              expect(columns[1].tasks.first.position, 50000);
            });

            test('a move into the done bucket marks the task done', () async {
              final task = await place(seed.c, seed.done, position: 300000);

              expect(task.done, isTrue);
              expect(task.doneAt, isNotNull);
              final columns = await board();
              expect(idsIn(columns, seed.done), [seed.c]);
              expect(columns[2].tasks.single.done, isTrue);
            });

            test('a full bucket refuses the move with 10004', () async {
              await send(
                'POST',
                ApiVersion.v1,
                '/projects/${seed.projectId}/views/${seed.viewId}/buckets/'
                    '${seed.doing}',
                {'title': 'Doing', 'limit': 2, 'position': 200},
              );

              await expectLater(
                place(seed.d, seed.doing, position: 1),
                throwsA(
                  isA<DomainError>().having((f) => f.code, 'code', 10004),
                ),
              );
              final columns = await board();
              expect(idsIn(columns, seed.toDo), [seed.d]);
              final doing = columns[1].bucket;
              expect((doing.limit, doing.count, doing.isFull), (2, 2, true));
            });

            test('a filter-mode view reads synthetic buckets and refuses '
                'moves', () async {
              final view = await send(
                'PUT',
                ApiVersion.v1,
                '/projects/${seed.projectId}/views',
                {
                  'title': 'By state',
                  'view_kind': 'kanban',
                  'bucket_configuration_mode': 'filter',
                  'bucket_configuration': [
                    {
                      'title': 'Open',
                      'filter': {'filter': 'done = false'},
                    },
                    {
                      'title': 'Closed',
                      'filter': {'filter': 'done = true'},
                    },
                  ],
                },
              );
              final viewId = view['id']! as int;
              final columns = await patiently(
                () => buckets(apiVersion).board(seed.projectId, viewId),
              );

              expect(
                [
                  for (final column in columns)
                    (
                      column.bucket.id,
                      column.bucket.title,
                      column.bucket.count,
                    ),
                ],
                [(0, 'Open', 3), (1, 'Closed', 1)],
              );
              expect(idsIn(columns, 1), [seed.c]);
              await expectLater(
                writes(apiVersion).update(
                  seed.d,
                  TaskChanges(
                    kanban: {viewId: const BucketPlacement(bucketId: 0)},
                  ),
                ),
                throwsA(isA<NotFound>().having((f) => f.code, 'code', 10001)),
              );
            });

            test('a repeating task moved into the done bucket reopens in the '
                'default bucket, without the position', () async {
              // A due date in the past would be moved on until it lies in
              // the future, more than one interval.
              final now = DateTime.now().toUtc();
              final due = DateTime.utc(now.year, now.month, now.day + 2, 8);
              final created = await send(
                'POST',
                ApiVersion.v2,
                '/projects/${seed.projectId}/tasks',
                {
                  'title': 'E',
                  'repeat_after': 86400,
                  'due_date': due.toIso8601String(),
                },
              );
              final repeating = created['id']! as int;

              final task = await place(repeating, seed.done, position: 1);

              expect(task.done, isFalse);
              expect(task.dueDate, due.add(const Duration(days: 1)));
              final columns = await board();
              expect(idsIn(columns, seed.done), [seed.c]);
              expect(idsIn(columns, seed.toDo), [repeating, seed.d]);
              expect(columns.first.tasks.first.position, isNot(1));
            });
          });
        }
      });
    }
  });
}
