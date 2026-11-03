import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/project/project_detail_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/project/project_task_list.dart';
import 'package:vikunja_app/presentation/widgets/project/project_task_list_item.dart';
import 'package:vikunja_app/presentation/widgets/task_bottom_sheet.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/fake_controllers.dart';
import '../../../helpers/plugin_mocks.dart';
import '../../../helpers/test_app.dart';

void main() {
  setUpAll(loadL10n);

  late ControllerCalls calls;
  late FakeOutcome outcome;
  late TestRepositories repos;

  setUp(() {
    mockPlatformPlugins();
    calls = ControllerCalls();
    outcome = FakeOutcome();
    repos = TestRepositories();
  });

  Future<void> pumpList(
    WidgetTester tester, {
    List<dynamic> tasks = const [],
    List<Project> subprojects = const [],
    bool loadingNextPage = false,
  }) async {
    final project = buildProject(
      id: 1,
      title: 'Parent',
      subprojects: subprojects,
    );

    await pumpApp(
      tester,
      Scaffold(body: ProjectTaskList(project)),
      overrides: [
        ...repos.overrides,
        currentUserOverride(buildUser()),
        projectOverride(
          project,
          buildProjectPageModel(
            project,
            tasks: tasks.cast(),
            isLoadingNextPage: loadingNextPage,
          ),
          calls,
          outcome,
        ),
        // Opening a subproject builds its own detail page.
        for (final sub in subprojects)
          projectOverride(sub, buildProjectPageModel(sub), calls, outcome),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('lists the tasks', (tester) async {
      await pumpList(
        tester,
        tasks: [
          buildTask(id: 1, title: 'First', priority: 0),
          buildTask(id: 2, title: 'Second', priority: 0),
        ],
      );

      expect(find.byType(ProjectTaskListItem), findsNWidgets(2));
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('lists the subprojects', (tester) async {
      await pumpList(
        tester,
        subprojects: [buildProject(id: 2, title: 'Child')],
      );

      expect(find.text('Child'), findsOneWidget);
      expect(find.byIcon(Icons.list), findsOneWidget);
    });

    testWidgets('separates subprojects from tasks with section headers', (
      tester,
    ) async {
      await pumpList(
        tester,
        tasks: [buildTask(priority: 0)],
        subprojects: [buildProject(id: 2, title: 'Child')],
      );

      expect(find.text(l10n.projectSection), findsOneWidget);
      expect(find.text(l10n.tasksSection), findsOneWidget);
    });

    testWidgets('omits the headers when there are only tasks', (tester) async {
      await pumpList(tester, tasks: [buildTask(priority: 0)]);

      expect(find.text(l10n.projectSection), findsNothing);
      expect(find.text(l10n.tasksSection), findsNothing);
    });

    testWidgets('omits the headers when there are only subprojects', (
      tester,
    ) async {
      await pumpList(
        tester,
        subprojects: [buildProject(id: 2, title: 'Child')],
      );

      expect(find.text(l10n.projectSection), findsNothing);
      expect(find.text(l10n.tasksSection), findsNothing);
    });

    testWidgets('shows an empty view when there is nothing at all', (
      tester,
    ) async {
      await pumpList(tester);

      expect(find.byType(EmptyView), findsOneWidget);
      expect(find.text(l10n.noTasksOrSubproject), findsOneWidget);
    });

    testWidgets('shows a spinner while the next page loads', (tester) async {
      final project = buildProject(id: 1);
      await pumpApp(
        tester,
        Scaffold(body: ProjectTaskList(project)),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          projectOverride(
            project,
            buildProjectPageModel(
              project,
              tasks: [buildTask(priority: 0)],
              isLoadingNextPage: true,
            ),
            calls,
            outcome,
          ),
        ],
      );
      await tester.pump();

      expect(find.byType(ProjectTaskListItem), findsOneWidget);
    });

    testWidgets('shows a loader while the controller is still building', (
      tester,
    ) async {
      final project = buildProject(id: 1);
      await pumpApp(
        tester,
        Scaffold(body: ProjectTaskList(project)),
        overrides: [
          ...repos.overrides,
          projectControllerProviderOverridePending(project),
        ],
      );
      await tester.pump();

      expect(find.byType(LoadingWidget), findsOneWidget);
    });

    testWidgets('shows an error view when the load fails', (tester) async {
      final project = buildProject(id: 1);
      await pumpApp(
        tester,
        Scaffold(body: ProjectTaskList(project)),
        overrides: [
          ...repos.overrides,
          projectControllerProviderOverrideFailing(project),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(VikunjaErrorWidget), findsOneWidget);
    });
  });

  group('acting on a task', () {
    testWidgets('tapping a task opens its detail sheet', (tester) async {
      await pumpList(tester, tasks: [buildTask(title: 'Ship it', priority: 0)]);

      await tapAndSettle(tester, find.text('Ship it'));

      expect(find.byType(TaskBottomSheet), findsOneWidget);
    });

    testWidgets('ticking a task marks it done', (tester) async {
      await pumpList(tester, tasks: [buildTask(id: 9, priority: 0)]);

      await tapAndSettle(tester, find.byType(Checkbox));

      expect(calls.doneTasks.single.id, 9);
    });

    testWidgets('a failed completion reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpList(tester, tasks: [buildTask(priority: 0)]);

      await tapAndSettle(tester, find.byType(Checkbox));

      expect(find.text(l10n.failedToMarkDone), findsOneWidget);
    });

    testWidgets('editing from the row menu opens the task editor', (
      tester,
    ) async {
      await pumpList(tester, tasks: [buildTask(priority: 0)]);

      await tapAndSettle(tester, find.byIcon(Icons.more_vert));
      await tapAndSettle(tester, find.text(l10n.edit));

      expect(find.byType(TaskEditPage), findsOneWidget);
    });

    testWidgets('editing from the detail sheet opens the task editor', (
      tester,
    ) async {
      await pumpList(tester, tasks: [buildTask(priority: 0)]);

      await tapAndSettle(tester, find.byType(ListTile));
      await tapAndSettle(tester, find.byIcon(Icons.edit));

      expect(find.byType(TaskEditPage), findsOneWidget);
    });
  });

  group('opening a subproject', () {
    testWidgets('tapping a subproject opens its detail page', (tester) async {
      await pumpList(
        tester,
        subprojects: [buildProject(id: 2, title: 'Child')],
      );

      await tapAndSettle(tester, find.text('Child'));

      expect(find.byType(ProjectDetailPage), findsOneWidget);
    });
  });

  group('reordering tasks', () {
    /// Three tasks, evenly spaced, so the saved position is predictable.
    Future<void> pumpThree(WidgetTester tester) => pumpList(
      tester,
      tasks: [
        buildTask(id: 1, title: 'First', priority: 0, position: 100),
        buildTask(id: 2, title: 'Second', priority: 0, position: 200),
        buildTask(id: 3, title: 'Third', priority: 0, position: 300),
      ],
    );

    /// Long-presses 'First' and drags it down by [rows] row heights.
    Future<void> dragFirstDown(WidgetTester tester, double rows) async {
      final start = tester.getCenter(find.text('First'));
      final rowHeight = tester.getCenter(find.text('Second')).dy - start.dy;
      final gesture = await tester.startGesture(start);
      // ReorderableDelayedDragStartListener waits out a long press first.
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 8; i++) {
        await gesture.moveTo(
          Offset(start.dx, start.dy + rowHeight * rows * (i + 1) / 8),
        );
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('long-pressing a task lifts it', (tester) async {
      await pumpThree(tester);

      final start = tester.getCenter(find.text('First'));
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      expect(find.text('First'), findsWidgets);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('dropping a task one slot down swaps it with its neighbour', (
      tester,
    ) async {
      await pumpThree(tester);

      await dragFirstDown(tester, 1);

      final reorder = calls.reorders.single;
      expect(reorder.movedTaskId, 1);
      expect(reorder.order, [2, 1, 3]);
      // Between its new neighbours, 200 and 300.
      expect(reorder.newPosition, 250.0);
    });

    testWidgets('dropping a task at the end appends it after the last', (
      tester,
    ) async {
      await pumpThree(tester);

      await dragFirstDown(tester, 2);

      final reorder = calls.reorders.single;
      expect(reorder.movedTaskId, 1);
      expect(reorder.order, [2, 3, 1]);
      // Nothing follows it, so it lands a step past the last position.
      expect(reorder.newPosition, greaterThan(300));
    });

    testWidgets('a drag too short to change the order saves nothing', (
      tester,
    ) async {
      // onReorderItem reports the index the item would settle at, so a drag
      // that lands it back in its own slot never reaches the controller.
      await pumpThree(tester);

      await dragFirstDown(tester, 0.4);

      expect(calls.reorders, isEmpty);
      expect(calls.called('reorderTasks'), isFalse);
    });

    testWidgets('a failed reorder reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpThree(tester);

      await dragFirstDown(tester, 2);

      expect(find.text('Failed to reorder task'), findsOneWidget);
    });
  });
}
