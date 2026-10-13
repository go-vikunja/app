import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/tasks.dart';

// The fixture of server.md §6 as local wall times (they were Europe/Berlin
// there), created in this order; the probe ran on Tuesday 2026-10-13 at
// 22:48:55.
final _now = DateTime(2026, 10, 13, 22, 48, 55);
final List<Task> _fixture = [
  task(1, title: 'Sep 30 12:00', dueDate: DateTime(2026, 9, 30, 12)),
  task(2, title: 'Oct 1 00:00 exact', dueDate: DateTime(2026, 10)),
  task(3, title: 'Oct 1 00:30', dueDate: DateTime(2026, 10, 1, 0, 30)),
  task(4, title: 'last Sunday 12:00', dueDate: DateTime(2026, 10, 11, 12)),
  task(5, title: 'Monday 00:00 exact', dueDate: DateTime(2026, 10, 12)),
  task(6, title: 'Monday 00:30', dueDate: DateTime(2026, 10, 12, 0, 30)),
  task(7, title: 'yesterday 12:00', dueDate: DateTime(2026, 10, 12, 12)),
  task(8, title: 'today 00:00 exact', dueDate: DateTime(2026, 10, 13)),
  task(9, title: 'today 00:30', dueDate: DateTime(2026, 10, 13, 0, 30)),
  task(10, title: 'UTC midnight today', dueDate: DateTime(2026, 10, 13, 2)),
  task(11, title: 'today 09:00', dueDate: DateTime(2026, 10, 13, 9)),
  task(
    12,
    title: 'today 10:00 done',
    dueDate: DateTime(2026, 10, 13, 10),
    done: true,
  ),
  task(13, title: 'today 23:30', dueDate: DateTime(2026, 10, 13, 23, 30)),
  task(14, title: 'tomorrow 00:00 exact', dueDate: DateTime(2026, 10, 14)),
  task(15, title: 'tomorrow 12:00', dueDate: DateTime(2026, 10, 14, 12)),
  task(16, title: 'in 3 days 12:00', dueDate: DateTime(2026, 10, 16, 12)),
  task(17, title: 'in 8 days 12:00', dueDate: DateTime(2026, 10, 21, 12)),
  task(18, title: 'next month 12:00', dueDate: DateTime(2026, 11, 13, 12)),
  task(19, title: 'no due date'),
  task(20, title: 'no due date done', done: true),
];

const _allOverdue = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

// A map, so that expect compares the id lists element by element.
typedef _Ids = Map<String, List<int>>;

_Ids _select({
  required DateRangePreset preset,
  bool showOverdue = false,
  bool showWithoutDueDate = false,
  Iterable<Task>? tasks,
}) {
  final selection = selectUpcoming(
    tasks ?? _fixture,
    range: preset.resolve(_now),
    now: _now,
    showOverdue: showOverdue,
    showWithoutDueDate: showWithoutDueDate,
  );
  return {
    'overdue': idsOf(selection.overdue),
    'inRange': idsOf(selection.inRange),
    'withoutDue': idsOf(selection.withoutDueDate),
  };
}

void main() {
  // ShowTasks.test.ts mounts the screen with from now/d to now/d+1d and
  // toggles the two flags; the expected filters become these selections.
  // Its steps 1c and 2c switch a flag back and expect 1a and 2a again,
  // which a pure function gives by construction.
  group('ShowTasks.test.ts', () {
    test("1a done = false && due_date < 'now/d+1d' && due_date > 'now/d': "
        'strictly inside today', () {
      expect(_select(preset: DateRangePreset.today), {
        'overdue': <int>[],
        'inRange': [9, 10, 11, 13],
        'withoutDue': <int>[],
      });
    });

    test("1b show overdue (web: done = false && due_date < 'now/d+1d'): "
        'every overdue task pinned, never repeated in the range', () {
      expect(_select(preset: DateRangePreset.today, showOverdue: true), {
        'overdue': _allOverdue,
        'inRange': [13],
        'withoutDue': <int>[],
      });
    });

    test('2b show tasks without date (filter_include_nulls): undated open '
        'tasks, never the done one', () {
      expect(_select(preset: DateRangePreset.today, showWithoutDueDate: true), {
        'overdue': <int>[],
        'inRange': [9, 10, 11, 13],
        'withoutDue': [19],
      });
    });
  });

  group('server.md §6 boundaries, compared semantically', () {
    test('the default range, now to now + 7 days', () {
      expect(_select(preset: DateRangePreset.next7Days), {
        'overdue': <int>[],
        'inRange': [13, 14, 15, 16],
        'withoutDue': <int>[],
      });
    });

    test("today leaves out tomorrow 00:00 (the SQLite server's quirk "
        'includes it)', () {
      expect(
        _select(preset: DateRangePreset.today)['inRange'],
        isNot(contains(14)),
      );
    });

    test('this week starts after Monday 00:00 and ends before the next', () {
      expect(_select(preset: DateRangePreset.thisWeek)['inRange'], [
        6,
        7,
        8,
        9,
        10,
        11,
        13,
        14,
        15,
        16,
      ]);
    });

    test('last week holds only last Sunday', () {
      expect(_select(preset: DateRangePreset.lastWeek)['inRange'], [4]);
    });

    test('last week with overdue on moves its task to the overdue part', () {
      expect(_select(preset: DateRangePreset.lastWeek, showOverdue: true), {
        'overdue': _allOverdue,
        'inRange': <int>[],
        'withoutDue': <int>[],
      });
    });

    test('this month excludes October 1 00:00 exact and September', () {
      expect(_select(preset: DateRangePreset.thisMonth)['inRange'], [
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        13,
        14,
        15,
        16,
        17,
      ]);
    });

    test('everything at once', () {
      expect(
        _select(
          preset: DateRangePreset.next30Days,
          showOverdue: true,
          showWithoutDueDate: true,
        ),
        {
          'overdue': _allOverdue,
          'inRange': [13, 14, 15, 16, 17],
          'withoutDue': [19],
        },
      );
    });
  });

  group('overdue', () {
    test('a task due exactly now is overdue, a moment later it is not', () {
      final selection = selectUpcoming(
        [
          task(1, dueDate: _now),
          task(2, dueDate: _now.add(const Duration(microseconds: 1))),
        ],
        range: DateRangePreset.today.resolve(_now),
        now: _now,
        showOverdue: true,
        showWithoutDueDate: false,
      );

      expect(idsOf(selection.overdue), [1]);
      expect(idsOf(selection.inRange), [2]);
    });

    test('off, an overdue task outside the range is nowhere', () {
      expect(_select(preset: DateRangePreset.tomorrow), {
        'overdue': <int>[],
        'inRange': [15],
        'withoutDue': <int>[],
      });
    });
  });

  group('order: due date ascending, then newest first', () {
    final due = DateTime(2026, 10, 14, 9);
    final tasks = [
      task(30, dueDate: due),
      task(-2, dueDate: due),
      task(31, dueDate: due),
      task(-5, dueDate: due),
      task(29, dueDate: due.subtract(const Duration(minutes: 1))),
      task(40),
      task(-1),
      task(41),
    ];

    test('a task created here comes before the server ones', () {
      expect(
        _select(
          preset: DateRangePreset.next7Days,
          showWithoutDueDate: true,
          tasks: tasks,
        ),
        {
          'overdue': <int>[],
          'inRange': [29, -5, -2, 31, 30],
          'withoutDue': [-1, 41, 40],
        },
      );
    });

    test('server due dates in UTC compare by instant', () {
      final utcDue = DateTime(2026, 10, 14, 9).toUtc();
      final selection = selectUpcoming(
        [
          task(1, dueDate: utcDue.add(const Duration(minutes: 1))),
          task(2, dueDate: utcDue),
          task(3, dueDate: DateTime(2026, 10, 14, 9, 0, 30)),
        ],
        range: DateRangePreset.tomorrow.resolve(_now),
        now: _now,
        showOverdue: true,
        showWithoutDueDate: false,
      );

      expect(idsOf(selection.inRange), [2, 3, 1]);
    });
  });

  test('done tasks are ignored, and nothing is asked for: empty parts', () {
    final selection = selectUpcoming(
      [task(1, done: true, dueDate: DateTime(2026, 10, 2)), task(2)],
      range: DateRangePreset.today.resolve(_now),
      now: _now,
      showOverdue: true,
      showWithoutDueDate: false,
    );

    expect(selection.overdue, isEmpty);
    expect(selection.inRange, isEmpty);
    expect(selection.withoutDueDate, isEmpty);
  });

  test('a custom absolute range is exclusive at both ends', () {
    final range = DateRange(
      from: DateTime(2026, 10, 13, 9),
      to: DateTime(2026, 10, 14),
    );
    final selection = selectUpcoming(
      _fixture,
      range: range,
      now: _now,
      showOverdue: false,
      showWithoutDueDate: false,
    );

    expect(idsOf(selection.inRange), [13]);
  });
}
