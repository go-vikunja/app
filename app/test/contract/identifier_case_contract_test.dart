@Tags(['contract'])
@Timeout(Duration(minutes: 4))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_resolver.dart';

import '../helpers/test_database.dart';
import 'helpers.dart';

void main() {
  group(
    'project identifiers that differ only in case on Vikunja 2.3',
    skip:
        contractSkip ??
        (contractApiVersions.contains(ApiVersion.v2)
            ? '2.4 and later keep identifiers unique ignoring case'
            : null),
    () {
      late Dio dio;
      late VikunjaReadClient reads;
      late String lower;
      late String upper;
      late int lowerTaskId;
      late int upperTaskId;

      setUpAll(() async {
        dio = contractDio();
        final connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        final user = await registerAndLogin(dio, connection);
        final seeder = Seeder(dio, connection, user);
        final run = Random.secure().nextInt(1 << 24).toRadixString(16);
        lower = 'xy$run';
        upper = 'XY$run';
        Future<int> taskIn(String identifier) async {
          final projectId = await seeder.create('/projects', {
            'title': 'Case $identifier',
            'identifier': identifier,
          });
          return await seeder.create('/projects/$projectId/tasks', {
            'title': 'In $identifier',
          });
        }

        lowerTaskId = await taskIn(lower);
        upperTaskId = await taskIn(upper);
        final only = onlyApiVersion(connection, ApiVersion.v1);
        reads = createReadClient(
          dio: createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
          ),
          connection: only,
        );
      });

      tearDownAll(() => dio.close(force: true));

      /// A device without the tasks, with the user's projects when
      /// [synced].
      Future<LocalTaskResolver> device({required bool synced}) async {
        final db = testDatabase();
        if (synced) {
          await db.projectsDao.upsertAll(await reads.projects.listAll());
        }
        return LocalTaskResolver(db, reads);
      }

      test('the server keeps both as typed', () async {
        final identifiers = {
          for (final project in await reads.projects.listAll())
            project.identifier,
        };
        expect(identifiers, containsAll([lower, upper]));
      });

      test('the exact identifier finds its task, by the project id of the '
          'project on the device or by the identifier', () async {
        for (final synced in [false, true]) {
          final resolver = await device(synced: synced);
          expect(
            (await resolver.resolve(TaskByIdentifier(lower, 1))).id,
            lowerTaskId,
            reason: 'synced: $synced',
          );
          expect(
            (await resolver.resolve(TaskByIdentifier(upper, 1))).id,
            upperTaskId,
            reason: 'synced: $synced',
          );
        }
      });

      test('another case names both and finds none', () async {
        final either = TaskByIdentifier('Xy${lower.substring(2)}', 1);

        for (final synced in [false, true]) {
          final resolver = await device(synced: synced);
          expect(await resolver.findLocal(either), isNull);
          await expectLater(
            resolver.resolve(either),
            throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
            reason: 'synced: $synced',
          );
        }
      });
    },
  );
}
