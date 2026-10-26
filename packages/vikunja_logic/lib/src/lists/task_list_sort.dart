import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/src/lists/task_order.dart';

/// The single-key sort of the web's List view (`SortPopup.vue`), "Manually"
/// first and the rest in the web's value order.
enum TaskListSort {
  manual('position', descending: false),
  titleAsc('title', descending: false),
  titleDesc('title', descending: true),
  priorityDesc('priority', descending: true),
  priorityAsc('priority', descending: false),
  dueDateAsc('due_date', descending: false),
  dueDateDesc('due_date', descending: true),
  startDateAsc('start_date', descending: false),
  startDateDesc('start_date', descending: true),
  endDateAsc('end_date', descending: false),
  endDateDesc('end_date', descending: true),
  percentDoneDesc('percent_done', descending: true),
  percentDoneAsc('percent_done', descending: false),
  createdDesc('created', descending: true),
  createdAsc('created', descending: false),
  updatedDesc('updated', descending: true),
  updatedAsc('updated', descending: false);

  new(this.field, {required this.descending});

  final String field;
  final bool descending;

  /// The web's URL form, e.g. `due_date:asc`.
  String get wireName => '$field:${descending ? 'desc' : 'asc'}';

  static TaskListSort fromWireName(String? wireName) =>
      values.where((sort) => sort.wireName == wireName).firstOrNull ?? manual;
}

/// Orders the top-level rows of a list. A missing value sorts last in both
/// directions, as on the server; titles compare case-insensitively first,
/// and a task never sent has its creation as its last update. Ties, and
/// [TaskListSort.manual] itself, fall back to the manual order: tasks
/// without an entry in [positions] first (newest first, a temporary id
/// before every server id: the server puts new tasks on top), then by
/// position, then by id. With [separateDone], for a list whose done tasks
/// show in a done part of their own, the done tasks come after the open
/// ones and among themselves by done-at, newest first, then newest first;
/// without it (the server's positions place the done tasks of the list
/// too) done and open tasks share the manual order.
int compareTasksForList(
  Task a,
  Task b,
  TaskListSort sort, {
  Map<int, double> positions = const {},
  bool separateDone = true,
}) {
  final byKey = _compareByKey(a, b, sort);
  return byKey != 0
      ? byKey
      : _compareManually(a, b, positions, separateDone: separateDone);
}

// The server stores an unset priority and no progress as 0, not as null, so
// those sort as values.
int _compareByKey(Task a, Task b, TaskListSort sort) => switch (sort) {
  TaskListSort.manual => 0,
  TaskListSort.titleAsc ||
  TaskListSort.titleDesc => _directed(sort, compareTitles(a.title, b.title)),
  TaskListSort.priorityDesc || TaskListSort.priorityAsc => _directed(
    sort,
    a.priority.value.compareTo(b.priority.value),
  ),
  TaskListSort.dueDateAsc ||
  TaskListSort.dueDateDesc => _nullsLast(sort, a.dueDate, b.dueDate),
  TaskListSort.startDateAsc ||
  TaskListSort.startDateDesc => _nullsLast(sort, a.startDate, b.startDate),
  TaskListSort.endDateAsc ||
  TaskListSort.endDateDesc => _nullsLast(sort, a.endDate, b.endDate),
  TaskListSort.percentDoneDesc || TaskListSort.percentDoneAsc => _directed(
    sort,
    a.percentDone.compareTo(b.percentDone),
  ),
  TaskListSort.createdDesc ||
  TaskListSort.createdAsc => _nullsLast(sort, a.created, b.created),
  TaskListSort.updatedDesc || TaskListSort.updatedAsc => _nullsLast(
    sort,
    a.updated ?? a.created,
    b.updated ?? b.created,
  ),
};

int _directed(TaskListSort sort, int order) => sort.descending ? -order : order;

int _nullsLast(TaskListSort sort, DateTime? a, DateTime? b) =>
    compareNullsLast(a, b, descending: sort.descending);

int _compareManually(
  Task a,
  Task b,
  Map<int, double> positions, {
  required bool separateDone,
}) {
  if (separateDone) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (a.done) {
      final byDoneAt = compareNullsLast(a.doneAt, b.doneAt, descending: true);
      return byDoneAt != 0 ? byDoneAt : compareNewestFirst(a, b);
    }
  }
  return switch ((positions[a.id], positions[b.id])) {
    (null, null) => compareNewestFirst(a, b),
    (null, _) => -1,
    (_, null) => 1,
    (final double aPosition, final double bPosition) =>
      aPosition != bPosition
          ? aPosition.compareTo(bPosition)
          : a.id.compareTo(b.id),
  };
}
