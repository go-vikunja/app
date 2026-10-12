import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../quick_add/presentation/composer_harness.dart';

void main() {
  late ComposerHarness harness;

  setUp(() {
    harness = ComposerHarness();
    harness.data.tasks.all = [sampleTask(id: 1, title: 'Existing')];
  });

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(NewTaskSheet), findsOneWidget);
  }

  Finder addButton() => find.widgetWithText(FilledButton, en.newTaskAdd);

  bool addEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(addButton()).onPressed != null;

  Finder projectChip(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ActionChip));

  testWidgets('the overview has an extended FAB, a project a plain one', (
    tester,
  ) async {
    await harness.pumpApp(tester);
    expect(
      find.widgetWithText(FloatingActionButton, en.newTask),
      findsOneWidget,
    );

    routerOf(tester).go(AppRoutes.project(1));
    await tester.pumpAndSettle();
    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.tooltip, en.newTask);
    expect(fab.isExtended, isFalse);
  });

  testWidgets('opens with the title focused, Add disabled until typed, and '
      'the Inbox preselected on the overview', (tester) async {
    await harness.open(tester);

    expect(tester.widget<TextField>(composerField()).autofocus, isTrue);
    expect(addEnabled(tester), isFalse);
    expect(projectChip('Inbox'), findsOneWidget);
    for (final label in [
      en.shortcutToday,
      en.shortcutTomorrow,
      en.shortcutNextWeek,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text(en.shortcutNextMonday), findsNothing);

    await typeLine(tester, '  ');
    expect(addEnabled(tester), isFalse);
    await typeLine(tester, 'Buy milk');
    expect(addEnabled(tester), isTrue);
  });

  testWidgets('the field takes quotes and dashes as typed', (tester) async {
    await harness.open(tester);

    final field = tester.widget<TextField>(composerField());
    expect(field.smartQuotesType, SmartQuotesType.disabled);
    expect(field.smartDashesType, SmartDashesType.disabled);
  });

  testWidgets('a project list preselects its own project', (tester) async {
    await harness.open(tester, projectId: 3);

    expect(projectChip('Garage Sale'), findsOneWidget);
  });

  testWidgets("the user's default project comes before the Inbox, the "
      "list's own project before both", (tester) async {
    harness.settings = const UserSettings(defaultProjectId: 3);
    await harness.open(tester);
    expect(projectChip('Garage Sale'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    routerOf(tester).go(AppRoutes.project(1));
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(projectChip('Work'), findsOneWidget);
  });

  testWidgets('without an Inbox the first project of the tree is used', (
    tester,
  ) async {
    harness.data.projects.all = [
      sampleProject(id: 5, title: 'Zebra', position: 2),
      sampleProject(id: 4, title: 'Alpha', position: 1),
    ];
    await harness.open(tester);

    expect(projectChip('Alpha'), findsOneWidget);
  });

  testWidgets('Add hands the text to quick add with the project, dates the '
      'task, closes the sheet and confirms', (tester) async {
    await harness.open(tester, projectId: 1);

    await typeLine(tester, ' Buy milk ');
    await tester.tap(find.text(en.shortcutTomorrow));
    await tester.pumpAndSettle();
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(harness.service.submits, [
      (
        text: ' Buy milk ',
        fallbackProjectId: 1,
        fallbackDueDate: DateTime(2026, 10, 11, 12).toUtc(),
      ),
    ]);
    expect(find.byType(NewTaskSheet), findsNothing);
    expect(find.text(en.newTaskCreated('Buy milk')), findsOneWidget);
  });

  testWidgets('tapping a selected shortcut again clears the due date', (
    tester,
  ) async {
    await harness.open(tester);
    Finder tomorrowChip() => find.ancestor(
      of: find.text(en.shortcutTomorrow),
      matching: find.byType(ChoiceChip),
    );

    await typeLine(tester, 'Buy milk');
    await tester.tap(find.text(en.shortcutTomorrow));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(tomorrowChip()).selected, isTrue);
    await tester.tap(find.text(en.shortcutTomorrow));
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(tomorrowChip()).selected, isFalse);
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(harness.service.submits.single.fallbackDueDate, isNull);
  });

  testWidgets('the keyboard action adds too', (tester) async {
    await harness.open(tester);

    await typeLine(tester, 'Call Sam');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(harness.service.submits, [
      (text: 'Call Sam', fallbackProjectId: 2, fallbackDueDate: null),
    ]);
    expect(find.byType(NewTaskSheet), findsNothing);
  });

  testWidgets('the keyboard action with nothing to add keeps the sheet', (
    tester,
  ) async {
    await harness.open(tester);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(harness.service.submits, isEmpty);
    expect(find.byType(NewTaskSheet), findsOneWidget);
  });

  testWidgets('the project chip opens the picker', (tester) async {
    await harness.open(tester);

    await tester.tap(projectChip('Inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Garage Sale'));
    await tester.pumpAndSettle();

    expect(projectChip('Garage Sale'), findsOneWidget);
    await typeLine(tester, 'Moved');
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(harness.service.submits.single.fallbackProjectId, 3);
  });

  testWidgets('Pick date opens the pickers and shows the date as a chip '
      'that can be removed', (tester) async {
    await harness.open(tester);

    // The chips wrap, so the picker is on screen without scrolling.
    for (final label in [en.shortcutNextWeek, en.newTaskPickDate]) {
      expect(
        tester.getBottomRight(find.text(label)).dx,
        lessThanOrEqualTo(phoneSize.width),
      );
    }
    await tester.tap(find.text(en.newTaskPickDate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(InputChip, 'Oct 20, 2026 12:00 PM'),
      findsOneWidget,
    );
    await typeLine(tester, 'Later');
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(
      harness.service.submits.single.fallbackDueDate,
      DateTime(2026, 10, 20, 12).toUtc(),
    );
  });

  testWidgets('More options creates the task and opens the edit page on it', (
    tester,
  ) async {
    harness.service.beforeSubmit = () async {
      await harness.data.tasks.createTask(
        const NewTask(projectId: 2, title: 'Plan trip'),
      );
    };
    await harness.open(tester);

    await typeLine(tester, 'Plan trip');
    await tester.tap(find.text(en.newTaskMoreOptions));
    await tester.pumpAndSettle();

    expect(harness.data.tasks.writes, ['create -1 Plan trip']);
    expect(find.byType(NewTaskSheet), findsNothing);
    expect(find.byType(TaskEditPage), findsOneWidget);
    expect(routerOf(tester).state.uri.toString(), AppRoutes.taskEdit(-1));
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, en.taskEditTitleLabel),
          )
          .controller
          ?.text,
      'Plan trip',
    );
    expect(find.text(en.newTaskCreated('Plan trip')), findsNothing);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await harness.pumpApp(tester);
    expect(find.text(de.newTask), findsOneWidget);
    await openSheet(tester);

    expect(find.text(de.newTaskAdd), findsOneWidget);
    expect(find.text(de.newTaskMoreOptions), findsOneWidget);
    expect(find.text(de.shortcutTomorrow), findsOneWidget);
  });

  testWidgets('at 200 % text scale in dark mode the sheet still adds', (
    tester,
  ) async {
    useAccessibilityExtremes(tester);
    await harness.open(tester);

    await typeLine(tester, 'Big text');
    await tester.pumpAndSettle();
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(harness.service.submits.single.text, 'Big text');
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the keyboard up at 200 % the sheet scrolls instead of '
      'overflowing', (tester) async {
    useAccessibilityExtremes(tester);
    await harness.open(tester);
    // A 300 dp keyboard on the 3x surface.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    await typeLine(tester, 'Big text');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(addButton());
    await tester.pumpAndSettle();
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(harness.service.submits.single.text, 'Big text');
    expect(tester.takeException(), isNull);
  });
}
