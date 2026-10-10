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
    ];

    for (final (name, changes, body) in cases) {
      test('patches only the set fields: $name', () async {
        final dio = fakeDio({
          '$_v2/tasks/42': json(taskJson(42, overrides: {'title': 'Milk'})),
        });

        final task = await _client(dio).tasks.update(42, changes);

        final adapter = adapterOf(dio);
        final request = adapter.requests.single;
        expect(request.method, 'PATCH');
        expect(request.headers['content-type'], 'application/merge-patch+json');
        expect(request.headers['Accept'], 'application/json');
        expect(adapter.decodedBodies.single, body);
        expect(task.id, 42);
        expect(task.title, 'Milk');
      });
    }

    test('a local date is sent as UTC', () async {
      final dio = fakeDio({'$_v2/tasks/42': json(taskJson(42))});
      final local = DateTime(2026, 10, 12, 9);

      await _client(dio).tasks
          .update(42, TaskChanges(dueDate: DateChange.set(local)));

      expect(adapterOf(dio).decodedBodies.single, {
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

        final body = adapterOf(dio).decodedBodies.last! as Map<String, Object?>;
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
    }

    test('other 404s are failures', () async {
      final dio = fakeDio({
        '$_v2/tasks/42': _notFound(3001),
        '$_v2/tasks/43': errorFixture('v2_404_route_2.7.0'),
      });
      final tasks = _client(dio).tasks;

      await expectLater(
        tasks.delete(42),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
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
}
