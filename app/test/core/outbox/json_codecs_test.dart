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
