import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/tasks.dart';

DateTime _oct(int day) => DateTime.utc(2026, 10, day);

final List<Task> _tasks = [
  task(
    1,
    title: 'banana',
    priority: TaskPriority.high,
    dueDate: _oct(15),
    startDate: _oct(10),
    endDate: _oct(20),
    percentDone: 0.5,
    created: _oct(1),
    updated: _oct(5),
  ),
  task(2, title: 'Apple', created: _oct(3), updated: _oct(3)),
  task(
    3,
    title: 'cherry',
    priority: TaskPriority.doNow,
    dueDate: _oct(14),
    startDate: _oct(12),
    percentDone: 1,
    created: _oct(2),
    updated: _oct(9),
  ),
  task(
    4,
    title: 'apple',
    priority: TaskPriority.low,
    dueDate: _oct(16),
    endDate: _oct(18),
    percentDone: 0.25,
    created: _oct(4),
    updated: _oct(4),
  ),
  // Created here: no position, no server times yet.
  task(
    -1,
    title: 'Date',
    priority: TaskPriority.medium,
    startDate: _oct(11),
    endDate: _oct(19),
  ),
];

// The manual order is -1 (not in the download), 2 and 4 (same position, by
// id), 3, 1.
const _positions = {1: 300.0, 2: 100.0, 3: 200.0, 4: 100.0};

const Map<TaskListSort, List<int>> _expected = {
  TaskListSort.manual: [-1, 2, 4, 3, 1],
  TaskListSort.titleAsc: [2, 4, 1, 3, -1],
  TaskListSort.titleDesc: [-1, 3, 1, 4, 2],
  // An unset priority is 0 on the server, not null: first when ascending.
  TaskListSort.priorityDesc: [3, 1, -1, 4, 2],
  TaskListSort.priorityAsc: [2, 4, -1, 1, 3],
  TaskListSort.dueDateAsc: [3, 1, 4, -1, 2],
  TaskListSort.dueDateDesc: [4, 1, 3, -1, 2],
  TaskListSort.startDateAsc: [1, -1, 3, 2, 4],
  TaskListSort.startDateDesc: [3, -1, 1, 2, 4],
  TaskListSort.endDateAsc: [4, -1, 1, 2, 3],
  TaskListSort.endDateDesc: [1, -1, 4, 2, 3],
  TaskListSort.percentDoneDesc: [3, 1, 4, -1, 2],
  TaskListSort.percentDoneAsc: [-1, 2, 4, 1, 3],
  TaskListSort.createdDesc: [4, 2, 3, 1, -1],
  TaskListSort.createdAsc: [1, 3, 2, 4, -1],
  TaskListSort.updatedDesc: [3, 1, 4, 2, -1],
  TaskListSort.updatedAsc: [2, 4, 1, 3, -1],
};

List<int> _sorted(
  Iterable<Task> tasks,
  TaskListSort sort, {
  Map<int, double> positions = const {},
  bool separateDone = true,
}) => idsOf(
  [...tasks]..sort(
    (a, b) => compareTasksForList(
      a,
      b,
      sort,
      positions: positions,
      separateDone: separateDone,
    ),
  ),
);

void main() {
  test('every sort is covered', () {
    expect(_expected.keys, unorderedEquals(TaskListSort.values));
  });

  group('the 17 sorts, missing values last both ways, ties manual', () {
    for (final MapEntry(key: sort, value: expected) in _expected.entries) {
      test(sort.wireName, () {
        expect(_sorted(_tasks, sort, positions: _positions), expected);
        expect(
          _sorted(_tasks.reversed, sort, positions: _positions),
          expected,
          reason: 'independent of the input order',
        );
      });
    }
  });

  group('titles', () {
    test('compare ignoring case first', () {
      final tasks = [
        task(1, title: 'b'),
        task(2, title: 'B'),
        task(3, title: 'a'),
        task(4, title: 'C'),
      ];

      expect(_sorted(tasks, TaskListSort.titleAsc), [3, 2, 1, 4]);
      expect(_sorted(tasks, TaskListSort.titleDesc), [4, 1, 2, 3]);
    });

    test('equal titles keep the manual order', () {
      final tasks = [task(1, title: 'x'), task(2, title: 'x')];

      expect(_sorted(tasks, TaskListSort.titleAsc, positions: {1: 1, 2: 2}), [
        1,
        2,
      ]);
      expect(_sorted(tasks, TaskListSort.titleDesc, positions: {1: 1, 2: 2}), [
        1,
        2,
      ]);
    });
  });

  group('manual', () {
    test('the download order: by position, then id', () {
      final tasks = [task(5), task(3), task(9), task(7)];

      expect(
        _sorted(
          tasks,
          TaskListSort.manual,
          positions: {5: 1024, 3: 65536, 9: 1024, 7: 0.5},
        ),
        [7, 5, 9, 3],
      );
    });

    test('tasks the download lacks come first, newest first, created here '
        'before every server task', () {
      final tasks = [task(1), task(2), task(5), task(6), task(-2), task(-3)];

      expect(_sorted(tasks, TaskListSort.manual, positions: {1: 10, 2: 5}), [
        -3,
        -2,
        6,
        5,
        2,
        1,
      ]);
    });

    test('without any download: newest first', () {
      final tasks = [task(1), task(-1), task(3), task(2), task(-4)];

      expect(_sorted(tasks, TaskListSort.manual), [-4, -1, 3, 2, 1]);
    });

    test('done tasks by done-at, newest first, then newest first', () {
      final tasks = [
        task(1, done: true, doneAt: _oct(3)),
        task(2, done: true, doneAt: _oct(5)),
        task(3, done: true),
        task(4, done: true, doneAt: _oct(5)),
        task(5, done: true),
        task(-1, done: true, doneAt: _oct(1)),
      ];

      expect(
        _sorted(tasks, TaskListSort.manual, positions: {1: 1, 2: 2, 3: 3}),
        [4, 2, 1, -1, 5, 3],
      );
    });

    test('open tasks before done ones', () {
      final tasks = [
        task(1, done: true, doneAt: _oct(9)),
        task(2),
        task(3, done: true, doneAt: _oct(1)),
        task(4),
      ];

      expect(_sorted(tasks, TaskListSort.manual, positions: {2: 2, 4: 1}), [
        4,
        2,
        1,
        3,
      ]);
    });

    test('without a separate done part, done tasks keep their positions '
        'among the open ones, as the server lists a view that holds both', () {
      final tasks = [
        task(1, done: true, doneAt: _oct(9)),
        task(2),
        task(3),
        task(4, done: true, doneAt: _oct(1)),
        task(5, done: true),
        task(-1),
      ];

      expect(
        _sorted(
          tasks,
          TaskListSort.manual,
          positions: {1: 1, 2: 2, 3: 3, 4: 0.5},
          separateDone: false,
        ),
        [-1, 5, 4, 1, 2, 3],
      );
    });

    test('a done tie on a key falls back to done-at', () {
      final tasks = [
        task(1, done: true, doneAt: _oct(1), dueDate: _oct(20)),
        task(2, done: true, doneAt: _oct(2), dueDate: _oct(20)),
        task(3, done: true, doneAt: _oct(3), dueDate: _oct(10)),
      ];

      expect(_sorted(tasks, TaskListSort.dueDateAsc), [3, 2, 1]);
      expect(_sorted(tasks, TaskListSort.dueDateDesc), [2, 1, 3]);
    });
  });

  test('a task never sent counts its creation as its last update, as the '
      'server sets both at once', () {
    final tasks = [
      task(1, created: _oct(1), updated: _oct(5)),
      task(2, created: _oct(2), updated: _oct(3)),
      task(-1, created: _oct(10)),
    ];

    expect(_sorted(tasks, TaskListSort.updatedDesc), [-1, 1, 2]);
    expect(_sorted(tasks, TaskListSort.updatedAsc), [2, 1, -1]);
  });

  group('wire names', () {
    test("the web's URL form", () {
      expect(TaskListSort.manual.wireName, 'position:asc');
      expect(TaskListSort.dueDateAsc.wireName, 'due_date:asc');
      expect(TaskListSort.percentDoneDesc.wireName, 'percent_done:desc');
    });

    test('round trip, anything unknown is manual', () {
      for (final sort in TaskListSort.values) {
        expect(TaskListSort.fromWireName(sort.wireName), sort);
      }
      for (final name in [null, '', 'due_date', 'due_date:up', 'id:desc']) {
        expect(TaskListSort.fromWireName(name), TaskListSort.manual);
      }
    });
  });
}
