@Tags(['contract'])
@Timeout(Duration(minutes: 4))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

/// [connection] over [apiVersion] only, as a client that stored 2.3.0
/// before the server was upgraded sees it: always the filtered read.
ServerConnection _storedAs23(
  ServerConnection connection,
  ApiVersion apiVersion,
) => ServerConnection(
  rootUri: connection.rootUri,
  apiVersions: {apiVersion},
  info: ServerInfo(
    version: const ServerVersion(2, 3, 0),
    maxItemsPerPage: connection.info.maxItemsPerPage,
  ),
  capabilities: connection.capabilities,
);

void main() {
  group(
    'a task by index where Vikunja has no by-index route (2.3)',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser owner;
      late String run;
      late int projectId;
      late String identifier;
      late int openId;
      late int doneId;
      late int doneIndex;
      late String archivedIdentifier;
      late int archivedTaskId;
      late int foreignId;
      late String foreignIdentifier;

      Future<Map<String, Object?>> send(
        TestUser user,
        String method,
        String path, [
        Map<String, Object?>? body,
      ]) async {
        final response = await despiteWriteRaces(
          () => seedRequest<Map<String, Object?>>(
            dio,
            connection,
            user.jwt,
            method,
            path,
            data: body,
          ),
        );
        return response.data!;
      }

      Future<Map<String, Object?>> project(
        TestUser user,
        String title,
        String identifier,
      ) => send(user, 'POST', '/projects', {
        'title': title,
        'identifier': identifier,
      });

      Future<Map<String, Object?>> task(TestUser user, int projectId) =>
          send(user, 'POST', '/projects/$projectId/tasks', {'title': 'Task'});

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractPort');
        owner = await registerAndLogin(dio, connection);
        final stranger = await registerAndLogin(dio, connection);
        run = Random.secure().nextInt(1 << 24).toRadixString(16);

        final created = await project(owner, 'Fallback $run', 'fb$run');
        projectId = created['id']! as int;
        identifier = created['identifier']! as String;
        openId = (await task(owner, projectId))['id']! as int;
        final done = await task(owner, projectId);
        doneId = done['id']! as int;
        doneIndex = done['index']! as int;
        await send(owner, 'PATCH', '/tasks/$doneId', {'done': true});

        final archived = await project(owner, 'Archived $run', 'ar$run');
        archivedIdentifier = archived['identifier']! as String;
        archivedTaskId =
            (await task(owner, archived['id']! as int))['id']! as int;
        await send(owner, 'PATCH', '/projects/${archived['id']}', {
          'is_archived': true,
        });

        final foreign = await project(stranger, 'Foreign $run', 'fo$run');
        foreignId = foreign['id']! as int;
        foreignIdentifier = foreign['identifier']! as String;
        await task(stranger, foreignId);
      });

      tearDownAll(() => dio.close(force: true));

      test('2.3 keeps an identifier as typed and unique only as typed; '
          '2.4 and later upper-case it and keep it unique ignoring case', () {
        if (contractServerVersion.isAtLeast(2, 4)) {
          expect(identifier, 'FB$run'.toUpperCase());
        } else {
          expect(identifier, 'fb$run');
        }
      });

      test('a twin in another case exists only on 2.3', () async {
        final twin = send(owner, 'POST', '/projects', {
          'title': 'Twin $run',
          'identifier': 'FB$run'.toUpperCase(),
        });
        if (contractServerVersion.isAtLeast(2, 4)) {
          await expectLater(
            twin,
            throwsA(
              isA<DioException>().having(
                (e) => (e.response?.data as Map?)?['code'],
                'code',
                3007,
              ),
            ),
          );
        } else {
          expect((await twin)['identifier'], 'FB$run'.toUpperCase());
        }
      });

      for (final apiVersion in contractApiVersions) {
        for (final stored in [
          false,
          if (contractServerVersion.isAtLeast(2, 4)) true,
        ]) {
          final path = stored || !contractServerVersion.isAtLeast(2, 4)
              ? 'filtered read'
              : 'by-index route';
          group('${apiVersion.pathSegment}, '
              '${stored ? 'a stored 2.3.0, ' : ''}$path', () {
            late TasksPort reads;

            setUpAll(() {
              final only = stored
                  ? _storedAs23(connection, apiVersion)
                  : onlyVersion(connection, apiVersion);
              reads = createReadClient(
                dio: createAuthenticatedDio(
                  base: dio,
                  connection: only,
                  tokens: StaticJwt(owner.jwt),
                ),
                connection: only,
              ).tasks;
            });

            test('by project id and identifier, a done task and one in an '
                'archived project too', () async {
              expect((await reads.readByIndex('$projectId', 1)).id, openId);
              expect((await reads.readByIndex(identifier, 1)).id, openId);
              expect(
                (await reads.readByIndex(identifier.toLowerCase(), 1)).id,
                openId,
              );
              final done = await reads.readByIndex(identifier, doneIndex);
              expect(done.id, doneId);
              expect(done.done, isTrue);
              expect(
                (await reads.readByIndex(archivedIdentifier, 1)).id,
                archivedTaskId,
              );
            });

            test("unknown project or index; another user's project is "
                'Forbidden by id, by identifier only on the route', () async {
              await expectLater(
                reads.readByIndex('NO$identifier', 1),
                throwsA(isA<NotFound>()),
              );
              await expectLater(
                reads.readByIndex(identifier, 999999),
                throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
              );
              await expectLater(
                reads.readByIndex('999999999', 1),
                throwsA(isA<NotFound>()),
              );
              await expectLater(
                reads.readByIndex('$foreignId', 1),
                throwsA(isA<Forbidden>()),
              );
              await expectLater(
                reads.readByIndex(foreignIdentifier, 1),
                path == 'filtered read'
                    ? throwsA(
                        isA<NotFound>().having((f) => f.code, 'code', 3001),
                      )
                    : throwsA(isA<Forbidden>()),
              );
            });
          });
        }
      }

      group(
        'identifiers that differ only in case (2.3)',
        skip: contractServerVersion.isAtLeast(2, 4)
            ? 'a 2.3 server only'
            : null,
        () {
          late TasksPort reads;
          late int twinTaskId;

          setUpAll(() async {
            final only = onlyVersion(connection, ApiVersion.v1);
            reads = createReadClient(
              dio: createAuthenticatedDio(
                base: dio,
                connection: only,
                tokens: StaticJwt(owner.jwt),
              ),
              connection: only,
            ).tasks;
            final twin = await project(owner, 'Twin two $run', 'fB$run');
            twinTaskId = (await task(owner, twin['id']! as int))['id']! as int;
          });

          test('the exact one is found; another case names both and finds '
              'none', () async {
            expect((await reads.readByIndex('fb$run', 1)).id, openId);
            expect((await reads.readByIndex('fB$run', 1)).id, twinTaskId);
            await expectLater(
              reads.readByIndex('Fb$run', 1),
              throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
            );
          });
        },
      );
    },
  );
}
