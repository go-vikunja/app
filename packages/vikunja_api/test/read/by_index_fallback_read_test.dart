import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

const _v1 = '$testServerRoot/api/v1';
const _projects = '$_v1/projects?is_archived=true&page=1&expand=permissions';

String _byIndexFilter(int projectId, int index) =>
    '$_v1/projects/$projectId/tasks?filter=index+%3D+$index'
    '&sort_by=id&order_by=asc&page=1&per_page=1';

TasksPort _tasks(
  Dio dio, {
  ServerVersion version = const ServerVersion(2, 3, 0),
}) => createReadClient(
  dio: dio,
  connection: testConnection(hasV2: false, version: version),
).tasks;

FakeRoute _list(List<Object?> items) =>
    (_) => ResponseBody.fromString(
      jsonEncode(items),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        'x-pagination-total-pages': ['1'],
        'x-pagination-result-count': ['${items.length}'],
      },
    );

Map<String, Object?> _project(int id, String identifier) => {
  'id': id,
  'title': 'Project $id',
  'description': '',
  'identifier': identifier,
  'hex_color': '',
  'parent_project_id': 0,
  'is_archived': false,
  'position': id * 65536.0,
  'created': '2026-10-09T08:17:58Z',
  'updated': '2026-10-09T08:17:58Z',
};

void main() {
  group('2.3, without the by-index route', () {
    test('a project id reads its tasks filtered by the index', () async {
      final dio = fakeDio({
        _byIndexFilter(17, 3): _list([taskJson(19)]),
      });

      final task = await _tasks(dio).readByIndex('17', 3);

      expect(task.id, 19);
      expect(adapterOf(dio).requestedUrls, [_byIndexFilter(17, 3)]);
    });

    test('an identifier is looked up among all projects, archived ones '
        'too, pseudo projects never', () async {
      final dio = fakeDio({
        _projects: _list([
          _project(-1, 'GARDEN'),
          _project(7, 'garden'),
          _project(8, 'STRAßE'),
        ]),
        _byIndexFilter(7, 3): _list([taskJson(19)]),
        _byIndexFilter(8, 1): _list([taskJson(20)]),
      });
      final tasks = _tasks(dio);

      expect((await tasks.readByIndex('GARDEN', 3)).id, 19);
      expect((await tasks.readByIndex('straße', 1)).id, 20);
      expect(adapterOf(dio).requestedUrls, [
        _projects,
        _byIndexFilter(7, 3),
        _projects,
        _byIndexFilter(8, 1),
      ]);
    });

    test('identifiers that differ only in case: the exact one, none for '
        'another case', () async {
      final dio = fakeDio({
        _projects: _list([_project(7, 'ab'), _project(8, 'AB')]),
        _byIndexFilter(7, 1): _list([taskJson(19)]),
        _byIndexFilter(8, 1): _list([taskJson(20)]),
      });
      final tasks = _tasks(dio);

      expect((await tasks.readByIndex('ab', 1)).id, 19);
      expect((await tasks.readByIndex('AB', 1)).id, 20);
      await expectLater(
        tasks.readByIndex('Ab', 1),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
      expect(adapterOf(dio).requestedUrls.last, _projects);
    });

    test('unknown identifier, unknown index, a project id beyond any '
        'number, no access', () async {
      final dio = fakeDio({
        _projects: _list([_project(7, 'GARDEN')]),
        _byIndexFilter(7, 999): _list([]),
        _byIndexFilter(19, 1): json({
          'code': 7003,
          'message': 'This user does not have access to the project.',
        }, status: 403),
        _byIndexFilter(999, 1): json({
          'code': 3001,
          'message': 'This project does not exist.',
        }, status: 404),
      });
      final tasks = _tasks(dio);

      await expectLater(
        tasks.readByIndex('NOPE', 1),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
      await expectLater(
        tasks.readByIndex('GARDEN', 999),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
      );
      await expectLater(tasks.readByIndex('19', 1), throwsA(isA<Forbidden>()));
      await expectLater(
        tasks.readByIndex('999', 1),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
      final requests = adapterOf(dio).requests.length;
      await expectLater(
        tasks.readByIndex('99999999999999999999', 1),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
      expect(adapterOf(dio).requests, hasLength(requests));
    });
  });

  test(
    '2.4 and later, also on /api/v1 only, keep the by-index route',
    () async {
      final dio = fakeDio({
        '$_v1/projects/ab/tasks/by-index/2': json(taskJson(19)),
      });

      final task = await _tasks(
        dio,
        version: const ServerVersion(2, 4, 0),
      ).readByIndex('ab', 2);

      expect(task.id, 19);
      expect(adapterOf(dio).requestedUrls, [
        '$_v1/projects/ab/tasks/by-index/2',
      ]);
    },
  );
}
