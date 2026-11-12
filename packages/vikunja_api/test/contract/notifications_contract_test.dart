@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

Future<Map<String, Object?>> _post(
  Dio dio,
  ServerConnection connection,
  TestUser user,
  String path,
  Map<String, Object?> body,
) async {
  final v2 = connection.apiBaseUri(ApiVersion.v2);
  try {
    final response = await despiteWriteRaces(
      () => dio.postUri<Map<String, Object?>>(
        v2.replace(path: '${v2.path}$path'),
        data: body,
        options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
      ),
    );
    return response.data!;
  } on DioException catch (error) {
    throw StateError(
      'POST $path failed with ${error.response?.statusCode}: '
      '${error.response?.data}',
    );
  }
}

Map<String, Object?> _object(Object? value) => value! as Map<String, Object?>;

void main() {
  group('notifications on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser reader;
        late TestUser doer;
        late int projectId;
        late String runId;

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          // The doer shares a project with the reader and then assigns the
          // reader and comments on a task; the reader reads and marks.
          reader = await registerAndLogin(dio, connection);
          doer = await registerAndLogin(dio, connection);
          runId = Random.secure().nextInt(1 << 16).toRadixString(16);
          projectId =
              (await _post(dio, connection, doer, '/projects', {
                    'title': 'Notifications contract $runId',
                  }))['id']!
                  as int;
          await _post(dio, connection, doer, '/projects/$projectId/users', {
            'username': reader.username,
            'permission': 1,
          });
        });

        tearDownAll(() => dio.close(force: true));

        for (final apiVersion in ApiVersion.values) {
          group(apiVersion.pathSegment, () {
            late NotificationsPort notifications;
            late NotificationsWritePort writes;
            late int taskId;
            late bool commentsEnabled;
            late Map<String, ServerNotification> arrived;

            final suffix = apiVersion.pathSegment;

            Future<Map<String, ServerNotification>> waitFor(
              Set<String> names,
            ) async {
              // The server stores notifications from asynchronous event
              // handlers, a moment after the request that caused them.
              final deadline = DateTime.now().add(const Duration(seconds: 30));
              while (true) {
                final page = await notifications.list();
                final found = {
                  for (final notification in page.items)
                    if (notification.taskId == taskId &&
                        names.contains(notification.name))
                      notification.name: notification,
                };
                if (found.length == names.length ||
                    DateTime.now().isAfter(deadline)) {
                  return found;
                }
                await Future<void>.delayed(const Duration(milliseconds: 500));
              }
            }

            // Some notifications come from listeners that run on their own,
            // like a late task.created (see
            // app/test/contract/activity_contract_test.dart), and may be
            // stored after [waitFor] returned, between two reads of a test.
            Future<void> settled() async {
              Future<int> newest() async =>
                  (await notifications.list(perPage: 1)).items.single.id;
              var last = await newest();
              for (var quiet = 0; quiet < 2;) {
                await Future<void>.delayed(const Duration(seconds: 1));
                final now = await newest();
                quiet = now == last ? quiet + 1 : 0;
                last = now;
              }
            }

            Future<ServerNotification> current(int id) async {
              final page = await notifications.list();
              return page.items.singleWhere((n) => n.id == id);
            }

            setUpAll(() async {
              expect(connection.apiVersions, contains(apiVersion));
              final only = onlyVersion(connection, apiVersion);
              final authenticated = createAuthenticatedDio(
                base: dio,
                connection: only,
                tokens: StaticJwt(reader.jwt),
              );
              notifications = createReadClient(
                dio: authenticated,
                connection: only,
              ).notifications;
              writes = createWriteClient(
                dio: authenticated,
                connection: only,
              ).notifications;
              commentsEnabled = connection.info.taskCommentsEnabled;

              taskId =
                  (await _post(
                        dio,
                        connection,
                        doer,
                        '/projects/$projectId/tasks',
                        {'title': 'Water the plants $suffix $runId'},
                      ))['id']!
                      as int;
              await _post(dio, connection, doer, '/tasks/$taskId/assignees', {
                'user_id': reader.id,
              });
              if (commentsEnabled) {
                // Without a subscription only a mention reaches the reader.
                final name = reader.username;
                final mention =
                    '<mention-user data-id="$name">@$name</mention-user>';
                await _post(dio, connection, doer, '/tasks/$taskId/comments', {
                  'comment': '<p>Check the <strong>pots</strong> $mention</p>',
                });
              }
              arrived = await waitFor({
                'task.assigned',
                if (commentsEnabled) 'task.comment',
              });
              await settled();
            });

            test(
              'an assignment by another user arrives with the doer, the task '
              'and the project',
              () async {
                final assigned = arrived['task.assigned'];

                expect(assigned, isNotNull, reason: 'no task.assigned');
                expect(assigned!.taskId, taskId);
                expect(assigned.projectId, projectId);
                expect(assigned.readAt, isNull);
                expect(
                  assigned.created.difference(DateTime.now()).abs(),
                  lessThan(const Duration(minutes: 5)),
                );
                expect(
                  assigned.payload['doer'],
                  allOf(
                    containsPair('id', doer.id),
                    containsPair('username', doer.username),
                  ),
                );
                expect(
                  assigned.payload['assignee'],
                  containsPair('id', reader.id),
                );
                expect(
                  assigned.payload['task'],
                  allOf(
                    containsPair('title', 'Water the plants $suffix $runId'),
                    containsPair('project_id', projectId),
                    contains('identifier'),
                    contains('index'),
                  ),
                );
                expect(
                  assigned.payload['project'],
                  containsPair('title', 'Notifications contract $runId'),
                );
              },
            );

            test('a comment that mentions the user arrives with its text', () {
              if (!commentsEnabled) {
                markTestSkipped('task comments are disabled on this server');
                return;
              }
              final comment = arrived['task.comment'];

              expect(comment, isNotNull, reason: 'no task.comment');
              expect(comment!.taskId, taskId);
              expect(comment.projectId, projectId);
              expect(comment.payload['doer'], containsPair('id', doer.id));
              expect(comment.payload['mentioned'], isTrue);
              final body = _object(comment.payload['comment']);
              expect(body['comment'], contains('<strong>pots</strong>'));
              expect(_object(body['author'])['id'], doer.id);
            });

            test('the list is newest first and paged', () async {
              final first = await notifications.list(perPage: 1);
              final second = await notifications.list(page: 2, perPage: 1);

              expect(first.items, hasLength(1));
              expect(second.items, hasLength(1));
              expect(
                first.items.single.id,
                greaterThan(second.items.single.id),
              );
              expect(first.perPage, 1);
              expect(first.totalPages, greaterThanOrEqualTo(2));
              expect(first.hasMore, isTrue);
              if (apiVersion == ApiVersion.v2) {
                expect(first.total, greaterThanOrEqualTo(2));
              }
            });

            test('markRead sets the read date, read false clears it', () async {
              final id = arrived['task.assigned']!.id;

              await despiteWriteRaces(() => writes.markRead(id));
              final read = await current(id);
              expect(read.readAt, isNotNull);
              expect(
                read.readAt!.difference(DateTime.now()).abs(),
                lessThan(const Duration(minutes: 5)),
              );

              await despiteWriteRaces(() => writes.markRead(id, read: false));
              expect((await current(id)).readAt, isNull);
            });

            test(
              'markRead of a notification that does not exist succeeds',
              () => expectLater(writes.markRead(2147483000), completes),
            );

            test('markAllRead marks every notification read', () async {
              expect(
                (await notifications.list()).items.where((n) => !n.isRead),
                isNotEmpty,
              );

              await despiteWriteRaces(writes.markAllRead);

              final page = await notifications.list();
              expect(page.items, isNotEmpty);
              expect(page.items.map((n) => n.isRead), everyElement(isTrue));
            });
          });
        }
      });
    }
  });
}
