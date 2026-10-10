import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/read/task_query_params.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  const overview = TaskQuery(
    filter: "done = false && due_date < 'now/d+1d'",
    sort: TaskQuery.dueDateSort,
    expand: {TaskExpand.commentCount, TaskExpand.isUnread},
  );

  test('maps every field to its wire parameter in a fixed order', () {
    expect(
      taskQueryParameters(overview, version: ApiVersion.v2, inView: false),
      {
        'filter': "done = false && due_date < 'now/d+1d'",
        'sort_by': ['due_date', 'id'],
        'order_by': ['asc', 'desc'],
        'expand': ['comment_count', 'is_unread'],
        'page': 1,
      },
    );
  });

  test('a bare query sends only the page', () {
    expect(
      taskQueryParameters(
        const TaskQuery(),
        version: ApiVersion.v2,
        inView: false,
      ),
      {'page': 1},
    );
  });

  test('search is q on v2 and s on v1', () {
    const query = TaskQuery(search: 'milk', page: 2, perPage: 25);

    expect(taskQueryParameters(query, version: ApiVersion.v2, inView: false), {
      'q': 'milk',
      'page': 2,
      'per_page': 25,
    });
    expect(taskQueryParameters(query, version: ApiVersion.v1, inView: false), {
      's': 'milk',
      'page': 2,
      'per_page': 25,
    });
  });

  test('empty filter and search are omitted', () {
    expect(
      taskQueryParameters(
        const TaskQuery(filter: '', search: '', filterTimezone: ''),
        version: ApiVersion.v2,
        inView: false,
      ),
      {'page': 1},
    );
  });

  test('timezone and include-nulls are sent when set', () {
    expect(
      taskQueryParameters(
        const TaskQuery(
          filter: 'due_date < now+7d',
          filterTimezone: 'Europe/Berlin',
          includeNulls: true,
        ),
        version: ApiVersion.v2,
        inView: false,
      ),
      {
        'filter': 'due_date < now+7d',
        'filter_timezone': 'Europe/Berlin',
        'filter_include_nulls': 'true',
        'page': 1,
      },
    );
  });

  group('position sort', () {
    const query = TaskQuery(sort: TaskQuery.defaultSort);

    test('is kept through a view', () {
      expect(taskQueryParameters(query, version: ApiVersion.v2, inView: true), {
        'sort_by': ['position', 'id'],
        'order_by': ['asc', 'desc'],
        'page': 1,
      });
    });

    test('is dropped outside a view, where the server rejects it', () {
      expect(
        taskQueryParameters(query, version: ApiVersion.v2, inView: false),
        {
          'sort_by': ['id'],
          'order_by': ['desc'],
          'page': 1,
        },
      );
    });

    test('leaves no sort when it was the only one', () {
      expect(
        taskQueryParameters(
          const TaskQuery(sort: [TaskSort(TaskSortField.position)]),
          version: ApiVersion.v2,
          inView: false,
        ),
        {'page': 1},
      );
    });
  });
}
