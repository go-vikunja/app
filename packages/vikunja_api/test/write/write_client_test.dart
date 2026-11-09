import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';
import '../helpers/task_json.dart';

const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';

VikunjaWriteClient _client(Dio dio, {bool hasV2 = true}) => createWriteClient(
  dio: dio,
  connection: testConnection(hasV2: hasV2),
);

FakeRoute _notModified() =>
    (_) => ResponseBody.fromString('', 304, headers: const {});

FakeRoute _noContent() =>
    (_) => ResponseBody.fromString('', 204, headers: const {});

FakeRoute _notFound(int code) =>
    json({'code': code, 'message': 'The task does not exist.'}, status: 404);

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);

FakeRoute _domainError(int status, int code) =>
    json({'code': code, 'message': 'Vikunja code $code'}, status: status);

FakeRoute _forbiddenWithoutCode() =>
    json({'code': 0, 'message': 'Forbidden'}, status: 403);

FakeRoute _created(Map<String, Object?> body) => json(body, status: 201);

Map<String, Object?> _taskWith({
  List<int> labels = const [],
  List<int> assignees = const [],
  Map<String, Object?> overrides = const {},
}) => taskJson(
  42,
  overrides: {
    'labels': labels.isEmpty
        ? null
        : [for (final id in labels) labelJson(id, 'label $id')],
    'assignees': assignees.isEmpty
        ? null
        : [for (final id in assignees) userJson(id, 'user$id')],
    ...overrides,
  },
);

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

/// A task with everything a v1 replace could lose: assignees, reminders,
/// labels, dates, a repeat, a colour and a cover image.
final Map<String, Object?> _richTask = taskJson(
  42,
  overrides: {
    'title': 'Water the plants',
    'description': '<p>Every pot</p>',
    'due_date': '2026-10-11T08:12:10+02:00',
    'start_date': '2026-10-10T08:12:10Z',
    'priority': 3,
    'percent_done': 0.25,
    'hex_color': 'ff00aa',
    'repeat_after': 604800,
    'repeat_mode': 0,
    'is_favorite': true,
    'cover_image_attachment_id': 5,
    'assignees': [userJson(13, 'bob'), userJson(14, 'carol')],
    'reminders': [
      {
        'reminder': '2026-10-10T10:12:10Z',
        'relative_period': 0,
        'relative_to': '',
      },
      {
        'reminder': '2026-10-11T05:12:10Z',
        'relative_period': -3600,
        'relative_to': 'due_date',
      },
    ],
    'labels': [labelJson(4, 'urgent', hexColor: 'e8323c')],
    'related_tasks': {
      'subtask': [
        taskJson(43, overrides: {'related_tasks': null}),
      ],
    },
    'subscription': {'id': 1, 'entity': 'task', 'entity_id': 42},
  },
);

void main() {
  final monday = DateTime.utc(2026, 10, 12, 9);

  group('v2 update', () {
    final cases = <(String, TaskChanges, Map<String, Object?>)>[
      ('title', const TaskChanges(title: 'Milk'), {'title': 'Milk'}),
      (
        'description',
        const TaskChanges(description: '<p>Oat</p>'),
        {'description': '<p>Oat</p>'},
      ),
      ('done', const TaskChanges(done: true), {'done': true}),
      ('undone', const TaskChanges(done: false), {'done': false}),
      ('favourite', const TaskChanges(isFavorite: true), {'is_favorite': true}),
      ('priority', const TaskChanges(priority: 3), {'priority': 3}),
      (
        'percent done',
        const TaskChanges(percentDone: 0.5),
        {'percent_done': 0.5},
      ),
      (
        'colour without the hash',
        const TaskChanges(hexColor: '#4caf50'),
        {'hex_color': '4caf50'},
      ),
      ('colour cleared', const TaskChanges(hexColor: ''), {'hex_color': ''}),
      (
        'due date set',
        TaskChanges(dueDate: DateChange.set(monday)),
        {'due_date': '2026-10-12T09:00:00.000Z'},
      ),
      (
        'due date cleared',
        const TaskChanges(dueDate: DateChange.clear()),
        {'due_date': zeroDateJson},
      ),
      (
        'start date set',
        TaskChanges(startDate: DateChange.set(monday)),
        {'start_date': '2026-10-12T09:00:00.000Z'},
      ),
      (
        'start date cleared',
        const TaskChanges(startDate: DateChange.clear()),
        {'start_date': zeroDateJson},
      ),
      (
        'end date set',
        TaskChanges(endDate: DateChange.set(monday)),
        {'end_date': '2026-10-12T09:00:00.000Z'},
      ),
      (
        'end date cleared',
        const TaskChanges(endDate: DateChange.clear()),
        {'end_date': zeroDateJson},
      ),
      (
        'several fields',
        TaskChanges(
          title: 'Milk',
          done: true,
          priority: 1,
          dueDate: const DateChange.clear(),
          endDate: DateChange.set(monday),
        ),
        {
          'title': 'Milk',
          'done': true,
          'priority': 1,
          'due_date': zeroDateJson,
          'end_date': '2026-10-12T09:00:00.000Z',
        },
      ),
      (
        'repeat every 30 days',
        const TaskChanges(
          repeatAfter: Duration(days: 30),
          repeatMode: RepeatMode.afterAmount,
        ),
        {'repeat_after': 2592000, 'repeat_mode': 0},
      ),
      (
        'repeat monthly',
        const TaskChanges(repeatMode: RepeatMode.monthly),
        {'repeat_mode': 1},
      ),
      (
        'repeat two weeks from completion',
        const TaskChanges(
          repeatAfter: Duration(days: 14),
          repeatMode: RepeatMode.fromCurrentDate,
        ),
        {'repeat_after': 1209600, 'repeat_mode': 2},
      ),
      (
        'repeat removed',
        const TaskChanges(
          repeatAfter: Duration.zero,
          repeatMode: RepeatMode.afterAmount,
        ),
        {'repeat_after': 0, 'repeat_mode': 0},
      ),
    ];

    for (final (name, changes, body) in cases) {
      test('patches only the set fields: $name', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': json(taskJson(42, overrides: {'title': 'Milk'})),
        });

        final task = await _client(dio).tasks.update(42, changes);

        final adapter = adapterOf(dio);
        final request = adapter.requests.first;
        expect(request.method, 'PATCH');
        expect(request.headers['content-type'], 'application/merge-patch+json');
        expect(request.headers['Accept'], 'application/json');
        expect(adapter.decodedBodies.first, body);
        final changesDates =
            changes.dueDate != null ||
            changes.startDate != null ||
            changes.endDate != null;
        expect(_calls(dio), [
          'PATCH $_v2/tasks/42',
          if (changesDates) 'GET $_v2/tasks/42',
        ]);
        expect(task.id, 42);
        expect(task.title, 'Milk');
      });
    }

    test('a local date is sent as UTC', () async {
      final dio = fakeDio({'$_v2/tasks/42': json(taskJson(42))});
      final local = DateTime(2026, 10, 12, 9);

      await _client(dio).tasks
          .update(42, TaskChanges(dueDate: DateChange.set(local)));

      expect(adapterOf(dio).decodedBodies.first, {
        'due_date': local.toUtc().toIso8601String(),
      });
    });

    test('a 304 re-reads the task', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': sequence([
          _notModified(),
          json(taskJson(42, overrides: {'done': true})),
        ]),
      });

      final task = await _client(dio).tasks
          .update(42, const TaskChanges(done: true));

      expect(adapterOf(dio).requests.map((r) => r.method), ['PATCH', 'GET']);
      expect(adapterOf(dio).requestedUrls, ['$_v2/tasks/42', '$_v2/tasks/42']);
      expect(task.done, isTrue);
    });

    test('empty changes only read', () async {
      final dio = fakeDio({'$_v2/tasks/42': json(taskJson(42))});

      final task = await _client(dio).tasks.update(42, const TaskChanges());

      expect(adapterOf(dio).requests.single.method, 'GET');
      expect(task.id, 42);
    });

    test('the response is the task as stored: a repeating task reopens', () {
      final dio = fakeDio({
        '$_v2/tasks/42': json(
          taskJson(
            42,
            overrides: {
              'done': false,
              'done_at': '2026-10-10T12:00:00Z',
              'due_date': '2026-10-13T09:00:00Z',
              'repeat_after': 86400,
            },
          ),
        ),
      });

      expect(
        _client(dio).tasks.update(42, const TaskChanges(done: true)),
        completion(
          isA<Task>()
              .having((t) => t.done, 'done', isFalse)
              .having((t) => t.doneAt, 'doneAt', DateTime.utc(2026, 10, 10, 12))
              .having(
                (t) => t.dueDate,
                'dueDate',
                DateTime.utc(2026, 10, 13, 9),
              )
              .having((t) => t.repeats, 'repeats', isTrue),
        ),
      );
    });

    test('a 304 on empty changes is not special: no body is a GET', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': sequence([_notModified(), json(taskJson(42))]),
      });

      await _client(dio).tasks.update(42, const TaskChanges(title: 'Task 42'));

      expect(adapterOf(dio).decodedBodies, [
        {'title': 'Task 42'},
        null,
      ]);
    });

    test('a response that is not a task is unexpected', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': json({'title': 'no id'}),
      });

      await expectLater(
        _client(dio).tasks.update(42, const TaskChanges(done: true)),
        throwsA(
          isA<UnexpectedResponse>()
              .having((f) => f.statusCode, 'statusCode', 200)
              .having((f) => f.message, 'message', 'task without id'),
        ),
      );
    });
  });

  group('v2 move', () {
    // The server answers a move with the identifier it built before moving.
    test('reads the task back for its new identifier', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': sequence([
          json(
            taskJson(
              42,
              overrides: {'project_id': 9, 'identifier': 'P7-42', 'index': 1},
            ),
          ),
          json(
            taskJson(
              42,
              overrides: {'project_id': 9, 'identifier': 'OTHER-1', 'index': 1},
            ),
          ),
        ]),
      });

      final task = await _client(dio).tasks
          .update(42, const TaskChanges(projectId: 9));

      final adapter = adapterOf(dio);
      expect(adapter.requests.map((r) => r.method), ['PATCH', 'GET']);
      expect(adapter.decodedBodies, [
        {'project_id': 9},
        null,
      ]);
      expect(task.projectId, 9);
      expect(task.identifier, 'OTHER-1');
      expect(task.index, 1);
    });
  });

  group('v1 update', () {
    test('reads, overlays the change and posts the whole task back', () async {
      final dio = fakeDio({
        '$_v1/tasks/42': sequence([
          json(_richTask),
          json({..._richTask, 'done': true, 'done_at': '2026-10-10T12:00:00Z'}),
        ]),
      });

      final task = await _client(
        dio,
        hasV2: false,
      ).tasks.update(42, const TaskChanges(done: true));

      final adapter = adapterOf(dio);
      expect(adapter.requests.map((r) => r.method), ['GET', 'POST']);
      expect(adapter.requestedUrls, ['$_v1/tasks/42', '$_v1/tasks/42']);
      expect(adapter.requests.last.headers['content-type'], 'application/json');
      final body = adapter.decodedBodies.last! as Map<String, Object?>;
      expect(body['done'], isTrue);
      expect(body['assignees'], _richTask['assignees']);
      expect(body['reminders'], _richTask['reminders']);
      for (final untouched in const [
        'id',
        'title',
        'description',
        'due_date',
        'start_date',
        'end_date',
        'priority',
        'percent_done',
        'hex_color',
        'repeat_after',
        'repeat_mode',
        'is_favorite',
        'project_id',
        'cover_image_attachment_id',
      ]) {
        expect(body[untouched], _richTask[untouched], reason: untouched);
      }
      expect(
        body.keys,
        isNot(
          anyOf(
            contains('labels'),
            contains('related_tasks'),
            contains('attachments'),
            contains('subscription'),
          ),
        ),
      );
      expect(task.done, isTrue);
      expect(task.doneAt, DateTime.utc(2026, 10, 10, 12));
      expect(task.assignees.map((u) => u.username), ['bob', 'carol']);
      expect(task.reminders, hasLength(2));
      expect(task.labels.single.title, 'urgent');
    });

    test('the labels of the read fill in a response without them', () async {
      final dio = fakeDio({
        '$_v1/tasks/42': sequence([
          json(_richTask),
          json({..._richTask, 'done': true, 'labels': null}),
        ]),
      });

      final task = await _client(
        dio,
        hasV2: false,
      ).tasks.update(42, const TaskChanges(done: true));

      expect(task.done, isTrue);
      expect(task.labels.map((l) => l.id), [4]);
    });

    test('labels in the response win over the read', () async {
      final dio = fakeDio({
        '$_v1/tasks/42': sequence([
          json(_richTask),
          json({
            ..._richTask,
            'labels': [labelJson(9, 'fresh')],
          }),
        ]),
      });

      final task = await _client(
        dio,
        hasV2: false,
      ).tasks.update(42, const TaskChanges(done: true));

      expect(task.labels.map((l) => l.id), [9]);
    });

    test(
      'overlays every changed field and clears a date with the zero date',
      () async {
        final dio = fakeDio({'$_v1/tasks/42': json(_richTask)});

        await _client(dio, hasV2: false).tasks.update(
          42,
          TaskChanges(
            title: 'Renamed',
            description: '',
            isFavorite: false,
            priority: 0,
            percentDone: 1,
            hexColor: '#123456',
            dueDate: const DateChange.clear(),
            startDate: DateChange.set(monday),
            endDate: DateChange.set(monday),
          ),
        );

        expect(_calls(dio), [
          'GET $_v1/tasks/42',
          'POST $_v1/tasks/42',
          'GET $_v1/tasks/42',
        ]);
        final body = adapterOf(dio).decodedBodies[1]! as Map<String, Object?>;
        expect(body['title'], 'Renamed');
        expect(body['description'], '');
        expect(body['is_favorite'], isFalse);
        expect(body['priority'], 0);
        expect(body['percent_done'], 1);
        expect(body['hex_color'], '123456');
        expect(body['due_date'], zeroDateJson);
        expect(body['start_date'], '2026-10-12T09:00:00.000Z');
        expect(body['end_date'], '2026-10-12T09:00:00.000Z');
        expect(body['done'], isFalse);
        expect(body['assignees'], _richTask['assignees']);
        expect(body['reminders'], _richTask['reminders']);
      },
    );

    test('a task without assignees and reminders posts them as null', () async {
      final dio = fakeDio({'$_v1/tasks/42': json(taskJson(42))});

      await _client(
        dio,
        hasV2: false,
      ).tasks.update(42, const TaskChanges(isFavorite: true));

      final body = adapterOf(dio).decodedBodies.last! as Map<String, Object?>;
      expect(body.containsKey('assignees'), isTrue);
      expect(body['assignees'], isNull);
      expect(body['reminders'], isNull);
      expect(body['is_favorite'], isTrue);
    });

    test('a failed read sends no update', () async {
      final dio = fakeDio({'$_v1/tasks/42': _notFound(4002)});

      await expectLater(
        _client(
          dio,
          hasV2: false,
        ).tasks.update(42, const TaskChanges(done: true)),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 4002)),
      );
      expect(adapterOf(dio).requests.map((r) => r.method), ['GET']);
    });

    test('empty changes only read', () async {
      final dio = fakeDio({'$_v1/tasks/42': json(taskJson(42))});

      await _client(dio, hasV2: false).tasks.update(42, const TaskChanges());

      expect(adapterOf(dio).requests.map((r) => r.method), ['GET']);
    });

    test('the posted response is the task as stored', () async {
      final dio = fakeDio({
        '$_v1/tasks/42': sequence([
          json(taskJson(42, overrides: {'repeat_after': 86400})),
          json(
            taskJson(
              42,
              overrides: {
                'repeat_after': 86400,
                'due_date': '2026-10-13T09:00:00Z',
              },
            ),
          ),
        ]),
      });

      final task = await _client(
        dio,
        hasV2: false,
      ).tasks.update(42, const TaskChanges(done: true));

      expect(task.done, isFalse);
      expect(task.dueDate, DateTime.utc(2026, 10, 13, 9));
    });

    test('a read that is not a task is unexpected', () async {
      final dio = fakeDio({
        '$_v1/tasks/42': json([1, 2]),
      });

      await expectLater(
        _client(
          dio,
          hasV2: false,
        ).tasks.update(42, const TaskChanges(done: true)),
        throwsA(
          isA<UnexpectedResponse>().having(
            (f) => f.message,
            'message',
            'task is not a JSON object',
          ),
        ),
      );
    });
  });

  group('v1 move and repeat', () {
    test('a project move changes project_id in the full POST and reads the '
        'task back for its new identifier', () async {
      final dio = fakeDio({
        '$_v1/tasks/42': sequence([
          json(_richTask),
          json({..._richTask, 'project_id': 9, 'index': 1}),
          json({
            ..._richTask,
            'project_id': 9,
            'identifier': 'OTHER-1',
            'index': 1,
          }),
        ]),
      });

      final task = await _client(
        dio,
        hasV2: false,
      ).tasks.update(42, const TaskChanges(projectId: 9));

      final adapter = adapterOf(dio);
      expect(adapter.requests.map((r) => r.method), ['GET', 'POST', 'GET']);
      final body = adapter.decodedBodies[1]! as Map<String, Object?>;
      expect(body['project_id'], 9);
      expect(body['id'], 42);
      expect(body['title'], _richTask['title']);
      expect(body['repeat_after'], _richTask['repeat_after']);
      expect(body['assignees'], _richTask['assignees']);
      expect(body['reminders'], _richTask['reminders']);
      expect(task.projectId, 9);
      expect(task.identifier, 'OTHER-1');
      expect(task.labels.map((l) => l.id), [4]);
    });

    test('a repeat is overlaid in seconds with its mode', () async {
      final dio = fakeDio({'$_v1/tasks/42': json(_richTask)});

      await _client(dio, hasV2: false).tasks.update(
        42,
        const TaskChanges(
          repeatAfter: Duration(days: 30),
          repeatMode: RepeatMode.fromCurrentDate,
        ),
      );

      final body = adapterOf(dio).decodedBodies.last! as Map<String, Object?>;
      expect(body['repeat_after'], 2592000);
      expect(body['repeat_mode'], 2);
      expect(body['project_id'], _richTask['project_id']);
    });

    test('a repeat removal overlays zero', () async {
      final dio = fakeDio({'$_v1/tasks/42': json(_richTask)});

      await _client(dio, hasV2: false).tasks.update(
        42,
        const TaskChanges(
          repeatAfter: Duration.zero,
          repeatMode: RepeatMode.afterAmount,
        ),
      );

      final body = adapterOf(dio).decodedBodies.last! as Map<String, Object?>;
      expect(body['repeat_after'], 0);
      expect(body['repeat_mode'], 0);
    });
  });

  group('create', () {
    final due = DateTime.utc(2030, 1, 2, 3, 4, 5);
    final full = NewTask(
      projectId: 7,
      title: 'Water the plants',
      description: '<p>Every pot</p>',
      dueDate: due,
      startDate: DateTime.utc(2030),
      endDate: DateTime.utc(2030, 1, 3),
      priority: TaskPriority.high,
      percentDone: 0.5,
      hexColor: 'ff4136',
      repeatAfter: const Duration(days: 30),
      repeatMode: RepeatMode.fromCurrentDate,
      isFavorite: true,
    );
    const fullBody = <String, Object?>{
      'title': 'Water the plants',
      'description': '<p>Every pot</p>',
      'due_date': '2030-01-02T03:04:05.000Z',
      'start_date': '2030-01-01T00:00:00.000Z',
      'end_date': '2030-01-03T00:00:00.000Z',
      'priority': 3,
      'percent_done': 0.5,
      'hex_color': 'ff4136',
      'repeat_after': 2592000,
      'repeat_mode': 2,
      'is_favorite': true,
    };
    const minimalBody = <String, Object?>{
      'title': 'Milk',
      'description': '',
      'priority': 0,
      'percent_done': 0,
      'hex_color': '',
      'repeat_after': 0,
      'repeat_mode': 0,
      'is_favorite': false,
    };
    final created = taskJson(
      43,
      overrides: {
        ...fullBody,
        'due_date': '2030-01-02T03:04:05Z',
        'start_date': '2030-01-01T00:00:00Z',
        'end_date': '2030-01-03T00:00:00Z',
        'identifier': 'P7-12',
        'index': 12,
      },
    );

    for (final (hasV2, base, method) in [
      (true, _v2, 'POST'),
      (false, _v1, 'PUT'),
    ]) {
      final version = hasV2 ? 'v2' : 'v1';

      test('$version sends every field with $method and parses the '
          'created task', () async {
        final dio = fakeDio({'$base/projects/7/tasks': json(created)});

        final task = await _client(dio, hasV2: hasV2).tasks.create(full);

        final adapter = adapterOf(dio);
        final request = adapter.requests.single;
        expect(request.method, method);
        expect(request.headers['content-type'], 'application/json');
        expect(request.headers['Accept'], 'application/json');
        expect(adapter.decodedBodies.single, fullBody);
        expect(task.id, 43);
        expect(task.projectId, 7);
        expect(task.identifier, 'P7-12');
        expect(task.index, 12);
        expect(task.title, 'Water the plants');
        expect(task.dueDate, due);
        expect(task.repeatAfter, const Duration(days: 30));
        expect(task.repeatMode, RepeatMode.fromCurrentDate);
        expect(task.isFavorite, isTrue);
      });

      test('$version omits unset dates and sends the defaults', () async {
        final dio = fakeDio({
          '$base/projects/7/tasks': json(
            taskJson(43, overrides: {'title': 'Milk'}),
          ),
        });

        final task = await _client(
          dio,
          hasV2: hasV2,
        ).tasks.create(const NewTask(projectId: 7, title: 'Milk'));

        expect(adapterOf(dio).decodedBodies.single, minimalBody);
        expect(task.title, 'Milk');
        expect(task.dueDate, isNull);
      });

      // A project_id in a v1 body overrides the path, so none is ever sent.
      test('$version carries the project only in the path', () async {
        final dio = fakeDio({'$base/projects/7/tasks': json(created)});

        await _client(dio, hasV2: hasV2).tasks.create(full);

        final body =
            adapterOf(dio).decodedBodies.single! as Map<String, Object?>;
        expect(body.containsKey('project_id'), isFalse);
        expect(body.containsKey('id'), isFalse);
        expect(adapterOf(dio).requestedUrls, ['$base/projects/7/tasks']);
      });
    }

    test('a local date is sent as UTC', () async {
      final dio = fakeDio({'$_v2/projects/7/tasks': json(created)});
      final local = DateTime(2030, 1, 2, 9);

      await _client(dio).tasks
          .create(NewTask(projectId: 7, title: 'Milk', dueDate: local));

      final body = adapterOf(dio).decodedBodies.single! as Map<String, Object?>;
      expect(body['due_date'], local.toUtc().toIso8601String());
    });

    for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
      test(
        '${hasV2 ? 'v2' : 'v1'} sends reminders in their wire form',
        () async {
          final dio = fakeDio({'$base/projects/7/tasks': json(created)});

          await _client(dio, hasV2: hasV2).tasks.create(
            NewTask(
              projectId: 7,
              title: 'Milk',
              dueDate: due,
              reminders: [
                TaskReminder(reminder: DateTime.utc(2030, 1, 1, 18)),
                const TaskReminder(
                  relativePeriod: Duration(hours: -2),
                  relativeTo: ReminderRelativeTo.dueDate,
                ),
              ],
            ),
          );

          final body =
              adapterOf(dio).decodedBodies.single! as Map<String, Object?>;
          expect(body['reminders'], [
            {
              'reminder': '2030-01-01T18:00:00.000Z',
              'relative_period': 0,
              'relative_to': '',
            },
            {'relative_period': -7200, 'relative_to': 'due_date'},
          ]);
        },
      );
    }

    test('the colour loses its hash', () async {
      final dio = fakeDio({'$_v2/projects/7/tasks': json(created)});

      await _client(dio).tasks.create(
        const NewTask(projectId: 7, title: 'Milk', hexColor: '#4caf50'),
      );

      final body = adapterOf(dio).decodedBodies.single! as Map<String, Object?>;
      expect(body['hex_color'], '4caf50');
    });

    test('a response that is not a task is unexpected', () async {
      final dio = fakeDio({
        '$_v2/projects/7/tasks': json({'title': 'no id'}, status: 201),
      });

      await expectLater(
        _client(dio).tasks.create(const NewTask(projectId: 7, title: 'Milk')),
        throwsA(
          isA<UnexpectedResponse>()
              .having((f) => f.statusCode, 'statusCode', 201)
              .having((f) => f.message, 'message', 'task without id'),
        ),
      );
    });

    group('errors', () {
      const empty = NewTask(projectId: 7, title: '');

      test('an empty title is a validation failure on v2', () async {
        final dio = fakeDio({
          '$_v2/projects/7/tasks': errorFixture('v2_422_title_empty_2.7.0'),
        });

        await expectLater(
          _client(dio).tasks.create(empty),
          throwsA(
            isA<ValidationFailed>().having(
              (f) => f.fieldErrors,
              'fieldErrors',
              {
                'title': ['expected length >= 1'],
              },
            ),
          ),
        );
      });

      test('an empty title is domain error 4001 on v1', () async {
        final dio = fakeDio({
          '$_v1/projects/7/tasks': errorFixture('v1_400_title_empty_2.7.0'),
        });

        await expectLater(
          _client(dio, hasV2: false).tasks.create(empty),
          throwsA(
            isA<DomainError>()
                .having((f) => f.statusCode, 'status', 400)
                .having((f) => f.code, 'code', 4001),
          ),
        );
      });

      for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
        final version = hasV2 ? 'v2' : 'v1';

        test(
          'a repeat beyond ten years is domain error 4029 on $version',
          () async {
            final dio = fakeDio({
              '$base/projects/7/tasks': errorFixture(
                '${version}_400_repeat_range_2.7.0',
              ),
            });

            await expectLater(
              _client(dio, hasV2: hasV2).tasks.create(
                const NewTask(
                  projectId: 7,
                  title: 'Milk',
                  repeatAfter: Duration(days: 4000),
                ),
              ),
              throwsA(
                isA<DomainError>()
                    .having((f) => f.statusCode, 'status', 400)
                    .having((f) => f.code, 'code', 4029),
              ),
            );
          },
        );

        test('an unknown project is not found on $version', () async {
          final dio = fakeDio({
            '$base/projects/7/tasks': errorFixture(
              '${version}_404_project_2.7.0',
            ),
          });

          await expectLater(
            _client(
              dio,
              hasV2: hasV2,
            ).tasks.create(const NewTask(projectId: 7, title: 'Milk')),
            throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
          );
        });
      }

      test('an archived project is a domain error', () async {
        final dio = fakeDio({
          '$_v2/projects/7/tasks': json({
            'code': 3008,
            'message': 'This project is archived.',
          }, status: 412),
        });

        await expectLater(
          _client(dio).tasks.create(const NewTask(projectId: 7, title: 'Milk')),
          throwsA(
            isA<DomainError>()
                .having((f) => f.statusCode, 'status', 412)
                .having((f) => f.code, 'code', 3008),
          ),
        );
      });

      test('network failures are normalized', () async {
        await expectLater(
          _client(fakeDio({})).tasks
              .create(const NewTask(projectId: 7, title: 'Milk')),
          throwsA(isA<NetworkFailure>()),
        );
      });

      test('a cancelled request rethrows its DioException', () async {
        final dio = fakeDio({
          '$_v2/projects/7/tasks': failsWith(
            (request) => DioException.requestCancelled(
              requestOptions: request,
              reason: 'closed',
            ),
          ),
        });

        await expectLater(
          _client(dio).tasks.create(const NewTask(projectId: 7, title: 'Milk')),
          throwsA(
            isA<DioException>().having(
              (e) => e.type,
              'type',
              DioExceptionType.cancel,
            ),
          ),
        );
      });
    });
  });

  group('delete', () {
    test('v2 answers 204', () async {
      final dio = fakeDio({'$_v2/tasks/42': _noContent()});

      await _client(dio).tasks.delete(42);

      final request = adapterOf(dio).requests.single;
      expect(request.method, 'DELETE');
      expect(request.uri.toString(), '$_v2/tasks/42');
      expect(adapterOf(dio).requestBodies.single, isNull);
    });

    test('v1 answers 200 with a message', () async {
      final dio = fakeDio({
        '$_v1/tasks/42': json({'message': 'Successfully deleted.'}),
      });

      await _client(dio, hasV2: false).tasks.delete(42);

      expect(adapterOf(dio).requests.single.method, 'DELETE');
    });

    for (final (hasV2, base) in [(true, _v2), (false, _v1)]) {
      test('an already deleted task (404 code 4002) is success on '
          '${hasV2 ? 'v2' : 'v1'}', () async {
        final dio = fakeDio({'$base/tasks/42': _notFound(4002)});

        await expectLater(
          _client(dio, hasV2: hasV2).tasks.delete(42),
          completes,
        );
      });

      final version = hasV2 ? 'v2' : 'v1';
      for (final (what, fixture) in [
        ('a task in the trash (404 code 4040)', 'task_trashed'),
        (
          'a task whose project is in the trash (404 code 3001)',
          'task_delete_project_trashed',
        ),
      ]) {
        test('$what is success on $version', () async {
          final dio = fakeDio({
            '$base/tasks/42': errorFixture('${version}_404_${fixture}_2.8.0'),
          });

          await expectLater(
            _client(dio, hasV2: hasV2).tasks.delete(42),
            completes,
          );
        });
      }
    }

    test('the 404 code 3018 a read gets for a task in a trashed project is '
        'success too', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': errorFixture('v2_404_task_project_trashed_2.8.0'),
      });

      await expectLater(_client(dio).tasks.delete(42), completes);
    });

    test('other 404s are failures', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': _notFound(4009),
        '$_v2/tasks/43': errorFixture('v2_404_route_2.7.0'),
      });
      final tasks = _client(dio).tasks;

      await expectLater(
        tasks.delete(42),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 4009)),
      );
      await expectLater(
        tasks.delete(43),
        throwsA(
          isA<NotFound>().having((f) => f.routeAbsent, 'routeAbsent', isTrue),
        ),
      );
    });
  });

  group('errors', () {
    test('are normalized on v2', () async {
      final dio = fakeDio({
        '$_v2/tasks/1': errorFixture('v2_422_validation_2.7.0'),
        '$_v2/tasks/2': errorFixture('v2_401_code11_missing_2.7.0'),
        '$_v2/tasks/3': errorFixture('v2_403_project_2.7.0'),
        '$_v2/tasks/4': json({
          'code': 3008,
          'message': 'This project is archived.',
        }, status: 412),
        '$_v2/tasks/5': json({'message': 'boom'}, status: 500),
        '$_v2/tasks/6': status(
          429,
          headers: {
            'retry-after': ['7'],
          },
        ),
      });
      final tasks = _client(dio).tasks;
      const change = TaskChanges(title: 'x');

      await expectLater(
        tasks.update(1, change),
        throwsA(
          isA<ValidationFailed>().having((f) => f.fieldErrors, 'fieldErrors', {
            'title': ['expected length <= 250'],
          }),
        ),
      );
      await expectLater(tasks.update(2, change), throwsA(isA<TokenRejected>()));
      await expectLater(tasks.update(3, change), throwsA(isA<Forbidden>()));
      await expectLater(
        tasks.update(4, change),
        throwsA(
          isA<DomainError>()
              .having((f) => f.statusCode, 'status', 412)
              .having((f) => f.code, 'code', 3008),
        ),
      );
      await expectLater(
        tasks.update(5, change),
        throwsA(
          isA<ServerFailure>().having((f) => f.statusCode, 'status', 500),
        ),
      );
      await expectLater(
        tasks.delete(6),
        throwsA(
          isA<RateLimited>().having(
            (f) => f.retryAfter,
            'retryAfter',
            const Duration(seconds: 7),
          ),
        ),
      );
    });

    test('are normalized on v1 for the read and the post', () async {
      final dio = fakeDio({
        '$_v1/tasks/1': sequence([
          json(taskJson(1)),
          errorFixture('v1_412_invalid_fields_2.7.0'),
        ]),
        '$_v1/tasks/2': errorFixture('v1_403_project_2.7.0'),
      });
      final tasks = _client(dio, hasV2: false).tasks;

      await expectLater(
        tasks.update(1, const TaskChanges(title: 'x')),
        throwsA(
          isA<ValidationFailed>().having((f) => f.fieldErrors.keys, 'fields', [
            'title',
          ]),
        ),
      );
      await expectLater(
        tasks.update(2, const TaskChanges(title: 'x')),
        throwsA(isA<Forbidden>()),
      );
    });

    test('network failures are normalized', () async {
      await expectLater(
        _client(fakeDio({})).tasks.update(1, const TaskChanges(done: true)),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        _client(fakeDio({})).tasks.delete(1),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a cancelled request rethrows its DioException', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': failsWith(
          (request) => DioException.requestCancelled(
            requestOptions: request,
            reason: 'closed',
          ),
        ),
      });
      final cancelled = isA<DioException>().having(
        (e) => e.type,
        'type',
        DioExceptionType.cancel,
      );

      await expectLater(
        _client(dio).tasks.update(42, const TaskChanges(done: true)),
        throwsA(cancelled),
      );
      await expectLater(_client(dio).tasks.delete(42), throwsA(cancelled));
    });
  });

  group('reminders', () {
    final absolute = TaskReminder(reminder: DateTime.utc(2026, 10, 12, 9));
    final absoluteWire = <String, Object?>{
      'reminder': '2026-10-12T09:00:00.000Z',
      'relative_period': 0,
      'relative_to': '',
    };
    final cases = <(String, List<TaskReminder>, List<Object?>)>[
      ('absolute', [absolute], [absoluteWire]),
      (
        'relative, before the due date',
        const [
          TaskReminder(
            relativePeriod: Duration(hours: -1),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
        ],
        [
          {'relative_period': -3600, 'relative_to': 'due_date'},
        ],
      ),
      (
        'relative, after the start date',
        const [
          TaskReminder(
            relativePeriod: Duration(days: 2),
            relativeTo: ReminderRelativeTo.startDate,
          ),
        ],
        [
          {'relative_period': 172800, 'relative_to': 'start_date'},
        ],
      ),
      (
        'on the end date, with the instant the server computed before',
        [
          TaskReminder(
            reminder: DateTime.utc(2026, 10, 16, 17),
            relativeTo: ReminderRelativeTo.endDate,
          ),
        ],
        [
          {'relative_period': 0, 'relative_to': 'end_date'},
        ],
      ),
      ('all removed', const [], []),
      (
        'absolute without an instant as the zero date',
        const [TaskReminder()],
        [
          {'reminder': zeroDateJson, 'relative_period': 0, 'relative_to': ''},
        ],
      ),
    ];

    for (final (name, reminders, wire) in cases) {
      test('v2 patches the whole list: $name', () async {
        final dio = fakeDio({'$_v2/tasks/42': json(taskJson(42))});

        await _client(dio).tasks.update(42, TaskChanges(reminders: reminders));

        expect(adapterOf(dio).decodedBodies.first, {'reminders': wire});
      });
    }

    test('a local instant is sent as UTC', () async {
      final dio = fakeDio({'$_v2/tasks/42': json(taskJson(42))});
      final local = DateTime(2026, 10, 12, 9);

      await _client(dio).tasks
          .update(42, TaskChanges(reminders: [TaskReminder(reminder: local)]));

      final body = adapterOf(dio).decodedBodies.first! as Map<String, Object?>;
      expect(
        (body['reminders']! as List<Object?>).single,
        containsPair('reminder', local.toUtc().toIso8601String()),
      );
    });

    // The server answers an update with the reminders as sent but stores
    // only the last one per instant.
    test('v2 reads the task back for the stored list', () async {
      final stored = {
        'reminder': '2026-10-12T09:00:00Z',
        'relative_period': 0,
        'relative_to': '',
      };
      final dio = fakeDio({
        '$_v2/tasks/42': _byMethod({
          'PATCH': json(
            taskJson(
              42,
              overrides: {
                'reminders': [stored, stored],
              },
            ),
          ),
          'GET': json(
            taskJson(
              42,
              overrides: {
                'reminders': [stored],
              },
            ),
          ),
        }),
      });

      final task = await _client(dio).tasks
          .update(42, TaskChanges(reminders: [absolute, absolute]));

      expect(_calls(dio), ['PATCH $_v2/tasks/42', 'GET $_v2/tasks/42']);
      expect(task.reminders, [absolute]);
    });

    test('v1 replaces the reminders as read and keeps the assignees', () async {
      final dio = fakeDio({'$_v1/tasks/42': json(_richTask)});

      await _client(
        dio,
        hasV2: false,
      ).tasks.update(42, TaskChanges(reminders: [absolute]));

      expect(_calls(dio), [
        'GET $_v1/tasks/42',
        'POST $_v1/tasks/42',
        'GET $_v1/tasks/42',
      ]);
      final body = adapterOf(dio).decodedBodies[1]! as Map<String, Object?>;
      expect(body['reminders'], [absoluteWire]);
      expect(body['assignees'], _richTask['assignees']);
      expect(body['title'], _richTask['title']);
    });

    // Clearing the date puts both relative reminders on the zero instant:
    // the answer still lists both, the server keeps one.
    for (final hasV2 in [true, false]) {
      test('${hasV2 ? 'v2' : 'v1'} reads a date change back for the reminders '
          'the server merged', () async {
        final base = hasV2 ? _v2 : _v1;
        Map<String, Object?> relative(int seconds) => {
          'reminder': zeroDateJson,
          'relative_period': seconds,
          'relative_to': 'due_date',
        };
        final answered = taskJson(
          42,
          overrides: {
            'reminders': [relative(0), relative(-86400)],
          },
        );
        final stored = taskJson(
          42,
          overrides: {
            'reminders': [relative(-86400)],
          },
        );
        final dio = fakeDio({
          '$base/tasks/42': hasV2
              ? _byMethod({'PATCH': json(answered), 'GET': json(stored)})
              : sequence([json(answered), json(answered), json(stored)]),
        });

        final task = await _client(
          dio,
          hasV2: hasV2,
        ).tasks.update(42, const TaskChanges(dueDate: DateChange.clear()));

        expect(_calls(dio), [
          if (!hasV2) 'GET $base/tasks/42',
          '${hasV2 ? 'PATCH' : 'POST'} $base/tasks/42',
          'GET $base/tasks/42',
        ]);
        expect(task.reminders, const [
          TaskReminder(
            relativePeriod: Duration(days: -1),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
        ]);
      });
    }

    test('v1 clears them with an empty list', () async {
      final dio = fakeDio({'$_v1/tasks/42': json(_richTask)});

      await _client(
        dio,
        hasV2: false,
      ).tasks.update(42, const TaskChanges(reminders: []));

      final body = adapterOf(dio).decodedBodies[1]! as Map<String, Object?>;
      expect(body['reminders'], isEmpty);
      expect(body['assignees'], _richTask['assignees']);
    });
  });

  group('labels and assignees', () {
    test('are never body fields', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': json(_taskWith(labels: [4], assignees: [13])),
      });

      await _client(dio).tasks.update(
        42,
        const TaskChanges(
          title: 'Milk',
          labels: IdSetChange(added: {4}),
          assignees: IdSetChange(added: {13}),
        ),
      );

      expect(adapterOf(dio).decodedBodies.single, {'title': 'Milk'});
    });

    for (final (hasV2, base, add, deleted) in [
      (true, _v2, 'POST', _noContent()),
      (false, _v1, 'PUT', json({'message': 'Successfully deleted.'})),
    ]) {
      final version = hasV2 ? 'v2' : 'v1';

      test('$version reads the task and sends only the missing label '
          'requests, then reads it again', () async {
        final dio = fakeDio({
          '$base/tasks/42': sequence([
            json(_taskWith(labels: [4, 6])),
            json(_taskWith(labels: [4, 5])),
          ]),
          '$base/tasks/42/labels/6': deleted,
          '$base/tasks/42/labels': _created({'label_id': 5}),
        });

        final task = await _client(dio, hasV2: hasV2).tasks.update(
          42,
          const TaskChanges(
            labels: IdSetChange(added: {5, 4}, removed: {6, 7}),
          ),
        );

        expect(_calls(dio), [
          'GET $base/tasks/42',
          'DELETE $base/tasks/42/labels/6',
          '$add $base/tasks/42/labels',
          'GET $base/tasks/42',
        ]);
        expect(adapterOf(dio).decodedBodies, [
          null,
          null,
          {'label_id': 5},
          null,
        ]);
        expect(task.labels.map((l) => l.id), [4, 5]);
      });

      test('$version assignee requests go to the assignee endpoints', () async {
        final dio = fakeDio({
          '$base/tasks/42': sequence([
            json(_taskWith(assignees: [13])),
            json(_taskWith(assignees: [14])),
          ]),
          '$base/tasks/42/assignees/13': deleted,
          '$base/tasks/42/assignees': _created({'user_id': 14}),
        });

        final task = await _client(dio, hasV2: hasV2).tasks.update(
          42,
          const TaskChanges(
            assignees: IdSetChange(added: {14}, removed: {13}),
          ),
        );

        expect(_calls(dio), [
          'GET $base/tasks/42',
          'DELETE $base/tasks/42/assignees/13',
          '$add $base/tasks/42/assignees',
          'GET $base/tasks/42',
        ]);
        expect(adapterOf(dio).decodedBodies[2], {'user_id': 14});
        expect(task.assignees.map((u) => u.id), [14]);
      });
    }

    test('v2 with body fields: the patch answer is the state to diff, and '
        'the order is label removes, label adds, assignee removes, '
        'assignee adds', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': _byMethod({
          'PATCH': json(
            _taskWith(
              labels: [4, 6],
              assignees: [13, 15],
              overrides: {'title': 'Milk'},
            ),
          ),
          'GET': json(
            _taskWith(
              labels: [5, 7],
              assignees: [14, 16],
              overrides: {'title': 'Milk'},
            ),
          ),
        }),
        '$_v2/tasks/42/labels/4': _noContent(),
        '$_v2/tasks/42/labels/6': _noContent(),
        '$_v2/tasks/42/labels': _created({}),
        '$_v2/tasks/42/assignees/13': _noContent(),
        '$_v2/tasks/42/assignees/15': _noContent(),
        '$_v2/tasks/42/assignees': _created({}),
      });

      final task = await _client(dio).tasks.update(
        42,
        const TaskChanges(
          title: 'Milk',
          labels: IdSetChange(added: {5, 7}, removed: {4, 6}),
          assignees: IdSetChange(added: {14, 16}, removed: {13, 15}),
        ),
      );

      expect(_calls(dio), [
        'PATCH $_v2/tasks/42',
        'DELETE $_v2/tasks/42/labels/4',
        'DELETE $_v2/tasks/42/labels/6',
        'POST $_v2/tasks/42/labels',
        'POST $_v2/tasks/42/labels',
        'DELETE $_v2/tasks/42/assignees/13',
        'DELETE $_v2/tasks/42/assignees/15',
        'POST $_v2/tasks/42/assignees',
        'POST $_v2/tasks/42/assignees',
        'GET $_v2/tasks/42',
      ]);
      expect(adapterOf(dio).decodedBodies, [
        {'title': 'Milk'},
        null,
        null,
        {'label_id': 5},
        {'label_id': 7},
        null,
        null,
        {'user_id': 14},
        {'user_id': 16},
        null,
      ]);
      expect(task.labels.map((l) => l.id), [5, 7]);
      expect(task.assignees.map((u) => u.id), [14, 16]);
    });

    test('v1 with body fields: the posted body keeps the assignees as read, '
        'the endpoints change them afterwards', () async {
      final before = _taskWith(labels: [4], assignees: [13]);
      final dio = fakeDio({
        '$_v1/tasks/42': _byMethod({
          'GET': sequence([
            json(before),
            json(_taskWith(labels: [5], assignees: [14])),
          ]),
          // The v1 update answers without the labels.
          'POST': json({...before, 'title': 'Milk', 'labels': null}),
        }),
        '$_v1/tasks/42/labels/4': json({'message': 'Successfully deleted.'}),
        '$_v1/tasks/42/labels': _created({}),
        '$_v1/tasks/42/assignees/13': json({
          'message': 'Successfully deleted.',
        }),
        '$_v1/tasks/42/assignees': _created({}),
      });

      final task = await _client(dio, hasV2: false).tasks.update(
        42,
        const TaskChanges(
          title: 'Milk',
          labels: IdSetChange(added: {5}, removed: {4}),
          assignees: IdSetChange(added: {14}, removed: {13}),
        ),
      );

      expect(_calls(dio), [
        'GET $_v1/tasks/42',
        'POST $_v1/tasks/42',
        'DELETE $_v1/tasks/42/labels/4',
        'PUT $_v1/tasks/42/labels',
        'DELETE $_v1/tasks/42/assignees/13',
        'PUT $_v1/tasks/42/assignees',
        'GET $_v1/tasks/42',
      ]);
      final posted = adapterOf(dio).decodedBodies[1]! as Map<String, Object?>;
      expect(posted['title'], 'Milk');
      expect(posted['assignees'], before['assignees']);
      expect(posted.containsKey('labels'), isFalse);
      expect(adapterOf(dio).decodedBodies[3], {'label_id': 5});
      expect(adapterOf(dio).decodedBodies[5], {'user_id': 14});
      expect(task.labels.map((l) => l.id), [5]);
      expect(task.assignees.map((u) => u.id), [14]);
    });

    test(
      'nothing is sent when the server already matches: only the read',
      () async {
        final dio = fakeDio({
          '$_v2/tasks/42': json(_taskWith(labels: [4], assignees: [13])),
        });

        final task = await _client(dio).tasks.update(
          42,
          const TaskChanges(
            labels: IdSetChange(added: {4}, removed: {6}),
            assignees: IdSetChange(added: {13}, removed: {15}),
          ),
        );

        expect(_calls(dio), ['GET $_v2/tasks/42']);
        expect(task.labels.map((l) => l.id), [4]);
        expect(task.assignees.map((u) => u.id), [13]);
      },
    );

    test('with body fields and a matching server only the patch is sent '
        'and its answer returned', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': json(
          _taskWith(labels: [4], overrides: {'title': 'Milk'}),
        ),
      });

      final task = await _client(dio).tasks.update(
        42,
        const TaskChanges(
          title: 'Milk',
          labels: IdSetChange(added: {4}),
        ),
      );

      expect(_calls(dio), ['PATCH $_v2/tasks/42']);
      expect(task.title, 'Milk');
    });

    test('empty id-set changes are no changes: only the read', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': json(_taskWith(labels: [4])),
      });

      await _client(dio).tasks.update(
        42,
        const TaskChanges(labels: IdSetChange(), assignees: IdSetChange()),
      );

      expect(_calls(dio), ['GET $_v2/tasks/42']);
    });

    test('an id both added and removed ends up added', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': sequence([
          json(_taskWith()),
          json(_taskWith(labels: [5])),
        ]),
        '$_v2/tasks/42/labels': _created({}),
      });

      await _client(dio).tasks.update(
        42,
        const TaskChanges(
          labels: IdSetChange(added: {5}, removed: {5}),
        ),
      );

      expect(_calls(dio), [
        'GET $_v2/tasks/42',
        'POST $_v2/tasks/42/labels',
        'GET $_v2/tasks/42',
      ]);
    });

    group('races a retry can meet', () {
      test(
        'a label already on the task (400 code 8001) counts as added',
        () async {
          final dio = fakeDio({
            '$_v2/tasks/42': json(_taskWith()),
            '$_v2/tasks/42/labels': _domainError(400, 8001),
            '$_v2/tasks/42/assignees': _created({}),
          });

          await _client(dio).tasks.update(
            42,
            const TaskChanges(
              labels: IdSetChange(added: {5}),
              assignees: IdSetChange(added: {14}),
            ),
          );

          expect(_calls(dio), [
            'GET $_v2/tasks/42',
            'POST $_v2/tasks/42/labels',
            'POST $_v2/tasks/42/assignees',
            'GET $_v2/tasks/42',
          ]);
        },
      );

      test(
        'a user already assigned (400 code 4021) counts as assigned',
        () async {
          final dio = fakeDio({
            '$_v1/tasks/42': json(_taskWith()),
            '$_v1/tasks/42/assignees': _domainError(400, 4021),
          });

          await _client(dio, hasV2: false).tasks.update(
            42,
            const TaskChanges(assignees: IdSetChange(added: {14})),
          );

          expect(_calls(dio), [
            'GET $_v1/tasks/42',
            'PUT $_v1/tasks/42/assignees',
            'GET $_v1/tasks/42',
          ]);
        },
      );

      test('a label remove answered 403 counts as done when a read shows the '
          'label gone', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': sequence([
            json(_taskWith(labels: [4, 6])),
            json(_taskWith(labels: [4])),
          ]),
          '$_v2/tasks/42/labels/6': _forbiddenWithoutCode(),
          '$_v2/tasks/42/labels/4': _noContent(),
        });

        final task = await _client(dio).tasks.update(
          42,
          const TaskChanges(labels: IdSetChange(removed: {6, 4})),
        );

        expect(_calls(dio), [
          'GET $_v2/tasks/42',
          'DELETE $_v2/tasks/42/labels/6',
          'GET $_v2/tasks/42',
          'DELETE $_v2/tasks/42/labels/4',
          'GET $_v2/tasks/42',
        ]);
        expect(task.labels.map((l) => l.id), [4]);
      });

      test('a label remove answered 403 fails when the label is still on '
          'the task, and nothing after it is sent', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': json(_taskWith(labels: [6])),
          '$_v2/tasks/42/labels/6': _forbiddenWithoutCode(),
          '$_v2/tasks/42/labels': _created({}),
        });

        await expectLater(
          _client(dio).tasks.update(
            42,
            const TaskChanges(
              labels: IdSetChange(added: {5}, removed: {6}),
            ),
          ),
          throwsA(isA<Forbidden>().having((f) => f.code, 'code', isNull)),
        );
        expect(_calls(dio), [
          'GET $_v2/tasks/42',
          'DELETE $_v2/tasks/42/labels/6',
          'GET $_v2/tasks/42',
        ]);
      });
    });

    group('failures propagate and stop the requests after them', () {
      final cases = <(String, String, FakeRoute, Matcher)>[
        (
          'a label that does not exist',
          'labels',
          _domainError(404, 8002),
          isA<NotFound>().having((f) => f.code, 'code', 8002),
        ),
        (
          "another user's label",
          'labels',
          _forbiddenWithoutCode(),
          isA<Forbidden>().having((f) => f.code, 'code', isNull),
        ),
        (
          'a label add that loses a write race',
          'labels',
          json({'message': 'Internal Server Error'}, status: 500),
          isA<ServerFailure>(),
        ),
        (
          'a user without access to the project',
          'assignees',
          _domainError(403, 7003),
          isA<Forbidden>().having((f) => f.code, 'code', 7003),
        ),
        (
          'a user that does not exist',
          'assignees',
          _domainError(404, 1005),
          isA<NotFound>().having((f) => f.code, 'code', 1005),
        ),
      ];

      for (final (name, endpoint, route, failure) in cases) {
        test(name, () async {
          final dio = fakeDio({
            '$_v2/tasks/42': json(_taskWith()),
            '$_v2/tasks/42/labels': endpoint == 'labels' ? route : _created({}),
            '$_v2/tasks/42/assignees': endpoint == 'assignees'
                ? route
                : _created({}),
          });

          await expectLater(
            _client(dio).tasks.update(
              42,
              const TaskChanges(
                labels: IdSetChange(added: {5}),
                assignees: IdSetChange(added: {14}),
              ),
            ),
            throwsA(failure),
          );
          expect(_calls(dio).last, 'POST $_v2/tasks/42/$endpoint');
          expect(
            _calls(dio).where((call) => call == 'GET $_v2/tasks/42'),
            hasLength(1),
          );
        });
      }

      test('a failed patch sends no label request', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': errorFixture('v2_403_project_2.7.0'),
          '$_v2/tasks/42/labels': _created({}),
        });

        await expectLater(
          _client(dio).tasks.update(
            42,
            const TaskChanges(
              title: 'Milk',
              labels: IdSetChange(added: {5}),
            ),
          ),
          throwsA(isA<Forbidden>()),
        );
        expect(_calls(dio), ['PATCH $_v2/tasks/42']);
      });
    });
  });

  group('label create', () {
    final created = labelJson(9, 'Groceries', hexColor: 'fb5607');

    for (final (hasV2, base, method) in [
      (true, _v2, 'POST'),
      (false, _v1, 'PUT'),
    ]) {
      final version = hasV2 ? 'v2' : 'v1';

      test('$version sends $method /labels and parses the label', () async {
        final dio = fakeDio({
          '$base/labels': json({
            ...created,
            'description': 'Shop runs',
          }, status: 201),
        });

        final label = await _client(dio, hasV2: hasV2).labels.create(
          const NewLabel(
            title: 'Groceries',
            hexColor: 'fb5607',
            description: 'Shop runs',
          ),
        );

        final request = adapterOf(dio).requests.single;
        expect(request.method, method);
        expect(request.uri.toString(), '$base/labels');
        expect(request.headers['content-type'], 'application/json');
        expect(adapterOf(dio).decodedBodies.single, {
          'title': 'Groceries',
          'hex_color': 'fb5607',
          'description': 'Shop runs',
        });
        expect(label.id, 9);
        expect(label.title, 'Groceries');
        expect(label.hexColor, 'fb5607');
        expect(label.description, 'Shop runs');
      });

      test('$version leaves out an empty colour and description', () async {
        final dio = fakeDio({'$base/labels': json(created, status: 201)});

        await _client(
          dio,
          hasV2: hasV2,
        ).labels.create(const NewLabel(title: 'Groceries'));

        expect(adapterOf(dio).decodedBodies.single, {'title': 'Groceries'});
      });
    }

    test('the colour loses its hash', () async {
      final dio = fakeDio({'$_v2/labels': json(created, status: 201)});

      await _client(dio).labels
          .create(const NewLabel(title: 'Groceries', hexColor: '#fb5607'));

      expect(adapterOf(dio).decodedBodies.single, {
        'title': 'Groceries',
        'hex_color': 'fb5607',
      });
    });

    test('a response that is not a label is unexpected', () async {
      final dio = fakeDio({
        '$_v2/labels': json({'title': 'no id'}, status: 201),
      });

      await expectLater(
        _client(dio).labels.create(const NewLabel(title: 'Groceries')),
        throwsA(
          isA<UnexpectedResponse>().having(
            (f) => f.message,
            'message',
            'label without id',
          ),
        ),
      );
    });

    test('errors are normalized', () async {
      final dio = fakeDio({
        '$_v2/labels': json({
          'status': 422,
          'title': 'Unprocessable Entity',
          'detail': 'validation failed',
          'errors': [
            {'location': 'body.title', 'message': 'expected length <= 250'},
          ],
        }, status: 422),
      });

      await expectLater(
        _client(dio).labels.create(NewLabel(title: 'x' * 251)),
        throwsA(
          isA<ValidationFailed>().having((f) => f.fieldErrors, 'fieldErrors', {
            'title': ['expected length <= 250'],
          }),
        ),
      );
      await expectLater(
        _client(fakeDio({})).labels.create(const NewLabel(title: 'Groceries')),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
