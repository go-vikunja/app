import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project_list_model.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/presentation/pages/home_page.dart';
import 'package:vikunja_app/presentation/pages/project/project_list_page.dart';
import 'package:vikunja_app/presentation/pages/settings_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_list_page.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_controllers.dart';
import '../../helpers/mock_http_overrides.dart';
import '../../helpers/plugin_mocks.dart';
import '../../helpers/test_app.dart';

void main() {
  setUpAll(loadL10n);

  late ControllerCalls calls;
  late FakeOutcome outcome;
  late TestRepositories repos;

  setUp(() {
    mockPlatformPlugins();
    mockNetworkImages();
    calls = ControllerCalls();
    outcome = FakeOutcome();
    repos = TestRepositories();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await pumpApp(
      tester,
      const HomePage(),
      overrides: [
        ...repos.overrides,
        currentUserOverride(
          buildUser(
            username: 'demo',
            settings: buildUserSettings(defaultProjectId: 4),
          ),
        ),
        taskPageOverride(
          TaskPageModel([buildTask(priority: 0)], false, 4, false),
          calls,
          outcome,
        ),
        projectsOverride(
          ProjectListModel([buildProject(title: 'Alpha')]),
          calls,
        ),
        settingsOverride(
          buildSettingsState(user: buildUser(username: 'demo')),
          calls,
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('the tab bar', () {
    testWidgets('offers the home, projects and settings tabs', (tester) async {
      await pumpHome(tester);

      expect(find.text(l10n.homeTab), findsOneWidget);
      expect(find.text(l10n.projectsTab), findsOneWidget);
      expect(find.text(l10n.settingsTab), findsOneWidget);
    });

    testWidgets('opens on the task list', (tester) async {
      await pumpHome(tester);

      expect(find.byType(TaskListPage), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
    });

    testWidgets('tapping Projects shows the project list', (tester) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.text(l10n.projectsTab));

      expect(find.byType(ProjectListPage), findsOneWidget);
      expect(find.byType(TaskListPage), findsNothing);
    });

    testWidgets('tapping Settings shows the settings page', (tester) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.text(l10n.settingsTab));

      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('tapping Home returns to the task list', (tester) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.text(l10n.settingsTab));
      await tapAndSettle(tester, find.text(l10n.homeTab));

      expect(find.byType(TaskListPage), findsOneWidget);
    });

    testWidgets('tracks the selected tab', (tester) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.text(l10n.projectsTab));

      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    });

    testWidgets('re-tapping the current tab keeps it selected', (tester) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.text(l10n.homeTab));

      expect(find.byType(TaskListPage), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
    });
  });

  group('the quick-add intent', () {
    testWidgets('does not open the add dialog on a plain launch', (
      tester,
    ) async {
      // The platform channel returns null, meaning the app was not opened from
      // the quick tile.
      await pumpHome(tester);

      expect(find.text(l10n.newTaskName), findsNothing);
    });
  });
}
