import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

CalendarDate date(String text) => CalendarDate.tryParse(text)!;

GanttRange range(String from, String to) =>
    GanttRange(from: date(from), to: date(to));

/// [task] with these relations added, carrying only the related ids like
/// the nested tasks the server embeds.
Task related(
  Task task, {
  List<int> blocking = const [],
  List<int> blocked = const [],
  List<int> precedes = const [],
  List<int> follows = const [],
}) => task.copyWith(
  relatedTasks: {
    ...task.relatedTasks,
    if (blocking.isNotEmpty) TaskRelationKind.blocking: _stubs(blocking),
    if (blocked.isNotEmpty) TaskRelationKind.blocked: _stubs(blocked),
    if (precedes.isNotEmpty) TaskRelationKind.precedes: _stubs(precedes),
    if (follows.isNotEmpty) TaskRelationKind.follows: _stubs(follows),
  },
);

List<Task> _stubs(List<int> ids) => [
  for (final id in ids) Task(id: id, title: 'Task $id', projectId: 1),
];

/// Every task matches and every task can be looked up, as when the filter
/// matched them all.
GanttLayout layoutAll(
  List<Task> tasks, {
  required GanttRange range,
  tz.Location? zone,
  CalendarDate? today,
  bool showTasksWithoutDates = false,
  Set<int> collapsed = const {},
}) => layoutGantt(
  matching: tasks,
  tasksById: {for (final task in tasks) task.id: task},
  range: range,
  today: today ?? range.from,
  zone: zone ?? tz.UTC,
  showTasksWithoutDates: showTasksWithoutDates,
  collapsed: collapsed,
);

List<int> rowIds(GanttLayout layout) => [
  for (final row in layout.rows) row.task.id,
];
