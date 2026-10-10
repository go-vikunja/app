import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_read_client.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';

void main() {
  late FakeReadClient client;

  setUp(() {
    client = FakeReadClient();
    client.projects.all = [
      sampleProject(id: 1, title: 'Work', position: 200, hexColor: '1973ff'),
      sampleProject(id: 2, title: 'Home', position: 100, favorite: true),
      sampleProject(id: 3, title: 'Reports', parent: 1, position: 20),
      sampleProject(id: 4, title: 'Admin', parent: 1, position: 10),
      sampleProject(id: 5, title: 'Old', archived: true),
      const Project(id: Project.favoritesId, title: 'Favorites'),
      const Project(id: -2, title: 'Saved filter'),
    ];
  });

  List<String> rowTitles(WidgetTester tester) => [
    for (final row in tester.widgetList<ProjectRow>(find.byType(ProjectRow)))
      row.project.title,
  ];

  Future<void> pumpProjects(WidgetTester tester) async {
    await pumpSignedInApp(tester, readClient: client);
    await openTab(tester, en.tabProjects);
  }

  testWidgets('shows favourites first, then the tree by position', (
    tester,
  ) async {
    await pumpProjects(tester);

    expect(find.text(en.projectsFavouritesHeading), findsOneWidget);
    expect(find.text(en.projectsAllHeading), findsOneWidget);
    expect(rowTitles(tester), ['Home', 'Home', 'Work', 'Admin', 'Reports']);
    expect(find.text('Old'), findsNothing);
    expect(find.text('Favorites'), findsNothing);
    expect(find.text('Saved filter'), findsNothing);
    expect(find.text(en.projectChildCount(2)), findsOneWidget);
    final stars = tester.widgetList<Icon>(find.byIcon(Icons.star));
    expect(stars.map((icon) => icon.semanticLabel), [
      en.favouriteLabel,
      en.favouriteLabel,
    ]);
  });

  testWidgets('children are indented and can be collapsed', (tester) async {
    await pumpProjects(tester);
    final parentLeft = tester.getTopLeft(find.text('Work')).dx;
    final childLeft = tester.getTopLeft(find.text('Admin')).dx;
    expect(childLeft, greaterThan(parentLeft));

    await tester.tap(find.byTooltip(en.projectCollapse('Work')));
    await tester.pumpAndSettle();
    expect(rowTitles(tester), ['Home', 'Home', 'Work']);

    await tester.tap(find.byTooltip(en.projectExpand('Work')));
    await tester.pumpAndSettle();
    expect(rowTitles(tester), ['Home', 'Home', 'Work', 'Admin', 'Reports']);
  });

  testWidgets('tapping a project opens its tasks', (tester) async {
    await pumpProjects(tester);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);
  });

  testWidgets('without projects shows the empty state', (tester) async {
    client.projects.all = [];
    await pumpProjects(tester);

    expect(find.text(en.projectsEmptyTitle), findsOneWidget);
  });

  testWidgets('a failed load is explained and can be retried', (tester) async {
    client.projects.onListAll = () async =>
        throw const NetworkFailure(NetworkProblem.timeout);
    await pumpProjects(tester);

    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(
      find.text(en.failureTimeoutExplanation('tasks.example.org')),
      findsOneWidget,
    );

    client.projects.onListAll = null;
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();

    expect(find.byType(DataFailureCard), findsNothing);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the projects', (tester) async {
    await pumpProjects(tester);
    client.projects.all = [sampleProject(id: 9, title: 'Fresh')];

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(rowTitles(tester), ['Fresh']);
    expect(client.projects.listAllCalls, 2);
  });

  testWidgets('the app bar button refreshes without a drag', (tester) async {
    await pumpProjects(tester);
    client.projects.all = [sampleProject(id: 9, title: 'Fresh')];

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(rowTitles(tester), ['Fresh']);
    expect(client.projects.listAllCalls, 2);
  });

  testWidgets('a failure notice and collapsed state do not outlive the '
      'account', (tester) async {
    final auth = AuthFakes();
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(
        issuedAt: DateTime.now().toUtc(),
        userId: 8,
        username: 'bob',
      ),
      activate: false,
    );
    await pumpSignedInApp(tester, readClient: client, auth: auth);
    await openTab(tester, en.tabProjects);
    await tester.tap(find.byTooltip(en.projectCollapse('Work')));
    await tester.pumpAndSettle();
    client.projects.onListAll = () async => throw const ServerFailure(502);
    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();
    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(rowTitles(tester), ['Home', 'Home', 'Work']);

    client.projects.onListAll = null;
    await containerOf(tester).read(accountRegistryProvider).setActive(bob.id);
    await tester.pumpAndSettle();

    expect(find.byType(DataFailureCard), findsNothing);
    expect(rowTitles(tester), ['Home', 'Home', 'Work', 'Admin', 'Reports']);
  });
}
