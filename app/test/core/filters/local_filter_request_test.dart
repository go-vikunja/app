import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/filters/filter_zone.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';

/// A request's filter (a timeline's range) meeting a view's or a saved
/// filter's own, as the server's tasks endpoint combines them
/// (`task_collection.go`), with the server's own vectors GO1 and GO2.
void main() {
  setUpAll(ensureTimeZones);

  final now = DateTime.utc(2026, 10, 26, 12);
  const user1 = 'user1';
  final dated = FilterableTask(
    id: 1,
    projectId: 7,
    title: 'dated',
    startDate: DateTime.utc(2020, 6),
    endDate: DateTime.utc(2020, 6, 10),
    assigneeUsernames: const {user1},
  );
  const dateless = FilterableTask(
    id: 2,
    projectId: 7,
    title: 'dateless',
    assigneeUsernames: {user1},
  );
  const datelessUnassigned = FilterableTask(
    id: 3,
    projectId: 7,
    title: 'dateless unassigned',
  );
  final doneDated = FilterableTask(
    id: 4,
    projectId: 7,
    title: 'done dated report',
    done: true,
    startDate: DateTime.utc(2020, 6, 2),
    endDate: DateTime.utc(2020, 6, 3),
  );
  final all = [dated, dateless, datelessUnassigned, doneDated];

  const window = ViewFilter(
    filter:
        "(start_date >= '2020-01-01T00:00:00' && "
        "start_date <= '2020-12-31T00:00:00') || "
        "(end_date >= '2020-01-01T00:00:00' && "
        "end_date <= '2020-12-31T00:00:00')",
  );
  const windowWithNulls = ViewFilter(
    filter:
        "(start_date >= '2020-01-01T00:00:00' && "
        "start_date <= '2020-12-31T00:00:00') || "
        "(end_date >= '2020-01-01T00:00:00' && "
        "end_date <= '2020-12-31T00:00:00')",
    includeNulls: true,
  );

  Set<String> titles(LocalFilter? filter) => {
    for (final task in all)
      if (filter!.matches(task)) task.title,
  };

  LocalFilter? combine(
    ViewFilter? own,
    ViewFilter request, {
    bool savedFilter = false,
  }) => LocalFilter.compileWithRequest(
    own,
    request,
    location: tz.UTC,
    now: now,
    savedFilter: savedFilter,
  );

  group('a project view', () {
    test('without a filter of its own evaluates the request alone', () {
      expect(titles(combine(null, window)), {'dated', 'done dated report'});
      expect(titles(combine(const ViewFilter(), window)), {
        'dated',
        'done dated report',
      });
    });

    test('ANDs its filter with the request', () {
      expect(
        titles(combine(const ViewFilter(filter: 'done = false'), window)),
        {'dated'},
      );
    });

    test('turns include-nulls on for the whole when either asks, its own '
        'conditions included (a task without assignees matches)', () {
      const everyTask = {
        'dated',
        'dateless',
        'dateless unassigned',
        'done dated report',
      };
      const assigned = ViewFilter(filter: 'assignees in $user1');
      expect(titles(combine(assigned, window)), {'dated'});
      expect(titles(combine(assigned, windowWithNulls)), everyTask);
      expect(
        titles(
          combine(
            const ViewFilter(filter: 'assignees in $user1', includeNulls: true),
            window,
          ),
        ),
        everyTask,
      );
    });

    test('applies its search', () {
      expect(titles(combine(const ViewFilter(search: 'report'), window)), {
        'done dated report',
      });
    });

    test('a request without a filter leaves the view as it is', () {
      expect(
        titles(
          combine(
            const ViewFilter(filter: 'done = true'),
            const ViewFilter(includeNulls: true),
          ),
        ),
        {'done dated report'},
      );
    });

    test('a filter the engine refuses, on either side, cannot be evaluated '
        'here', () {
      expect(
        combine(const ViewFilter(filter: 'priority = abc'), window),
        isNull,
      );
      expect(
        combine(const ViewFilter(filter: 'bucket_id = 3'), window),
        isNull,
      );
      expect(combine(null, const ViewFilter(filter: 'start_date >')), isNull);
    });

    test('only open tasks can match when either side says so', () {
      expect(
        combine(
          const ViewFilter(filter: 'done = false'),
          window,
        )!.onlyOpenTasks,
        isTrue,
      );
      expect(combine(null, window)!.onlyOpenTasks, isFalse);
    });
  });

  group('a saved filter', () {
    test('GO2: include-nulls asked by the request applies to the request '
        "alone, not to the saved filter's own conditions", () {
      const own = ViewFilter(filter: 'done = false && assignees in $user1');

      expect(titles(combine(own, windowWithNulls, savedFilter: true)), {
        'dated',
        'dateless',
      });
    });

    test('with its own include-nulls on, the whole has it', () {
      const own = ViewFilter(
        filter: 'done = false && assignees in $user1',
        includeNulls: true,
      );

      expect(titles(combine(own, windowWithNulls, savedFilter: true)), {
        'dated',
        'dateless',
        'dateless unassigned',
      });
    });

    test('without include-nulls anywhere the texts are ANDed', () {
      const own = ViewFilter(filter: 'done = false && assignees in $user1');

      expect(titles(combine(own, window, savedFilter: true)), {'dated'});
    });

    test('without a filter of its own takes the request with either '
        "side's include-nulls", () {
      expect(
        titles(
          combine(
            const ViewFilter(includeNulls: true),
            window,
            savedFilter: true,
          ),
        ),
        {'dated', 'dateless', 'dateless unassigned', 'done dated report'},
      );
    });

    test('refused on either side cannot be evaluated here', () {
      expect(
        combine(
          const ViewFilter(filter: 'priority = abc'),
          windowWithNulls,
          savedFilter: true,
        ),
        isNull,
      );
    });
  });

  test('GO1: a dateless parent does not match the window, its dated child '
      'does', () {
    final filter = LocalFilter.compile(
      const ViewFilter(
        filter:
            "(start_date >= '2020-01-01T00:00:00' && "
            "start_date <= '2020-12-31T00:00:00') || "
            "(end_date >= '2020-01-01T00:00:00' && "
            "end_date <= '2020-12-31T00:00:00') || "
            "(due_date >= '2020-01-01T00:00:00' && "
            "due_date <= '2020-12-31T00:00:00')",
      ),
      location: tz.UTC,
      now: now,
    )!;

    expect(filter.matches(const FilterableTask(id: 1, projectId: 7)), isFalse);
    expect(
      filter.matches(
        FilterableTask(
          id: 2,
          projectId: 7,
          startDate: DateTime.utc(2020, 6),
          endDate: DateTime.utc(2020, 6, 10),
          dueDate: DateTime.utc(2020, 6, 5),
        ),
      ),
      isTrue,
    );
  });

  test('a view refuses what only the server can evaluate', () {
    expect(refusesViewFilter(null), isFalse);
    expect(refusesViewFilter(const ViewFilter()), isFalse);
    expect(
      refusesViewFilter(const ViewFilter(filter: 'done = false')),
      isFalse,
    );
    expect(refusesViewFilter(const ViewFilter(search: 'x')), isFalse);
    expect(
      refusesViewFilter(const ViewFilter(filter: 'due_date < now/d+1d')),
      isFalse,
    );
    expect(
      refusesViewFilter(const ViewFilter(filter: 'priority = abc')),
      isTrue,
    );
    expect(
      refusesViewFilter(const ViewFilter(filter: 'bucket_id = 1')),
      isTrue,
    );
  });

  test("the web's Gantt filter for the default range evaluates in the "
      'zone given, as midnight there', () {
    final range = defaultGanttRange(DateTime(2026, 10, 26));
    final request = ViewFilter(filter: ganttFilterText(range));
    final lateOnTheLastDay = FilterableTask(
      id: 1,
      projectId: 7,
      startDate: DateTime.utc(2026, 12, 20, 5),
    );
    for (final (zone, matches) in [
      ('UTC', false),
      ('America/Los_Angeles', true),
      ('Europe/Berlin', false),
    ]) {
      final filter = LocalFilter.compileWithRequest(
        null,
        request,
        location: locationForFilters([zone]),
        now: now,
      )!;
      expect(filter.matches(lateOnTheLastDay), matches, reason: zone);
    }
  });
}
