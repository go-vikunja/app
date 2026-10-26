import 'package:meta/meta.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/src/lists/task_order.dart';

/// The columns the web's Table view sorts by, in its order; [wireName] is
/// the server's sort field.
enum TableSortField {
  taskIndex('index'),
  done('done'),
  title('title'),
  priority('priority'),
  dueDate('due_date'),
  startDate('start_date'),
  endDate('end_date'),
  percentDone('percent_done'),
  doneAt('done_at'),
  created('created'),
  updated('updated');

  new(this.wireName);

  final String wireName;

  static TableSortField? fromWire(String? name) =>
      values.where((field) => field.wireName == name).firstOrNull;
}

/// One sort key of a Table view.
@immutable
final class TableSort {
  const new(this.field, {required this.descending});

  /// [defaultSort] for anything that is not a [wireName].
  factory fromWireName(String? wireName) {
    if (wireName?.split(':') case [final name, final direction]
        when direction == 'asc' || direction == 'desc') {
      if (TableSortField.fromWire(name) case final field?) {
        return TableSort(field, descending: direction == 'desc');
      }
    }
    return defaultSort;
  }

  /// The web's default: the highest task number first.
  static const TableSort defaultSort = TableSort(
    TableSortField.taskIndex,
    descending: true,
  );

  final TableSortField field;
  final bool descending;

  /// The web's URL form, e.g. `due_date:asc`.
  String get wireName => '${field.wireName}:${descending ? 'desc' : 'asc'}';

  bool get isDefault => this == defaultSort;

  /// What a table showing [columns] sorts by: the web leaves a sort on a
  /// hidden column out of its request, so [defaultSort] stands in until
  /// the column shows again.
  TableSort forColumns(Set<TableColumn> columns) =>
      columns.any((column) => column.sortField == field) ? this : defaultSort;

  @override
  bool operator ==(Object other) =>
      other is TableSort &&
      other.field == field &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(field, descending);

  @override
  String toString() => 'TableSort($wireName)';
}

/// The web table's 16 columns in its chooser's order; [wireName] is the
/// key of its `tableViewColumns` storage.
enum TableColumn {
  taskIndex('index', TableSortField.taskIndex),
  done('done', TableSortField.done),
  project('project'),
  title('title', TableSortField.title),
  priority('priority', TableSortField.priority),
  labels('labels'),
  assignees('assignees'),
  commentCount('commentCount'),
  dueDate('dueDate', TableSortField.dueDate),
  startDate('startDate', TableSortField.startDate),
  endDate('endDate', TableSortField.endDate),
  percentDone('percentDone', TableSortField.percentDone),
  doneAt('doneAt', TableSortField.doneAt),
  created('created', TableSortField.created),
  updated('updated', TableSortField.updated),
  createdBy('createdBy');

  new(this.wireName, [this.sortField]);

  final String wireName;

  /// Null for a column the table cannot sort by.
  final TableSortField? sortField;

  /// The web's six default columns.
  static const Set<TableColumn> defaults = {
    taskIndex,
    done,
    title,
    labels,
    assignees,
    dueDate,
  };

  static TableColumn? fromWire(String? name) =>
      values.where((column) => column.wireName == name).firstOrNull;
}

/// The order of the web's Table view as the server sorts it: the key
/// first, a missing value last in both directions, priority and progress
/// 0 as values, open before done, no done-at for an open task (the server
/// clears it) nor for one created done, a task created here numbered after
/// every server task (it gets the project's next index when it is sent).
/// The server breaks ties by the view's positions, which the app does not
/// download for table views: newest first stands in for them, which is
/// their order in a table view created with its project. Titles compare
/// ignoring case first, unlike SQLite's byte order.
int compareTasksForTable(Task a, Task b, TableSort sort) {
  final byKey = _compareByField(a, b, sort);
  return byKey != 0 ? byKey : compareNewestFirst(a, b);
}

int _compareByField(Task a, Task b, TableSort sort) {
  int directed(int order) => sort.descending ? -order : order;
  int nullsLast(DateTime? x, DateTime? y) =>
      compareNullsLast(x, y, descending: sort.descending);
  return switch (sort.field) {
    TableSortField.taskIndex => directed(_compareIndexes(a, b)),
    TableSortField.done => directed(_compareDone(a.done, b.done)),
    TableSortField.title => directed(compareTitles(a.title, b.title)),
    TableSortField.priority => directed(
      a.priority.value.compareTo(b.priority.value),
    ),
    TableSortField.dueDate => nullsLast(a.dueDate, b.dueDate),
    TableSortField.startDate => nullsLast(a.startDate, b.startDate),
    TableSortField.endDate => nullsLast(a.endDate, b.endDate),
    TableSortField.percentDone => directed(
      a.percentDone.compareTo(b.percentDone),
    ),
    TableSortField.doneAt => nullsLast(_doneAt(a), _doneAt(b)),
    TableSortField.created => nullsLast(a.created, b.created),
    TableSortField.updated => nullsLast(
      a.updated ?? a.created,
      b.updated ?? b.created,
    ),
  };
}

// A temporary id is negative, the newer the lower.
int _compareIndexes(Task a, Task b) {
  final aIsLocal = a.id < 0;
  if (aIsLocal != b.id < 0) return aIsLocal ? 1 : -1;
  return aIsLocal ? b.id.compareTo(a.id) : a.index.compareTo(b.index);
}

int _compareDone(bool a, bool b) => a == b ? 0 : (a ? 1 : -1);

DateTime? _doneAt(Task task) => task.done ? task.doneAt : null;
