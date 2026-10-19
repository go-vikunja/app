import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

// The position answers were captured by tool/capture_ordering_fixtures.dart:
// project 1034 with list view 5794 and the tasks 6548 and 6549; 5798 is the
// list view of another project.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _project = 1034;
const _list = 5794;
const _water = 6548;
const _milk = 6549;

TasksWritePort _tasks(Dio dio, {bool hasV2 = true}) => createWriteClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
).tasks;

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);

Map<String, Object?> _stored(
  int id, {
  Map<String, Object?> overrides = const {},
}) => taskJson(id, overrides: {'project_id': _project, ...overrides});

FakeRoute _positioned(int taskId, int viewId, double position) =>
    json({'task_id': taskId, 'project_view_id': viewId, 'position': position});

void main() {
  for (final hasV2 in [true, false]) {
    final version = hasV2 ? 'v2' : 'v1';
    final base = hasV2 ? _v2 : _v1;
    final verb = hasV2 ? 'PUT' : 'POST';

    group('list positions over $version', () {
      test('read the task, then $verb the position; no read-back', () async {
        final taskId = hasV2 ? _milk : _water;
        final dio = fakeDio({
          '$base/tasks/$taskId': json(_stored(taskId)),
          '$base/tasks/$taskId/position': capturedFixture(
            'write/${version}_list_position_2.7.0',
          ),
        });

        final task = await _tasks(dio, hasV2: hasV2).update(
          taskId,
          TaskChanges(positions: {_list: hasV2 ? 3000 : 1500.5}),
        );

        expect(_calls(dio), [
          'GET $base/tasks/$taskId',
          '$verb $base/tasks/$taskId/position',
        ]);
        expect(adapterOf(dio).decodedBodies, [
          null,
          {'project_view_id': _list, 'position': hasV2 ? 3000 : 1500.5},
        ]);
        expect(task.id, taskId);
      });

      test('go after the body', () async {
        final done = _stored(42, overrides: {'done': true});
        final dio = fakeDio({
          '$base/tasks/42': hasV2
              ? _byMethod({'PATCH': json(done)})
              : _byMethod({'GET': json(_stored(42)), 'POST': json(done)}),
          '$base/tasks/42/position': _positioned(42, _list, 7),
        });

        final task = await _tasks(
          dio,
          hasV2: hasV2,
        ).update(42, const TaskChanges(done: true, positions: {_list: 7}));

        expect(_calls(dio), [
          if (hasV2)
            'PATCH $base/tasks/42'
          else ...[
            'GET $base/tasks/42',
            'POST $base/tasks/42',
          ],
          '$verb $base/tasks/42/position',
        ]);
        expect(task.done, isTrue);
      });

      test('go after the kanban placements', () async {
        const kanban = 5797;
        const doing = 4001;
        final dio = fakeDio({
          '$base/tasks/42': json(_stored(42)),
          '$base/projects/$_project/views/$kanban/buckets/$doing/tasks': json({
            'bucket_id': doing,
            'task_id': 42,
            'project_view_id': kanban,
            'task': _stored(42),
          }),
          '$base/tasks/42/position': _positioned(42, kanban, 1),
        });

        await _tasks(dio, hasV2: hasV2).update(
          42,
          const TaskChanges(
            kanban: {kanban: BucketPlacement(bucketId: doing, position: 1)},
            positions: {_list: 2},
          ),
        );

        expect(_calls(dio), [
          'GET $base/tasks/42',
          '$verb $base/projects/$_project/views/$kanban/buckets/$doing/tasks',
          '$verb $base/tasks/42/position',
          '$verb $base/tasks/42/position',
        ]);
        expect(adapterOf(dio).decodedBodies.whereType<Map<String, Object?>>(), [
          {'task_id': 42},
          {'project_view_id': kanban, 'position': 1},
          {'project_view_id': _list, 'position': 2},
        ]);
      });

      test('go after the label requests', () async {
        final dio = fakeDio({
          '$base/tasks/42': json(_stored(42)),
          '$base/tasks/42/labels': json({'label_id': 3}, status: 201),
          '$base/tasks/42/position': _positioned(42, _list, 2),
        });

        await _tasks(dio, hasV2: hasV2).update(
          42,
          const TaskChanges(
            labels: IdSetChange(added: {3}),
            positions: {_list: 2},
          ),
        );

        expect(_calls(dio), [
          'GET $base/tasks/42',
          '${hasV2 ? 'POST' : 'PUT'} $base/tasks/42/labels',
          '$verb $base/tasks/42/position',
          'GET $base/tasks/42',
        ]);
      });

      test('go per view, in turn', () async {
        final dio = fakeDio({
          '$base/tasks/42': json(_stored(42)),
          '$base/tasks/42/position': _positioned(42, _list, 1),
        });

        await _tasks(
          dio,
          hasV2: hasV2,
        ).update(42, const TaskChanges(positions: {_list: 1, 5796: 2.5}));

        expect(_calls(dio), [
          'GET $base/tasks/42',
          '$verb $base/tasks/42/position',
          '$verb $base/tasks/42/position',
        ]);
        expect(adapterOf(dio).decodedBodies.skip(1), [
          {'project_view_id': _list, 'position': 1},
          {'project_view_id': 5796, 'position': 2.5},
        ]);
      });

      test('after a project move, go into the new project and read the task '
          'back', () async {
        final moved = _stored(42, overrides: {'project_id': 9});
        final dio = fakeDio({
          '$base/tasks/42': _byMethod({
            'PATCH': json(moved),
            'POST': json(moved),
            'GET': hasV2
                ? json(moved)
                : sequence([json(_stored(42)), json(moved)]),
          }),
          '$base/tasks/42/position': _positioned(42, 91, 4),
        });

        final task = await _tasks(
          dio,
          hasV2: hasV2,
        ).update(42, const TaskChanges(projectId: 9, positions: {91: 4}));

        expect(_calls(dio), [
          if (hasV2)
            'PATCH $base/tasks/42'
          else ...[
            'GET $base/tasks/42',
            'POST $base/tasks/42',
          ],
          '$verb $base/tasks/42/position',
          'GET $base/tasks/42',
        ]);
        expect(task.projectId, 9);
      });

      test('a view that is gone fails with NotFound 3014', () async {
        final dio = fakeDio({
          '$base/tasks/$_water': json(_stored(_water)),
          '$base/tasks/$_water/position': capturedFixture(
            'write/${version}_list_position_unknown_view_2.7.0',
          ),
        });

        await expectLater(
          _tasks(
            dio,
            hasV2: hasV2,
          ).update(_water, const TaskChanges(positions: {999999999: 5})),
          throwsA(isA<NotFound>().having((f) => f.code, 'code', 3014)),
        );
      });
    });
  }

  group('list positions and the server answer', () {
    test("another project's view is refused with a Forbidden", () async {
      final dio = fakeDio({
        '$_v2/tasks/$_water': json(_stored(_water)),
        '$_v2/tasks/$_water/position': capturedFixture(
          'write/v2_list_position_foreign_view_2.7.0',
        ),
      });

      await expectLater(
        _tasks(dio).update(_water, const TaskChanges(positions: {5798: 5})),
        throwsA(isA<Forbidden>().having((f) => f.code, 'code', isNull)),
      );
    });

    test('a refused position ends the update before the next view', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': json(_stored(42)),
        '$_v2/tasks/42/position': sequence([
          capturedFixture('write/v2_list_position_unknown_view_2.7.0'),
          _positioned(42, _list, 1),
        ]),
      });

      await expectLater(
        _tasks(dio)
            .update(42, const TaskChanges(positions: {999999999: 5, _list: 1})),
        throwsA(isA<NotFound>()),
      );
      expect(_calls(dio), ['GET $_v2/tasks/42', 'PUT $_v2/tasks/42/position']);
    });

    test('an empty position map is no change: only the read', () async {
      final dio = fakeDio({'$_v2/tasks/42': json(_stored(42))});

      await _tasks(dio).update(42, const TaskChanges(positions: {}));

      expect(_calls(dio), ['GET $_v2/tasks/42']);
    });

    test('the stored task is returned, not the position answer', () async {
      final stored = _stored(
        _water,
        overrides: {'updated': '2026-10-19T20:57:00Z'},
      );
      final dio = fakeDio({
        '$_v2/tasks/$_water': json(stored),
        '$_v2/tasks/$_water/position': _positioned(_water, _list, 14333.33),
      });

      final task = await _tasks(dio)
          .update(_water, const TaskChanges(positions: {_list: 5120}));

      expect(task.updated, DateTime.utc(2026, 10, 19, 20, 57));
    });
  });
}
