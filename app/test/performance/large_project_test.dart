import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/application/project_rows.dart';

import '../helpers/budgets.dart';
import '../helpers/sample_data.dart';

// What the rows of one project with 5,000 tasks cost on this machine, and
// that a build of the screen that changes none of what they are built
// from costs nothing. The budgets hold only with VIKUNJA_BENCHMARK=1.
void main() {
  const count = 5000;
  final monday = DateTime.utc(2026, 11, 16, 9);

  /// Every tenth task has three subtasks; a quarter are done.
  final tasks = [
    for (var id = 1; id <= count; id++)
      sampleTask(
        id: id,
        title: 'Task $id',
        done: id % 4 == 0,
        due: id % 3 == 0 ? monday.add(Duration(hours: id % 400)) : null,
        priority: TaskPriority.values[id % TaskPriority.values.length],
        subtaskIds: id % 10 == 1 && id + 3 <= count
            ? [id + 1, id + 2, id + 3]
            : const [],
        parentIds: id % 10 >= 2 && id % 10 <= 4 ? [id - id % 10 + 1] : const [],
      ),
  ];
  final source = ProjectListSource(
    projectTasks: tasks,
    tasksById: {for (final task in tasks) task.id: task},
    snapshot: ListSnapshot(
      positions: {for (final task in tasks) task.id: (count - task.id) * 10.0},
      loadedAt: monday,
    ),
  );
  const manual = ViewPreferences(showDone: true);
  const byDue = TableSort(TableSortField.dueDate, descending: false);

  int fastestOf(void Function() run) {
    run();
    var fastest = 1 << 30;
    for (var i = 0; i < 3; i++) {
      final watch = Stopwatch()..start();
      run();
      final ms = watch.elapsedMilliseconds;
      if (ms < fastest) fastest = ms;
    }
    return fastest;
  }

  test('the list and the table of 5,000 tasks', () {
    expectWithinBudget(
      fastestOf(
        () => ProjectRows().listModel(
          source,
          kind: ViewFilterKind.openOnly,
          preferences: manual,
        ),
      ),
      40,
      'List rows, sorted by hand and nested',
    );
    expectWithinBudget(
      fastestOf(
        () => ProjectRows().tableRows(
          source,
          kind: ViewFilterKind.none,
          showDone: true,
          sort: byDue,
        ),
      ),
      20,
      'Table rows, sorted by due date',
    );
  });

  test('a build that changes nothing they come from takes the rows built '
      'before', () {
    final rows = ProjectRows();
    final model = rows.listModel(
      source,
      kind: ViewFilterKind.openOnly,
      preferences: manual,
      leaving: {4: tasks[3]},
    );
    final table = rows.tableRows(
      source,
      kind: ViewFilterKind.none,
      showDone: true,
      sort: byDue,
    );
    expect(model.rows.length + model.doneRows!.length, count);
    expect(model.rows.where((row) => row.depth > 0), isNotEmpty);
    expect(table, hasLength(count));

    expectWithinBudget(
      fastestOf(() {
        expect(
          rows.listModel(
            source,
            kind: ViewFilterKind.openOnly,
            preferences: manual,
            leaving: {4: tasks[3]},
          ),
          same(model),
        );
        expect(
          rows.tableRows(
            source,
            kind: ViewFilterKind.none,
            showDone: true,
            sort: byDue,
          ),
          same(table),
        );
      }),
      2,
      'List and table rows again, nothing changed',
    );
  });
}
