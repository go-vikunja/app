import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/presentation/pages/project/project_edit.dart';

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

  /// The edit page is always reached by a push, and a successful save pops
  /// back — so the test pushes it onto a host page rather than making it the
  /// root, where the pop would take the snackbar's Scaffold with it.
  Future<Project> pumpPage(
    WidgetTester tester, {
    String title = 'Roadmap',
    String description = 'Long term plans',
    bool displayDoneTask = false,
  }) async {
    final project = buildProject(id: 1, title: title, description: description);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProjectEditPage(
                    project: project,
                    displayDoneTask: displayDoneTask,
                  ),
                ),
              ),
              child: const Text('open editor'),
            ),
          ),
        ),
      ),
      surfaceSize: tallPhoneSurface,
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
    await tapAndSettle(tester, find.text('open editor'));
    return project;
  }

  Finder titleField() => find.byType(TextFormField).first;
  Finder descriptionField() => find.byType(TextFormField).last;

  group('rendering', () {
    testWidgets('prefills the title and description', (tester) async {
      await pumpPage(tester);

      expect(find.text('Roadmap'), findsOneWidget);
      expect(find.text('Long term plans'), findsOneWidget);
      expect(find.text(l10n.editProjectTitle), findsOneWidget);
    });

    testWidgets('reflects the current done-task setting', (tester) async {
      await pumpPage(tester, displayDoneTask: true);

      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
    });
  });

  group('validation', () {
    testWidgets('rejects an empty title', (tester) async {
      await pumpPage(tester);

      await enterTextAndSettle(tester, titleField(), '');
      await tapAndSettle(tester, find.text(l10n.save));

      expect(
        find.text('The title needs to have between 1 and 250 characters.'),
        findsOneWidget,
      );
      expect(calls.called('updateProject'), isFalse);
    });

    testWidgets('rejects a title longer than 250 characters', (tester) async {
      await pumpPage(tester);

      await enterTextAndSettle(tester, titleField(), 'x' * 251);
      await tapAndSettle(tester, find.text(l10n.save));

      expect(
        find.text('The title needs to have between 1 and 250 characters.'),
        findsOneWidget,
      );
      expect(calls.called('updateProject'), isFalse);
    });

    testWidgets('accepts a title of exactly 250 characters', (tester) async {
      await pumpPage(tester);

      await enterTextAndSettle(tester, titleField(), 'x' * 250);
      await tapAndSettle(tester, find.text(l10n.save));

      expect(calls.called('updateProject'), isTrue);
    });

    testWidgets('rejects a description longer than 1000 characters', (
      tester,
    ) async {
      await pumpPage(tester);

      await enterTextAndSettle(tester, descriptionField(), 'x' * 1001);
      await tapAndSettle(tester, find.text(l10n.save));

      expect(
        find.text('The description can have a maximum of 1000 characters.'),
        findsOneWidget,
      );
      expect(calls.called('updateProject'), isFalse);
    });

    testWidgets('accepts an empty description', (tester) async {
      await pumpPage(tester);

      await enterTextAndSettle(tester, descriptionField(), '');
      await tapAndSettle(tester, find.text(l10n.save));

      expect(calls.called('updateProject'), isTrue);
    });
  });

  group('saving', () {
    testWidgets('saves the edited title and description', (tester) async {
      await pumpPage(tester);

      await enterTextAndSettle(tester, titleField(), 'Renamed');
      await enterTextAndSettle(tester, descriptionField(), 'New description');
      await tapAndSettle(tester, find.text(l10n.save));

      final saved = calls.updatedProjects.single;
      expect(saved.title, 'Renamed');
      expect(saved.description, 'New description');
    });

    testWidgets('a successful save confirms with a snackbar', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.save));

      expect(find.text(l10n.projectUpdatedSuccess), findsOneWidget);
    });

    testWidgets('a failed save reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpPage(tester);

      await tapAndSettle(tester, find.text(l10n.save));

      expect(find.text(l10n.projectUpdateError), findsOneWidget);
      expect(calls.displayDoneTaskChanges, isEmpty);
    });

    testWidgets('a successful save also persists the done-task setting', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byType(CheckboxListTile));
      await tapAndSettle(tester, find.text(l10n.save));

      expect(calls.displayDoneTaskChanges, [true]);
    });

    testWidgets('persists the done-task setting as it was left', (
      tester,
    ) async {
      await pumpPage(tester, displayDoneTask: true);

      await tapAndSettle(tester, find.byType(CheckboxListTile));
      await tapAndSettle(tester, find.text(l10n.save));

      expect(calls.displayDoneTaskChanges, [false]);
    });
  });

  group('the done-task checkbox', () {
    testWidgets('tapping it flips the tick', (tester) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byType(CheckboxListTile));

      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
    });

    testWidgets('tapping it twice returns to the original state', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapAndSettle(tester, find.byType(CheckboxListTile));
      await tapAndSettle(tester, find.byType(CheckboxListTile));

      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
    });
  });
}
