import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'filter_test_support.dart';

final DateTime _now = utc('2026-10-20T08:05:00Z');

FilterContext _context({bool includeNulls = false, int? viewId}) =>
    FilterContext(
      now: _now,
      location: zone('UTC'),
      includeNulls: includeNulls,
      viewId: viewId,
    );

bool _matches(
  String filter,
  FilterableTask task, {
  bool includeNulls = false,
  int? viewId,
}) => matchesFilter(
  parsed(filter),
  task,
  _context(includeNulls: includeNulls, viewId: viewId),
);

FilterableTask _task({
  String title = '',
  String description = '',
  int? priority = 0,
  double? percentDone = 0,
  bool? done = false,
  DateTime? dueDate,
  int index = 0,
  int projectId = 1,
  int repeatAfter = 0,
  int createdById = 0,
  String? creator,
  Set<int> labels = const {},
  Set<String> assignees = const {},
  List<DateTime> reminders = const [],
  Map<int, int> buckets = const {},
}) => FilterableTask(
  id: 7,
  projectId: projectId,
  title: title,
  description: description,
  priority: priority,
  percentDone: percentDone,
  done: done,
  dueDate: dueDate,
  index: index,
  repeatAfterSeconds: repeatAfter,
  createdById: createdById,
  createdByUsername: creator,
  labelIds: labels,
  assigneeUsernames: assignees,
  reminders: reminders,
  bucketIds: buckets,
);

void main() {
  setUpAll(loadTimeZones);

  group('like', () {
    test('folds ASCII case only', () {
      final task = _task(title: 'Ärger mit Öl and ALPHA');

      expect(_matches('title like alpha', task), isTrue);
      expect(_matches('title like ärger', task), isFalse);
      expect(_matches('title like Ärger', task), isTrue);
      expect(_matches('title like ÖL', task), isTrue);
      expect(_matches('title like öl', task), isFalse);
    });

    test('% and _ are wildcards, _ one code point', () {
      final task = _task(title: 'a😀c 50% off');

      expect(_matches('title like a_c', task), isTrue);
      expect(_matches('title like a__c', task), isFalse);
      expect(_matches('title like a%off', task), isTrue);
      expect(_matches('title like 50%', task), isTrue);
      expect(_matches('title like %%', task), isTrue);
      expect(_matches(r'title like 50\%', task), isFalse);
      expect(_matches('title like c%z', task), isFalse);
    });

    test('backtracks over earlier wildcards', () {
      final task = _task(title: 'abcabcabd');

      expect(_matches('title like a%b%abd', task), isTrue);
      expect(_matches('title like a_c%_bd', task), isTrue);
      expect(_matches('title like abd%a', task), isFalse);
    });

    test('agrees with a regular expression on random patterns', () {
      final random = Random(7);
      const alphabet = ['a', 'B', 'b', '%', '_', '😀'];
      String draw(int length) => [
        for (var i = 0; i < length; i++)
          alphabet[random.nextInt(alphabet.length)],
      ].join();
      for (var round = 0; round < 2000; round++) {
        final value = draw(random.nextInt(5));
        final title = draw(random.nextInt(8)).replaceAll(RegExp('[%_]'), 'x');
        final reference = RegExp(
          [
            '^.*',
            for (final char in value.toLowerCase().runes)
              switch (String.fromCharCode(char)) {
                '%' => '.*',
                '_' => '.',
                final other => RegExp.escape(other),
              },
            r'.*$',
          ].join(),
          unicode: true,
          dotAll: true,
        );
        expect(
          _matches("title like '$value'", _task(title: title)),
          reference.hasMatch(title.toLowerCase()),
          reason: '$title like $value',
        );
      }
    });

    test('description is matched as stored HTML', () {
      final task = _task(description: '<p>Hello <b>World</b></p>');

      expect(_matches('description like <b>world', task), isTrue);
      expect(_matches('description like Hello World', task), isFalse);
    });
  });

  group('text comparisons are binary', () {
    test('= is case-sensitive and exact', () {
      expect(_matches('title = Delta', _task(title: 'Delta')), isTrue);
      expect(_matches('title = delta', _task(title: 'Delta')), isFalse);
      expect(_matches('title != delta', _task(title: 'Delta')), isTrue);
    });

    test('order is by code point, as UTF-8 bytes order', () {
      // UTF-16 code units would put the emoji (a surrogate pair) first.
      expect(_matches('title > ｚ', _task(title: '😀')), isTrue);
      expect(_matches('title > M', _task(title: 'a')), isTrue);
      expect(_matches('title < M', _task(title: 'Z')), isFalse);
      expect(_matches('title >= abc', _task(title: 'abc')), isTrue);
    });
  });

  group('missing values', () {
    test('fail every comparison, != and not in included', () {
      final undated = _task(priority: null, done: null);

      for (final filter in [
        'due_date != now',
        'due_date not in now',
        'priority != 3',
        'priority not in 3',
        'done != false',
        'done = false',
        'due_date < now',
      ]) {
        expect(_matches(filter, undated), isFalse, reason: filter);
      }
      expect(_matches('percent_done < 2', _task(percentDone: null)), isFalse);
    });

    test('include-nulls lets them match', () {
      final undated = _task(priority: null, done: null);

      expect(_matches('due_date = now', undated, includeNulls: true), isTrue);
      expect(_matches('priority in 3', undated, includeNulls: true), isTrue);
      expect(_matches('done = true', undated, includeNulls: true), isTrue);
    });

    test('include-nulls counts 0 as missing for integer comparisons', () {
      final zero = _task(projectId: 0);
      for (final filter in [
        'priority = 3',
        'priority > 3',
        'priority != 0',
        'repeat_after > 60',
        'index = 4',
        'created_by_id = 5',
        'project_id = 2',
      ]) {
        expect(
          _matches(filter, zero, includeNulls: true),
          isTrue,
          reason: filter,
        );
        expect(_matches(filter, zero), isFalse, reason: filter);
      }
      expect(_matches('priority in 3', zero, includeNulls: true), isFalse);
      expect(_matches('priority not in 0', zero, includeNulls: true), isFalse);
      expect(
        _matches('percent_done > 0.5', _task(), includeNulls: true),
        isFalse,
      );
    });

    test('an unresolvable date never compares', () {
      final task = _task(dueDate: _now);

      expect(_matches('due_date < now+999999999y', task), isFalse);
      expect(_matches('due_date != now+999999999y', task), isFalse);
      expect(_matches('due_date not in now+999999999y, now-1d', task), isFalse);
      expect(_matches('due_date in now+999999999y, now', task), isTrue);
    });
  });

  group('booleans and numbers', () {
    test('booleans order false before true', () {
      expect(_matches('done > false', _task(done: true)), isTrue);
      expect(_matches('done > false', _task()), isFalse);
      expect(_matches('done <= false', _task()), isTrue);
      expect(_matches('done in true', _task(done: true)), isTrue);
      expect(_matches('done not in true, false', _task(done: true)), isFalse);
    });

    test('percent_done is a fraction; NaN never compares', () {
      expect(_matches('percent_done = 0.5', _task(percentDone: 0.5)), isTrue);
      expect(_matches('percent_done = 50', _task(percentDone: 0.5)), isFalse);
      expect(_matches('percent_done = NaN', _task(percentDone: 0.5)), isFalse);
      expect(_matches('percent_done != NaN', _task(percentDone: 0.5)), isFalse);
      expect(_matches('percent_done < Inf', _task(percentDone: 0.5)), isTrue);
    });
  });

  group('relations', () {
    test('labels compare by existence', () {
      final task = _task(labels: {4, 9});

      expect(_matches('labels = 4', task), isTrue);
      expect(_matches('labels in 5, 9', task), isTrue);
      expect(_matches('labels != 4', task), isFalse);
      expect(_matches('labels not in 5, 6', task), isTrue);
      expect(_matches('labels > 8', task), isTrue);
      expect(_matches('labels > 4 && labels < 9', task), isFalse);
      expect(_matches('labels >= 4 && labels <= 4', task), isTrue);
      expect(_matches('labels = 4 && labels = 9', task), isTrue);
      expect(_matches('labels != 5', _task()), isTrue);
      expect(_matches('labels > 0', _task()), isFalse);
      expect(_matches('labels > 0', _task(), includeNulls: true), isTrue);
    });

    test('one reminder must sit inside a merged window', () {
      final task = _task(
        reminders: [utc('2026-10-20T22:30:00Z'), utc('2026-10-25T08:00:00Z')],
      );

      expect(
        _matches('reminders > 2026-10-21 && reminders < 2026-10-24', task),
        isFalse,
      );
      expect(
        _matches('reminders > 2026-10-21 || reminders < 2026-10-24', task),
        isTrue,
      );
      expect(
        _matches(
          'reminders > 2026-10-21 && done = false && reminders < 2026-10-24',
          task,
        ),
        isTrue,
      );
      expect(_matches('reminders = 2026-10-25T08:00:00Z', task), isTrue);
    });

    test('assignees and the creator by exact username', () {
      final task = _task(assignees: {'anna', 'ben'}, creator: 'anna');

      expect(_matches('assignees = anna', task), isTrue);
      expect(_matches('assignees = Anna', task), isFalse);
      expect(_matches('assignees = carl, ben', task), isTrue);
      expect(_matches('assignees != carl, ben', task), isFalse);
      expect(_matches("assignees in ','", task), isFalse);
      expect(_matches("assignees not in ','", task), isTrue);
      expect(_matches('created_by = anna', task), isTrue);
      expect(_matches('created_by != anna', task), isFalse);
      expect(_matches('created_by != anna', _task()), isTrue);
      expect(_matches('created_by = anna', _task()), isFalse);
      expect(
        _matches('created_by = anna', _task(), includeNulls: true),
        isFalse,
      );
      expect(_matches('assignees = anna', _task(), includeNulls: true), isTrue);
    });
  });

  group('bucket_id', () {
    final both = _task(buckets: {1: 5, 2: 6});

    test('without a view any bucket row may satisfy the whole filter', () {
      expect(_matches('bucket_id = 5', both), isTrue);
      expect(_matches('bucket_id = 5 && bucket_id = 6', both), isFalse);
      expect(_matches('bucket_id = 5 || bucket_id = 6', both), isTrue);
      expect(_matches('bucket_id != 5', both), isTrue);
      expect(_matches('bucket_id > 0', _task()), isFalse);
      expect(_matches('bucket_id = 3', _task(), includeNulls: true), isTrue);
    });

    test("with a view only that view's bucket counts", () {
      expect(_matches('bucket_id = 5', both, viewId: 1), isTrue);
      expect(_matches('bucket_id = 6', both, viewId: 1), isFalse);
      expect(_matches('bucket_id = 6', both, viewId: 3), isFalse);
      expect(
        _matches('bucket_id = 6', both, viewId: 3, includeNulls: true),
        isTrue,
      );
    });

    test('is reported', () {
      expect(parsed('bucket_id = 1 || done = true').usesBucketId, isTrue);
      expect(parsed('done = true').usesBucketId, isFalse);
    });
  });

  group('combining', () {
    test('folds strictly from the left', () {
      final task = _task(priority: 5);

      expect(
        _matches('priority = 5 || priority = 3 && done = true', task),
        isFalse,
      );
      expect(
        _matches('priority = 5 || (priority = 3 && done = true)', task),
        isTrue,
      );
    });

    test('and() is both, as the server combines request and view', () {
      final expression = parsed('priority = 5 || priority = 3')
          .and(parsed('done = false'));

      expect(matchesFilter(expression, _task(priority: 3), _context()), isTrue);
      expect(
        matchesFilter(expression, _task(priority: 3, done: true), _context()),
        isFalse,
      );
      expect(
        parsed('done = true').and(FilterExpression.matchAll),
        parsed('done = true'),
      );
      expect(
        FilterExpression.matchAll.and(parsed('done = true')),
        parsed('done = true'),
      );
    });

    test('includingNulls() applies to its part only', () {
      final expression = parsed('due_date < now')
          .includingNulls()
          .and(parsed('labels = 1'));

      expect(matchesFilter(expression, _task(labels: {1}), _context()), isTrue);
      expect(matchesFilter(expression, _task(), _context()), isFalse);
      expect(FilterExpression.matchAll.includingNulls().isEmpty, isTrue);
    });
  });

  group('matchesFilter', () {
    test('re-binds when the context changes', () {
      final expression = parsed('due_date < now');
      final task = _task(dueDate: _now.add(const Duration(hours: 1)));

      expect(matchesFilter(expression, task, _context()), isFalse);
      expect(
        matchesFilter(
          expression,
          task,
          FilterContext(
            now: _now.add(const Duration(hours: 2)),
            location: zone('UTC'),
          ),
        ),
        isTrue,
      );
      expect(matchesFilter(expression, task, _context()), isFalse);
    });

    test('evaluates in the context zone', () {
      // 23:30 UTC on the 19th is the 20th in Berlin.
      final task = _task(dueDate: utc('2026-10-19T23:30:00Z'));
      final expression = parsed('due_date >= 2026-10-20');

      expect(matchesFilter(expression, task, _context()), isFalse);
      expect(
        matchesFilter(
          expression,
          task,
          FilterContext(now: _now, location: zone('Europe/Berlin')),
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          parsed('due_date < 2026-10-20'),
          task,
          FilterContext(now: _now, location: zone('Europe/Berlin')),
        ),
        isFalse,
      );
    });
  });

  test('fromTask reads what the language needs', () {
    final task = Task(
      id: 3,
      title: 'Plan',
      projectId: 9,
      description: '<p>x</p>',
      done: true,
      priority: TaskPriority.high,
      percentDone: 0.5,
      hexColor: 'ff0000',
      index: 4,
      repeatAfter: const Duration(hours: 1),
      labels: const [
        Label(id: 1, title: 'a'),
        Label(id: 2, title: 'b'),
      ],
      assignees: const [User(id: 5, username: 'anna')],
      reminders: [
        TaskReminder(reminder: utc('2026-10-20T10:00:00Z')),
        const TaskReminder(
          relativePeriod: Duration(hours: -1),
          relativeTo: ReminderRelativeTo.dueDate,
        ),
      ],
      createdBy: const User(id: 6, username: 'ben'),
    );
    final filterable = FilterableTask.fromTask(task, bucketIds: const {1: 2});

    expect(filterable.priority, 3);
    expect(filterable.repeatAfterSeconds, 3600);
    expect(filterable.labelIds, {1, 2});
    expect(filterable.assigneeUsernames, {'anna'});
    expect(filterable.reminders, [utc('2026-10-20T10:00:00Z')]);
    expect(filterable.createdById, 6);
    expect(filterable.createdByUsername, 'ben');
    expect(filterable.bucketIds, {1: 2});
    expect(
      matchesFilter(
        parsed(
          'done = true && priority = 3 && hex_color = ff0000 && '
          'repeat_after = 3600 && index = 4 && project = 9 && '
          'created_by = ben && labels = 2 && assignees = anna',
        ),
        filterable,
        _context(),
      ),
      isTrue,
    );
  });
}
