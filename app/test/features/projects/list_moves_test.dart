import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/application/list_moves.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';

import '../../helpers/sample_data.dart';

void main() {
  final listView = sampleListView(id: 11, projectId: 1);

  group('listIsReorderable', () {
    test('a project list view sorted manually, the project not archived', () {
      expect(
        listIsReorderable(
          projectId: 1,
          view: listView,
          sort: TaskListSort.manual,
          archived: false,
        ),
        isTrue,
      );
    });

    test('not under another sort, in an archived project, without a list '
        'view, in a kanban view or a saved filter', () {
      bool reorderable({
        int projectId = 1,
        ProjectView? view,
        TaskListSort sort = TaskListSort.manual,
        bool archived = false,
      }) => listIsReorderable(
        projectId: projectId,
        view: view,
        sort: sort,
        archived: archived,
      );

      expect(reorderable(view: listView, sort: TaskListSort.dueDateAsc), false);
      expect(reorderable(view: listView, archived: true), isFalse);
      expect(reorderable(), isFalse);
      expect(
        reorderable(view: sampleKanbanView(id: 14, projectId: 1)),
        isFalse,
      );
      expect(reorderable(projectId: -2, view: listView), isFalse);
    });
  });

  group('listGroupsOf', () {
    final rows = [
      ProjectListRow(sampleTask(id: 1, title: 'A'), 0),
      ProjectListRow(sampleTask(id: 2, title: 'A1'), 1),
      ProjectListRow(sampleTask(id: 3, title: 'A1a'), 2),
      ProjectListRow(sampleTask(id: 4, title: 'B'), 0),
      ProjectListRow(sampleTask(id: 5, title: 'C'), 0),
      ProjectListRow(sampleTask(id: 6, title: 'C1'), 1),
    ];

    test('each top-level row takes the rows nested under it', () {
      final groups = listGroupsOf(rows, const {1: 10, 4: 20, 5: 30});

      expect(
        [
          for (final group in groups)
            [for (final row in group.rows) row.task.id],
        ],
        [
          [1, 2, 3],
          [4],
          [5, 6],
        ],
      );
      expect([for (final group in groups) group.position], [10, 20, 30]);
      expect([for (final group in groups) group.madeUp], [false, false, false]);
    });

    test('tasks without a position are spread below the first placed one, '
        'as the board places its cards', () {
      final groups = listGroupsOf(rows, const {5: 30});

      expect([for (final group in groups) group.position], [10, 20, 30]);
      expect([for (final group in groups) group.madeUp], [true, true, false]);
    });

    test('without any position they are 2^16 apart', () {
      final groups = listGroupsOf(rows, const {});

      expect(
        [for (final group in groups) group.position],
        [65536, 131072, 196608],
      );
    });
  });

  group('planListMove', () {
    List<ListGroup> groupsAt(Map<int, double> positions) => listGroupsOf([
      for (final id in positions.keys)
        ProjectListRow(sampleTask(id: id, title: '$id'), 0),
    ], positions);

    final groups = groupsAt(const {1: 100, 2: 200, 3: 300, 4: 400});

    test('between its new neighbours', () {
      expect(planListMove(groups, 1, 2), {1: 350});
      expect(planListMove(groups, 4, 1), {4: 150});
    });

    test('on top half the first position, at the end 2^16 below the last', () {
      expect(planListMove(groups, 3, 0), {3: 50});
      expect(planListMove(groups, 2, 3), {2: 400 + 65536});
    });

    test('where it is already, or for a task not listed, nothing', () {
      expect(planListMove(groups, 2, 1), isNull);
      expect(planListMove(groups, 9, 0), isNull);
    });

    test('between neighbours sharing a position, theirs when its id sorts '
        'between, else nothing', () {
      final tied = groupsAt(const {1: 100, 3: 200, 5: 200, 2: 300});

      expect(planListMove(tied, 2, 2), isNull);
      expect(planListMove(tied, 1, 1), isNull);
      final between = groupsAt(const {4: 100, 3: 200, 5: 200});
      expect(planListMove(between, 4, 1), {4: 200});
    });

    test('the tasks without a position that end up below it take theirs, '
        'first', () {
      final rows = [
        for (final id in [7, 6, 1, 2])
          ProjectListRow(sampleTask(id: id, title: '$id'), 0),
      ];
      final groups = listGroupsOf(rows, const {1: 300, 2: 600});

      expect(planListMove(groups, 2, 0), {7: 100, 6: 200, 2: 50});
      expect(planListMove(groups, 2, 0)!.keys, [7, 6, 2]);
      expect(planListMove(groups, 2, 1), {6: 200, 2: 150});
      expect(planListMove(groups, 6, 0), {7: 100, 6: 50});
      expect(planListMove(groups, 7, 2), {7: 450});
      expect(planListMove(groups, 1, 3), {1: 600 + 65536});
    });
  });

  group('the list after a move shows it where it was dropped', () {
    final now = DateTime.utc(2026, 10, 10, 12);

    /// Tasks 1 to 4 downloaded at 100 to 400; 6 and 7 added since, the
    /// newest (7) first.
    List<Task> tasks() => [
      for (final id in [1, 2, 3, 4, 6, 7]) sampleTask(id: id, title: '$id'),
    ];
    const downloaded = <int, double>{1: 100, 2: 200, 3: 300, 4: 400};

    List<int> order(Map<int, double> queued) => [
      for (final row in buildProjectListModel(
        ProjectListSource(
          projectTasks: tasks(),
          tasksById: {for (final task in tasks()) task.id: task},
          snapshot: ListSnapshot(positions: downloaded, loadedAt: now),
          queuedPositions: queued,
        ),
        kind: ViewFilterKind.openOnly,
        preferences: const ViewPreferences(),
      ).rows)
        row.task.id,
    ];

    List<int> afterMove(int taskId, int index) {
      final before = order(const {});
      final groups = listGroupsOf([
        for (final id in before)
          ProjectListRow(sampleTask(id: id, title: '$id'), 0),
      ], downloaded);
      return order(planListMove(groups, taskId, index)!);
    }

    test('among the tasks without a position', () {
      expect(order(const {}), [7, 6, 1, 2, 3, 4]);

      expect(afterMove(6, 0), [6, 7, 1, 2, 3, 4]);
      expect(afterMove(7, 1), [6, 7, 1, 2, 3, 4]);
    });

    test('a task with a position above or between them', () {
      expect(afterMove(3, 0), [3, 7, 6, 1, 2, 4]);
      expect(afterMove(4, 1), [7, 4, 6, 1, 2, 3]);
      expect(afterMove(1, 0), [1, 7, 6, 2, 3, 4]);
    });

    test('one without a position among those with one', () {
      expect(afterMove(7, 3), [6, 1, 2, 7, 3, 4]);
    });
  });
}
