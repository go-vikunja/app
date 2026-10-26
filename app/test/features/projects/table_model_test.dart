import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/application/table_model.dart';

import '../../helpers/sample_data.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  final tasks = [
    sampleTask(id: 1, title: 'Parent', subtaskIds: [2]),
    sampleTask(id: 2, title: 'Child', parentIds: [1]),
    sampleTask(id: 3, title: 'Done', done: true, doneAt: now),
    sampleTask(id: 4, title: 'Four'),
  ];
  final byId = {for (final task in tasks) task.id: task};

  int byNumber(Task a, Task b) =>
      compareTasksForTable(a, b, TableSort.defaultSort);

  List<int> ids(List<Task> rows) => [for (final task in rows) task.id];

  List<Task> rowsOf(
    ProjectListSource source,
    ViewFilterKind kind, {
    bool showDone = false,
    Map<int, Task> leaving = const {},
  }) => buildTableRows(
    source,
    kind: kind,
    showDone: showDone,
    compare: byNumber,
    leaving: leaving,
  );

  final source = ProjectListSource(projectTasks: tasks, tasksById: byId);

  test('every task flat, subtasks and done ones among the others', () {
    expect(ids(rowsOf(source, ViewFilterKind.none)), [4, 3, 2, 1]);
  });

  test('open tasks, or all of them with show done; done ones alone', () {
    expect(ids(rowsOf(source, ViewFilterKind.openOnly)), [4, 2, 1]);
    expect(ids(rowsOf(source, ViewFilterKind.openOnly, showDone: true)), [
      4,
      3,
      2,
      1,
    ]);
    expect(ids(rowsOf(source, ViewFilterKind.doneOnly)), [3]);
  });

  test("another filter's matches, or the tasks of the view's last download "
      'where the device cannot evaluate it, in the table sort', () {
    final matching = ProjectListSource(
      projectTasks: tasks,
      tasksById: byId,
      matchingIds: const {1, 3},
    );
    expect(ids(rowsOf(matching, ViewFilterKind.other)), [3, 1]);

    final downloaded = ProjectListSource(
      projectTasks: tasks,
      tasksById: byId,
      snapshot: const ListSnapshot(positions: {2: 1, 4: 2, 99: 3}),
    );
    expect(ids(rowsOf(downloaded, ViewFilterKind.other)), [4, 2]);
  });

  test('a task marked done here stays where it was while its Undo is '
      'offered, standing in where the source has dropped it', () {
    final copy = byId[4]!.copyWith(done: true, doneAt: now);
    final withoutIt = ProjectListSource(
      projectTasks: [
        for (final task in tasks)
          if (task.id != 4) task,
      ],
      tasksById: {...byId}..remove(4),
    );

    final rows = rowsOf(withoutIt, ViewFilterKind.openOnly, leaving: {4: copy});
    expect(ids(rows), [4, 2, 1]);
    expect(rows.first.done, isTrue);

    final byDone = buildTableRows(
      ProjectListSource(
        projectTasks: [...tasks.where((task) => task.id != 4), copy],
        tasksById: {...byId, 4: copy},
      ),
      kind: ViewFilterKind.none,
      showDone: false,
      compare: (a, b) => compareTasksForTable(
        a,
        b,
        const TableSort(TableSortField.done, descending: false),
      ),
      leaving: {4: copy},
    );
    expect(ids(byDone), [4, 2, 1, 3]);
  });
}
