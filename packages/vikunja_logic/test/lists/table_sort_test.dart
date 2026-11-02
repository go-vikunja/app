import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/tasks.dart';

// The table probe on Vikunja 2.7.0 (scratchpad step29/table.md §4), v1 and
// v2 alike: task number n has id 3131 + n and was created n-th; a table
// view's positions put newer tasks first, so the server's ties (position,
// then id) are newest first here too. Cherry and Date were created done,
// so they have no done-at; Apple was updated last.
DateTime _day(int month, int day) => DateTime.utc(2026, month, day, 12);

DateTime _created(int number) =>
    DateTime.utc(2026, 10, 26, 14, 34, 30 + number);

Task _probe(
  int number,
  String title, {
  int priority = 0,
  DateTime? due,
  DateTime? start,
  DateTime? end,
  double percent = 0,
  bool done = false,
  DateTime? updated,
}) => task(
  3131 + number,
  title: title,
  priority: TaskPriority.fromValue(priority),
  dueDate: due,
  startDate: start,
  endDate: end,
  percentDone: percent,
  done: done,
  created: _created(number),
  updated: updated ?? _created(number),
).copyWith(index: number);

final List<Task> _probeTasks = [
  _probe(1, 'banana', priority: 3, due: _day(11, 5), percent: 0.5),
  _probe(2, 'Apple', updated: DateTime.utc(2026, 10, 26, 14, 34, 40)),
  _probe(
    3,
    'cherry',
    priority: 5,
    due: _day(11, 1),
    start: _day(10, 20),
    end: _day(11, 10),
    percent: 1,
    done: true,
  ),
  _probe(
    4,
    'apple',
    priority: 1,
    due: _day(11, 5),
    start: _day(10, 25),
    percent: 0.2,
  ),
  _probe(5, 'Date', priority: 3, end: _day(11, 3), done: true),
  _probe(6, '_under', priority: 2, due: _day(10, 30), percent: 0.3),
  _probe(7, 'Éclair', priority: 4, start: _day(10, 21)),
  _probe(8, 'zeta', due: _day(10, 28), percent: 0.29),
];

// The server's orders by task number, except for the titles (below).
const Map<String, List<int>> _serverOrders = {
  'index:desc': [8, 7, 6, 5, 4, 3, 2, 1],
  'done:asc': [8, 7, 6, 4, 2, 1, 5, 3],
  'done:desc': [5, 3, 8, 7, 6, 4, 2, 1],
  'priority:asc': [8, 2, 4, 6, 5, 1, 7, 3],
  'priority:desc': [3, 7, 5, 1, 6, 4, 8, 2],
  'due_date:asc': [8, 6, 3, 4, 1, 7, 5, 2],
  'due_date:desc': [4, 1, 3, 6, 8, 7, 5, 2],
  'start_date:asc': [3, 7, 4, 8, 6, 5, 2, 1],
  'start_date:desc': [4, 7, 3, 8, 6, 5, 2, 1],
  'end_date:asc': [5, 3, 8, 7, 6, 4, 2, 1],
  'end_date:desc': [3, 5, 8, 7, 6, 4, 2, 1],
  'percent_done:asc': [7, 5, 2, 4, 8, 6, 1, 3],
  'percent_done:desc': [3, 1, 6, 8, 4, 7, 5, 2],
  'done_at:asc': [8, 7, 6, 5, 4, 3, 2, 1],
  'done_at:desc': [8, 7, 6, 5, 4, 3, 2, 1],
  'created:asc': [1, 2, 3, 4, 5, 6, 7, 8],
  'created:desc': [8, 7, 6, 5, 4, 3, 2, 1],
  'updated:asc': [1, 3, 4, 5, 6, 7, 8, 2],
  'updated:desc': [2, 8, 7, 6, 5, 4, 3, 1],
};

List<int> _sorted(Iterable<Task> tasks, TableSort sort) =>
    idsOf([...tasks]..sort((a, b) => compareTasksForTable(a, b, sort)));

List<int> _numbers(Iterable<Task> tasks, TableSort sort) => [
  for (final id in _sorted(tasks, sort)) id - 3131,
];

void main() {
  group('the server order of every key and direction', () {
    for (final MapEntry(key: wireName, value: expected)
        in _serverOrders.entries) {
      test(wireName, () {
        final sort = TableSort.fromWireName(wireName);
        expect(sort.wireName, wireName);
        expect(_numbers(_probeTasks, sort), expected);
        expect(
          _numbers(_probeTasks.reversed, sort),
          expected,
          reason: 'independent of the input order',
        );
      });
    }

    test('every key and direction is checked', () {
      expect(
        _serverOrders.keys.toSet(),
        {
            for (final field in TableSortField.values) ...[
              '${field.wireName}:asc',
              '${field.wireName}:desc',
            ],
          }
          ..remove('title:asc')
          ..remove('title:desc')
          // Only sorted by as the default.
          ..remove('index:asc'),
      );
    });
  });

  group('titles', () {
    test('ignore case first, unlike SQLite, which put the capitals first '
        '(Apple, Date, _under, apple, banana, cherry, zeta, Éclair)', () {
      expect(_numbers(_probeTasks, TableSort.fromWireName('title:asc')), [
        6,
        2,
        4,
        1,
        3,
        5,
        8,
        7,
      ]);
      expect(_numbers(_probeTasks, TableSort.fromWireName('title:desc')), [
        7,
        8,
        5,
        3,
        1,
        4,
        2,
        6,
      ]);
    });

    test('follow the server without capitals', () {
      final lowercase = [
        for (final task in _probeTasks)
          if (!{2, 5}.contains(task.index)) task,
      ];

      expect(_numbers(lowercase, TableSort.fromWireName('title:asc')), [
        6,
        4,
        1,
        3,
        8,
        7,
      ]);
      expect(_numbers(lowercase, TableSort.fromWireName('title:desc')), [
        7,
        8,
        3,
        1,
        4,
        6,
      ]);
    });
  });

  group('done at', () {
    // The second probe: four done at :45, two at :47, five done and undone
    // again; the server cleared five's done-at, which this copy still has.
    final at = DateTime.utc(2026, 10, 26, 14, 35);
    final tasks = [
      task(3165, title: 'one'),
      task(
        3166,
        title: 'two',
        done: true,
        doneAt: at.add(const Duration(seconds: 47)),
      ),
      task(3167, title: 'three'),
      task(
        3168,
        title: 'four',
        done: true,
        doneAt: at.add(const Duration(seconds: 45)),
      ),
      task(3169, title: 'five', doneAt: at.add(const Duration(seconds: 48))),
    ];

    test('open tasks have none, missing values last both ways', () {
      expect(_sorted(tasks, TableSort.fromWireName('done_at:asc')), [
        3168,
        3166,
        3169,
        3167,
        3165,
      ]);
      expect(_sorted(tasks, TableSort.fromWireName('done_at:desc')), [
        3166,
        3168,
        3169,
        3167,
        3165,
      ]);
    });
  });

  group('tasks created here', () {
    final tasks = [
      task(10).copyWith(index: 1),
      task(-1),
      task(12).copyWith(index: 3),
      task(-2),
      task(11).copyWith(index: 2),
    ];

    test('are numbered after every server task, the newest highest', () {
      expect(_sorted(tasks, TableSort.defaultSort), [-2, -1, 12, 11, 10]);
    });

    test('come first among equal values, as the newest', () {
      expect(_sorted(tasks, TableSort.fromWireName('priority:desc')), [
        -2,
        -1,
        12,
        11,
        10,
      ]);
    });
  });

  group('wire names', () {
    test('every field and direction reads back, the number only as the '
        'default', () {
      for (final field in TableSortField.values) {
        for (final descending in [false, true]) {
          final sort = TableSort(field, descending: descending);
          expect(
            TableSort.fromWireName(sort.wireName),
            field == TableSortField.taskIndex ? TableSort.defaultSort : sort,
            reason: sort.wireName,
          );
        }
      }
    });

    test('the default is the highest number first; the lowest first, no '
        'longer offered, reads as the default', () {
      expect(TableSort.defaultSort.wireName, 'index:desc');
      expect(TableSort.fromWireName('index:asc'), TableSort.defaultSort);
    });

    test('anything else falls back to the default, not to manual', () {
      for (final stored in [
        null,
        '',
        'position',
        'position:asc',
        'manual',
        'title',
        'title:up',
        'title:asc:x',
        'comment_count:desc',
        'id:asc',
        'Title:asc',
      ]) {
        expect(
          TableSort.fromWireName(stored),
          TableSort.defaultSort,
          reason: '$stored',
        );
      }
    });

    test('the server names the fields', () {
      expect(
        [for (final field in TableSortField.values) field.wireName],
        [
          'index',
          'done',
          'title',
          'priority',
          'due_date',
          'start_date',
          'end_date',
          'percent_done',
          'done_at',
          'created',
          'updated',
        ],
      );
      expect(TableSortField.fromWire('due_date'), TableSortField.dueDate);
      expect(TableSortField.fromWire('dueDate'), isNull);
    });
  });

  group('columns', () {
    test("the web's in its chooser order, without its number", () {
      expect(
        [for (final column in TableColumn.values) column.wireName],
        [
          'done',
          'project',
          'title',
          'priority',
          'labels',
          'assignees',
          'commentCount',
          'dueDate',
          'startDate',
          'endDate',
          'percentDone',
          'doneAt',
          'created',
          'updated',
          'createdBy',
        ],
      );
    });

    test("the web's defaults without its number", () {
      expect(TableColumn.defaults, {
        TableColumn.done,
        TableColumn.title,
        TableColumn.labels,
        TableColumn.assignees,
        TableColumn.dueDate,
      });
    });

    test('ten sort, each by its own field; the number has no column', () {
      final sortable = [
        for (final column in TableColumn.values) ?column.sortField,
      ];

      expect(sortable, [
        for (final field in TableSortField.values)
          if (field != TableSortField.taskIndex) field,
      ]);
    });

    test('a sort on a hidden column gives way to the default', () {
      const byDue = TableSort(TableSortField.dueDate, descending: false);
      const byPriority = TableSort(TableSortField.priority, descending: true);

      expect(byDue.forColumns(TableColumn.defaults), byDue);
      expect(
        byPriority.forColumns(TableColumn.defaults),
        TableSort.defaultSort,
      );
      expect(
        byPriority.forColumns({...TableColumn.defaults, TableColumn.priority}),
        byPriority,
      );
      expect(
        TableSort.defaultSort.forColumns({TableColumn.title}),
        TableSort.defaultSort,
      );
      expect(
        const TableSort(
          TableSortField.taskIndex,
          descending: false,
        ).forColumns(TableColumn.values.toSet()),
        TableSort.defaultSort,
      );
    });

    test('read back from their keys only', () {
      for (final column in TableColumn.values) {
        expect(TableColumn.fromWire(column.wireName), column);
      }
      expect(TableColumn.fromWire('due_date'), isNull);
      expect(TableColumn.fromWire('index'), isNull);
      expect(TableColumn.fromWire(null), isNull);
    });
  });
}
