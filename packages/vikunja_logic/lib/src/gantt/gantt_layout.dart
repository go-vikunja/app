import 'dart:math';

import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/src/gantt/gantt_arrows.dart';
import 'package:vikunja_logic/src/gantt/gantt_range.dart';
import 'package:vikunja_logic/src/lists/task_order.dart';
import 'package:vikunja_logic/src/time/calendar_date.dart';

enum GanttBarKind {
  /// A start and an end or due date.
  scheduled,

  /// A start only: seven days, fading out to the right.
  startOnly,

  /// An end or due date only: seven or eight days ending there, fading in
  /// from the left.
  endOnly,

  /// No dates (shown with "tasks without dates" only): today through
  /// today + 7, drawn neutral and dashed.
  estimated,
}

/// A bar in whole calendar days.
@immutable
final class GanttBar {
  const new({
    required this.kind,
    required this.first,
    required this.days,
    required this.column,
    this.derived = false,
  });

  final GanttBarKind kind;

  /// The dates come from the subtasks of a parent without dates of its
  /// own; drawn dashed.
  final bool derived;

  /// The first day the bar covers.
  final CalendarDate first;

  /// At least 1.
  final int days;

  /// [first]'s day column: 0 is the range's first day, negative before it.
  final int column;

  CalendarDate get last => first.addDays(days - 1);

  /// The column after the bar's last day.
  int get endColumn => column + days;

  @override
  bool operator ==(Object other) =>
      other is GanttBar &&
      other.kind == kind &&
      other.derived == derived &&
      other.first == first &&
      other.days == days &&
      other.column == column;

  @override
  int get hashCode => Object.hash(kind, derived, first, days, column);

  @override
  String toString() =>
      'GanttBar(${kind.name}${derived ? ', derived' : ''}, $first, '
      '$days days, column $column)';
}

@immutable
final class GanttRow {
  const new({
    required this.task,
    required this.bar,
    this.indent = 0,
    this.parent,
    this.isParent = false,
    this.canCollapse = false,
    this.collapsed = false,
  });

  final Task task;
  final GanttBar bar;

  /// The depth in the tree, at most 4.
  final int indent;

  /// The task this row sits under; null for a top-level row.
  final Task? parent;

  /// Has subtasks among the timeline's tasks (shown or not): drawn with
  /// end markers, as the web does.
  final bool isParent;

  /// Has a subtask row that shows when it is expanded.
  final bool canCollapse;
  final bool collapsed;
}

/// What a timeline shows: the rows in order (tasks hidden by a collapsed
/// parent or outside the range left out) and the relation arrows between
/// them.
@immutable
final class GanttLayout {
  new({
    required this.range,
    required this.today,
    this.rows = const [],
    this.arrows = const [],
  });

  final GanttRange range;
  final CalendarDate today;
  final List<GanttRow> rows;
  final List<GanttArrow> arrows;

  late final Map<int, int> _rowIndexes = {
    for (final (index, row) in rows.indexed) row.task.id: index,
  };

  int get dayCount => range.dayCount;

  bool get isEmpty => rows.isEmpty;

  /// Null when today is outside the range.
  int? get todayColumn =>
      range.contains(today) ? today.daysSince(range.from) : null;

  /// The index in [rows] of the task's row, null when it is not shown.
  int? rowOf(int taskId) => _rowIndexes[taskId];

  /// For each row, the bands of the groups it is in, outermost first, as
  /// `(column, endColumn)`: a parent and the deeper rows right below it, as
  /// wide as all their bars (the web's group bands).
  late final List<List<(int, int)>> groupSpans = () {
    final spans = [for (final _ in rows) <(int, int)>[]];
    for (var i = 0; i < rows.length; i++) {
      var end = i;
      var first = rows[i].bar.column;
      var last = rows[i].bar.endColumn;
      while (end + 1 < rows.length && rows[end + 1].indent > rows[i].indent) {
        end++;
        first = min(first, rows[end].bar.column);
        last = max(last, rows[end].bar.endColumn);
      }
      if (end == i) continue;
      for (var k = i; k <= end; k++) {
        spans[k].add((first, last));
      }
    }
    return spans;
  }();
}

/// The web's Gantt chart as a read-only model, in calendar days of [zone]
/// (the device's).
///
/// [matching] are the tasks the Gantt filter matched; every descendant of
/// them in [tasksById] joins them, in any project. Top-level rows are the
/// tasks without a parent among those, by start date (missing last), open
/// before done, then newest first; each is followed by its subtasks in
/// relation order, depth first, each task once (under its first parent),
/// indented up to 4 levels. A parent without dates takes the earliest start
/// and the latest end (else due date) of its descendants.
///
/// Bars: start and end (else due) rounded to their days, an end before
/// noon ending the bar at the start of its day; a start alone runs 7 days;
/// an end alone starts 7 days before its day; a task without any date
/// runs from [today] through today + 7 and shows only with
/// [showTasksWithoutDates]. A bar is at least one day wide. A row is left
/// out when its bar starts after the range or ends before its first day,
/// and when a shown parent in [collapsed] hides it.
GanttLayout layoutGantt({
  required Iterable<Task> matching,
  required Map<int, Task> tasksById,
  required GanttRange range,
  required CalendarDate today,
  required Location zone,
  bool showTasksWithoutDates = false,
  Set<int> collapsed = const {},
}) {
  final nodes = _treeOf(_withDescendants(matching, tasksById));
  final byId = {for (final node in nodes) node.task.id: node};
  for (final node in nodes) {
    final bar = _barOf(node, byId, range: range, today: today, zone: zone);
    node
      ..bar = bar.bar
      ..passesDates =
          (bar.hasDates || showTasksWithoutDates) &&
          !bar.bar.first.isAfter(range.to) &&
          !bar.endDay.isBefore(range.from);
    // A parent outside the range cannot be expanded, so it hides nothing.
    final parent = node.parent;
    if (parent != null) {
      node.hiddenUnder =
          parent.hiddenUnder ??
          (parent.passesDates && collapsed.contains(parent.task.id)
              ? parent
              : null);
    }
  }
  for (final node in nodes.reversed) {
    if (node.passesDates || node.hasShownDescendant) {
      node.parent?.hasShownDescendant = true;
    }
  }

  final rows = <GanttRow>[];
  final anchors = <int, GanttAnchor>{};
  final hiddenToAncestor = <int, int>{};
  for (final node in nodes) {
    if (node.hiddenUnder case final ancestor?) {
      hiddenToAncestor[node.task.id] = ancestor.task.id;
      continue;
    }
    if (!node.passesDates) continue;
    final bar = node.bar;
    anchors[node.task.id] = GanttAnchor(
      row: rows.length,
      start: bar.column,
      end: bar.endColumn,
    );
    rows.add(
      GanttRow(
        task: node.task,
        bar: bar,
        indent: min(node.depth, _maxIndent),
        parent: node.parent?.task,
        isParent: node.childIds.isNotEmpty,
        canCollapse: node.hasShownDescendant,
        collapsed: collapsed.contains(node.task.id),
      ),
    );
  }
  return GanttLayout(
    range: range,
    today: today,
    rows: List.unmodifiable(rows),
    arrows: ganttArrows(
      tasks: [for (final node in nodes) node.task],
      anchors: anchors,
      hiddenToAncestor: hiddenToAncestor,
    ),
  );
}

const _maxIndent = 4;
const _openEndDays = 7;

final class _Node {
  new(this.task, this.depth, this.parent, this.childIds);

  final Task task;
  final int depth;
  final _Node? parent;

  /// The subtasks among the timeline's tasks, in relation order, whether
  /// or not they sit under this row.
  final List<int> childIds;

  late GanttBar bar;
  bool passesDates = false;
  bool hasShownDescendant = false;

  /// The outermost collapsed ancestor.
  _Node? hiddenUnder;
}

/// [matching] and every task below them in [tasksById], each once.
Map<int, Task> _withDescendants(
  Iterable<Task> matching,
  Map<int, Task> tasksById,
) {
  final tasks = {for (final task in matching) task.id: task};
  final pending = [...tasks.values];
  while (pending.isNotEmpty) {
    for (final subtask in pending.removeLast().subtasks) {
      if (tasks.containsKey(subtask.id)) continue;
      final child = tasksById[subtask.id];
      if (child == null) continue;
      tasks[child.id] = child;
      pending.add(child);
    }
  }
  return tasks;
}

/// `ganttTaskTree.ts` depth first; tasks no root reaches (a relation cycle)
/// follow as roots of their own.
List<_Node> _treeOf(Map<int, Task> tasks) {
  List<int> childIdsOf(Task task) => [
    for (final subtask in task.subtasks)
      if (tasks.containsKey(subtask.id)) subtask.id,
  ];
  final roots = [
    for (final task in tasks.values)
      if (!task.parentTasks.any((parent) => tasks.containsKey(parent.id))) task,
  ]..sort(_compareRoots);
  final unreached = [...tasks.values]..sort(_compareRoots);

  final nodes = <_Node>[];
  final placed = <int>{};
  final pending = <(Task, int, _Node?)>[];
  for (final start in [...roots, ...unreached]) {
    pending.add((start, 0, null));
    while (pending.isNotEmpty) {
      final (task, depth, parent) = pending.removeLast();
      if (!placed.add(task.id)) continue;
      final node = _Node(task, depth, parent, childIdsOf(task));
      nodes.add(node);
      for (final childId in node.childIds.reversed) {
        pending.add((tasks[childId]!, depth + 1, node));
      }
    }
  }
  return nodes;
}

/// The web's request order: start date ascending with tasks without one
/// last, open before done, newest first.
int _compareRoots(Task a, Task b) {
  final byStart = compareNullsLast(a.startDate, b.startDate, descending: false);
  if (byStart != 0) return byStart;
  if (a.done != b.done) return a.done ? 1 : -1;
  return compareNewestFirst(a, b);
}

typedef _PlacedBar = ({GanttBar bar, CalendarDate endDay, bool hasDates});

/// `endDay` is the day the bar's end falls on, at its start or its end:
/// a bar that ends at midnight of the range's first day still counts as
/// reaching it, as on the web.
_PlacedBar _barOf(
  _Node node,
  Map<int, _Node> byId, {
  required GanttRange range,
  required CalendarDate today,
  required Location zone,
}) {
  final task = node.task;
  final ownEnd = task.endDate ?? task.dueDate;
  final derived =
      node.childIds.isNotEmpty && task.startDate == null && ownEnd == null
      ? _childDates(node, byId)
      : null;
  final start = task.startDate ?? derived?.start;
  final end = ownEnd ?? derived?.end;

  _PlacedBar placed(
    GanttBarKind kind,
    CalendarDate first,
    int days,
    CalendarDate endDay,
  ) => (
    bar: GanttBar(
      kind: kind,
      first: first,
      days: max(1, days),
      column: first.daysSince(range.from),
      derived: derived != null && (start != null || end != null),
    ),
    endDay: endDay,
    hasDates: start != null || end != null,
  );

  if (start == null && end == null) {
    return placed(
      GanttBarKind.estimated,
      today,
      _openEndDays + 1,
      today.addDays(_openEndDays),
    );
  }
  if (end == null) {
    final first = CalendarDate.inZone(start!, zone);
    return placed(
      GanttBarKind.startOnly,
      first,
      _openEndDays,
      first.addDays(_openEndDays),
    );
  }
  final (endDay, pastNoon) = _roundedEnd(end, zone);
  final afterEnd = pastNoon ? endDay.addDays(1) : endDay;
  if (start == null) {
    final first = endDay.addDays(-_openEndDays);
    return placed(
      GanttBarKind.endOnly,
      first,
      afterEnd.daysSince(first),
      endDay,
    );
  }
  final first = CalendarDate.inZone(start, zone);
  return placed(
    GanttBarKind.scheduled,
    first,
    afterEnd.daysSince(first),
    endDay,
  );
}

/// The day of [end] and whether the bar covers it: an end before noon
/// ends the bar at the start of its day (`roundToNaturalDayBoundary`).
(CalendarDate, bool) _roundedEnd(DateTime end, Location zone) {
  final local = TZDateTime.from(end, zone);
  return (CalendarDate.of(local), local.hour >= 12);
}

/// The earliest start and the latest end (else due date) among the
/// descendants of [node] in the timeline, `collectChildDates`.
({DateTime? start, DateTime? end}) _childDates(
  _Node node,
  Map<int, _Node> byId,
) {
  DateTime? start;
  DateTime? end;
  final seen = <int>{node.task.id};
  final pending = [...node.childIds];
  while (pending.isNotEmpty) {
    final child = byId[pending.removeLast()];
    if (child == null || !seen.add(child.task.id)) continue;
    final task = child.task;
    if (task.startDate case final childStart?
        when start == null || childStart.isBefore(start)) {
      start = childStart;
    }
    if (task.endDate ?? task.dueDate case final childEnd?
        when end == null || childEnd.isAfter(end)) {
      end = childEnd;
    }
    pending.addAll(child.childIds);
  }
  return (start: start, end: end);
}
