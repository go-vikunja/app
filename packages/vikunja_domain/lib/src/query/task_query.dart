import 'package:meta/meta.dart';

enum TaskSortField {
  id('id'),
  title('title'),
  done('done'),
  doneAt('done_at'),
  dueDate('due_date'),
  startDate('start_date'),
  endDate('end_date'),
  priority('priority'),
  percentDone('percent_done'),
  projectId('project_id'),
  created('created'),
  updated('updated'),
  position('position'),
  taskIndex('index');

  new(this.wireName);

  final String wireName;
}

@immutable
final class TaskSort {
  const new(this.field, {this.descending = false});

  final TaskSortField field;
  final bool descending;
}

enum TaskExpand {
  subtasks('subtasks'),
  buckets('buckets'),
  reactions('reactions'),
  comments('comments'),
  commentCount('comment_count'),
  timeEntriesCount('time_entries_count'),
  isUnread('is_unread');

  new(this.wireName);

  final String wireName;
}

/// Parameters of a task list request. [filter] uses Vikunja's filter
/// language, e.g. `done = false && due_date < now/d+1d`; relative dates in it
/// are evaluated in [filterTimezone].
@immutable
final class TaskQuery {
  const new({
    this.filter,
    this.search,
    this.sort = const [],
    this.page = 1,
    this.perPage,
    this.expand = const {},
    this.filterTimezone,
    this.includeNulls = false,
  });

  /// The web's generic default: open order by position, newest first.
  static const defaultSort = [
    TaskSort(TaskSortField.position),
    TaskSort(TaskSortField.id, descending: true),
  ];

  /// The web's overview and upcoming screens: nearest due date first.
  static const dueDateSort = [
    TaskSort(TaskSortField.dueDate),
    TaskSort(TaskSortField.id, descending: true),
  ];

  final String? filter;
  final String? search;
  final List<TaskSort> sort;
  final int page;

  /// Null leaves the server default (`max_items_per_page`).
  final int? perPage;
  final Set<TaskExpand> expand;

  /// IANA zone name; the server zone applies when null.
  final String? filterTimezone;
  final bool includeNulls;

  TaskQuery copyWith({int? page, String? filter, Set<TaskExpand>? expand}) =>
      TaskQuery(
        filter: filter ?? this.filter,
        search: search,
        sort: sort,
        page: page ?? this.page,
        perPage: perPage,
        expand: expand ?? this.expand,
        filterTimezone: filterTimezone,
        includeNulls: includeNulls,
      );
}
