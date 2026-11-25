import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';
import 'package:vikunja_mobile/features/projects/application/project_rows.dart';
import 'package:vikunja_mobile/features/projects/application/table_model.dart';

import '../../helpers/sample_data.dart';

void main() {
  final tasks = [
    sampleTask(id: 1, title: 'Alpha'),
    sampleTask(id: 2, title: 'Bravo', done: true),
    sampleTask(id: 3, title: 'Charlie'),
  ];
  ProjectListSource sourceOf(List<Task> tasks) => ProjectListSource(
    projectTasks: tasks,
    tasksById: {for (final task in tasks) task.id: task},
    snapshot: const ListSnapshot(positions: {1: 30, 2: 20, 3: 10}),
  );
  const byTitle = TableSort(TableSortField.title, descending: false);

  group('the list model', () {
    late ProjectRows rows;
    final source = sourceOf(tasks);
    ProjectListModel model({
      ProjectListSource? from,
      ViewPreferences preferences = const ViewPreferences(),
      Map<int, Task> leaving = const {},
    }) => rows.listModel(
      from ?? source,
      kind: ViewFilterKind.openOnly,
      preferences: preferences,
      leaving: leaving,
    );

    setUp(() => rows = ProjectRows());

    test('is the one built before while nothing it is built from changed, '
        'the copies kept for an Undo compared by content', () {
      final first = model(leaving: {2: tasks[1]});

      expect(model(leaving: Map.unmodifiable({2: tasks[1]})), same(first));
    });

    test('is what buildProjectListModel builds', () {
      final built = buildProjectListModel(
        source,
        kind: ViewFilterKind.openOnly,
        preferences: const ViewPreferences(),
      );

      expect(
        [for (final row in model().rows) row.task.id],
        [for (final row in built.rows) row.task.id],
      );
    });

    test('is built again when any one thing it is built from changed', () {
      for (final (label, variant) in [
        ('tasks', () => model(from: sourceOf(tasks))),
        (
          'filter kind',
          () => rows.listModel(
            source,
            kind: ViewFilterKind.none,
            preferences: const ViewPreferences(),
          ),
        ),
        (
          'sort',
          () => model(
            preferences: const ViewPreferences(sort: TaskListSort.titleAsc),
          ),
        ),
        (
          'done toggle',
          () => model(preferences: const ViewPreferences(showDone: true)),
        ),
        ('copies', () => model(leaving: {2: tasks[1]})),
      ]) {
        rows = ProjectRows();
        final base = model();
        expect(variant(), isNot(same(base)), reason: label);
      }
    });
  });

  group('the table rows', () {
    late ProjectRows rows;
    final source = sourceOf(tasks);
    List<Task> table({
      ProjectListSource? from,
      bool showDone = false,
      TableSort sort = byTitle,
      Map<int, Task> leaving = const {},
    }) => rows.tableRows(
      from ?? source,
      kind: ViewFilterKind.openOnly,
      showDone: showDone,
      sort: sort,
      leaving: leaving,
    );

    setUp(() => rows = ProjectRows());

    test('are the ones built before while nothing they are built from '
        'changed', () {
      final first = table(leaving: {2: tasks[1]});

      expect(table(leaving: {2: tasks[1]}), same(first));
      expect(
        first,
        buildTableRows(
          source,
          kind: ViewFilterKind.openOnly,
          showDone: false,
          compare: (a, b) => compareTasksForTable(a, b, byTitle),
          leaving: {2: tasks[1]},
        ),
      );
    });

    test('are built again when any one thing they are built from '
        'changed', () {
      for (final (label, variant) in [
        ('tasks', () => table(from: sourceOf(tasks))),
        (
          'filter kind',
          () => rows.tableRows(
            source,
            kind: ViewFilterKind.none,
            showDone: false,
            sort: byTitle,
          ),
        ),
        (
          'sort',
          () => table(
            sort: const TableSort(TableSortField.title, descending: true),
          ),
        ),
        ('done toggle', () => table(showDone: true)),
        ('copies', () => table(leaving: {2: tasks[1]})),
      ]) {
        rows = ProjectRows();
        final base = table();
        expect(variant(), isNot(same(base)), reason: label);
      }
    });
  });
}
