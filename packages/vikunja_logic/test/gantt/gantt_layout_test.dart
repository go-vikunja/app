import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/tasks.dart';
import 'gantt_test_support.dart';

// ganttTaskTree.spec.ts: every task starts on 2026-03-01 and ends on
// 2026-03-10 unless the case says otherwise.
Task _treeTask(
  int id, {
  List<int> subtasks = const [],
  List<int> parents = const [],
}) => task(
  id,
  startDate: DateTime.utc(2026, 3),
  endDate: DateTime.utc(2026, 3, 10),
  subtaskIds: subtasks,
  parentIds: parents,
);

final GanttRange _march = range('2026-02-15', '2026-04-30');

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('the tree (ganttTaskTree.spec.ts)', () {
    test('TT1: a flat list without relations', () {
      final layout = layoutAll([_treeTask(1), _treeTask(2)], range: _march);

      // The web keeps the server's order, which puts the newer of two tasks
      // with the same start first; the model sorts the same way.
      expect(rowIds(layout), [2, 1]);
      expect([for (final row in layout.rows) row.indent], [0, 0]);
      expect(layout.rows.any((row) => row.isParent), isFalse);
      expect(layout.rows.every((row) => row.parent == null), isTrue);
    });

    test('TT2: subtasks under their parent, depth first', () {
      final layout = layoutAll([
        _treeTask(1, subtasks: [2, 3]),
        _treeTask(2, parents: [1]),
        _treeTask(3, parents: [1]),
      ], range: _march);

      expect(rowIds(layout), [1, 2, 3]);
      expect([for (final row in layout.rows) row.indent], [0, 1, 1]);
      expect(layout.rows[0].isParent, isTrue);
      expect(layout.rows[0].canCollapse, isTrue);
      expect([for (final row in layout.rows) row.parent?.id], [null, 1, 1]);
    });

    test('TT3: several levels', () {
      final layout = layoutAll([
        _treeTask(1, subtasks: [2]),
        _treeTask(2, parents: [1], subtasks: [3]),
        _treeTask(3, parents: [2]),
      ], range: _march);

      expect(rowIds(layout), [1, 2, 3]);
      expect([for (final row in layout.rows) row.indent], [0, 1, 2]);
      expect(layout.rows[1].isParent, isTrue);
      expect(layout.rows[2].isParent, isFalse);
    });

    test('TT4: the indent stops at 4', () {
      final layout = layoutAll([
        for (var id = 1; id <= 6; id++)
          _treeTask(
            id,
            parents: [if (id > 1) id - 1],
            subtasks: [if (id < 6) id + 1],
          ),
      ], range: _march);

      expect(rowIds(layout), [1, 2, 3, 4, 5, 6]);
      expect([for (final row in layout.rows) row.indent], [0, 1, 2, 3, 4, 4]);
    });

    test('TT5: a parent without dates takes them from its subtasks', () {
      final layout = layoutAll([
        task(1, subtaskIds: [2, 3]),
        task(
          2,
          startDate: DateTime.utc(2026, 3, 5),
          endDate: DateTime.utc(2026, 3, 10),
          parentIds: [1],
        ),
        task(
          3,
          startDate: DateTime.utc(2026, 3),
          endDate: DateTime.utc(2026, 3, 15),
          parentIds: [1],
        ),
      ], range: _march);
      final bar = layout.rows.first.bar;

      expect(layout.rows.first.task.id, 1);
      expect(bar.derived, isTrue);
      expect(bar.kind, GanttBarKind.scheduled);
      expect(bar.first, date('2026-03-01'));
      // The latest end, 03-15 at midnight, ends the bar at the start of
      // that day.
      expect(bar.first.addDays(bar.days), date('2026-03-15'));
    });

    test('a group band spans the parent and the subtasks below it, as wide '
        'as all their bars (GanttChart.vue parentGroupBands)', () {
      final layout = layoutAll([
        task(
          1,
          startDate: DateTime.utc(2026, 3),
          endDate: DateTime.utc(2026, 3, 10),
          subtaskIds: [2],
        ),
        task(
          2,
          startDate: DateTime.utc(2026, 3, 12),
          endDate: DateTime.utc(2026, 3, 20),
          parentIds: [1],
        ),
        task(
          3,
          startDate: DateTime.utc(2026, 4),
          endDate: DateTime.utc(2026, 4, 3),
        ),
      ], range: _march);
      final band = (layout.rows[0].bar.column, layout.rows[1].bar.endColumn);

      expect(rowIds(layout), [1, 2, 3]);
      expect(layout.groupSpans, [
        [band],
        [band],
        <(int, int)>[],
      ]);
    });

    test('derived dates reach grandchildren and fall back to due dates', () {
      final layout = layoutAll([
        task(1, subtaskIds: [2]),
        task(2, subtaskIds: [3, 4], parentIds: [1]),
        task(3, startDate: DateTime.utc(2026, 3, 2, 9), parentIds: [2]),
        task(4, dueDate: DateTime.utc(2026, 3, 20, 15), parentIds: [2]),
      ], range: _march);
      final parent = layout.rows.first;

      expect(parent.bar.derived, isTrue);
      expect(parent.bar.first, date('2026-03-02'));
      expect(parent.bar.last, date('2026-03-20'));
      expect(
        layout.rows[1].bar.derived,
        isTrue,
        reason: 'task 2 has no dates either',
      );
    });

    test('a parent with dates of its own keeps them', () {
      final layout = layoutAll([
        task(1, dueDate: DateTime.utc(2026, 3, 4, 15), subtaskIds: [2]),
        task(
          2,
          startDate: DateTime.utc(2026, 3),
          endDate: DateTime.utc(2026, 3, 20),
          parentIds: [1],
        ),
      ], range: _march);
      final bar = layout.rows.first.bar;

      expect(bar.derived, isFalse);
      expect(bar.kind, GanttBarKind.endOnly);
      expect(bar.last, date('2026-03-04'));
    });

    test('a parent whose subtasks have no dates either is estimated', () {
      final children = [
        task(1, subtaskIds: [2]),
        task(2, parentIds: [1]),
      ];

      expect(layoutAll(children, range: _march).rows, isEmpty);
      final layout = layoutAll(
        children,
        range: _march,
        today: date('2026-03-10'),
        showTasksWithoutDates: true,
      );
      expect(layout.rows.first.bar.kind, GanttBarKind.estimated);
      expect(layout.rows.first.bar.derived, isFalse);
    });
  });

  group('rows', () {
    test(
      'top level: by start (missing last), open before done, newest first',
      () {
        final tasks = [
          task(
            1,
            startDate: DateTime.utc(2026, 3, 5, 10),
            endDate: DateTime.utc(2026, 3, 6),
          ),
          task(2, dueDate: DateTime.utc(2026, 3, 8)),
          task(3, startDate: DateTime.utc(2026, 3, 5, 10), done: true),
          task(4, startDate: DateTime.utc(2026, 3, 5, 10)),
          task(5, endDate: DateTime.utc(2026, 3, 8)),
          task(6, startDate: DateTime.utc(2026, 3, 1, 23)),
          task(7, endDate: DateTime.utc(2026, 3, 9), done: true),
          task(-1, startDate: DateTime.utc(2026, 3, 5, 10)),
        ];

        expect(rowIds(layoutAll(tasks, range: _march)), [
          6,
          -1,
          4,
          1,
          3,
          5,
          2,
          7,
        ]);
        expect(rowIds(layoutAll(tasks.reversed.toList(), range: _march)), [
          6,
          -1,
          4,
          1,
          3,
          5,
          2,
          7,
        ]);
      },
    );

    test('descendants of the matching tasks join them, in any project', () {
      final parent = task(
        1,
        startDate: DateTime.utc(2026, 3, 2),
        subtaskIds: [2],
      );
      final child = task(
        2,
        projectId: 9,
        startDate: DateTime.utc(2026, 3, 3),
        parentIds: [1],
        subtaskIds: [3],
      );
      final grandchild = task(
        3,
        projectId: 9,
        dueDate: DateTime.utc(2026, 3, 4),
        parentIds: [2],
      );

      final layout = layoutGantt(
        matching: [parent],
        tasksById: {1: parent, 2: child, 3: grandchild},
        range: _march,
        today: date('2026-03-01'),
        zone: tz.UTC,
      );

      expect(rowIds(layout), [1, 2, 3]);
      expect([for (final row in layout.rows) row.indent], [0, 1, 2]);
    });

    test(
      'a matching subtask whose parent does not match is a top-level row',
      () {
        final parent = task(1, subtaskIds: [2]);
        final child = task(
          2,
          startDate: DateTime.utc(2026, 3, 3),
          parentIds: [1],
        );

        final layout = layoutGantt(
          matching: [child],
          tasksById: {1: parent, 2: child},
          range: _march,
          today: date('2026-03-01'),
          zone: tz.UTC,
        );

        expect(rowIds(layout), [2]);
        expect(layout.rows.single.indent, 0);
        expect(layout.rows.single.parent, isNull);
      },
    );

    test('a subtask of two parents shows once, under the first', () {
      final tasks = [
        task(1, startDate: DateTime.utc(2026, 3, 2), subtaskIds: [3]),
        task(2, startDate: DateTime.utc(2026, 3, 4), subtaskIds: [3]),
        task(3, startDate: DateTime.utc(2026, 3, 3), parentIds: [1, 2]),
      ];

      final layout = layoutAll(tasks, range: _march);

      expect(rowIds(layout), [1, 3, 2]);
      expect(layout.rows[1].parent?.id, 1);
      expect(layout.rows[2].isParent, isTrue);
      expect(layout.rows[2].canCollapse, isFalse);
    });

    test('a relation cycle shows each task once', () {
      final tasks = [
        task(
          1,
          startDate: DateTime.utc(2026, 3, 2),
          subtaskIds: [2],
          parentIds: [2],
        ),
        task(
          2,
          startDate: DateTime.utc(2026, 3, 3),
          subtaskIds: [1],
          parentIds: [1],
        ),
        task(3, startDate: DateTime.utc(2026, 3)),
      ];

      final layout = layoutAll(tasks, range: _march);

      expect(rowIds(layout), [3, 1, 2]);
      expect([for (final row in layout.rows) row.indent], [0, 0, 1]);
    });

    test('a subtask missing from the lookup is left out', () {
      final parent = task(
        1,
        startDate: DateTime.utc(2026, 3, 2),
        subtaskIds: [2],
      );

      final layout = layoutGantt(
        matching: [parent],
        tasksById: {1: parent},
        range: _march,
        today: date('2026-03-01'),
        zone: tz.UTC,
      );

      expect(rowIds(layout), [1]);
      expect(layout.rows.single.isParent, isFalse);
    });
  });

  group('rounding to days (roundToNaturalDayBoundary.test.ts)', () {
    late final berlin = tz.getLocation('Europe/Berlin');
    final january = range('2023-12-20', '2024-01-31');
    DateTime local(int month, int day, int hour) =>
        tz.TZDateTime(berlin, month == 12 ? 2023 : 2024, month, day, hour);

    GanttBar barOf({DateTime? start, DateTime? end}) => layoutAll(
      [task(1, startDate: start, endDate: end)],
      range: january,
      zone: berlin,
    ).rows.single.bar;

    test('RB1: a start counts from the start of its day', () {
      expect(
        barOf(start: local(1, 1, 8), end: local(1, 3, 13)).first,
        date('2024-01-01'),
      );
      expect(
        barOf(start: local(1, 1, 13), end: local(1, 3, 13)).first,
        date('2024-01-01'),
      );
    });

    test('RB2: an end before noon ends the bar at the start of its day', () {
      expect(
        barOf(start: local(12, 30, 9), end: local(1, 1, 8)).last,
        date('2023-12-31'),
      );
      expect(
        barOf(start: local(12, 30, 9), end: local(1, 1, 13)).last,
        date('2024-01-01'),
      );
    });

    test('RB3: an evening on the same day is one day', () {
      expect(barOf(start: local(1, 1, 15), end: local(1, 1, 18)).days, 1);
    });

    test('RB4: a morning on the same day is one day too', () {
      final bar = barOf(start: local(1, 1, 8), end: local(1, 1, 10));

      expect(bar.days, 1);
      expect(bar.first, date('2024-01-01'));
    });

    test('RB5: start and end at the same midnight are one day', () {
      expect(barOf(start: local(1, 1, 0), end: local(1, 1, 0)).days, 1);
    });

    test('RB6: several days', () {
      expect(barOf(start: local(1, 1, 8), end: local(1, 3, 18)).days, 3);
      expect(barOf(start: local(1, 1, 8), end: local(1, 3, 10)).days, 2);
    });

    test('an end before the start is one day at the start', () {
      final bar = barOf(start: local(1, 5, 8), end: local(1, 3, 18));

      expect(bar.first, date('2024-01-05'));
      expect(bar.days, 1);
    });
  });

  group(
    'bars (GanttChart.vue, derived from its code; UTC, today 2024-01-01)',
    () {
      final january = range('2023-12-20', '2024-02-29');
      final today = date('2024-01-01');
      DateTime at(int day, int hour) => DateTime.utc(2024, 1, day, hour);

      GanttBar? barOf(Task task, {bool withoutDates = false}) => layoutAll(
        [task],
        range: january,
        today: today,
        showTasksWithoutDates: withoutDates,
      ).rows.firstOrNull?.bar;

      void expectBar(
        GanttBar? bar, {
        required GanttBarKind kind,
        required String first,
        required int days,
      }) {
        expect(bar?.kind, kind);
        expect(bar?.first, date(first));
        expect(bar?.days, days);
        expect(bar?.column, date(first).daysSince(january.from));
        expect(bar?.derived, isFalse);
      }

      test('start and end', () {
        expectBar(
          barOf(task(1, startDate: at(1, 8), endDate: at(3, 18))),
          kind: GanttBarKind.scheduled,
          first: '2024-01-01',
          days: 3,
        );
      });

      test('start and due', () {
        expectBar(
          barOf(task(1, startDate: at(1, 8), dueDate: at(3, 10))),
          kind: GanttBarKind.scheduled,
          first: '2024-01-01',
          days: 2,
        );
      });

      test('start only: seven days', () {
        expectBar(
          barOf(task(1, startDate: at(1, 15))),
          kind: GanttBarKind.startOnly,
          first: '2024-01-01',
          days: 7,
        );
      });

      test('end only, after noon: eight days', () {
        expectBar(
          barOf(task(1, endDate: at(10, 15))),
          kind: GanttBarKind.endOnly,
          first: '2024-01-03',
          days: 8,
        );
      });

      test('end only, before noon: seven days', () {
        expectBar(
          barOf(task(1, endDate: at(10, 9))),
          kind: GanttBarKind.endOnly,
          first: '2024-01-03',
          days: 7,
        );
      });

      test('due only', () {
        expectBar(
          barOf(task(1, dueDate: at(10, 15))),
          kind: GanttBarKind.endOnly,
          first: '2024-01-03',
          days: 8,
        );
      });

      test('the end date wins over the due date', () {
        final bar = barOf(task(1, endDate: at(10, 15), dueDate: at(20, 15)));

        expect(bar?.kind, GanttBarKind.endOnly);
        expect(bar?.last, date('2024-01-10'));
      });

      test('no dates, with tasks without dates: today through today + 7', () {
        expectBar(
          barOf(task(1), withoutDates: true),
          kind: GanttBarKind.estimated,
          first: '2024-01-01',
          days: 8,
        );
      });

      test('no dates, without them: no row', () {
        expect(barOf(task(1)), isNull);
      });
    },
  );

  group('calendar days across a DST change, unlike the web', () {
    test('Europe/Berlin in October: 13 days, where the web draws 14', () {
      final layout = layoutAll(
        [
          task(
            1,
            startDate: DateTime.utc(2026, 10, 20, 10),
            endDate: DateTime.utc(2026, 11, 2, 10),
          ),
        ],
        range: range('2026-10-11', '2026-12-20'),
        zone: tz.getLocation('Europe/Berlin'),
      );

      expect(layout.rows.single.bar.first, date('2026-10-20'));
      expect(layout.rows.single.bar.days, 13);
      expect(layout.rows.single.bar.column, 9);
    });

    test('America/Los_Angeles in November: 7 days, where the web draws 8', () {
      final layout = layoutAll(
        [
          task(
            1,
            startDate: DateTime.utc(2026, 10, 28, 19),
            endDate: DateTime.utc(2026, 11, 3, 21),
          ),
          task(2, endDate: DateTime.utc(2026, 11, 5, 10)),
        ],
        range: range('2026-10-11', '2026-12-20'),
        zone: tz.getLocation('America/Los_Angeles'),
      );

      expect(layout.rows[0].bar.first, date('2026-10-28'));
      expect(layout.rows[0].bar.days, 7);
      expect(layout.rows[1].bar.first, date('2026-10-29'));
      expect(layout.rows[1].bar.days, 7);
    });

    test('Europe/Berlin in March', () {
      final berlin = tz.getLocation('Europe/Berlin');
      final layout = layoutAll(
        [
          task(
            1,
            startDate: tz.TZDateTime(berlin, 2026, 3, 28, 9),
            endDate: tz.TZDateTime(berlin, 2026, 3, 30, 13),
          ),
        ],
        range: range('2026-03-15', '2026-04-15'),
        zone: berlin,
      );

      expect(layout.rows.single.bar.days, 3);
    });
  });

  group('the range', () {
    final november = range('2026-11-01', '2026-11-30');

    GanttLayout layoutOf(
      Task task, {
      bool withoutDates = false,
      String today = '2026-11-10',
    }) => layoutAll(
      [task],
      range: november,
      today: date(today),
      showTasksWithoutDates: withoutDates,
    );

    test('a bar starting after the last day is left out', () {
      expect(
        layoutOf(task(1, startDate: DateTime.utc(2026, 12, 1, 1))).rows,
        isEmpty,
      );
      expect(
        layoutOf(task(1, startDate: DateTime.utc(2026, 11, 30, 23))).rows,
        hasLength(1),
      );
    });

    test('a bar ending before the first day is left out', () {
      expect(
        layoutOf(task(1, dueDate: DateTime.utc(2026, 10, 31, 15))).rows,
        isEmpty,
      );
      expect(
        layoutOf(task(1, startDate: DateTime.utc(2026, 10, 24))).rows,
        isEmpty,
      );
    });

    test('a bar ending at midnight of the first day stays, as on the web', () {
      // Its task ends on the first day, before noon.
      final layout = layoutOf(task(1, endDate: DateTime.utc(2026, 11, 1, 9)));

      expect(layout.rows.single.bar.endColumn, 0);
      expect(
        layoutOf(task(1, startDate: DateTime.utc(2026, 10, 25))).rows,
        hasLength(1),
      );
    });

    test('a bar over the whole range stays', () {
      final layout = layoutOf(
        task(
          1,
          startDate: DateTime.utc(2026, 9),
          endDate: DateTime.utc(2027, 1, 31),
        ),
      );

      expect(layout.rows.single.bar.column, -61);
      expect(layout.rows.single.bar.endColumn, 91);
    });

    test('an estimated bar needs today near the range', () {
      expect(layoutOf(task(1), withoutDates: true).rows, hasLength(1));
      expect(
        layoutOf(task(1), withoutDates: true, today: '2026-12-01').rows,
        isEmpty,
      );
      expect(
        layoutOf(task(1), withoutDates: true, today: '2026-10-25').rows,
        hasLength(1),
      );
    });

    test("today's column", () {
      expect(layoutOf(task(1)).todayColumn, 9);
      expect(layoutOf(task(1), today: '2026-12-01').todayColumn, isNull);
      expect(layoutOf(task(1)).dayCount, 30);
    });
  });

  group('collapse', () {
    final tasks = [
      task(1, startDate: DateTime.utc(2026, 3, 2), subtaskIds: [2, 4]),
      task(
        2,
        startDate: DateTime.utc(2026, 3, 3),
        parentIds: [1],
        subtaskIds: [3],
      ),
      task(3, startDate: DateTime.utc(2026, 3, 4), parentIds: [2]),
      task(4, startDate: DateTime.utc(2026, 3, 5), parentIds: [1]),
      task(5, startDate: DateTime.utc(2026, 3, 6), subtaskIds: [6]),
      task(6, startDate: DateTime.utc(2027, 3, 6), parentIds: [5]),
    ];

    test('nothing is collapsed at first', () {
      final layout = layoutAll(tasks, range: _march);

      expect(rowIds(layout), [1, 2, 3, 4, 5]);
      expect(layout.rows.any((row) => row.collapsed), isFalse);
    });

    test('a collapsed parent hides all its descendants', () {
      final layout = layoutAll(tasks, range: _march, collapsed: {1});

      expect(rowIds(layout), [1, 5]);
      expect(layout.rows.first.collapsed, isTrue);
      expect(layout.rows.first.canCollapse, isTrue);
    });

    test('a collapsed subtask hides only its own', () {
      final layout = layoutAll(tasks, range: _march, collapsed: {2});

      expect(rowIds(layout), [1, 2, 4, 5]);
      expect(layout.rows[1].collapsed, isTrue);
    });

    test('a collapsed parent outside the range hides nothing', () {
      final layout = layoutAll(
        [
          task(1, startDate: DateTime.utc(2027, 3, 2), subtaskIds: [2]),
          task(2, startDate: DateTime.utc(2026, 3, 3), parentIds: [1]),
        ],
        range: _march,
        collapsed: {1},
      );

      expect(rowIds(layout), [2]);
      expect(layout.rows.single.indent, 1);
    });

    test(
      'a parent whose subtasks are all outside the range cannot collapse',
      () {
        final layout = layoutAll(tasks, range: _march);
        final parent = layout.rows[layout.rowOf(5)!];

        expect(parent.isParent, isTrue);
        expect(parent.canCollapse, isFalse);
        expect(layout.rowOf(6), isNull);
      },
    );
  });

  group('arrows', () {
    Task dated(
      int id,
      int day, {
      List<int> subtasks = const [],
      List<int> parents = const [],
    }) => task(
      id,
      startDate: DateTime.utc(2026, 3, day),
      endDate: DateTime.utc(2026, 3, day + 2),
      subtaskIds: subtasks,
      parentIds: parents,
    );

    test('blocking and precedes, from the right edge to the left edge', () {
      final layout = layoutAll([
        related(dated(1, 2), blocking: [2], precedes: [3]),
        related(dated(2, 6), blocked: [1]),
        related(dated(3, 10), follows: [1]),
      ], range: _march);

      expect(layout.arrows, [
        const GanttArrow(
          fromTaskId: 1,
          toTaskId: 2,
          kind: GanttArrowKind.blocking,
          fromRow: 0,
          toRow: 1,
          fromColumn: 17,
          toColumn: 19,
          fromOffset: -3,
        ),
        const GanttArrow(
          fromTaskId: 1,
          toTaskId: 3,
          kind: GanttArrowKind.precedes,
          fromRow: 0,
          toRow: 2,
          fromColumn: 17,
          toColumn: 23,
          fromOffset: 3,
        ),
      ]);
    });

    test('other relations draw nothing', () {
      final layout = layoutAll([
        dated(1, 2).copyWith(
          relatedTasks: {
            TaskRelationKind.related: [
              const Task(id: 2, title: '', projectId: 1),
            ],
            TaskRelationKind.duplicateOf: [
              const Task(id: 2, title: '', projectId: 1),
            ],
          },
        ),
        dated(2, 6),
      ], range: _march);

      expect(layout.arrows, isEmpty);
    });

    test('an end outside the range draws nothing', () {
      final layout = layoutAll([
        related(dated(1, 2), blocking: [2]),
        related(task(2, startDate: DateTime.utc(2026, 6)), blocked: [1]),
      ], range: _march);

      expect(layout.arrows, isEmpty);
    });

    test("a collapsed task's arrows go to its visible ancestor", () {
      final layout = layoutAll(
        [
          related(dated(1, 2), blocking: [3]),
          dated(2, 6, subtasks: [3]),
          related(
            dated(3, 8, parents: [2], subtasks: [4]),
            blocked: [1],
          ),
          related(dated(4, 9, parents: [3]), precedes: [1]),
        ],
        range: _march,
        collapsed: {2, 3},
      );

      expect(rowIds(layout), [1, 2]);
      expect(
        [
          for (final arrow in layout.arrows)
            (arrow.fromTaskId, arrow.toTaskId, arrow.kind),
        ],
        [(1, 2, GanttArrowKind.blocking), (2, 1, GanttArrowKind.precedes)],
      );
    });

    test('an arrow between a parent and its collapsed subtask is dropped', () {
      final layout = layoutAll(
        [
          related(dated(1, 2, subtasks: [2]), blocking: [2]),
          related(dated(2, 6, parents: [1]), blocked: [1]),
        ],
        range: _march,
        collapsed: {1},
      );

      expect(layout.arrows, isEmpty);
    });
  });

  test('1,000 tasks are laid out well inside a frame', () {
    final berlin = tz.getLocation('Europe/Berlin');
    final today = date('2026-10-26');
    final tasks = <Task>[];
    for (var id = 1; id <= 1000; id++) {
      final start = DateTime.utc(2026, 9).add(Duration(hours: id * 37 % 2400));
      final parent = id % 5 == 0 && id > 5 ? id - 3 : null;
      tasks.add(
        related(
          task(
            id,
            startDate: id % 7 == 0 ? null : start,
            endDate: id % 3 == 0 ? null : start.add(Duration(days: id % 20)),
            dueDate: id % 11 == 0 ? start.add(const Duration(days: 3)) : null,
            done: id % 13 == 0,
            parentIds: [?parent],
            subtaskIds: [if (id % 5 == 2 && id + 3 <= 1000) id + 3],
          ),
          blocking: [if (id % 17 == 0 && id < 990) id + 9],
          precedes: [if (id % 19 == 0 && id > 30) id - 30],
        ),
      );
    }
    GanttLayout run() => layoutAll(
      tasks,
      range: defaultGanttRange(DateTime(2026, 10, 26)),
      zone: berlin,
      today: today,
      showTasksWithoutDates: true,
      collapsed: {7, 22},
    );

    run();
    final stopwatch = Stopwatch()..start();
    final layout = run();
    stopwatch.stop();

    expect(layout.rows.length, greaterThan(500));
    expect(layout.arrows, isNotEmpty);
    expect(stopwatch.elapsedMilliseconds, lessThan(50));
  });
}
