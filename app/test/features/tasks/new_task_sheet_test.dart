import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  // A Saturday at noon.
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', position: 1),
      sampleProject(id: 2, title: 'Inbox', position: 2),
      sampleProject(id: 3, title: 'Personal', position: 3),
    ];
    data.tasks.all = [sampleTask(id: 1, title: 'Existing')];
  });

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  Future<void> pumpOverview(WidgetTester tester) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);
  }

  Future<void> pumpProject(WidgetTester tester, int id) async {
    await pumpOverview(tester);
    routerOf(tester).go(AppRoutes.project(id));
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(NewTaskSheet), findsOneWidget);
  }

  Finder titleField() => find.widgetWithText(TextField, en.taskEditTitleLabel);

  Finder addButton() => find.widgetWithText(FilledButton, en.newTaskAdd);

  bool addEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(addButton()).onPressed != null;

  Finder projectChip(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ActionChip));

  testWidgets('the overview has an extended FAB, a project a plain one', (
    tester,
  ) async {
    await pumpOverview(tester);
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
    await pumpOverview(tester);
    await openSheet(tester);

    expect(tester.widget<TextField>(titleField()).autofocus, isTrue);
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

    await tester.enterText(titleField(), '  ');
    await tester.pumpAndSettle();
    expect(addEnabled(tester), isFalse);
    await tester.enterText(titleField(), 'Buy milk');
    await tester.pumpAndSettle();
    expect(addEnabled(tester), isTrue);
  });

  testWidgets('a project list preselects its own project', (tester) async {
    await pumpProject(tester, 3);
    await openSheet(tester);

    expect(projectChip('Personal'), findsOneWidget);
  });

  testWidgets('without an Inbox the first project of the tree is used', (
    tester,
  ) async {
    data.projects.all = [
      sampleProject(id: 5, title: 'Zebra', position: 2),
      sampleProject(id: 4, title: 'Alpha', position: 1),
    ];
    await pumpOverview(tester);
    await openSheet(tester);

    expect(projectChip('Alpha'), findsOneWidget);
  });

  testWidgets('Add creates the task with its project and due date, closes '
      'the sheet and confirms', (tester) async {
    await pumpProject(tester, 1);
    await openSheet(tester);

    await tester.enterText(titleField(), ' Buy milk ');
    await tester.tap(find.text(en.shortcutTomorrow));
    await tester.pumpAndSettle();
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(data.tasks.creates, [
      NewTask(
        projectId: 1,
        title: 'Buy milk',
        dueDate: DateTime(2026, 10, 11, 12).toUtc(),
      ),
    ]);
    expect(data.tasks.writes, ['create -1 Buy milk']);
    expect(find.byType(NewTaskSheet), findsNothing);
    expect(find.text(en.newTaskCreated('Buy milk')), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
    // No identifier until the server assigns one.
    expect(find.textContaining('#0'), findsNothing);
  });

  testWidgets('tapping a selected shortcut again clears the due date', (
    tester,
  ) async {
    await pumpOverview(tester);
    await openSheet(tester);
    Finder tomorrowChip() => find.ancestor(
      of: find.text(en.shortcutTomorrow),
      matching: find.byType(ChoiceChip),
    );

    await tester.enterText(titleField(), 'Buy milk');
    await tester.tap(find.text(en.shortcutTomorrow));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(tomorrowChip()).selected, isTrue);
    await tester.tap(find.text(en.shortcutTomorrow));
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(tomorrowChip()).selected, isFalse);
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(data.tasks.creates.single.dueDate, isNull);
    expect(find.textContaining('#0'), findsNothing);
  });

  testWidgets('the keyboard action adds too', (tester) async {
    await pumpOverview(tester);
    await openSheet(tester);

    await tester.enterText(titleField(), 'Call Sam');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(data.tasks.creates.single.title, 'Call Sam');
    expect(data.tasks.creates.single.projectId, 2);
    expect(data.tasks.creates.single.dueDate, isNull);
    expect(find.byType(NewTaskSheet), findsNothing);
  });

  testWidgets('the project chip opens the picker', (tester) async {
    await pumpOverview(tester);
    await openSheet(tester);

    await tester.tap(projectChip('Inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Personal'));
    await tester.pumpAndSettle();

    expect(projectChip('Personal'), findsOneWidget);
    await tester.enterText(titleField(), 'Moved');
    await tester.pump();
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(data.tasks.creates.single.projectId, 3);
  });

  testWidgets('Pick date opens the pickers and shows the date as a chip '
      'that can be removed', (tester) async {
    await pumpOverview(tester);
    await openSheet(tester);

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
    await tester.enterText(titleField(), 'Later');
    await tester.pump();
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(
      data.tasks.creates.single.dueDate,
      DateTime(2026, 10, 20, 12).toUtc(),
    );
  });

  testWidgets('More options creates the task and opens the edit page on it', (
    tester,
  ) async {
    await pumpOverview(tester);
    await openSheet(tester);

    await tester.enterText(titleField(), 'Plan trip');
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.newTaskMoreOptions));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['create -1 Plan trip']);
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
    await pumpOverview(tester);
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
    await pumpOverview(tester);
    await openSheet(tester);

    await tester.enterText(titleField(), 'Big text');
    await tester.pumpAndSettle();
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(data.tasks.creates.single.title, 'Big text');
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the keyboard up at 200 % the sheet scrolls instead of '
      'overflowing', (tester) async {
    useAccessibilityExtremes(tester);
    await pumpOverview(tester);
    await openSheet(tester);
    // A 300 dp keyboard on the 3x surface.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    await tester.enterText(titleField(), 'Big text');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(addButton());
    await tester.pumpAndSettle();
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(data.tasks.creates.single.title, 'Big text');
    expect(tester.takeException(), isNull);
  });
}
