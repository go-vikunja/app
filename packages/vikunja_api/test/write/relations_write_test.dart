import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

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

FakeRoute _noContent() =>
    (_) => ResponseBody.fromString('', 204, headers: const {});

FakeRoute _deleted({required bool hasV2}) =>
    hasV2 ? _noContent() : json({'message': 'Successfully deleted.'});

FakeRoute _created(Map<String, Object?> body) => json(body, status: 201);

/// The error bodies of 2.7.0: problem+json on v2, `{code, message}` on v1.
FakeRoute _error(int status, int? code, {required bool hasV2}) => json(
  hasV2
      ? {
          'title': 'Error',
          'status': status,
          'detail': 'Vikunja code $code',
          'code': ?code,
        }
      : {'code': code ?? 0, 'message': 'Vikunja code $code'},
  status: status,
);

const _parentOf7 = TaskRelationRef(TaskRelationKind.parentTask, 7);
const _relatedTo8 = TaskRelationRef(TaskRelationKind.related, 8);
const _blocks9 = TaskRelationRef(TaskRelationKind.blocking, 9);

/// Task 42 with [edges] in `related_tasks`, the nested tasks as 2.7.0
/// sends them (without relations of their own).
Map<String, Object?> _taskWith(
  Set<TaskRelationRef> edges, {
  Map<String, Object?> overrides = const {},
}) => taskJson(
  42,
  overrides: {
    'related_tasks': {
      for (final kind in {for (final edge in edges) edge.kind})
        kind.wireName: [
          for (final edge in edges.where((edge) => edge.kind == kind))
            taskJson(edge.otherTaskId, overrides: {'related_tasks': null}),
        ],
    },
    ...overrides,
  },
);

Set<TaskRelationRef> _edges(Task task) => {
  for (final MapEntry(key: kind, value: others) in task.relatedTasks.entries)
    for (final other in others) TaskRelationRef(kind, other.id),
};

TaskChanges _relations({
  Set<TaskRelationRef> added = const {},
  Set<TaskRelationRef> removed = const {},
}) => TaskChanges(
  relations: RelationChange(added: added, removed: removed),
);

void main() {
  group('relations', () {
    for (final hasV2 in [true, false]) {
      final version = hasV2 ? 'v2' : 'v1';
      final base = hasV2 ? _v2 : _v1;
      final add = hasV2 ? 'POST' : 'PUT';

      test('$version reads the task, removes then adds only the edges that '
          'differ, and reads it again', () async {
        final dio = fakeDio({
          '$base/tasks/42': sequence([
            json(_taskWith({_parentOf7, _blocks9})),
            json(_taskWith({_relatedTo8, _blocks9})),
          ]),
          '$base/tasks/42/relations/parenttask/7': _deleted(hasV2: hasV2),
          '$base/tasks/42/relations': _created({
            'task_id': 42,
            'other_task_id': 8,
            'relation_kind': 'related',
          }),
        });

        final task = await _tasks(dio, hasV2: hasV2).update(
          42,
          _relations(
            added: {_relatedTo8, _blocks9},
            removed: {
              _parentOf7,
              const TaskRelationRef(TaskRelationKind.follows, 3),
            },
          ),
        );

        expect(_calls(dio), [
          'GET $base/tasks/42',
          'DELETE $base/tasks/42/relations/parenttask/7',
          '$add $base/tasks/42/relations',
          'GET $base/tasks/42',
        ]);
        expect(adapterOf(dio).decodedBodies, [
          null,
          null,
          {'other_task_id': 8, 'relation_kind': 'related'},
          null,
        ]);
        expect(_edges(task), {_relatedTo8, _blocks9});
      });

      test('$version every kind travels under its wire name', () async {
        final dio = fakeDio({
          '$base/tasks/42': json(_taskWith(const {})),
          '$base/tasks/42/relations': _created({}),
        });

        await _tasks(dio, hasV2: hasV2).update(
          42,
          _relations(
            added: {
              for (final (index, kind) in TaskRelationKind.values.indexed)
                TaskRelationRef(kind, 100 + index),
            },
          ),
        );

        expect(adapterOf(dio).decodedBodies.skip(1).take(11), [
          for (final (index, kind) in TaskRelationKind.values.indexed)
            {'other_task_id': 100 + index, 'relation_kind': kind.wireName},
        ]);
      });
    }

    test(
      'nothing is sent when the server already matches: only the read',
      () async {
        final dio = fakeDio({
          '$_v2/tasks/42': json(_taskWith({_relatedTo8})),
        });

        final task = await _tasks(
          dio,
        ).update(42, _relations(added: {_relatedTo8}, removed: {_parentOf7}));

        expect(_calls(dio), ['GET $_v2/tasks/42']);
        expect(_edges(task), {_relatedTo8});
      },
    );

    test('an empty relation change is no change: only the read', () async {
      final dio = fakeDio({'$_v2/tasks/42': json(_taskWith(const {}))});

      await _tasks(dio).update(42, _relations());

      expect(_calls(dio), ['GET $_v2/tasks/42']);
    });

    test('the same other task under another kind is another edge', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': json(
          _taskWith({const TaskRelationRef(TaskRelationKind.related, 7)}),
        ),
        '$_v2/tasks/42/relations': _created({}),
      });

      await _tasks(dio).update(42, _relations(added: {_parentOf7}));

      expect(_calls(dio), [
        'GET $_v2/tasks/42',
        'POST $_v2/tasks/42/relations',
        'GET $_v2/tasks/42',
      ]);
      expect(adapterOf(dio).decodedBodies[1], {
        'other_task_id': 7,
        'relation_kind': 'parenttask',
      });
    });

    test('an edge both added and removed ends up added', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': json(_taskWith(const {})),
        '$_v2/tasks/42/relations': _created({}),
      });

      await _tasks(dio)
          .update(42, _relations(added: {_relatedTo8}, removed: {_relatedTo8}));

      expect(_calls(dio), [
        'GET $_v2/tasks/42',
        'POST $_v2/tasks/42/relations',
        'GET $_v2/tasks/42',
      ]);
    });

    test('v2 with body fields, labels and assignees: the patch answer is the '
        'state to diff, relations go last', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': _byMethod({
          'PATCH': json(_taskWith({_parentOf7}, overrides: {'title': 'Milk'})),
          'GET': json(_taskWith({_relatedTo8}, overrides: {'title': 'Milk'})),
        }),
        '$_v2/tasks/42/labels': _created({}),
        '$_v2/tasks/42/assignees': _created({}),
        '$_v2/tasks/42/relations/parenttask/7': _noContent(),
        '$_v2/tasks/42/relations': _created({}),
      });

      final task = await _tasks(dio).update(
        42,
        TaskChanges(
          title: 'Milk',
          labels: const IdSetChange(added: {5}),
          assignees: const IdSetChange(added: {14}),
          relations: RelationChange(
            added: {_relatedTo8},
            removed: {_parentOf7},
          ),
        ),
      );

      expect(_calls(dio), [
        'PATCH $_v2/tasks/42',
        'POST $_v2/tasks/42/labels',
        'POST $_v2/tasks/42/assignees',
        'DELETE $_v2/tasks/42/relations/parenttask/7',
        'POST $_v2/tasks/42/relations',
        'GET $_v2/tasks/42',
      ]);
      expect(adapterOf(dio).decodedBodies.first, {'title': 'Milk'});
      expect(_edges(task), {_relatedTo8});
    });

    test('v1 with body fields: the full POST leaves related_tasks out and the '
        'endpoints change them afterwards', () async {
      final before = _taskWith({_parentOf7});
      final dio = fakeDio({
        '$_v1/tasks/42': _byMethod({
          'GET': sequence([json(before), json(_taskWith(const {}))]),
          // 2.7.0 answers a v1 update with `related_tasks` empty.
          'POST': json({
            ...before,
            'title': 'Milk',
            'related_tasks': <String, Object?>{},
          }),
        }),
        '$_v1/tasks/42/relations/parenttask/7': json({
          'message': 'Successfully deleted.',
        }),
      });

      final task = await _tasks(dio, hasV2: false).update(
        42,
        TaskChanges(
          title: 'Milk',
          relations: RelationChange(removed: {_parentOf7}),
        ),
      );

      expect(_calls(dio), [
        'GET $_v1/tasks/42',
        'POST $_v1/tasks/42',
        'DELETE $_v1/tasks/42/relations/parenttask/7',
        'GET $_v1/tasks/42',
      ]);
      final posted = adapterOf(dio).decodedBodies[1]! as Map<String, Object?>;
      expect(posted['title'], 'Milk');
      expect(posted.containsKey('related_tasks'), isFalse);
      expect(task.relatedTasks, isEmpty);
    });

    for (final (name, answered) in [
      ('a title change answers them as {}', <String, Object?>{}),
      ('a done toggle answers them as null', null),
    ]) {
      test('v1 body-only update keeps the edges of the read made first: '
          '$name', () async {
        final before = _taskWith({_parentOf7, _blocks9});
        final dio = fakeDio({
          '$_v1/tasks/42': _byMethod({
            'GET': json(before),
            'POST': json({
              ...before,
              'title': 'Milk',
              'related_tasks': answered,
            }),
          }),
        });

        final task = await _tasks(
          dio,
          hasV2: false,
        ).update(42, const TaskChanges(title: 'Milk'));

        expect(_calls(dio), ['GET $_v1/tasks/42', 'POST $_v1/tasks/42']);
        expect(task.title, 'Milk');
        expect(_edges(task), {_parentOf7, _blocks9});
      });
    }

    group('a temporary other task id is refused before any request', () {
      for (final (name, changes) in [
        (
          'added',
          _relations(
            added: {const TaskRelationRef(TaskRelationKind.parentTask, -3)},
          ),
        ),
        (
          'removed',
          _relations(
            removed: {const TaskRelationRef(TaskRelationKind.related, -3)},
          ),
        ),
        (
          'zero, with body fields',
          TaskChanges(
            title: 'Milk',
            relations: RelationChange(
              added: {const TaskRelationRef(TaskRelationKind.related, 0)},
            ),
          ),
        ),
      ]) {
        test(name, () async {
          final dio = fakeDio({'$_v2/tasks/42': json(_taskWith(const {}))});

          await expectLater(
            _tasks(dio).update(42, changes),
            throwsA(isA<ArgumentError>()),
          );
          expect(adapterOf(dio).requests, isEmpty);
        });
      }
    });

    group('races a retry or another device can meet', () {
      for (final hasV2 in [true, false]) {
        final version = hasV2 ? 'v2' : 'v1';
        final base = hasV2 ? _v2 : _v1;
        final add = hasV2 ? 'POST' : 'PUT';

        test('$version an edge that exists meanwhile (409 code 4008, also for '
            'one added from the other side) counts as added', () async {
          final dio = fakeDio({
            '$base/tasks/42': json(_taskWith(const {})),
            '$base/tasks/42/relations': sequence([
              _error(409, 4008, hasV2: hasV2),
              _created({}),
            ]),
          });

          await _tasks(
            dio,
            hasV2: hasV2,
          ).update(42, _relations(added: {_parentOf7, _relatedTo8}));

          expect(_calls(dio), [
            'GET $base/tasks/42',
            '$add $base/tasks/42/relations',
            '$add $base/tasks/42/relations',
            'GET $base/tasks/42',
          ]);
        });

        test('$version an edge gone meanwhile (404 code 4009) counts as '
            'removed', () async {
          final dio = fakeDio({
            '$base/tasks/42': json(_taskWith({_parentOf7, _relatedTo8})),
            '$base/tasks/42/relations/parenttask/7': _error(
              404,
              4009,
              hasV2: hasV2,
            ),
            '$base/tasks/42/relations/related/8': _deleted(hasV2: hasV2),
          });

          await _tasks(
            dio,
            hasV2: hasV2,
          ).update(42, _relations(removed: {_parentOf7, _relatedTo8}));

          expect(_calls(dio), [
            'GET $base/tasks/42',
            'DELETE $base/tasks/42/relations/parenttask/7',
            'DELETE $base/tasks/42/relations/related/8',
            'GET $base/tasks/42',
          ]);
        });
      }

      test('a remove whose other task was deleted (404 code 4002) counts as '
          'done when a read shows the edge gone with it', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': sequence([
            json(_taskWith({_parentOf7})),
            json(_taskWith(const {})),
          ]),
          '$_v2/tasks/42/relations/parenttask/7': _error(
            404,
            4002,
            hasV2: true,
          ),
        });

        final task = await _tasks(dio)
            .update(42, _relations(removed: {_parentOf7}));

        expect(_calls(dio), [
          'GET $_v2/tasks/42',
          'DELETE $_v2/tasks/42/relations/parenttask/7',
          'GET $_v2/tasks/42',
          'GET $_v2/tasks/42',
        ]);
        expect(task.relatedTasks, isEmpty);
      });

      test('a remove answered 404 code 4002 while the read still shows the '
          'edge is a missing related task', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': json(_taskWith({_parentOf7})),
          '$_v2/tasks/42/relations/parenttask/7': _error(
            404,
            4002,
            hasV2: true,
          ),
        });

        await expectLater(
          _tasks(dio).update(42, _relations(removed: {_parentOf7})),
          throwsA(
            isA<RelatedTaskMissing>().having(
              (f) => f.otherTaskId,
              'otherTaskId',
              7,
            ),
          ),
        );
      });
    });

    group('a missing other task', () {
      for (final hasV2 in [true, false]) {
        final version = hasV2 ? 'v2' : 'v1';
        final base = hasV2 ? _v2 : _v1;
        final add = hasV2 ? 'POST' : 'PUT';

        test('$version an add answered 404 code 4002 while the task itself '
            'reads fine fails as RelatedTaskMissing once the edges after it '
            'were sent', () async {
          final dio = fakeDio({
            '$base/tasks/42': json(_taskWith(const {})),
            '$base/tasks/42/relations': sequence([
              _error(404, 4002, hasV2: hasV2),
              _created({}),
              _created({}),
            ]),
          });

          await expectLater(
            _tasks(dio, hasV2: hasV2).update(
              42,
              _relations(added: {_parentOf7, _relatedTo8, _blocks9}),
            ),
            throwsA(
              isA<RelatedTaskMissing>()
                  .having((f) => f.otherTaskId, 'otherTaskId', 7)
                  .having((f) => f.code, 'code', 4002),
            ),
          );
          expect(_calls(dio), [
            'GET $base/tasks/42',
            '$add $base/tasks/42/relations',
            'GET $base/tasks/42',
            '$add $base/tasks/42/relations',
            '$add $base/tasks/42/relations',
          ]);
          expect(
            adapterOf(dio).decodedBodies.whereType<Map<String, Object?>>(),
            [
              {'other_task_id': 7, 'relation_kind': 'parenttask'},
              {'other_task_id': 8, 'relation_kind': 'related'},
              {'other_task_id': 9, 'relation_kind': 'blocking'},
            ],
          );
        });
      }

      test(
        'when the task itself is gone, its plain NotFound propagates',
        () async {
          final dio = fakeDio({
            '$_v2/tasks/42': sequence([
              json(_taskWith(const {})),
              _error(404, 4002, hasV2: true),
            ]),
            '$_v2/tasks/42/relations': _error(404, 4002, hasV2: true),
          });

          await expectLater(
            _tasks(dio).update(42, _relations(added: {_parentOf7})),
            throwsA(
              isA<NotFound>()
                  .having((f) => f.code, 'code', 4002)
                  .having(
                    (f) => f,
                    'failure',
                    isNot(isA<RelatedTaskMissing>()),
                  ),
            ),
          );
        },
      );
    });

    group('the trash of 2.8.0', () {
      final taskTrashed = {
        for (final hasV2 in [true, false])
          hasV2: errorFixture(
            '${hasV2 ? 'v2' : 'v1'}_404_relation_task_trashed_2.8.0',
          ),
      };
      final projectTrashed = errorFixture('v2_404_task_project_trashed_2.8.0');

      for (final hasV2 in [true, false]) {
        final version = hasV2 ? 'v2' : 'v1';
        final base = hasV2 ? _v2 : _v1;

        test('$version an add answered 404 code 4040 (the other task is in '
            'the trash) fails as RelatedTaskMissing with that code', () async {
          final dio = fakeDio({
            '$base/tasks/42': json(_taskWith(const {})),
            '$base/tasks/42/relations': taskTrashed[hasV2]!,
          });

          await expectLater(
            _tasks(
              dio,
              hasV2: hasV2,
            ).update(42, _relations(added: {_parentOf7})),
            throwsA(
              isA<RelatedTaskMissing>()
                  .having((f) => f.otherTaskId, 'otherTaskId', 7)
                  .having((f) => f.code, 'code', 4040),
            ),
          );
        });

        test('$version a remove answered 404 code 4040 counts as done when '
            'the read no longer lists the edge', () async {
          final dio = fakeDio({
            '$base/tasks/42': sequence([
              json(_taskWith({_parentOf7})),
              json(_taskWith(const {})),
            ]),
            '$base/tasks/42/relations/parenttask/7': taskTrashed[hasV2]!,
          });

          final task = await _tasks(
            dio,
            hasV2: hasV2,
          ).update(42, _relations(removed: {_parentOf7}));

          expect(_calls(dio), [
            'GET $base/tasks/42',
            'DELETE $base/tasks/42/relations/parenttask/7',
            'GET $base/tasks/42',
            'GET $base/tasks/42',
          ]);
          expect(task.relatedTasks, isEmpty);
        });
      }

      test('a remove answered 404 code 4040 while the read still shows the '
          'edge is a missing related task with that code', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': json(_taskWith({_parentOf7})),
          '$_v2/tasks/42/relations/parenttask/7': taskTrashed[true]!,
        });

        await expectLater(
          _tasks(dio).update(42, _relations(removed: {_parentOf7})),
          throwsA(
            isA<RelatedTaskMissing>()
                .having((f) => f.otherTaskId, 'otherTaskId', 7)
                .having((f) => f.code, 'code', 4040),
          ),
        );
      });

      test('an add answered 404 code 3018 (the other task is in a trashed '
          'project) fails as RelatedTaskMissing with that code', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': json(_taskWith(const {})),
          '$_v2/tasks/42/relations': projectTrashed,
        });

        await expectLater(
          _tasks(dio).update(42, _relations(added: {_parentOf7})),
          throwsA(
            isA<RelatedTaskMissing>()
                .having((f) => f.otherTaskId, 'otherTaskId', 7)
                .having((f) => f.code, 'code', 3018),
          ),
        );
      });

      test('a remove answered 404 code 3018 counts as done when the read no '
          'longer lists the edge', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': sequence([
            json(_taskWith({_parentOf7})),
            json(_taskWith(const {})),
          ]),
          '$_v2/tasks/42/relations/parenttask/7': projectTrashed,
        });

        final task = await _tasks(dio)
            .update(42, _relations(removed: {_parentOf7}));

        expect(task.relatedTasks, isEmpty);
      });

      test('when the task itself is in the trash, its plain NotFound '
          'propagates', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': sequence([
            json(_taskWith(const {})),
            errorFixture('v2_404_task_trashed_2.8.0'),
          ]),
          '$_v2/tasks/42/relations': taskTrashed[true]!,
        });

        await expectLater(
          _tasks(dio).update(42, _relations(added: {_parentOf7})),
          throwsA(
            isA<NotFound>()
                .having((f) => f.code, 'code', 4040)
                .having((f) => f.taskGone, 'taskGone', isTrue),
          ),
        );
      });

      test('when the task is in a trashed project (the add answers 3001, the '
          'read 3018), its plain NotFound propagates', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': sequence([
            json(_taskWith(const {})),
            projectTrashed,
          ]),
          '$_v2/tasks/42/relations': errorFixture(
            'v2_404_task_delete_project_trashed_2.8.0',
          ),
        });

        await expectLater(
          _tasks(dio).update(42, _relations(added: {_parentOf7})),
          throwsA(
            isA<NotFound>()
                .having((f) => f.code, 'code', 3018)
                .having((f) => f.projectGone, 'projectGone', isTrue),
          ),
        );
      });
    });

    group('failures propagate and stop the requests after them', () {
      final cases = <(String, bool, FakeRoute, Matcher)>[
        (
          'a cycle',
          true,
          _error(409, 4023, hasV2: true),
          isA<DomainError>()
              .having((f) => f.statusCode, 'status', 409)
              .having((f) => f.code, 'code', 4023),
        ),
        (
          'a relation to the task itself',
          false,
          _error(400, 4010, hasV2: false),
          isA<DomainError>().having((f) => f.code, 'code', 4010),
        ),
        (
          'an unknown kind on v1',
          false,
          _error(400, 4007, hasV2: false),
          isA<DomainError>().having((f) => f.code, 'code', 4007),
        ),
        (
          'an unknown kind on v2',
          true,
          json({
            'title': 'Unprocessable Entity',
            'status': 422,
            'detail': 'validation failed',
            'errors': [
              {
                'message': 'expected value to be one of "subtask, …"',
                'location': 'body.relation_kind',
                'value': 'nope',
              },
            ],
          }, status: 422),
          isA<ValidationFailed>(),
        ),
        (
          'another task the user may not see',
          true,
          _error(403, null, hasV2: true),
          isA<Forbidden>(),
        ),
        (
          'a lost write race',
          true,
          json({'message': 'Internal Server Error'}, status: 500),
          isA<ServerFailure>(),
        ),
        (
          'a server without the route',
          true,
          json({'message': 'Not Found'}, status: 404),
          isA<NotFound>().having((f) => f.routeAbsent, 'routeAbsent', true),
        ),
      ];

      for (final (name, hasV2, route, failure) in cases) {
        test(name, () async {
          final base = hasV2 ? _v2 : _v1;
          final dio = fakeDio({
            '$base/tasks/42': json(_taskWith(const {})),
            '$base/tasks/42/relations': sequence([route, _created({})]),
          });

          await expectLater(
            _tasks(
              dio,
              hasV2: hasV2,
            ).update(42, _relations(added: {_parentOf7, _relatedTo8})),
            throwsA(failure),
          );
          expect(_calls(dio), hasLength(2));
          expect(_calls(dio).last, endsWith('/tasks/42/relations'));
        });
      }

      test('a failed remove sends no add', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': json(_taskWith({_parentOf7})),
          '$_v2/tasks/42/relations/parenttask/7': _error(
            403,
            null,
            hasV2: true,
          ),
          '$_v2/tasks/42/relations': _created({}),
        });

        await expectLater(
          _tasks(
            dio,
          ).update(42, _relations(added: {_relatedTo8}, removed: {_parentOf7})),
          throwsA(isA<Forbidden>()),
        );
        expect(_calls(dio), [
          'GET $_v2/tasks/42',
          'DELETE $_v2/tasks/42/relations/parenttask/7',
        ]);
      });
    });
  });

  group('duplicate', () {
    final copy = taskJson(
      43,
      overrides: {
        'title': 'Task 42',
        'related_tasks': {
          'copiedfrom': [
            taskJson(42, overrides: {'related_tasks': null}),
          ],
        },
      },
    );

    for (final (hasV2, base, method) in [
      (true, _v2, 'POST'),
      (false, _v1, 'PUT'),
    ]) {
      final version = hasV2 ? 'v2' : 'v1';

      test(
        '$version sends $method without a body and returns the copy',
        () async {
          final dio = fakeDio({
            '$base/tasks/42/duplicate': _created({
              if (hasV2) r'$schema': '$base/schemas/TaskDuplicate.json',
              'duplicated_task': copy,
            }),
          });

          final task = await _tasks(dio, hasV2: hasV2).duplicate(42);

          expect(_calls(dio), ['$method $base/tasks/42/duplicate']);
          expect(adapterOf(dio).decodedBodies, [null]);
          expect(task.id, 43);
          expect(task.title, 'Task 42');
          expect(_edges(task), {
            const TaskRelationRef(TaskRelationKind.copiedFrom, 42),
          });
        },
      );
    }

    test('a missing task is not found', () async {
      final dio = fakeDio({
        '$_v2/tasks/42/duplicate': _error(404, 4002, hasV2: true),
      });

      await expectLater(
        _tasks(dio).duplicate(42),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
      );
    });

    test('an answer without the copy is unexpected', () async {
      final dio = fakeDio({
        '$_v2/tasks/42/duplicate': _created({'task': copy}),
      });

      await expectLater(
        _tasks(dio).duplicate(42),
        throwsA(isA<UnexpectedResponse>()),
      );
    });
  });
}
