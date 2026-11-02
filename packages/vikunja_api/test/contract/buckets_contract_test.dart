@Tags(['contract'])
@Timeout(Duration(minutes: 4))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Per API version one project whose Kanban view has the default To-Do,
// Doing and Done and a view filter that matches every task; A stays in
// To-Do, B is moved to Doing and C into Done. The tests run in order and
// build on each other: Later is created rightmost, Review between Doing and
// Done with a limit, Review is renamed to Checked, Doing gets a limit,
// Later moves to the front, Doing is deleted, the done and default buckets
// are set and cleared, a second board is deleted down to its last bucket,
// and a third is filled up to the server's cap.
typedef _Seed = ({
  int projectId,
  int viewId,
  Bucket toDo,
  Bucket doing,
  Bucket done,
  int a,
  int b,
  int c,
});

const _pace = Duration(milliseconds: 500);

// Bumped by every view update, or not sent at all.
const _volatileViewFields = {
  r'$schema',
  'updated',
  'max_permission',
  'done_bucket_id',
  'default_bucket_id',
};

void main() {
  group('bucket writes on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser user;

        Uri at(String path) {
          final base = connection.apiBaseUri(ApiVersion.v2);
          return base.replace(path: '${base.path}$path');
        }

        Future<Map<String, Object?>> send(
          String method,
          String path, {
          Map<String, Object?>? body,
          String? contentType,
        }) async {
          try {
            final response = await despiteWriteRaces(
              () => dio.requestUri<Map<String, Object?>>(
                at(path),
                data: body,
                options: Options(
                  method: method,
                  contentType: contentType,
                  headers: {'Authorization': 'Bearer ${user.jwt}'},
                ),
              ),
            );
            if (method != 'GET') await Future<void>.delayed(_pace);
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

        VikunjaReadClient reads() => createReadClient(
          dio: authorized(connection),
          connection: connection,
        );

        VikunjaWriteClient writeClient(ApiVersion apiVersion) {
          final only = onlyVersion(connection, apiVersion);
          return createWriteClient(dio: authorized(only), connection: only);
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

            BucketsWritePort buckets() =>
                RetryingBucketsWrites(writeClient(apiVersion).buckets);

            ProjectViewsWritePort views() =>
                RetryingProjectViewsWrites(writeClient(apiVersion).views);

            Future<T> paced<T>(Future<T> Function() write) async {
              final result = await write();
              await Future<void>.delayed(_pace);
              return result;
            }

            Future<List<BoardBucket>> board({int? viewId}) => patiently(
              () =>
                  reads().buckets.board(seed.projectId, viewId ?? seed.viewId),
            );

            BoardBucket column(List<BoardBucket> board, int bucketId) =>
                board.singleWhere((column) => column.bucket.id == bucketId);

            List<String> titles(List<BoardBucket> board) => [
              for (final column in board) column.bucket.title,
            ];

            Future<Map<String, Object?>> rawView() =>
                send('GET', '/projects/${seed.projectId}/views/${seed.viewId}');

            Map<String, Object?> lasting(Map<String, Object?> view) => {
              for (final MapEntry(:key, :value) in view.entries)
                if (!_volatileViewFields.contains(key)) key: value,
            };

            setUpAll(() async {
              final project = await send(
                'POST',
                '/projects',
                body: {'title': 'Bucket contract ${apiVersion.pathSegment}'},
              );
              final projectId = project['id']! as int;
              final kanban =
                  await patiently(() => reads().projects.read(projectId)).then(
                    (project) => project.views.firstWhere(
                      (view) => view.kind == ProjectViewKind.kanban,
                    ),
                  );
              final views = '/projects/$projectId/views/${kanban.id}';
              Future<int> create(String title) async {
                final created = await send(
                  'POST',
                  '/projects/$projectId/tasks',
                  body: {'title': title},
                );
                return created['id']! as int;
              }

              final a = await create('A');
              final b = await create('B');
              final c = await create('C');
              await send(
                'PATCH',
                views,
                body: {
                  'filter': {'filter': 'priority >= 0'},
                },
                contentType: 'application/merge-patch+json',
              );
              final columns = await patiently(
                () => reads().buckets.board(projectId, kanban.id),
              );
              Bucket titled(String title) => columns
                  .singleWhere((column) => column.bucket.title == title)
                  .bucket;
              final doing = titled('Doing');
              final done = titled('Done');
              await send(
                'PUT',
                '$views/buckets/${doing.id}/tasks',
                body: {'task_id': b},
              );
              await send(
                'PUT',
                '$views/buckets/${done.id}/tasks',
                body: {'task_id': c},
              );
              seed = (
                projectId: projectId,
                viewId: kanban.id,
                toDo: titled('To-Do'),
                doing: doing,
                done: done,
                a: a,
                b: b,
                c: c,
              );
              expect(kanban.defaultBucketId, seed.toDo.id);
              expect(kanban.doneBucketId, seed.done.id);
            });

            late Bucket later;
            late Bucket review;

            test('a bucket created without a position lands rightmost and is '
                'answered with count 0', () async {
              later = await paced(
                () => buckets().create(
                  seed.projectId,
                  seed.viewId,
                  title: 'Later',
                ),
              );

              expect(
                (later.title, later.viewId, later.limit, later.count),
                ('Later', seed.viewId, 0, 0),
              );
              final columns = await board();
              expect(titles(columns), ['To-Do', 'Doing', 'Done', 'Later']);
              expect(column(columns, later.id).bucket.position, later.position);
              expect([
                for (final column in columns)
                  for (final task in column.tasks) task.id,
              ], unorderedEquals([seed.a, seed.b, seed.c]));
            });

            test('a bucket is created with a limit and a position', () async {
              final position = (seed.doing.position + seed.done.position) / 2;

              review = await paced(
                () => buckets().create(
                  seed.projectId,
                  seed.viewId,
                  title: 'Review',
                  limit: 3,
                  position: position,
                ),
              );

              expect((review.limit, review.position), (3, position));
              final columns = await board();
              expect(titles(columns), [
                'To-Do',
                'Doing',
                'Review',
                'Done',
                'Later',
              ]);
              expect(column(columns, review.id).bucket.limit, 3);
            });

            test('a rename sent with the limit and the position keeps '
                'both', () async {
              final renamed = await paced(
                () => buckets().update(
                  seed.projectId,
                  seed.viewId,
                  bucketId: review.id,
                  title: 'Checked',
                  limit: review.limit,
                  position: review.position,
                ),
              );

              expect(
                renamed,
                Bucket(
                  id: review.id,
                  viewId: seed.viewId,
                  title: 'Checked',
                  limit: 3,
                  position: review.position,
                ),
              );
              final stored = column(await board(), review.id).bucket;
              expect(
                (stored.title, stored.limit, stored.position),
                ('Checked', 3, review.position),
              );
              review = renamed;
            });

            test('a limit is stored and the count stays', () async {
              await paced(
                () => buckets().update(
                  seed.projectId,
                  seed.viewId,
                  bucketId: seed.doing.id,
                  title: seed.doing.title,
                  limit: 1,
                  position: seed.doing.position,
                ),
              );

              final doing = column(await board(), seed.doing.id);
              expect(
                (doing.bucket.limit, doing.bucket.count, doing.bucket.isFull),
                (1, 1, true),
              );
              expect([for (final task in doing.tasks) task.id], [seed.b]);
              expect(doing.bucket.title, 'Doing');
              expect(doing.bucket.position, seed.doing.position);
            });

            test('a new position reorders the columns and is stored as '
                'sent', () async {
              final position = seed.toDo.position / 3;

              await paced(
                () => buckets().update(
                  seed.projectId,
                  seed.viewId,
                  bucketId: later.id,
                  title: later.title,
                  limit: later.limit,
                  position: position,
                ),
              );

              final columns = await board();
              expect(titles(columns), [
                'Later',
                'To-Do',
                'Doing',
                'Checked',
                'Done',
              ]);
              expect(columns.first.bucket.position, position);
            });

            test('a delete moves the tasks to the default bucket with their '
                'positions, and a repeated one passes', () async {
              final before = column(await board(), seed.doing.id).tasks.single;

              await paced(
                () => buckets().delete(
                  seed.projectId,
                  seed.viewId,
                  seed.doing.id,
                ),
              );
              await paced(
                () => buckets().delete(
                  seed.projectId,
                  seed.viewId,
                  seed.doing.id,
                ),
              );

              final columns = await board();
              expect(titles(columns), ['Later', 'To-Do', 'Checked', 'Done']);
              final toDo = column(columns, seed.toDo.id);
              expect(toDo.bucket.count, 2);
              final moved = toDo.tasks.singleWhere((t) => t.id == seed.b);
              expect(moved.position, before.position);
              expect(moved.done, isFalse);
            });

            test('done and default set through the ${apiVersion.pathSegment} '
                'request leave the rest of the view and every task as they '
                'were', () async {
              final before = await rawView();

              final view = await paced(
                () => views().setBuckets(
                  seed.projectId,
                  seed.viewId,
                  doneBucketId: review.id,
                  defaultBucketId: later.id,
                ),
              );

              expect(
                (view.id, view.doneBucketId, view.defaultBucketId),
                (seed.viewId, review.id, later.id),
              );
              expect(view.kind, ProjectViewKind.kanban);
              expect(view.filter?.filter, 'priority >= 0');
              final after = await rawView();
              expect(lasting(after), lasting(before));
              expect(
                (after['done_bucket_id'], after['default_bucket_id']),
                (review.id, later.id),
              );
              final columns = await board();
              expect(column(columns, review.id).tasks, isEmpty);
              expect([
                for (final task in column(columns, seed.toDo.id).tasks)
                  (task.id, task.done),
              ], unorderedEquals([(seed.a, false), (seed.b, false)]));
              expect(
                [
                  for (final task in column(columns, seed.done.id).tasks)
                    (task.id, task.done),
                ],
                [(seed.c, true)],
              );
            });

            test('done and default cleared with 0 leave the rest of the view '
                'as it was', () async {
              final before = await rawView();

              final onlyDone = await paced(
                () => views().setBuckets(
                  seed.projectId,
                  seed.viewId,
                  doneBucketId: 0,
                ),
              );
              expect(
                (onlyDone.doneBucketId, onlyDone.defaultBucketId),
                (0, later.id),
              );
              final cleared = await paced(
                () => views().setBuckets(
                  seed.projectId,
                  seed.viewId,
                  defaultBucketId: 0,
                ),
              );

              expect((cleared.doneBucketId, cleared.defaultBucketId), (0, 0));
              final after = await rawView();
              expect(lasting(after), lasting(before));
              final done = column(await board(), seed.done.id);
              expect(
                [for (final task in done.tasks) (task.id, task.done)],
                [(seed.c, true)],
              );
            });

            test('the last bucket of a view cannot be deleted', () async {
              final created = await send(
                'POST',
                '/projects/${seed.projectId}/views',
                body: {
                  'title': 'Second board',
                  'view_kind': 'kanban',
                  'bucket_configuration_mode': 'manual',
                },
              );
              final viewId = created['id']! as int;
              final [...doomed, last] = [
                for (final column in await board(viewId: viewId))
                  column.bucket.id,
              ];
              for (final bucketId in doomed) {
                await paced(
                  () => buckets().delete(seed.projectId, viewId, bucketId),
                );
              }

              await expectLater(
                buckets().delete(seed.projectId, viewId, last),
                throwsA(
                  isA<DomainError>().having((f) => f.code, 'code', 10003),
                ),
              );
              expect(
                [
                  for (final column in await board(viewId: viewId))
                    column.bucket.id,
                ],
                [last],
              );
            });

            test('a view holds at most 100 buckets', () async {
              if (!connection.info.version!.isAtLeast(2, 7, 1)) {
                markTestSkipped('servers before 2.7.1 have no bucket cap');
                return;
              }
              final created = await send(
                'POST',
                '/projects/${seed.projectId}/views',
                body: {
                  'title': 'Full board',
                  'view_kind': 'kanban',
                  'bucket_configuration_mode': 'manual',
                },
              );
              final viewId = created['id']! as int;
              final path = '/projects/${seed.projectId}/views/$viewId/buckets';
              // Unpaced: a hundred paced writes would take a minute.
              for (var i = (await board(viewId: viewId)).length; i < 100; i++) {
                await despiteWriteRaces(
                  () => dio.requestUri<Object?>(
                    at(path),
                    data: {'title': 'Column $i'},
                    options: Options(
                      method: 'POST',
                      headers: {'Authorization': 'Bearer ${user.jwt}'},
                    ),
                  ),
                );
              }

              await expectLater(
                buckets().create(seed.projectId, viewId, title: 'One more'),
                throwsA(
                  isA<DomainError>()
                      .having((f) => f.statusCode, 'status', 412)
                      .having((f) => f.code, 'code', 10007),
                ),
              );
            });
          });
        }
      });
    }
  });
}
