import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

// The move and position answers were captured by
// tool/capture_kanban_fixtures.dart: project 664, Kanban view 3706 with
// To-Do 2778 (the default bucket), Doing 2779 (limit 2) and Done 2780.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _project = 664;
const _kanban = 3706;
const _toDo = 2778;
const _doing = 2779;
const _done = 2780;
const _before = '2026-10-19T15:46:42Z';

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
}) => taskJson(
  id,
  overrides: {'project_id': _project, 'updated': _before, ...overrides},
);

String _move(String base, int bucketId, {int viewId = _kanban}) =>
    '$base/projects/$_project/views/$viewId/buckets/$bucketId/tasks';

FakeRoute _moved(int taskId, int bucketId, {Map<String, Object?>? task}) =>
    json({
      'bucket_id': bucketId,
      'task_id': taskId,
      'project_view_id': _kanban,
      'bucket': task == null ? null : {'id': bucketId, 'count': 1},
      'task': task,
    });

FakeRoute _positioned(int taskId, double position) =>
    json({'task_id': taskId, 'project_view_id': _kanban, 'position': position});

TaskChanges _placed(int bucketId, {double? position, int viewId = _kanban}) =>
    TaskChanges(
      kanban: {viewId: BucketPlacement(bucketId: bucketId, position: position)},
    );

void main() {
  for (final hasV2 in [true, false]) {
    final version = hasV2 ? 'v2' : 'v1';
    final base = hasV2 ? _v2 : _v1;
    final verb = hasV2 ? 'PUT' : 'POST';

    group('kanban placements over $version', () {
      test('read the task for its project, move it, then set the '
          'position', () async {
        // The time the captured v1 move answer carries.
        final milk = _stored(
          4410,
          overrides: {'updated': '2026-10-19T15:46:46Z'},
        );
        final dio = fakeDio({
          '$base/tasks/4410': json(milk),
          _move(base, _doing): hasV2
              ? _moved(4410, _doing, task: milk)
              : capturedFixture('write/v1_bucket_move_2.7.0'),
          '$base/tasks/4410/position': capturedFixture(
            'write/${version}_task_position_2.7.0',
          ),
        });

        final task = await _tasks(
          dio,
          hasV2: hasV2,
        ).update(4410, _placed(_doing, position: 300000));

        expect(_calls(dio), [
          'GET $base/tasks/4410',
          '$verb ${_move(base, _doing)}',
          '$verb $base/tasks/4410/position',
        ]);
        expect(adapterOf(dio).decodedBodies, [
          null,
          {'task_id': 4410},
          {'project_view_id': _kanban, 'position': 300000},
        ]);
        expect(task.id, 4410);
      });

      test('send no position for a placement without one', () async {
        final dio = fakeDio({
          '$base/tasks/42': json(_stored(42)),
          _move(base, _doing): _moved(42, _doing, task: _stored(42)),
        });

        await _tasks(dio, hasV2: hasV2).update(42, _placed(_doing));

        expect(_calls(dio), [
          'GET $base/tasks/42',
          '$verb ${_move(base, _doing)}',
        ]);
      });

      test('go after the body, into the project the task is in now', () async {
        final moved = _stored(42, overrides: {'project_id': 9, 'done': true});
        final dio = fakeDio({
          '$base/tasks/42': hasV2
              ? _byMethod({'PATCH': json(moved), 'GET': json(moved)})
              : _byMethod({'GET': json(_stored(42)), 'POST': json(moved)}),
          '$base/projects/9/views/$_kanban/buckets/$_done/tasks': _moved(
            42,
            _done,
          ),
          '$base/tasks/42/position': _positioned(42, 10),
        });

        await _tasks(dio, hasV2: hasV2).update(
          42,
          const TaskChanges(
            done: true,
            projectId: 9,
            kanban: {_kanban: BucketPlacement(bucketId: _done, position: 10)},
          ),
        );

        expect(_calls(dio), [
          if (hasV2)
            'PATCH $base/tasks/42'
          else ...[
            'GET $base/tasks/42',
            'POST $base/tasks/42',
          ],
          '$verb $base/projects/9/views/$_kanban/buckets/$_done/tasks',
          '$verb $base/tasks/42/position',
          'GET $base/tasks/42',
        ]);
      });

      test('go after the label requests', () async {
        final dio = fakeDio({
          '$base/tasks/42': json(_stored(42)),
          '$base/tasks/42/labels': json({'label_id': 3}, status: 201),
          _move(base, _doing): _moved(42, _doing, task: _stored(42)),
        });

        await _tasks(dio, hasV2: hasV2).update(
          42,
          const TaskChanges(
            labels: IdSetChange(added: {3}),
            kanban: {_kanban: BucketPlacement(bucketId: _doing)},
          ),
        );

        expect(_calls(dio), [
          'GET $base/tasks/42',
          '${hasV2 ? 'POST' : 'PUT'} $base/tasks/42/labels',
          '$verb ${_move(base, _doing)}',
          'GET $base/tasks/42',
        ]);
      });

      test('move on every view in turn', () async {
        final dio = fakeDio({
          '$base/tasks/42': json(_stored(42)),
          _move(base, _doing): _moved(42, _doing, task: _stored(42)),
          _move(base, 31, viewId: 3707): _moved(42, 31, task: _stored(42)),
          '$base/tasks/42/position': _positioned(42, 1),
        });

        await _tasks(dio, hasV2: hasV2).update(
          42,
          const TaskChanges(
            kanban: {
              _kanban: BucketPlacement(bucketId: _doing, position: 1),
              3707: BucketPlacement(bucketId: 31, position: 2),
            },
          ),
        );

        expect(_calls(dio), [
          'GET $base/tasks/42',
          '$verb ${_move(base, _doing)}',
          '$verb $base/tasks/42/position',
          '$verb ${_move(base, 31, viewId: 3707)}',
          '$verb $base/tasks/42/position',
        ]);
        expect(adapterOf(dio).decodedBodies.whereType<Map<String, Object?>>(), [
          {'task_id': 42},
          {'project_view_id': _kanban, 'position': 1},
          {'task_id': 42},
          {'project_view_id': 3707, 'position': 2},
        ]);
      });

      test('a full bucket fails with 10004 before any position', () async {
        final dio = fakeDio({
          '$base/tasks/4411': json(_stored(4411)),
          _move(base, _doing): capturedFixture(
            'write/${version}_bucket_move_full_2.7.0',
          ),
        });

        await expectLater(
          _tasks(dio, hasV2: hasV2).update(4411, _placed(_doing, position: 5)),
          throwsA(isA<DomainError>().having((f) => f.code, 'code', 10004)),
        );
        expect(_calls(dio), [
          'GET $base/tasks/4411',
          '$verb ${_move(base, _doing)}',
        ]);
      });
    });
  }

  group('kanban placements and the server answer', () {
    test('a move into the bucket the task is in changes nothing and still '
        'sets the position', () async {
      final dio = fakeDio({
        '$_v2/tasks/4410': json(_stored(4410)),
        _move(_v2, _doing): capturedFixture(
          'write/v2_bucket_move_unchanged_2.7.0',
        ),
        '$_v2/tasks/4410/position': _positioned(4410, 7),
      });

      final task = await _tasks(dio).update(4410, _placed(_doing, position: 7));

      expect(_calls(dio), [
        'GET $_v2/tasks/4410',
        'PUT ${_move(_v2, _doing)}',
        'PUT $_v2/tasks/4410/position',
      ]);
      expect(task.updated, DateTime.parse(_before));
    });

    test('a move into the done bucket marks the task done; it is read '
        'back', () async {
      final done = _stored(
        4411,
        overrides: {
          'done': true,
          'done_at': '2026-10-19T15:46:50Z',
          'updated': '2026-10-19T15:46:50Z',
        },
      );
      final dio = fakeDio({
        '$_v2/tasks/4411': sequence([json(_stored(4411)), json(done)]),
        _move(_v2, _done): capturedFixture('write/v2_bucket_move_done_2.7.0'),
        '$_v2/tasks/4411/position': _positioned(4411, 3),
      });

      final task = await _tasks(dio).update(4411, _placed(_done, position: 3));

      expect(_calls(dio), [
        'GET $_v2/tasks/4411',
        'PUT ${_move(_v2, _done)}',
        'PUT $_v2/tasks/4411/position',
        'GET $_v2/tasks/4411',
      ]);
      expect(task.done, isTrue);
      expect(task.doneAt, DateTime.utc(2026, 10, 19, 15, 46, 50));
    });

    test('a repeating task moved into the done bucket lands in the default '
        'bucket: no position, the reopened task read back', () async {
      final reopened = _stored(
        4413,
        overrides: {
          'repeat_after': 86400,
          'due_date': '2026-11-03T08:00:00Z',
          'updated': '2026-10-19T15:46:52Z',
        },
      );
      final dio = fakeDio({
        '$_v2/tasks/4413': sequence([
          json(
            _stored(
              4413,
              overrides: {
                'repeat_after': 86400,
                'due_date': '2026-11-02T08:00:00Z',
              },
            ),
          ),
          json(reopened),
        ]),
        _move(_v2, _done): capturedFixture(
          'write/v2_bucket_move_repeating_2.7.0',
        ),
      });

      final task = await _tasks(dio).update(4413, _placed(_done, position: 3));

      expect(_calls(dio), [
        'GET $_v2/tasks/4413',
        'PUT ${_move(_v2, _done)}',
        'GET $_v2/tasks/4413',
      ]);
      expect(task.done, isFalse);
      expect(task.dueDate, DateTime.utc(2026, 11, 3, 8));
    });

    test('a plain move is not read back', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': json(_stored(42)),
        _move(_v2, _toDo): _moved(42, _toDo, task: _stored(42)),
        '$_v2/tasks/42/position': _positioned(42, 3),
      });

      await _tasks(dio).update(42, _placed(_toDo, position: 3));

      expect(_calls(dio).where((call) => call.startsWith('GET')), [
        'GET $_v2/tasks/42',
      ]);
    });

    test('a bucket that is gone fails with 10001', () async {
      final dio = fakeDio({
        '$_v2/tasks/4410': json(_stored(4410)),
        _move(_v2, 999999999): capturedFixture(
          'write/v2_bucket_move_unknown_2.7.0',
        ),
      });

      await expectLater(
        _tasks(dio).update(4410, _placed(999999999, position: 1)),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 10001)),
      );
    });

    test('a filter-mode bucket is refused like a missing one', () async {
      final dio = fakeDio({
        '$_v2/tasks/4410': json(_stored(4410)),
        _move(_v2, 0, viewId: 3707): capturedFixture(
          'write/v2_bucket_move_filter_mode_2.7.0',
        ),
      });

      await expectLater(
        _tasks(dio).update(4410, _placed(0, viewId: 3707)),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 10001)),
      );
    });

    test('an empty placement map is no change: only the read', () async {
      final dio = fakeDio({'$_v2/tasks/42': json(_stored(42))});

      await _tasks(dio).update(42, const TaskChanges(kanban: {}));

      expect(_calls(dio), ['GET $_v2/tasks/42']);
    });
  });
}
