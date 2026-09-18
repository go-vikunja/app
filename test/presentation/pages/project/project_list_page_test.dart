import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project_list_model.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/project/expansion_title.dart';
import 'package:vikunja_app/presentation/pages/project/project_detail_page.dart';
import 'package:vikunja_app/presentation/pages/project/project_list_page.dart';
import 'package:vikunja_app/presentation/widgets/project/add_project_dialog.dart';

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
    ProjectListModel? model,
    bool signedIn = true,
  }) async {
    final projects = model ?? ProjectListModel([buildProject(title: 'Alpha')]);
    await pumpApp(
      tester,
      const ProjectListPage(),
      overrides: [
        ...repos.overrides,
        if (signedIn) currentUserOverride(buildUser()),
        projectsOverride(projects, calls),
        // Opening a project builds its detail page against this controller.
        for (final project in projects.projects)
          projectOverride(
            project,
            buildProjectPageModel(project),
            calls,
            outcome,
          ),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('lists the top-level projects', (tester) async {
      await pumpPage(
        tester,
        model: ProjectListModel([
          buildProject(id: 1, title: 'Alpha'),
          buildProject(id: 2, title: 'Beta'),
        ]),
      );

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text(l10n.projectsTitle), findsOneWidget);
    });

    testWidgets('a project without children is a plain row', (tester) async {
      await pumpPage(tester);

      expect(find.byType(VikunjaExpansionTile), findsNothing);
      expect(find.byIcon(Icons.list), findsOneWidget);
    });

    testWidgets('a project with children gets an expander', (tester) async {
      await pumpPage(
        tester,
        model: ProjectListModel([
          buildProject(
            id: 1,
            title: 'Parent',
            subprojects: [buildProject(id: 2, title: 'Child')],
          ),
        ]),
      );

      expect(find.byType(VikunjaExpansionTile), findsOneWidget);
      expect(find.text('Child'), findsNothing);
    });

    testWidgets('expanding a project reveals its children', (tester) async {
      await pumpPage(
        tester,
        model: ProjectListModel([
          buildProject(
            id: 1,
            title: 'Parent',
            subprojects: [buildProject(id: 2, title: 'Child')],
          ),
        ]),
      );

      await tapAndSettle(tester, find.byIcon(Icons.keyboard_arrow_right));

      expect(find.text('Child'), findsOneWidget);
    });

    testWidgets('nests grandchildren under their parent', (tester) async {
      final grandchild = buildProject(id: 3, title: 'Grandchild');
      final child = buildProject(
        id: 2,
        title: 'Child',
        subprojects: [grandchild],
      );

      await pumpPage(
        tester,
        model: ProjectListModel([
          buildProject(id: 1, title: 'Parent', subprojects: [child]),
        ]),
      );

      await tapAndSettle(tester, find.byIcon(Icons.keyboard_arrow_right));
      await tapAndSettle(tester, find.byIcon(Icons.keyboard_arrow_right));

      expect(find.text('Grandchild'), findsOneWidget);
    });

    testWidgets('shows a loader while the controller is still building', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const ProjectListPage(),
        overrides: [
          ...repos.overrides,
          projectsControllerProviderOverridePending(),
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
        const ProjectListPage(),
        overrides: [
          ...repos.overrides,
          projectsControllerProviderOverrideFailing(),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(VikunjaErrorWidget), findsOneWidget);
    });

    testWidgets('shows a trailing spinner while the next page loads', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const ProjectListPage(),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          projectsOverride(
            ProjectListModel([buildProject()], isLoadingNextPage: true),
            calls,
          ),
        ],
      );
      await tester.pump();

      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('adding a project', () {
    testWidgets('the add button opens the add dialog', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byIcon(Icons.add));

      expect(find.byType(AddProjectDialog), findsOneWidget);
    });

    testWidgets('confirming the dialog creates the project', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byIcon(Icons.add));
      await enterTextAndSettle(tester, find.byType(TextField), 'Roadmap');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(calls.createdProjects.single.title, 'Roadmap');
    });

    testWidgets('the new project is owned by the signed-in user', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byIcon(Icons.add));
      await enterTextAndSettle(tester, find.byType(TextField), 'Roadmap');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(calls.createdProjects.single.owner!.username, 'testuser');
    });

    testWidgets('cancelling the dialog creates nothing', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byIcon(Icons.add));
      await enterTextAndSettle(tester, find.byType(TextField), 'Roadmap');
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(calls.createdProjects, isEmpty);
    });
  });

  group('opening a project', () {
    testWidgets('tapping a plain row opens its detail page', (tester) async {
      await pumpPage(
        tester,
        model: ProjectListModel([buildProject(id: 1, title: 'Alpha')]),
      );

      await tapAndSettle(tester, find.text('Alpha'));

      expect(find.byType(ProjectDetailPage), findsOneWidget);
    });

    testWidgets('tapping an expandable title opens its detail page', (
      tester,
    ) async {
      final child = buildProject(id: 2, title: 'Child');
      await pumpPage(
        tester,
        model: ProjectListModel([
          buildProject(id: 1, title: 'Parent', subprojects: [child]),
        ]),
      );

      await tapAndSettle(tester, find.text('Parent'));

      expect(find.byType(ProjectDetailPage), findsOneWidget);
    });
  });

  group('refreshing', () {
    testWidgets('pulling down reloads the list', (tester) async {
      await pumpPage(
        tester,
        model: ProjectListModel(
          List.generate(40, (i) => buildProject(id: i, title: 'Project $i')),
        ),
      );

      await pullToRefresh(tester, find.byType(ListView));

      expect(calls.called('reload'), isTrue);
    });
  });
}
