// The web's Gantt request against Vikunja 2.7.0 (v1 and v2 answered alike)
// and what the web draws from the answer (fixtures/gantt/
// gantt_observed.json, from scratchpad step29/gantt-vectors.json): the
// engine evaluates the web's filter text for the same tasks, and the
// layout draws the same rows, with calendar-day widths where the web's
// are a day wider across a DST change.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/tasks.dart';
import 'gantt_test_support.dart';

final Map<String, Object?> _fixture = jsonDecode(
  File('test/fixtures/gantt/gantt_observed.json').readAsStringSync(),
) as Map<String, Object?>;

List<Map<String, Object?>> _list(Object? json) => [
  for (final item in json! as List<Object?>) item! as Map<String, Object?>,
];

DateTime? _instant(Object? json) =>
    json == null ? null : DateTime.parse(json as String);

/// The probe's tasks by key, with their subtask relations both ways.
Map<String, Task> _probeTasks({required bool withX}) {
  final children = <String, List<String>>{};
  final parents = <String, List<String>>{};
  for (final pair
      in _fixture['relations_parent_to_subtask']! as List<Object?>) {
    final [parent, child] = [
      for (final key in pair! as List<Object?>) key! as String,
    ];
    (children[parent] ??= []).add(child);
    (parents[child] ??= []).add(parent);
  }
  final rows = [
    for (final row in _list(_fixture['fixture_tasks']))
      if (withX || row['key'] != 'X') row,
  ];
  final ids = {
    for (final row in rows) row['key']! as String: row['id']! as int,
  };
  List<Task> stubs(List<String>? keys) => [
    for (final key in keys ?? const <String>[])
      Task(id: ids[key]!, title: key, projectId: 1),
  ];
  return {
    for (final row in rows)
      row['key']! as String: Task(
        id: row['id']! as int,
        title: row['key']! as String,
        projectId: 1,
        startDate: _instant(row['start_date']),
        endDate: _instant(row['end_date']),
        dueDate: _instant(row['due_date']),
        done: row['done'] as bool? ?? false,
        relatedTasks: {
          if (children[row['key']] case final keys?)
            TaskRelationKind.subtask: stubs(keys),
          if (parents[row['key']] case final keys?)
            TaskRelationKind.parentTask: stubs(keys),
        },
      ),
  };
}

tz.Location _zone(String name) => switch (name) {
  // The parameter left out: the server's own zone, GMT on the probed server.
  '' || 'UTC' => tz.UTC,
  _ => tz.getLocation(name),
};

final _now = DateTime.utc(2026, 10, 26, 12);

List<Task> _matching(
  Map<String, Task> tasks, {
  required GanttRange range,
  required String timezone,
  required bool includeNulls,
  String? viewFilter,
}) {
  var expression = parseTaskFilter(ganttFilterText(range)) as FilterExpression;
  if (viewFilter != null) {
    expression = expression.and(
      parseTaskFilter(viewFilter) as FilterExpression,
    );
  }
  final context = FilterContext(
    now: _now,
    location: _zone(timezone),
    includeNulls: includeNulls,
  );
  return [
    for (final task in tasks.values)
      if (matchesFilter(expression, FilterableTask.fromTask(task), context))
        task,
  ];
}

/// Every task the server returned (the matching ones and all their
/// descendants), the top-level ones in its order, through a layout wide
/// enough to show them all.
({Set<String> all, List<String> topLevel}) _served(
  Map<String, Task> tasks,
  List<Task> matching,
) {
  final layout = layoutGantt(
    matching: matching,
    tasksById: {for (final task in tasks.values) task.id: task},
    range: range('2000-01-01', '2100-12-31'),
    today: date('2026-10-26'),
    zone: tz.UTC,
    showTasksWithoutDates: true,
  );
  return (
    all: {for (final row in layout.rows) row.task.title},
    topLevel: [
      for (final row in layout.rows)
        if (row.parent == null) row.task.title,
    ],
  );
}

void _expectServed(
  Map<String, Task> tasks,
  List<Task> matching,
  List<String> served,
) {
  final ours = _served(tasks, matching);
  expect(ours.all, served.toSet());
  // The server appends the descendants after the page's top-level tasks.
  expect(ours.topLevel, [
    for (final key in served)
      if (ours.topLevel.contains(key)) key,
  ]);
}

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group("the server's answers", () {
    for (final run in _list(_fixture['runs'])) {
      final timezone = run['tz']! as String;
      final includeNulls = run['include_nulls']! as bool;
      test('${run['version']} ${run['from']}..${run['to']} '
          'tz=${timezone.isEmpty ? '(none)' : timezone}'
          '${includeNulls ? ' with tasks without dates' : ''}', () {
        final tasks = _probeTasks(withX: false);
        final matching = _matching(
          tasks,
          range: range(run['from']! as String, run['to']! as String),
          timezone: timezone,
          includeNulls: includeNulls,
        );

        _expectServed(tasks, matching, [
          for (final key in run['titles_in_order']! as List<Object?>)
            key! as String,
        ]);
      });
    }

    final extra = _fixture['extra']! as Map<String, Object?>;
    List<String> keys(String name) => [
      for (final key in extra[name]! as List<Object?>) key! as String,
    ];
    final r1 = range('2026-10-11', '2026-12-20');

    for (final timezone in ['UTC', 'America/Los_Angeles', 'Europe/Berlin']) {
      test('X starting at 05:00Z on the last day, tz=$timezone', () {
        final tasks = _probeTasks(withX: true);

        _expectServed(
          tasks,
          _matching(tasks, range: r1, timezone: timezone, includeNulls: false),
          keys('X_start_2026-12-20T05:00Z_$timezone'),
        );
      });
    }

    // The server ignores the timezone setting without `filter_timezone`;
    // the web always sends it, and the app passes the setting too.
    for (final version in ['v1', 'v2']) {
      test('no filter_timezone, $version: the server zone', () {
        final tasks = _probeTasks(withX: true);

        _expectServed(
          tasks,
          _matching(tasks, range: r1, timezone: '', includeNulls: false),
          keys(
            'settings.timezone=Europe/Berlin_and_no_filter_timezone_$version',
          ),
        );
      });
    }

    for (final includeNulls in [false, true]) {
      test("the view's filter 'done = false' "
          '${includeNulls ? 'with' : 'without'} tasks without dates', () {
        final tasks = _probeTasks(withX: true);

        _expectServed(
          tasks,
          _matching(
            tasks,
            range: r1,
            timezone: 'UTC',
            includeNulls: includeNulls,
            viewFilter: 'done = false',
          ),
          keys("gantt_view_filter_'done = false'_nulls_${includeNulls}_UTC"),
        );
      });
    }

    test('a reversed range', () {
      final tasks = _probeTasks(withX: true);

      _expectServed(
        tasks,
        _matching(
          tasks,
          range: range('2026-12-20', '2026-10-11'),
          timezone: 'UTC',
          includeNulls: false,
        ),
        keys('reversed_range_2026-12-20_to_2026-10-11_UTC'),
      );
    });

    test('a single day: only the span', () {
      final tasks = _probeTasks(withX: true);

      _expectServed(
        tasks,
        _matching(
          tasks,
          range: range('2026-11-01', '2026-11-01'),
          timezone: 'UTC',
          includeNulls: false,
        ),
        keys('single_day_range_2026-11-01_UTC'),
      );
    });

    test('without expand: the matching tasks alone, in the server order', () {
      final tasks = _probeTasks(withX: true);
      final matching = _matching(
        tasks,
        range: r1,
        timezone: 'Europe/Berlin',
        includeNulls: false,
      );
      final layout = layoutGantt(
        matching: matching,
        tasksById: const {},
        range: range('2000-01-01', '2100-12-31'),
        today: date('2026-10-26'),
        zone: tz.UTC,
      );

      expect([
        for (final row in layout.rows) row.task.title,
      ], keys('no_expand_v2_R1_Berlin_nulls_false'));
    });

    test('paged by 2: the same tasks', () {
      final tasks = _probeTasks(withX: true);
      final paged =
          extra['per_page_2_v2_R1_Berlin_nulls_false']! as Map<String, Object?>;

      _expectServed(
        tasks,
        _matching(
          tasks,
          range: r1,
          timezone: 'Europe/Berlin',
          includeNulls: false,
        ),
        [for (final key in paged['titles']! as List<Object?>) key! as String],
      );
    });
  });

  // task_collection_test.go
  group("the server's own tests", () {
    test('GO1: a dateless parent does not match; its dated child is a '
        'top-level row', () {
      final parent = task(1, title: 'dateless parent', subtaskIds: [2]);
      final child = task(
        2,
        title: 'dated child',
        startDate: DateTime.utc(2020, 6),
        endDate: DateTime.utc(2020, 6, 10),
        dueDate: DateTime.utc(2020, 6, 5),
        parentIds: [1],
      );
      final tasks = {'parent': parent, 'child': child};
      const filter =
          "(start_date >= '2020-01-01T00:00:00' && "
          "start_date <= '2020-12-31T00:00:00') || "
          "(end_date >= '2020-01-01T00:00:00' && "
          "end_date <= '2020-12-31T00:00:00') || "
          "(due_date >= '2020-01-01T00:00:00' && "
          "due_date <= '2020-12-31T00:00:00')";
      final expression = parseTaskFilter(filter) as FilterExpression;
      final context = FilterContext(now: _now, location: tz.UTC);
      final matching = [
        for (final task in tasks.values)
          if (matchesFilter(expression, FilterableTask.fromTask(task), context))
            task,
      ];
      final layout = layoutGantt(
        matching: matching,
        tasksById: {1: parent, 2: child},
        range: range('2020-01-01', '2020-12-31'),
        today: date('2026-10-26'),
        zone: tz.UTC,
      );

      expect([for (final row in layout.rows) row.task.title], ['dated child']);
      expect(layout.rows.single.parent, isNull);
    });

    test('GO2: include-nulls covers the Gantt filter, not the saved '
        "filter's own conditions", () {
      const user = User(id: 1, username: 'user1');
      Task assigned(Task task) => task.copyWith(assignees: [user]);
      final tasks = [
        assigned(
          task(
            1,
            title: 'dated',
            projectId: 5,
            startDate: DateTime.utc(2020, 6),
            endDate: DateTime.utc(2020, 6, 10),
          ),
        ),
        assigned(task(2, title: 'dateless', projectId: 5)),
        task(3, title: 'dateless unassigned', projectId: 5),
      ];
      final merged = mergeSavedFilter(
        saved: parseTaskFilter(
          'done = false && project = 5 && assignees in user1',
        ) as FilterExpression,
        savedIncludesNulls: false,
        request: parseTaskFilter(
          "(start_date >= '2020-01-01T00:00:00' && "
          "start_date <= '2020-12-31T00:00:00') || "
          "(end_date >= '2020-01-01T00:00:00' && "
          "end_date <= '2020-12-31T00:00:00')",
        ) as FilterExpression,
        requestIncludesNulls: true,
      );
      final context = FilterContext(
        now: _now,
        location: tz.UTC,
        includeNulls: merged.includeNulls,
      );

      expect([
        for (final task in tasks)
          if (matchesFilter(
            merged.expression,
            FilterableTask.fromTask(task),
            context,
          ))
            task.title,
      ], unorderedEquals(['dated', 'dateless']));
    });
  });

  group('what the web draws', () {
    for (final scenario in _list(_fixture['derived_client_rows'])) {
      final timezone = scenario['filter_timezone_and_device_zone']! as String;
      final withoutDates = scenario['showTasksWithoutDates']! as bool;
      test('${scenario['from']}..${scenario['to']} $timezone'
          '${withoutDates ? ' with tasks without dates' : ''}', () {
        final tasks = _probeTasks(withX: timezone == 'America/Los_Angeles');
        final shown = range(
          scenario['from']! as String,
          scenario['to']! as String,
        );
        final layout = layoutGantt(
          matching: _matching(
            tasks,
            range: shown,
            timezone: timezone,
            includeNulls: withoutDates,
          ),
          tasksById: {for (final task in tasks.values) task.id: task},
          range: shown,
          today: date(scenario['today']! as String),
          zone: _zone(timezone),
          showTasksWithoutDates: withoutDates,
        );
        final expected = _list(scenario['web_rows']);

        expect(
          [for (final row in layout.rows) row.task.title],
          [for (final row in expected) row['task']],
        );
        for (final (index, web) in expected.indexed) {
          final row = layout.rows[index];
          final reason = '${web['task']}';
          final task = tasks[web['task']]!;
          final derived =
              web['isParent']! as bool &&
              task.startDate == null &&
              task.endDate == null &&
              task.dueDate == null;
          final kind = switch ((web['dateType'], web['style'])) {
            ('both', 'estimated') when !derived => GanttBarKind.estimated,
            ('both', _) => GanttBarKind.scheduled,
            ('startOnly', _) => GanttBarKind.startOnly,
            ('endOnly', _) => GanttBarKind.endOnly,
            _ => throw StateError('$web'),
          };
          final barEnd = web['barEndLocal']! as String;
          final afterEnd = date(barEnd.substring(0, 10))
              .addDays(barEnd.endsWith('T23:59') ? 1 : 0);

          expect(row.indent, web['indent'], reason: reason);
          expect(row.isParent, web['isParent'], reason: reason);
          expect(row.task.done, web['done'], reason: reason);
          expect(row.bar.kind, kind, reason: reason);
          expect(row.bar.derived, derived, reason: reason);
          expect(
            row.bar.first,
            date(web['barStartLocal']! as String),
            reason: reason,
          );
          expect(row.bar.column, web['dayColumnOffset'], reason: reason);
          expect(row.bar.days, web['widthCalendarDays'], reason: reason);
          expect(row.bar.first.addDays(row.bar.days), afterEnd, reason: reason);
        }
      });
    }
  });
}
