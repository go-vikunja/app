import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

void main() {
  group('TaskChanges', () {
    test('round-trips every field, cleared dates included', () {
      final changes = TaskChanges(
        title: 'Renamed',
        description: '<p>html</p>',
        done: true,
        isFavorite: false,
        priority: 3,
        percentDone: 0.5,
        hexColor: 'ff0000',
        dueDate: DateChange.set(DateTime.utc(2026, 10, 12, 9)),
        startDate: const DateChange.clear(),
        repeatAfter: const Duration(days: 30),
        repeatMode: RepeatMode.fromCurrentDate,
        projectId: 9,
      );

      final json = encodeTaskChanges(changes);

      expect(jsonDecode(json), {
        'title': 'Renamed',
        'description': '<p>html</p>',
        'done': true,
        'is_favorite': false,
        'priority': 3,
        'percent_done': 0.5,
        'hex_color': 'ff0000',
        'due_date': '2026-10-12T09:00:00.000Z',
        'start_date': '',
        'repeat_after': 2592000,
        'repeat_mode': 2,
        'project_id': 9,
      });
      expect(decodeTaskChanges(json), changes);
    });

    test('a removed repeat is zero seconds in the default mode', () {
      const removed = TaskChanges(
        repeatAfter: Duration.zero,
        repeatMode: RepeatMode.afterAmount,
      );

      final json = encodeTaskChanges(removed);

      expect(jsonDecode(json), {'repeat_after': 0, 'repeat_mode': 0});
      expect(decodeTaskChanges(json), removed);
    });

    test('an empty change is an empty object', () {
      expect(encodeTaskChanges(const TaskChanges()), '{}');
      expect(decodeTaskChanges('{}').isEmpty, isTrue);
      expect(decodeTaskChanges('[]').isEmpty, isTrue);
    });

    test('a local date is stored in UTC', () {
      final local = DateTime(2026, 10, 12, 9);
      final decoded = decodeTaskChanges(
        encodeTaskChanges(TaskChanges(endDate: DateChange.set(local))),
      );
      expect(decoded.endDate, DateChange.set(local.toUtc()));
    });

    test('label and assignee changes are id deltas, reminders the whole '
        'list', () {
      final changes = TaskChanges(
        labels: const IdSetChange(added: {7, 3}, removed: {9}),
        assignees: const IdSetChange(removed: {2}),
        reminders: [
          TaskReminder(reminder: DateTime.utc(2026, 10, 12, 8)),
          const TaskReminder(
            relativePeriod: Duration(hours: -2),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
          TaskReminder(
            reminder: DateTime.utc(2026, 10, 13, 9),
            relativePeriod: const Duration(days: 1),
            relativeTo: ReminderRelativeTo.startDate,
          ),
        ],
      );

      final json = encodeTaskChanges(changes);

      expect(jsonDecode(json), {
        'labels': {
          'added': [3, 7],
          'removed': [9],
        },
        'assignees': {
          'added': <int>[],
          'removed': [2],
        },
        'reminders': [
          {'reminder': '2026-10-12T08:00:00.000Z', 'relative_period': 0},
          {'relative_period': -7200, 'relative_to': 'due_date'},
          {
            'reminder': '2026-10-13T09:00:00.000Z',
            'relative_period': 86400,
            'relative_to': 'start_date',
          },
        ],
      });
      expect(decodeTaskChanges(json), changes);
    });

    test('an empty reminder list removes them all and stays a change', () {
      const cleared = TaskChanges(reminders: []);

      final json = encodeTaskChanges(cleared);

      expect(jsonDecode(json), {'reminders': <Object?>[]});
      final back = decodeTaskChanges(json);
      expect(back, cleared);
      expect(back.reminders, isEmpty);
      expect(back.isEmpty, isFalse);
    });

    test('a payload from before step 12b changes no label, assignee or '
        'reminder', () {
      final old = decodeTaskChanges('{"done":true,"priority":2}');

      expect(old, const TaskChanges(done: true, priority: 2));
      expect(old.labels, isNull);
      expect(old.assignees, isNull);
      expect(old.reminders, isNull);
    });

    test('relation changes are edges by kind and other task, sorted, '
        'temporary ids included', () {
      final changes = TaskChanges(
        title: 'Child',
        relations: RelationChange(
          added: {
            const TaskRelationRef(TaskRelationKind.related, 9),
            const TaskRelationRef(TaskRelationKind.parentTask, -3),
            const TaskRelationRef(TaskRelationKind.related, 4),
          },
          removed: {const TaskRelationRef(TaskRelationKind.blocked, 12)},
        ),
      );

      final json = encodeTaskChanges(changes);

      expect(jsonDecode(json), {
        'title': 'Child',
        'relations': {
          'added': [
            {'kind': 'parenttask', 'other': -3},
            {'kind': 'related', 'other': 4},
            {'kind': 'related', 'other': 9},
          ],
          'removed': [
            {'kind': 'blocked', 'other': 12},
          ],
        },
      });
      expect(decodeTaskChanges(json), changes);
      expect(json, encodeTaskChanges(decodeTaskChanges(json)));
    });

    test('a payload from before step 14 changes no relation; an edge of an '
        'unknown kind or without an id is skipped', () {
      expect(decodeTaskChanges('{"done":true}').relations, isNull);
      expect(
        decodeTaskChanges(
          '{"relations":{"added":[{"kind":"later","other":1},'
          '{"kind":"related"},{"kind":"related","other":2}]}}',
        ).relations,
        RelationChange(
          added: {const TaskRelationRef(TaskRelationKind.related, 2)},
        ),
      );
    });

    test('kanban placements are keyed by view, the position left out to '
        "keep the server's", () {
      const changes = TaskChanges(
        done: true,
        kanban: {
          81: BucketPlacement(bucketId: 13, position: 32768.5),
          80: BucketPlacement(bucketId: 3),
        },
      );

      final json = encodeTaskChanges(changes);

      expect(jsonDecode(json), {
        'done': true,
        'kanban': {
          '80': {'bucket_id': 3},
          '81': {'bucket_id': 13, 'position': 32768.5},
        },
      });
      expect(json.indexOf('"80"'), lessThan(json.indexOf('"81"')));
      expect(decodeTaskChanges(json), changes);
      expect(
        decodeTaskChanges('{"kanban":{"5":{"bucket_id":2,"position":7}}}')
            .kanban,
        {5: const BucketPlacement(bucketId: 2, position: 7)},
      );
    });

    test('a payload from before step 20 places nothing; a placement without '
        'a view or bucket id is skipped', () {
      expect(decodeTaskChanges('{"done":true}').kanban, isNull);
      expect(
        decodeTaskChanges(
          '{"kanban":{"x":{"bucket_id":1},"6":{"position":2},'
          '"7":{"bucket_id":4}}}',
        ).kanban,
        {7: const BucketPlacement(bucketId: 4)},
      );
    });
  });

  group('NewTask', () {
    test('round-trips every field under the wire names', () {
      final task = NewTask(
        projectId: 7,
        title: 'Water the plants',
        description: '<p>Every pot</p>',
        dueDate: DateTime.utc(2026, 10, 12, 9),
        startDate: DateTime(2026, 10, 12, 8),
        priority: TaskPriority.high,
        percentDone: 0.3,
        hexColor: 'ff4136',
        repeatAfter: const Duration(days: 7),
        repeatMode: RepeatMode.monthly,
        isFavorite: true,
      );

      final json = encodeNewTask(task);

      expect(jsonDecode(json), {
        'project_id': 7,
        'title': 'Water the plants',
        'description': '<p>Every pot</p>',
        'due_date': '2026-10-12T09:00:00.000Z',
        'start_date': DateTime(2026, 10, 12, 8).toUtc().toIso8601String(),
        'priority': 3,
        'percent_done': 0.3,
        'hex_color': 'ff4136',
        'repeat_after': 604800,
        'repeat_mode': 1,
        'is_favorite': true,
      });
      final back = decodeNewTask(json);
      expect(back.startDate, DateTime(2026, 10, 12, 8).toUtc());
      expect(back.startDate!.isUtc, isTrue);
      expect(back.endDate, isNull);
      expect(decodeNewTask(encodeNewTask(back)), back);
    });

    test('reminders go with the create in the stored form', () {
      final task = NewTask(
        projectId: 7,
        title: 'Call back',
        dueDate: DateTime.utc(2026, 10, 12, 9),
        reminders: [
          const TaskReminder(
            relativePeriod: Duration(minutes: -30),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
          TaskReminder(reminder: DateTime(2026, 10, 11, 18)),
        ],
      );

      final json = encodeNewTask(task);

      expect((jsonDecode(json) as Map<String, Object?>)['reminders'], [
        {'relative_period': -1800, 'relative_to': 'due_date'},
        {
          'reminder': DateTime(2026, 10, 11, 18).toUtc().toIso8601String(),
          'relative_period': 0,
        },
      ]);
      final back = decodeNewTask(json);
      expect(back.reminders.last.reminder, DateTime(2026, 10, 11, 18).toUtc());
      expect(back.reminders.first, task.reminders.first);
      expect(decodeNewTask(encodeNewTask(back)), back);
    });

    test('the defaults fill what an older payload leaves out', () {
      final task = decodeNewTask('{"project_id":1,"title":"Bare"}');

      expect(task, const NewTask(projectId: 1, title: 'Bare'));
    });

    test('anything but an object is unreadable', () {
      expect(() => decodeNewTask('[]'), throwsFormatException);
    });
  });

  group('VikunjaFailure', () {
    final failures = <VikunjaFailure>[
      const NetworkFailure(NetworkProblem.tls, cause: 'dropped'),
      const TokenRejected(message: 'invalid token'),
      const SessionEnded(SessionEndReason.expired, code: 16003),
      const RefreshRaceLost(),
      const OAuthFailure(OAuthProblem.pkceMismatch, code: 17006),
      const Forbidden(code: 7003, message: 'no access'),
      const NotFound(code: 3001),
      const NotFound(),
      const RelatedTaskMissing(41, message: 'task does not exist'),
      const ValidationFailed(
        fieldErrors: {
          'title': ['must not be empty', 'too long'],
        },
        code: 4001,
      ),
      const RateLimited(retryAfter: Duration(seconds: 30)),
      const RateLimited(),
      const ServerFailure(502, code: 500, message: 'bad gateway'),
      const DomainError(412, code: 3008, message: 'archived'),
      const UnexpectedResponse(418, message: 'teapot'),
      const UnexpectedResponse(null),
    ];

    for (final failure in failures) {
      test('round-trips $failure', () {
        final back = decodeFailure(encodeFailure(failure));

        expect(back.runtimeType, failure.runtimeType);
        expect(back.code, failure.code);
        expect(back.message, failure.message);
        switch ((failure, back)) {
          case (final NetworkFailure a, final NetworkFailure b):
            expect(b.problem, a.problem);
            expect(b.cause, isNull);
          case (final SessionEnded a, final SessionEnded b):
            expect(b.reason, a.reason);
          case (final OAuthFailure a, final OAuthFailure b):
            expect(b.problem, a.problem);
          case (final RelatedTaskMissing a, final RelatedTaskMissing b):
            expect(b.otherTaskId, a.otherTaskId);
          case (final NotFound a, final NotFound b):
            expect(b.routeAbsent, a.routeAbsent);
          case (final ValidationFailed a, final ValidationFailed b):
            expect(b.fieldErrors, a.fieldErrors);
          case (final RateLimited a, final RateLimited b):
            expect(b.retryAfter, a.retryAfter);
          case (final ServerFailure a, final ServerFailure b):
            expect(b.statusCode, a.statusCode);
          case (final DomainError a, final DomainError b):
            expect(b.statusCode, a.statusCode);
          case (final UnexpectedResponse a, final UnexpectedResponse b):
            expect(b.statusCode, a.statusCode);
          case _:
            break;
        }
      });
    }

    test('an unknown kind reads as an unexpected response', () {
      expect(decodeFailure('{"kind":"future"}'), isA<UnexpectedResponse>());
      expect(decodeFailure('42'), isA<UnexpectedResponse>());
    });
  });
}
