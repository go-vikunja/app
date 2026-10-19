@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

const _connector = IoRealtimeConnector();

// Every upgrade counts against the limit of /login and /register, so the
// file opens four sockets and registers two users.
Future<RealtimeSocket> _connect(
  ServerConnection connection,
  ApiVersion version,
) => patiently(
  () => _connector.connect(
    realtimeUri(onlyVersion(connection, version)),
    headers: {'User-Agent': 'Rurana contract tests'},
  ),
);

Future<Map<String, Object?>> _send(
  Dio dio,
  ServerConnection connection,
  TestUser user,
  String method,
  String path, {
  ApiVersion version = ApiVersion.v2,
  Map<String, Object?> body = const {},
}) async {
  final base = connection.apiBaseUri(version);
  try {
    final response = await despiteWriteRaces(
      () => dio.requestUri<Map<String, Object?>>(
        base.replace(path: '${base.path}$path'),
        data: body,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer ${user.jwt}'},
        ),
      ),
    );
    return response.data ?? const {};
  } on DioException catch (error) {
    throw StateError('$method $path failed with ${error.response?.statusCode}');
  }
}

/// Keeps every message of a socket, so a test can wait for the next one.
final class _Inbox {
  new(this.socket) {
    socket.messages.listen(_messages.add, onDone: _closed.complete);
  }

  final RealtimeSocket socket;
  final _messages = <RealtimeMessage>[];
  final _closed = Completer<void>();
  var _read = 0;

  Future<void> get closed =>
      _closed.future.timeout(const Duration(seconds: 15));

  Future<RealtimeMessage> next() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (_read == _messages.length) {
      if (_closed.isCompleted) {
        throw StateError('closed with ${socket.closeCode}');
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('no message within 15 s');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return _messages[_read++];
  }

  Future<T> nextWhere<T extends RealtimeMessage>(bool Function(T) test) async {
    while (true) {
      if (await next() case final T message when test(message)) return message;
    }
  }
}

void main() {
  group('realtime on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser reader;
        late TestUser doer;
        late int taskId;
        late String runId;
        late String apiToken;
        final inboxes = <ApiVersion, _Inbox>{};
        final repliesBeforeAuth = <ApiVersion, RealtimeMessage>{};
        final authReplies = <ApiVersion, RealtimeMessage>{};

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          // The reader owns the task, so it is subscribed to it; the doer
          // comments on it through a shared project.
          reader = await registerAndLogin(dio, connection);
          doer = await registerAndLogin(dio, connection);
          runId = Random.secure().nextInt(1 << 16).toRadixString(16);
          final project = await _send(
            dio,
            connection,
            reader,
            'POST',
            '/projects',
            body: {'title': 'Realtime contract $runId'},
          );
          final projectId = project['id']! as int;
          final task = await _send(
            dio,
            connection,
            reader,
            'POST',
            '/projects/$projectId/tasks',
            body: {'title': 'Repot the fern $runId'},
          );
          taskId = task['id']! as int;
          await _send(
            dio,
            connection,
            reader,
            'POST',
            '/projects/$projectId/users',
            body: {'username': doer.username, 'permission': 1},
          );
          final token = await _send(
            dio,
            connection,
            reader,
            'PUT',
            '/tokens',
            version: ApiVersion.v1,
            body: {
              'title': 'Realtime contract $runId',
              'permissions': {
                'tasks': ['read_all'],
              },
              'expires_at': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 1))
                  .toIso8601String(),
            },
          );
          apiToken = token['token']! as String;

          for (final apiVersion in ApiVersion.values) {
            final inbox = inboxes[apiVersion] = _Inbox(
              await _connect(connection, apiVersion),
            );
            inbox.socket.subscribe(RealtimeSocket.notificationCreated);
            repliesBeforeAuth[apiVersion] = await inbox.next();
            inbox.socket.authenticate(reader.jwt);
            authReplies[apiVersion] = await inbox.next();
            inbox.socket.subscribe(RealtimeSocket.notificationCreated);
          }
        });

        tearDownAll(() async {
          for (final inbox in inboxes.values) {
            await inbox.socket.close();
          }
          dio.close(force: true);
        });

        for (final apiVersion in ApiVersion.values) {
          group('/api/${apiVersion.pathSegment}/ws', () {
            test('a subscription before auth is answered auth_required', () {
              expect(
                repliesBeforeAuth[apiVersion],
                const RealtimeError(RealtimeError.authRequired),
              );
            });

            test('a user JWT authenticates', () {
              expect(authReplies[apiVersion], isA<RealtimeAuthSucceeded>());
            });

            test(
              'an API token is answered invalid_token, then closed with 1000',
              () async {
                final inbox = _Inbox(await _connect(connection, apiVersion));

                inbox.socket.authenticate(apiToken);

                expect(
                  await inbox.next(),
                  const RealtimeError(RealtimeError.invalidToken),
                );
                await inbox.closed;
                expect(inbox.socket.closeCode, 1000);
              },
            );
          });
        }

        test("another user's comment reaches every socket as the notifications "
            'list item', () async {
          if (!connection.info.taskCommentsEnabled) {
            markTestSkipped('task comments are disabled on this server');
            return;
          }

          final comment = await _send(
            dio,
            connection,
            doer,
            'POST',
            '/tasks/$taskId/comments',
            body: {'comment': '<p>Fresh soil $runId</p>'},
          );

          final pushed = {
            for (final apiVersion in ApiVersion.values)
              apiVersion:
                  (await inboxes[apiVersion]!.nextWhere<RealtimeNotification>(
                    (m) => m.notification.taskId == taskId,
                  )).notification,
          };
          final notification = pushed[ApiVersion.v2]!;
          expect(pushed[ApiVersion.v1], notification);
          expect(notification.name, 'task.comment');
          expect(notification.readAt, isNull);
          expect(notification.payload['doer'], containsPair('id', doer.id));
          expect(
            notification.payload['comment'],
            containsPair('id', comment['id']),
          );

          for (final apiVersion in ApiVersion.values) {
            final only = onlyVersion(connection, apiVersion);
            final page = await createReadClient(
              dio: createAuthenticatedDio(
                base: dio,
                connection: only,
                tokens: StaticJwt(reader.jwt),
              ),
              connection: only,
            ).notifications.list();
            final listed = page.items.singleWhere(
              (item) => item.id == notification.id,
            );
            expect(pushed[apiVersion], listed, reason: '$apiVersion');
            expect(
              pushed[apiVersion]!.payload,
              listed.payload,
              reason: '$apiVersion',
            );
          }
        });

        test(
          "signing out closes the session's sockets with 1008 session revoked",
          () async {
            await _send(
              dio,
              connection,
              reader,
              'POST',
              '/user/logout',
              version: ApiVersion.v1,
            );

            for (final MapEntry(key: apiVersion, value: inbox)
                in inboxes.entries) {
              await inbox.closed;
              expect(inbox.socket.closeCode, 1008, reason: '$apiVersion');
              expect(
                inbox.socket.closeReason,
                'session revoked',
                reason: '$apiVersion',
              );
            }
          },
        );
      });
    }
  });
}
