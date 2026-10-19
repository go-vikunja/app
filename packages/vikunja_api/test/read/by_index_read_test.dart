import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

TasksPort _tasks(Dio dio, {bool hasV2 = true, String root = testServerRoot}) {
  final connection = testConnection(hasV2: hasV2);
  return createReadClient(
    dio: dio,
    connection: ServerConnection(
      rootUri: Uri.parse(root),
      apiVersions: connection.apiVersions,
      info: connection.info,
      capabilities: connection.capabilities,
    ),
  ).tasks;
}

FakeRoute _temporaryRedirect(String location) =>
    (_) => ResponseBody.fromString(
      'null\n',
      307,
      headers: {
        'location': [location],
        'cache-control': ['no-store'],
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
    group(hasV2 ? 'v2' : 'v1', () {
      test('by a numeric project id', () async {
        final dio = fakeDio({
          '$base/projects/17/tasks/by-index/3': json(taskJson(19)),
        });

        final task = await _tasks(dio, hasV2: hasV2).readByIndex('17', 3);

        expect(task.id, 19);
        expect(adapterOf(dio).requests.single.method, 'GET');
      });

      test('by an identifier as typed, one encoded path segment', () async {
        final dio = fakeDio({
          '$base/projects/pa9332/tasks/by-index/1': json(taskJson(1)),
          '$base/projects/X%20Y933/tasks/by-index/2': json(taskJson(2)),
          '$base/projects/STRA%C3%9FE/tasks/by-index/3': json(taskJson(3)),
          '$base/projects/A%2FB%3F%23/tasks/by-index/4': json(taskJson(4)),
          '$base/projects/A-B9332/tasks/by-index/5': json(taskJson(5)),
        });
        final tasks = _tasks(dio, hasV2: hasV2);

        expect((await tasks.readByIndex('pa9332', 1)).id, 1);
        expect((await tasks.readByIndex('X Y933', 2)).id, 2);
        expect((await tasks.readByIndex('STRAßE', 3)).id, 3);
        expect((await tasks.readByIndex('A/B?#', 4)).id, 4);
        expect((await tasks.readByIndex('A-B9332', 5)).id, 5);
      });

      test('an identifier of dots is not found without a request', () async {
        final dio = fakeDio({});
        final tasks = _tasks(dio, hasV2: hasV2);

        for (final identifier in ['.', '..']) {
          await expectLater(
            tasks.readByIndex(identifier, 3),
            throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
          );
        }
        expect(adapterOf(dio).requests, isEmpty);
      });

      test('unknown project, unknown index and no access', () async {
        final dio = fakeDio({
          '$base/projects/ZZZQQQ/tasks/by-index/1': hasV2
              ? json({
                  'title': 'Not Found',
                  'status': 404,
                  'detail': 'This project does not exist.',
                  'code': 3001,
                }, status: 404)
              : json({'message': 'Project not found'}, status: 404),
          '$base/projects/17/tasks/by-index/999': json({
            'code': 4002,
            'message': 'This task does not exist',
          }, status: 404),
          '$base/projects/19/tasks/by-index/1': json({
            'code': 0,
            'message': "You don't have the permission to see this",
          }, status: 403),
        });
        final tasks = _tasks(dio, hasV2: hasV2);

        await expectLater(
          tasks.readByIndex('ZZZQQQ', 1),
          throwsA(isA<NotFound>()),
        );
        await expectLater(
          tasks.readByIndex('17', 999),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
        );
        await expectLater(
          tasks.readByIndex('19', 1),
          throwsA(isA<Forbidden>()),
        );
      });
    });
  }

  group('v2 307 for an index the task had before it moved', () {
    test('followed once on the same client', () async {
      final dio = fakeDio({
        '$_v2/projects/17/tasks/by-index/3': _temporaryRedirect(
          '/api/v2/projects/18/tasks/by-index/1',
        ),
        '$_v2/projects/18/tasks/by-index/1': json(taskJson(19)),
      });

      final task = await _tasks(dio).readByIndex('17', 3);

      expect(task.id, 19);
      final requests = adapterOf(dio).requests;
      expect(requests.map((r) => r.uri.toString()), [
        '$_v2/projects/17/tasks/by-index/3',
        '$_v2/projects/18/tasks/by-index/1',
      ]);
    });

    test('the captured 307 keeps its query', () async {
      final dio = fakeDio({
        '$_v2/projects/PA9332/tasks/by-index/3': _temporaryRedirect(
          '/api/v2/projects/17/tasks/by-index/6?expand=comment_count',
        ),
        '$_v2/projects/17/tasks/by-index/6?expand=comment_count': json(
          taskJson(19),
        ),
      });

      expect((await _tasks(dio).readByIndex('PA9332', 3)).id, 19);
    });

    test('re-attached to a server under a sub-path', () async {
      const root = 'https://example.com/vikunja';
      final dio = fakeDio({
        '$root/api/v2/projects/17/tasks/by-index/3': _temporaryRedirect(
          '/api/v2/projects/18/tasks/by-index/1',
        ),
        '$root/api/v2/projects/18/tasks/by-index/1': json(taskJson(19)),
      });

      final task = await _tasks(dio, root: root).readByIndex('17', 3);

      expect(task.id, 19);
    });

    test('a Location of any other shape is not followed', () async {
      for (final location in [
        'https://evil.example/api/v2/projects/18/tasks/by-index/1',
        '//evil.example/api/v2/projects/18/tasks/by-index/1',
        '/api/v2/tasks/1',
        '/api/v1/projects/18/tasks/by-index/1',
        '/api/v2/projects/IDENT/tasks/by-index/1',
        '/api/v2/projects/18/tasks/by-index/1/../../../../user',
        '',
      ]) {
        final dio = fakeDio({
          '$_v2/projects/17/tasks/by-index/3': _temporaryRedirect(location),
        });

        await expectLater(
          _tasks(dio).readByIndex('17', 3),
          throwsA(
            isA<UnexpectedResponse>().having(
              (f) => f.statusCode,
              'statusCode',
              307,
            ),
          ),
          reason: location,
        );
        expect(adapterOf(dio).requests, hasLength(1), reason: location);
      }
    });

    test('a second redirect is not followed', () async {
      final dio = fakeDio({
        '$_v2/projects/17/tasks/by-index/3': _temporaryRedirect(
          '/api/v2/projects/18/tasks/by-index/1',
        ),
        '$_v2/projects/18/tasks/by-index/1': _temporaryRedirect(
          '/api/v2/projects/19/tasks/by-index/1',
        ),
      });

      await expectLater(
        _tasks(dio).readByIndex('17', 3),
        throwsA(isA<UnexpectedResponse>()),
      );
      expect(adapterOf(dio).requests, hasLength(2));
    });

    test('the target may be gone or forbidden', () async {
      final dio = fakeDio({
        '$_v2/projects/17/tasks/by-index/3': _temporaryRedirect(
          '/api/v2/projects/18/tasks/by-index/1',
        ),
        '$_v2/projects/18/tasks/by-index/1': json({
          'title': 'Forbidden',
          'status': 403,
        }, status: 403),
      });

      await expectLater(
        _tasks(dio).readByIndex('17', 3),
        throwsA(isA<Forbidden>()),
      );
    });
  });

  test('v1 never takes a 307 as an answer', () async {
    final dio = fakeDio({
      '$_v1/projects/17/tasks/by-index/3': _temporaryRedirect(
        '/api/v2/projects/18/tasks/by-index/1',
      ),
    });

    await expectLater(
      _tasks(dio, hasV2: false).readByIndex('17', 3),
      throwsA(isA<UnexpectedResponse>()),
    );
    expect(adapterOf(dio).requests, hasLength(1));
  });
}
