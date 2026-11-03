import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/project/project_detail_page.dart';
import 'package:vikunja_app/presentation/pages/project/project_edit.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/project_task_list.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';

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

  Project listProject({int id = 1, String title = 'Alpha'}) => buildProject(
    id: id,
    title: title,
    views: [buildView(id: 10, projectId: id)],
  );

  Project twoViewProject() => buildProject(
    id: 2,
    title: 'Board',
    views: [
      buildView(id: 20, projectId: 2),
      buildView(id: 21, projectId: 2, kind: ViewKind.kanban, title: 'Kanban'),
    ],
  );

  Future<void> pumpPage(
    WidgetTester tester,
    Project project, {
    int viewIndex = 0,
    bool displayDoneTask = false,
    bool signedIn = true,
  }) async {
    await pumpApp(
      tester,
      ProjectDetailPage(project: project),
      overrides: [
        ...repos.overrides,
        if (signedIn) currentUserOverride(buildUser()),
        projectOverride(
          project,
          buildProjectPageModel(
            project,
            tasks: [buildTask(priority: 0)],
            viewIndex: viewIndex,
            displayDoneTask: displayDoneTask,
          ),
          calls,
          outcome,
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('titles the page with the project name', (tester) async {
      await pumpPage(tester, listProject(title: 'Roadmap'));

      expect(find.text('Roadmap'), findsOneWidget);
    });

    testWidgets('shows the task list for a list view', (tester) async {
      await pumpPage(tester, listProject());

      expect(find.byType(ProjectTaskList), findsOneWidget);
      expect(find.byType(KanbanWidget), findsNothing);
    });

    testWidgets('shows a loader while the controller is still building', (
      tester,
    ) async {
      final project = listProject();
      await pumpApp(
        tester,
        ProjectDetailPage(project: project),
        overrides: [
          ...repos.overrides,
          projectControllerProviderOverridePending(project),
        ],
      );
      await tester.pump();

      expect(find.byType(LoadingWidget), findsOneWidget);
    });

    testWidgets('shows an error view with a retry when the load fails', (
      tester,
    ) async {
      final project = listProject();
      await pumpApp(
        tester,
        ProjectDetailPage(project: project),
        overrides: [
          ...repos.overrides,
          projectControllerProviderOverrideFailing(project),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(VikunjaErrorWidget), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
    });

    testWidgets('says so when the project has no views', (tester) async {
      final project = buildProject(id: 3, title: 'Empty', views: []);

      await pumpApp(
        tester,
        ProjectDetailPage(project: project),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          projectOverride(
            project,
            buildProjectPageModel(project),
            calls,
            outcome,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.noViews), findsOneWidget);
    });
  });

  group('the view switcher', () {
    testWidgets('is hidden for a project with a single view', (tester) async {
      await pumpPage(tester, listProject());

      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('offers one entry per view when there are several', (
      tester,
    ) async {
      await pumpPage(tester, twoViewProject());

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Kanban'), findsOneWidget);
    });

    testWidgets('tapping a view loads it', (tester) async {
      await pumpPage(tester, twoViewProject());

      await tapAndSettle(tester, find.text('Kanban'));

      expect(calls.viewIndexes, [1]);
    });
  });

  group('adding a task', () {
    testWidgets('a list view offers an add button', (tester) async {
      await pumpPage(tester, listProject());

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('the add button opens the add dialog', (tester) async {
      await pumpPage(tester, listProject());

      await tapAndSettle(tester, find.byType(FloatingActionButton));

      expect(find.byType(AddTaskDialog), findsOneWidget);
    });

    testWidgets('confirming the dialog creates the task in this project', (
      tester,
    ) async {
      await pumpPage(tester, listProject(id: 7));

      await tapAndSettle(tester, find.byType(FloatingActionButton));
      await enterTextAndSettle(tester, find.byType(TextField), 'Write specs');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(calls.addedTasks.single.title, 'Write specs');
      expect(calls.addedTasks.single.projectId, 7);
      expect(calls.addedTasks.single.done, isFalse);
    });

    testWidgets('a successful add confirms with a snackbar', (tester) async {
      await pumpPage(tester, listProject());

      await tapAndSettle(tester, find.byType(FloatingActionButton));
      await enterTextAndSettle(tester, find.byType(TextField), 'Write specs');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(find.text(l10n.taskAddedSuccess), findsOneWidget);
    });

    testWidgets('a failed add reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpPage(tester, listProject());

      await tapAndSettle(tester, find.byType(FloatingActionButton));
      await enterTextAndSettle(tester, find.byType(TextField), 'Write specs');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(find.text(l10n.taskAddError), findsOneWidget);
    });

    testWidgets('adding is skipped when nobody is signed in', (tester) async {
      await pumpPage(tester, listProject(), signedIn: false);

      await tapAndSettle(tester, find.byType(FloatingActionButton));
      await enterTextAndSettle(tester, find.byType(TextField), 'Write specs');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(calls.addedTasks, isEmpty);
    });

    testWidgets('a project with no views offers no add button', (tester) async {
      final project = buildProject(id: 3, views: []);

      await pumpApp(
        tester,
        ProjectDetailPage(project: project),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          projectOverride(
            project,
            buildProjectPageModel(project),
            calls,
            outcome,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('a pseudo project offers no add button', (tester) async {
      // Saved filters arrive with a negative id and cannot take new tasks.
      final project = buildProject(id: -1, title: 'Favorites');

      await pumpApp(
        tester,
        ProjectDetailPage(project: project),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          projectOverride(
            project,
            buildProjectPageModel(project),
            calls,
            outcome,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('editing the project', () {
    testWidgets('the edit action opens the edit page', (tester) async {
      await pumpPage(tester, listProject());

      await tapAndSettle(tester, find.byIcon(Icons.edit));

      expect(find.byType(ProjectEditPage), findsOneWidget);
    });

    testWidgets('hands the edit page the current done-task setting', (
      tester,
    ) async {
      await pumpPage(tester, listProject(), displayDoneTask: true);

      await tapAndSettle(tester, find.byIcon(Icons.edit));

      expect(
        tester
            .widget<ProjectEditPage>(find.byType(ProjectEditPage))
            .displayDoneTask,
        isTrue,
      );
    });
  });

  group('refreshing', () {
    testWidgets('pulling down reloads the current view', (tester) async {
      final project = listProject();
      await pumpApp(
        tester,
        ProjectDetailPage(project: project),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          projectOverride(
            project,
            buildProjectPageModel(
              project,
              tasks: List.generate(40, (i) => buildTask(id: i, priority: 0)),
            ),
            calls,
            outcome,
          ),
        ],
      );
      await tester.pumpAndSettle();

      await pullToRefresh(tester, find.byType(CustomScrollView));

      expect(calls.called('loadForView'), isTrue);
    });
  });
}
