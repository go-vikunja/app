import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';

import '../../helpers/sample_data.dart';

void main() {
  final doneAt = DateTime.utc(2026, 10, 10, 12);

  /// Project 1: an open parent (1) with an open (2) and a done (3) child,
  /// the open child with a grandchild in project 2 (4); a done parent (5)
  /// with an open child (6); two plain open tasks (7, 8) and a plain done
  /// one (9).
  List<Task> projectTasks() => [
    sampleTask(id: 1, title: 'Parent', subtaskIds: [2, 3]),
    sampleTask(id: 2, title: 'Open child', parentIds: [1], subtaskIds: [4]),
    sampleTask(
      id: 3,
      title: 'Done child',
      parentIds: [1],
      done: true,
      doneAt: doneAt,
    ),
    sampleTask(
      id: 5,
      title: 'Done parent',
      subtaskIds: [6],
      done: true,
      doneAt: doneAt.subtract(const Duration(days: 1)),
    ),
    sampleTask(id: 6, title: 'Orphaned child', parentIds: [5]),
    sampleTask(id: 7, title: 'Seven'),
    sampleTask(id: 8, title: 'Eight'),
    sampleTask(id: 9, title: 'Done nine', done: true, doneAt: doneAt),
  ];

  ProjectListSource source({
    Map<int, double> positions = const {},
    Map<int, double> queuedPositions = const {},
    DateTime? loadedAt,
    List<Task>? tasks,
  }) {
    final inProject = tasks ?? projectTasks();
    final grandchild = sampleTask(
      id: 4,
      title: 'Elsewhere',
      projectId: 2,
      parentIds: [2],
    );
    return ProjectListSource(
      projectTasks: inProject,
      tasksById: {
        for (final task in inProject) task.id: task,
        grandchild.id: grandchild,
      },
      snapshot: ListSnapshot(positions: positions, loadedAt: loadedAt),
      queuedPositions: queuedPositions,
    );
  }

  List<(int, int)> idsAndDepths(List<ProjectListRow>? rows) => [
    for (final row in rows ?? const <ProjectListRow>[])
      (row.task.id, row.depth),
  ];

  group('openOnly', () {
    test('nests every subtask under its open parent, an open child of a '
        'done parent at the top, newest first without positions', () {
      final model = buildProjectListModel(
        source(),
        kind: ViewFilterKind.openOnly,
        preferences: const ViewPreferences(),
      );

      expect(idsAndDepths(model.rows), [
        (8, 0),
        (7, 0),
        (6, 0),
        (1, 0),
        (2, 1),
        (4, 2),
        (3, 1),
      ]);
      expect(model.doneRows, isNull);
    });

    test('manual order follows the view positions, tasks the download did '
        'not have first', () {
      final model = buildProjectListModel(
        source(positions: {1: 10, 7: 20, 6: 5}),
        kind: ViewFilterKind.openOnly,
        preferences: const ViewPreferences(),
      );

      expect(
        [
          for (final row in model.rows)
            if (row.depth == 0) row.task.id,
        ],
        [8, 6, 1, 7],
      );
    });

    test('a queued position wins over the downloaded one, also for a task '
        'the download did not have', () {
      final model = buildProjectListModel(
        source(
          positions: {1: 10, 7: 20, 6: 5},
          queuedPositions: {6: 15, 8: 30},
        ),
        kind: ViewFilterKind.openOnly,
        preferences: const ViewPreferences(),
      );

      expect(
        [
          for (final row in model.rows)
            if (row.depth == 0) row.task.id,
        ],
        [1, 6, 7, 8],
      );
    });

    test('a queued position adds no task to a view the device cannot '
        'evaluate', () {
      final model = buildProjectListModel(
        source(positions: {7: 20, 1: 10}, queuedPositions: {8: 15, 7: 5}),
        kind: ViewFilterKind.other,
        preferences: const ViewPreferences(),
      );

      expect(
        [
          for (final row in model.rows)
            if (row.depth == 0) row.task.id,
        ],
        [7, 1],
      );
    });

    test('another sort orders the top level only', () {
      final model = buildProjectListModel(
        source(),
        kind: ViewFilterKind.openOnly,
        preferences: const ViewPreferences(sort: TaskListSort.titleAsc),
      );

      expect(idsAndDepths(model.rows), [
        (8, 0),
        (6, 0),
        (1, 0),
        (2, 1),
        (4, 2),
        (3, 1),
        (7, 0),
      ]);
    });

    test('show done adds the done tasks without a parent in the project '
        'below, newest done first, with their subtasks; the open child of '
        'a done parent only under it, so every task is listed once', () {
      final model = buildProjectListModel(
        source(),
        kind: ViewFilterKind.openOnly,
        preferences: const ViewPreferences(showDone: true),
      );

      expect(idsAndDepths(model.rows), [
        (8, 0),
        (7, 0),
        (1, 0),
        (2, 1),
        (4, 2),
        (3, 1),
      ]);
      expect(idsAndDepths(model.doneRows), [(9, 0), (5, 0), (6, 1)]);
      final ids = [
        for (final row in [...model.rows, ...?model.doneRows]) row.task.id,
      ];
      expect(ids, unorderedEquals(ids.toSet()));
    });

    test('a task marked done here keeps its place while it leaves', () {
      final tasks = [
        for (final task in projectTasks())
          if (task.id == 7) task.copyWith(done: true, doneAt: doneAt) else task,
      ];
      final leaving = {7: tasks.firstWhere((task) => task.id == 7)};
      final model = buildProjectListModel(
        source(tasks: tasks),
        kind: ViewFilterKind.openOnly,
        preferences: const ViewPreferences(),
        leaving: leaving,
      );

      expect(model.rows[1].task.id, 7);
      expect(model.rows[1].task.done, isTrue);

      final gone = buildProjectListModel(
        source(tasks: tasks),
        kind: ViewFilterKind.openOnly,
        preferences: const ViewPreferences(),
      );
      expect(gone.rows.map((row) => row.task.id), isNot(contains(7)));
    });

    test(
      'a leaving task the source no longer loads stands in as it showed',
      () {
        final copy = projectTasks()
            .firstWhere((task) => task.id == 7)
            .copyWith(done: true, doneAt: doneAt);
        final model = buildProjectListModel(
          source(
            tasks: [
              for (final task in projectTasks())
                if (task.id != 7) task,
            ],
          ),
          kind: ViewFilterKind.openOnly,
          preferences: const ViewPreferences(),
          leaving: {7: copy},
        );

        expect(model.rows[1].task, same(copy));
      },
    );

    test('a subtask row names the row it is nested under', () {
      final model = buildProjectListModel(
        source(),
        kind: ViewFilterKind.openOnly,
        preferences: const ViewPreferences(),
      );

      expect(
        [for (final row in model.rows) (row.task.id, row.parent?.id)],
        [(8, null), (7, null), (6, null), (1, null), (2, 1), (4, 2), (3, 1)],
      );
    });
  });

  test('a view without a filter puts the done top-level tasks in the done '
      'part, the open child of a done parent under it', () {
    final model = buildProjectListModel(
      source(),
      kind: ViewFilterKind.none,
      preferences: const ViewPreferences(),
    );

    expect(idsAndDepths(model.rows), [
      (8, 0),
      (7, 0),
      (1, 0),
      (2, 1),
      (4, 2),
      (3, 1),
    ]);
    expect(idsAndDepths(model.doneRows), [(9, 0), (5, 0), (6, 1)]);
  });

  test('a done-only view shows the done tasks in one part', () {
    final model = buildProjectListModel(
      source(),
      kind: ViewFilterKind.doneOnly,
      preferences: const ViewPreferences(),
    );

    // 3's open parent is not in the view. Without a download, newest
    // first, as the server puts new tasks on top.
    expect(idsAndDepths(model.rows), [(9, 0), (5, 0), (6, 1), (3, 0)]);
    expect(model.doneRows, isNull);

    final positioned = buildProjectListModel(
      source(positions: {3: 1, 5: 2, 9: 3}),
      kind: ViewFilterKind.doneOnly,
      preferences: const ViewPreferences(),
    );
    expect(idsAndDepths(positioned.rows), [(3, 0), (5, 0), (6, 1), (9, 0)]);
  });

  test('a view the device cannot evaluate shows its last download in its '
      'positions, done tasks among the open ones as on the server, leaving '
      'out tasks the device no longer has', () {
    final model = buildProjectListModel(
      source(positions: {7: 2, 5: 1, 8: 3, 404: 0}, loadedAt: doneAt),
      kind: ViewFilterKind.other,
      preferences: const ViewPreferences(),
    );

    expect(idsAndDepths(model.rows), [(5, 0), (6, 1), (7, 0), (8, 0)]);
    expect(model.doneRows, isNull);
  });

  test('only a view that can show done tasks at the top level loads them', () {
    expect(
      showsDoneTasks(ViewFilterKind.openOnly, const ViewPreferences()),
      isFalse,
    );
    expect(
      showsDoneTasks(
        ViewFilterKind.openOnly,
        const ViewPreferences(showDone: true),
      ),
      isTrue,
    );
    expect(
      showsDoneTasks(ViewFilterKind.none, const ViewPreferences()),
      isTrue,
    );
    expect(
      showsDoneTasks(ViewFilterKind.doneOnly, const ViewPreferences()),
      isTrue,
    );
    expect(
      showsDoneTasks(
        ViewFilterKind.other,
        const ViewPreferences(showDone: true),
      ),
      isFalse,
    );
  });

  test('an empty project is empty in every kind', () {
    for (final kind in ViewFilterKind.values) {
      final model = buildProjectListModel(
        source(tasks: const []),
        kind: kind,
        preferences: const ViewPreferences(showDone: true),
      );
      expect(model.isEmpty, isTrue, reason: '$kind');
    }
  });

  group('views', () {
    final project = sampleProject(
      id: 1,
      title: 'Work',
      views: [
        sampleListView(id: 12, projectId: 1, title: 'Second', position: 300),
        const ProjectView(
          id: 10,
          projectId: 1,
          title: 'Kanban',
          kind: ProjectViewKind.kanban,
        ),
        sampleListView(id: 11, projectId: 1),
      ],
    );

    test('list and kanban views, by position', () {
      expect(shownViewsOf(project).map((view) => view.id), [10, 11, 12]);
      expect(shownViewsOf(null), isEmpty);
    });

    test('the remembered view while it exists, else the first', () {
      final views = shownViewsOf(project);
      expect(resolveViewId(views, remembered: 12), 12);
      expect(resolveViewId(views, remembered: 10), 10);
      expect(resolveViewId(views, remembered: 99), 10);
      expect(resolveViewId(views, remembered: null), 10);
      expect(resolveViewId(const [], remembered: 12), 0);
    });
  });
}
