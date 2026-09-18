import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_list_page.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_list_item.dart';
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

  Future<void> pumpPage(
    WidgetTester tester, {
    TaskPageModel? model,
    bool signedIn = true,
  }) async {
    await pumpApp(
      tester,
      const TaskListPage(),
      overrides: [
        ...repos.overrides,
        if (signedIn) currentUserOverride(buildUser()),
        taskPageOverride(
          model ?? TaskPageModel([buildTask(priority: 0)], false, 4, false),
          calls,
          outcome,
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('shows a row per task', (tester) async {
      await pumpPage(
        tester,
        model: TaskPageModel(
          [buildTask(id: 1, title: 'First'), buildTask(id: 2, title: 'Second')],
          false,
          4,
          false,
        ),
      );

      expect(find.byType(TaskListItem), findsNWidgets(2));
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('shows the project name under a task', (tester) async {
      await pumpPage(
        tester,
        model: TaskPageModel(
          [
            buildTask(
              title: 'Task',
              project: buildProject(title: 'Subproject A'),
            ),
          ],
          false,
          4,
          false,
        ),
      );

      expect(find.text('Subproject A'), findsOneWidget);
    });

    testWidgets('shows an empty view when there are no tasks', (tester) async {
      await pumpPage(tester, model: TaskPageModel([], false, 4, false));

      expect(find.byType(EmptyView), findsOneWidget);
      expect(find.text(l10n.noTasks), findsOneWidget);
    });

    testWidgets('shows a trailing spinner while the next page loads', (
      tester,
    ) async {
      // The spinner animates forever, so this pumps rather than settles.
      await pumpApp(
        tester,
        const TaskListPage(),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          taskPageOverride(
            TaskPageModel([buildTask()], false, 4, true),
            calls,
            outcome,
          ),
        ],
      );
      await tester.pump();

      expect(find.byType(TaskListItem), findsOneWidget);
      // The spinner row sits after the task, separated by a divider.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('shows a loader while the controller is still building', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const TaskListPage(),
        overrides: [
          ...repos.overrides,
          taskPageControllerProviderOverridePending(),
        ],
      );
      await tester.pump();

      expect(find.byType(LoadingWidget), findsOneWidget);
    });

    testWidgets('shows an error view when the controller fails', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const TaskListPage(),
        overrides: [
          ...repos.overrides,
          taskPageControllerProviderOverrideFailing(),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(VikunjaErrorWidget), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
    });
  });

  group('adding a task', () {
    testWidgets('the add button opens the add dialog', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byType(FloatingActionButton));

      expect(find.byType(AddTaskDialog), findsOneWidget);
    });

    testWidgets('the add button warns when no default project is set', (
      tester,
    ) async {
      await pumpPage(
        tester,
        model: TaskPageModel([buildTask()], false, 0, false),
      );

      await tapAndSettle(tester, find.byType(FloatingActionButton));

      expect(find.byType(AddTaskDialog), findsNothing);
      expect(find.text(l10n.selectDefaultProject), findsOneWidget);
    });

    testWidgets('confirming the dialog creates the task', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byType(FloatingActionButton));
      await enterTextAndSettle(tester, find.byType(TextField), 'Buy milk');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(calls.addedTasks.single.title, 'Buy milk');
      expect(calls.addedTasks.single.projectId, 4);
    });

    testWidgets('a successful add confirms with a snackbar', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byType(FloatingActionButton));
      await enterTextAndSettle(tester, find.byType(TextField), 'Buy milk');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(find.text(l10n.taskAddedSuccess), findsOneWidget);
    });

    testWidgets('a failed add reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpPage(tester);

      await tapAndSettle(tester, find.byType(FloatingActionButton));
      await enterTextAndSettle(tester, find.byType(TextField), 'Buy milk');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(find.text(l10n.taskAddError), findsOneWidget);
    });

    testWidgets('adding is skipped when nobody is signed in', (tester) async {
      await pumpPage(tester, signedIn: false);

      await tapAndSettle(tester, find.byType(FloatingActionButton));
      await enterTextAndSettle(tester, find.byType(TextField), 'Buy milk');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(calls.addedTasks, isEmpty);
    });
  });

  group('the due-date filter', () {});

  group('acting on a task', () {
    testWidgets('tapping a task opens its detail sheet', (tester) async {
      await pumpPage(
        tester,
        model: TaskPageModel([buildTask(title: 'Ship it')], false, 4, false),
      );

      await tapAndSettle(tester, find.text('Ship it'));

      expect(find.byType(TaskBottomSheet), findsOneWidget);
    });

    testWidgets('ticking a task marks it done', (tester) async {
      final task = buildTask(id: 9);
      await pumpPage(tester, model: TaskPageModel([task], false, 4, false));

      await tapAndSettle(tester, find.byType(Checkbox));

      expect(calls.doneTasks.single.id, 9);
    });

    testWidgets('a failed completion reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpPage(tester);

      await tapAndSettle(tester, find.byType(Checkbox));

      expect(find.text(l10n.taskMarkDoneError), findsOneWidget);
    });

    testWidgets('editing from the row menu opens the edit page', (
      tester,
    ) async {
      await pumpPage(tester);

      // The app bar has its own overflow button; target the row's.
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(TaskListItem),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tapAndSettle(tester, find.text(l10n.edit));

      expect(find.byType(TaskEditPage), findsOneWidget);
    });

    testWidgets('editing from the detail sheet opens the edit page', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byType(ListTile));
      await tapAndSettle(tester, find.byIcon(Icons.edit));

      expect(find.byType(TaskEditPage), findsOneWidget);
    });
  });

  group('refreshing', () {
    testWidgets('pulling down reloads the list', (tester) async {
      await pumpPage(
        tester,
        model: TaskPageModel(
          List.generate(40, (i) => buildTask(id: i, priority: 0)),
          false,
          4,
          false,
        ),
      );

      await pullToRefresh(tester, find.byType(ListView));

      expect(calls.called('reload'), isTrue);
    });
  });
}
