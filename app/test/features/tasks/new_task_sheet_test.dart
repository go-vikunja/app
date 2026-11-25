import 'dart:async';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/quick_add_help_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

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

  Finder projectField(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ProjectField));

  /// A chip's text [label], also while it shows its time after it.
  Finder chipText(String label) => find.descendant(
    of: find.byType(NewTaskSheet),
    matching: find.textContaining(RegExp('^${RegExp.escape(label)}( |\$)')),
  );

  Finder choiceChip(String label) =>
      find.ancestor(of: chipText(label), matching: find.byType(ChoiceChip));

  Finder moreOptionsButton() => find.ancestor(
    of: find.text(en.newTaskMoreOptions),
    matching: find.byWidgetPredicate((widget) => widget is TextButton),
  );

  Finder descriptionField() =>
      find.widgetWithText(TextField, en.taskDetailDescription);

  Finder amountField() => find.widgetWithText(TextField, en.repeatAmountLabel);

  Rect contentViewport(WidgetTester tester) => tester.getRect(
    find
        .descendant(
          of: find.byType(NewTaskSheet),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomScrollView &&
                widget.scrollDirection == Axis.vertical,
          ),
        )
        .first,
  );

  Rect caretRect(WidgetTester tester) {
    final editable = tester
        .state<EditableTextState>(
          find.descendant(
            of: composerField(),
            matching: find.byType(EditableText),
          ),
        )
        .renderEditable;
    return MatrixUtils.transformRect(
      editable.getTransformTo(null),
      editable.getLocalRectForCaret(editable.selection!.extent),
    );
  }

  Future<void> enterInvalidRepeat(WidgetTester tester) async {
    await typeLine(tester, 'Water plants');
    await tapInSheet(tester, en.newTaskMoreOptions);
    await tapInSheet(tester, en.repeatModeEvery);
    await tester.enterText(amountField(), '0');
    await tester.pump();
  }

  void expectInView(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    final content = contentViewport(tester);
    expect(rect.top, greaterThanOrEqualTo(content.top));
    expect(rect.bottom, lessThanOrEqualTo(content.bottom));
  }

  testWidgets('the overview and a project have an extended FAB', (
    tester,
  ) async {
    await harness.pumpApp(tester);
    expect(
      find.widgetWithText(FloatingActionButton, en.newTask),
      findsOneWidget,
    );

    routerOf(tester).go(AppRoutes.project(1));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FloatingActionButton, en.newTask),
      findsOneWidget,
    );
  });

  testWidgets('opens with the title focused, Add disabled until typed, and '
      'the Inbox preselected on the overview', (tester) async {
    await harness.open(tester);

    expect(tester.widget<TextField>(composerField()).autofocus, isTrue);
    expect(addEnabled(tester), isFalse);
    expect(projectField('Inbox'), findsOneWidget);
    for (final label in [
      en.shortcutToday,
      en.shortcutTomorrow,
      en.shortcutNextWeek,
      en.priorityLow,
      en.priorityMedium,
      en.priorityHigh,
      en.priorityUrgent,
      en.priorityDoNow,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text(en.shortcutNextMonday), findsNothing);
    expect(find.text(en.priorityUnset), findsNothing);

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

    expect(projectField('Garage Sale'), findsOneWidget);
  });

  testWidgets("the user's default project comes before the Inbox, the "
      "list's own project before both", (tester) async {
    harness.settings = const UserSettings(defaultProjectId: 3);
    await harness.open(tester);
    expect(projectField('Garage Sale'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    routerOf(tester).go(AppRoutes.project(1));
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(projectField('Work'), findsOneWidget);
  });

  testWidgets('without an Inbox the first project of the tree is used', (
    tester,
  ) async {
    harness.data.projects.all = [
      sampleProject(id: 5, title: 'Zebra', position: 2),
      sampleProject(id: 4, title: 'Alpha', position: 1),
    ];
    await harness.open(tester);

    expect(projectField('Alpha'), findsOneWidget);
  });

  testWidgets('Add hands the text to quick add with the project, dates the '
      'task, closes the sheet and confirms', (tester) async {
    await harness.open(tester, projectId: 1);

    await typeLine(tester, ' Buy milk ');
    await tapInSheet(tester, en.shortcutTomorrow);
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(harness.service.submits, [
      (
        text: ' Buy milk ',
        fallbackProjectId: 1,
        fallbackDueDate: DateTime(2026, 10, 11, 12).toUtc(),
        fallbackPriority: null,
        extras: const QuickAddExtras(),
      ),
    ]);
    expect(find.byType(NewTaskSheet), findsNothing);
    expect(find.text(en.newTaskCreated('Buy milk')), findsOneWidget);
  });

  testWidgets("a day chip takes the default due time of the user's "
      'settings', (tester) async {
    harness.settings = const UserSettings(defaultDueTime: ClockTime(17, 45));
    await harness.open(tester, projectId: 1);

    await typeLine(tester, 'Buy milk');
    await tapInSheet(tester, en.shortcutTomorrow);
    expect(
      chipText(en.shortcutAtTime(en.shortcutTomorrow, '5:45 PM')),
      findsOneWidget,
    );
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(
      harness.service.submits.single.fallbackDueDate,
      DateTime(2026, 10, 11, 17, 45).toUtc(),
    );
  });

  testWidgets('the date chips turn over at midnight while the sheet stays '
      'open, and Today then sets the new day', (tester) async {
    harness.now = DateTime(2026, 10, 10, 23, 59, 30);
    await harness.open(tester, projectId: 1);
    await typeLine(tester, 'Buy milk');
    expect(
      tester.getSemantics(inSheet(en.shortcutToday)).label,
      en.shortcutSemantics(en.shortcutToday, 'Sat, Oct 10'),
    );

    harness.now = DateTime(2026, 10, 11, 0, 0, 30);
    await tester.pump(ClockTick.period);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(inSheet(en.shortcutToday)).label,
      en.shortcutSemantics(en.shortcutToday, 'Sun, Oct 11'),
    );

    await tapInSheet(tester, en.shortcutToday);
    expect(
      chipText(en.shortcutAtTime(en.shortcutToday, '9:00 AM')),
      findsOneWidget,
    );
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(
      harness.service.submits.single.fallbackDueDate,
      DateTime(2026, 10, 11, 9).toUtc(),
    );
  });

  testWidgets('Today takes the time of the tap: a default due time passed '
      'since the sheet was drawn becomes 23:59', (tester) async {
    harness
      ..settings = const UserSettings(defaultDueTime: ClockTime(17, 45))
      ..now = DateTime(2026, 10, 10, 17, 44, 30);
    await harness.open(tester, projectId: 1);
    await typeLine(tester, 'Buy milk');

    harness.now = DateTime(2026, 10, 10, 17, 46);
    await tester.tap(choiceChip(en.shortcutToday));
    await tester.pumpAndSettle();
    expect(
      chipText(en.shortcutAtTime(en.shortcutToday, '11:59 PM')),
      findsOneWidget,
    );
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(
      harness.service.submits.single.fallbackDueDate,
      DateTime(2026, 10, 10, 23, 59).toUtc(),
    );
  });

  testWidgets('Pick date dates a day without a time at the tap: a default '
      'due time passed since the sheet was drawn becomes 23:59', (
    tester,
  ) async {
    harness
      ..settings = const UserSettings(defaultDueTime: ClockTime(17, 45))
      ..now = DateTime(2026, 10, 10, 17, 44, 30);
    await harness.open(tester, projectId: 1);
    await tester.ensureVisible(inSheet(en.newTaskPickDate));
    await tester.pumpAndSettle();

    harness.now = DateTime(2026, 10, 10, 17, 46);
    await tester.tap(inSheet(en.newTaskPickDate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      chipText(en.shortcutAtTime(en.shortcutToday, '11:59 PM')),
      findsOneWidget,
    );
  });

  testWidgets("a typed day and its chip agree on the user's default due "
      'time', (tester) async {
    harness.settings = const UserSettings(defaultDueTime: ClockTime(17, 45));
    await harness.open(tester, projectId: 1);
    final tomorrowAt = chipText(
      en.shortcutAtTime(en.shortcutTomorrow, '5:45 PM'),
    );

    await typeLine(tester, 'Buy milk tomorrow');
    await tester.pumpAndSettle();
    expect(tomorrowAt, findsOneWidget);

    await typeLine(tester, 'Buy milk');
    await tester.pumpAndSettle();
    expect(tomorrowAt, findsNothing);
    await tapInSheet(tester, en.shortcutTomorrow);
    expect(tomorrowAt, findsOneWidget);
  });

  testWidgets('the headings sit above their rows, and the chosen day shows '
      'the time the due date gets', (tester) async {
    await harness.open(tester);
    for (final (heading, chip) in [
      (en.taskDetailDueDate, en.shortcutToday),
      (en.taskDetailPriority, en.priorityLow),
    ]) {
      expect(
        tester.getRect(inSheet(heading)).bottom,
        lessThanOrEqualTo(tester.getRect(choiceChip(chip)).top),
      );
    }

    await tapInSheet(tester, en.shortcutTomorrow);
    expect(
      chipText(en.shortcutAtTime(en.shortcutTomorrow, '12:00 PM')),
      findsOneWidget,
    );
    expect(chipText(en.shortcutToday), findsOneWidget);
    await typeLine(tester, 'Buy milk');
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(
      harness.service.submits.single.fallbackDueDate,
      DateTime(2026, 10, 11, 12).toUtc(),
    );
  });

  testWidgets("Upcoming's New task starts with today as the due date, which "
      'a tap on its chip clears', (tester) async {
    await harness.pumpApp(tester);
    routerOf(tester).go(AppRoutes.upcoming);
    await tester.pumpAndSettle();
    await openSheet(tester);

    final today = choiceChip(en.shortcutToday);
    expect(tester.widget<ChoiceChip>(today).selected, isTrue);
    expect(
      chipText(en.shortcutAtTime(en.shortcutToday, '12:00 PM')),
      findsOneWidget,
    );
    await typeLine(tester, 'Buy milk');
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(
      harness.service.submits.single.fallbackDueDate,
      DateTime(2026, 10, 10, 12).toUtc(),
    );

    // The confirmation goes and frees the button.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await tester.tap(choiceChip(en.shortcutToday));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(today).selected, isFalse);
  });

  testWidgets('a due day the sheet opens with is a removable chip at the '
      "user's default due time", (tester) async {
    harness.settings = const UserSettings(defaultDueTime: ClockTime(17, 45));
    await harness.pumpApp(tester);
    unawaited(
      showNewTaskSheet(
        tester.element(find.byType(FloatingActionButton)),
        dueDay: DateTime(2026, 10, 14),
      ),
    );
    await tester.pumpAndSettle();

    final chip = find.descendant(
      of: find.byType(NewTaskSheet),
      matching: find.byType(InputChip),
    );
    expect(tester.widget<InputChip>(chip).selected, isTrue);
    await typeLine(tester, 'Buy milk');
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(
      harness.service.submits.single.fallbackDueDate,
      DateTime(2026, 10, 14, 17, 45).toUtc(),
    );

    unawaited(
      showNewTaskSheet(
        tester.element(find.byType(FloatingActionButton)),
        dueDay: DateTime(2026, 10, 14),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: chip,
        matching: find.byTooltip(en.taskEditClearDueDate),
      ),
    );
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    await typeLine(tester, 'Buy bread');
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(harness.service.submits.last.fallbackDueDate, isNull);
  });

  test("a list of days dates a new task on the strip's day, else today, or "
      'the first day of a range ahead', () {
    final now = DateTime(2026, 10, 10, 12);
    final nextDays = DateRange(from: now, to: DateTime(2026, 10, 17, 12));
    expect(
      newTaskDayIn(nextDays, selectedDay: null, now: now),
      DateTime(2026, 10, 10),
    );
    expect(
      newTaskDayIn(nextDays, selectedDay: DateTime(2026, 10, 12), now: now),
      DateTime(2026, 10, 12),
    );
    expect(
      newTaskDayIn(nextDays, selectedDay: DateTime(2026, 10, 30), now: now),
      DateTime(2026, 10, 10),
    );
    final nextWeek = DateRange(
      from: DateTime(2026, 10, 12),
      to: DateTime(2026, 10, 19),
    );
    expect(
      newTaskDayIn(nextWeek, selectedDay: null, now: now),
      DateTime(2026, 10, 12),
    );
    final lastWeek = DateRange(
      from: DateTime(2026, 9, 28),
      to: DateTime(2026, 10, 5),
    );
    expect(
      newTaskDayIn(lastWeek, selectedDay: null, now: now),
      DateTime(2026, 10, 10),
    );
  });

  testWidgets("a single task's confirmation opens it; several tasks' has no "
      'Open', (tester) async {
    harness.service.result = const QuickAddResult(createdTaskIds: [1]);
    await harness.open(tester);
    await typeLine(tester, 'Existing');
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    final open = find.widgetWithText(SnackBarAction, en.taskDuplicateOpen);
    expect(open, findsOneWidget);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailSheet), findsOneWidget);

    await tester.tapAt(const Offset(180, 40));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    harness.service.result = const QuickAddResult(createdTaskIds: [-1, -2]);
    await openSheet(tester);
    await typeLine(tester, 'Buy milk\nCall Sam');
    await tester.tap(find.widgetWithText(FilledButton, en.newTaskAddMany(2)));
    await tester.pumpAndSettle();
    expect(find.text(en.newTaskCreatedMany(2)), findsOneWidget);
    expect(find.byType(SnackBarAction), findsNothing);
  });

  testWidgets('tapping a selected shortcut again clears the due date', (
    tester,
  ) async {
    await harness.open(tester);
    Finder tomorrowChip() => choiceChip(en.shortcutTomorrow);

    await typeLine(tester, 'Buy milk');
    await tapInSheet(tester, en.shortcutTomorrow);
    expect(tester.widget<ChoiceChip>(tomorrowChip()).selected, isTrue);
    await tester.tap(tomorrowChip());
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
      (
        text: 'Call Sam',
        fallbackProjectId: 2,
        fallbackDueDate: null,
        fallbackPriority: null,
        extras: const QuickAddExtras(),
      ),
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

  testWidgets('the project field opens the picker', (tester) async {
    await harness.open(tester);

    await tester.tap(projectField('Inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Garage Sale'));
    await tester.pumpAndSettle();

    expect(projectField('Garage Sale'), findsOneWidget);
    await typeLine(tester, 'Moved');
    await tester.tap(addButton());
    await tester.pumpAndSettle();
    expect(harness.service.submits.single.fallbackProjectId, 3);
  });

  testWidgets('Pick date opens the pickers and shows the date as a chip '
      'that can be removed', (tester) async {
    await harness.open(tester);

    await tapInSheet(tester, en.newTaskPickDate);
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

  testWidgets('a priority chip gives the tasks their priority, and tapping '
      'it again unsets it', (tester) async {
    await harness.open(tester);
    bool selected(String label) =>
        tester.widget<ChoiceChip>(choiceChip(label)).selected;

    await typeLine(tester, 'Buy milk');
    await tapInSheet(tester, en.priorityHigh);
    expect(selected(en.priorityHigh), isTrue);
    await tapInSheet(tester, en.priorityHigh);
    expect(selected(en.priorityHigh), isFalse);
    await tapInSheet(tester, en.priorityHigh);
    await tapInSheet(tester, en.priorityUrgent);
    expect(selected(en.priorityHigh), isFalse);
    expect(selected(en.priorityUrgent), isTrue);
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(harness.service.submits.single.fallbackPriority, 4);
  });

  testWidgets('the due date and priority rows are one line each, and stay in '
      'view with the keyboard up on a small phone', (tester) async {
    usePhoneSurface(tester);
    await harness.pumpApp(tester);
    tester.view
      ..padding = const FakeViewPadding(top: 48 * 3)
      ..viewPadding = const FakeViewPadding(top: 48 * 3);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // A 300 dp keyboard on the 3x surface.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    final content = contentViewport(tester);
    void expectRowsInView({bool priority = true}) {
      for (final row in [
        [
          en.shortcutToday,
          en.shortcutTomorrow,
          en.shortcutNextWeek,
          en.newTaskPickDate,
        ],
        if (priority)
          [
            en.priorityLow,
            en.priorityMedium,
            en.priorityHigh,
            en.priorityUrgent,
            en.priorityDoNow,
          ],
      ]) {
        final rects = [
          for (final label in row) tester.getRect(chipText(label)),
        ];
        for (final rect in rects) {
          expect(rect.center.dy, moreOrLessEquals(rects.first.center.dy));
        }
        final chip = tester.getRect(choiceChip(row.first));
        expect(chip.top, greaterThanOrEqualTo(content.top));
        expect(chip.bottom, lessThanOrEqualTo(content.bottom));
      }
      final caret = caretRect(tester);
      expect(caret.top, greaterThanOrEqualTo(content.top));
      expect(caret.bottom, lessThanOrEqualTo(content.bottom));
    }

    expectRowsInView();
    expect(
      tester.getRect(composerField()).top,
      greaterThanOrEqualTo(content.top),
    );
    await typeLine(tester, 'Buy milk');
    await tester.pumpAndSettle();
    expectRowsInView();
    // A date in the text adds a chip under the field, which on this phone
    // moves the priority row out of view under its heading; the sheet's own
    // priority and date repeat none.
    await typeLine(tester, 'Buy milk tomorrow');
    await tester.pumpAndSettle();
    expectRowsInView(priority: false);
    await typeLine(tester, '');
    await tester.pumpAndSettle();
    await tapInSheet(tester, en.priorityHigh);
    await tapInSheet(tester, en.shortcutTomorrow);
    await typeLine(tester, 'Buy milk');
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsNothing);
    // Scrolled up to the field for the date's chip, the sheet stays there:
    // on this phone the priority row is a short scroll away.
    expectRowsInView(priority: false);
    await typeLine(tester, 'Buy milk tomorrow');
    await tester.pumpAndSettle();
    expectRowsInView(priority: false);
  });

  testWidgets('the buttons clear the navigation bar, and the keyboard while it '
      'is up', (tester) async {
    usePhoneSurface(tester);
    await harness.pumpApp(tester);
    // A 48 dp navigation bar on the 3x surface.
    tester.view
      ..padding = const FakeViewPadding(bottom: 48 * 3)
      ..viewPadding = const FakeViewPadding(bottom: 48 * 3);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(addButton()).bottom,
      lessThanOrEqualTo(phoneSize.height - 48),
    );

    // The keyboard covers the navigation bar.
    tester.view
      ..padding = FakeViewPadding.zero
      ..viewInsets = const FakeViewPadding(bottom: 300 * 3);
    await tester.pumpAndSettle();
    final addBottom = tester.getRect(addButton()).bottom;
    expect(addBottom, lessThanOrEqualTo(phoneSize.height - 300));
    expect(addBottom, greaterThan(phoneSize.height - 300 - 48));
  });

  testWidgets('More options, even before a title, shows the description, '
      'labels, reminders and repeat, and Fewer options hides them', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await harness.open(tester);

    expect(descriptionField(), findsNothing);
    expect(tester.widget<TextButton>(moreOptionsButton()).onPressed, isNotNull);
    expect(
      tester.getSemantics(moreOptionsButton()),
      matchesSemantics(
        label: en.newTaskMoreOptions,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
        hasExpandedState: true,
      ),
    );
    await tapInSheet(tester, en.newTaskMoreOptions);

    expect(descriptionField(), findsOneWidget);
    for (final title in [
      en.taskDetailLabels,
      en.taskDetailReminders,
      en.taskEditRepeat,
    ]) {
      expect(inSheet(title), findsOneWidget, reason: title);
    }
    expect(inSheet(en.taskEditAddLabel), findsOneWidget);
    expect(inSheet(en.taskEditAddReminder), findsOneWidget);
    expect(inSheet(en.newTaskMoreOptions), findsNothing);
    expect(addEnabled(tester), isFalse);
    // The title field keeps the focus and the keyboard.
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: composerField(),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );

    expect(
      tester.getSemantics(
        find.ancestor(
          of: find.text(en.newTaskFewerOptions),
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        ),
      ),
      matchesSemantics(
        label: en.newTaskFewerOptions,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
        hasExpandedState: true,
        isExpanded: true,
      ),
    );
    await tapInSheet(tester, en.newTaskFewerOptions);
    expect(descriptionField(), findsNothing);
    expect(inSheet(en.newTaskMoreOptions), findsOneWidget);
    expect(harness.data.tasks.writes, isEmpty);
    expect(harness.service.submits, isEmpty);
    semantics.dispose();
  });

  testWidgets('with the keyboard up, More options scrolls the description '
      'into view under the rows', (tester) async {
    await harness.open(tester);
    // A 300 dp keyboard on the 3x surface.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    await typeLine(tester, 'Plan trip');
    await tester.tap(moreOptionsButton());
    await tester.pumpAndSettle();

    final description = tester.getRect(descriptionField());
    expect(description.bottom, lessThanOrEqualTo(phoneSize.height - 300));
    final buttons = tester.getRect(addButton());
    expect(description.bottom, lessThanOrEqualTo(buttons.top));
    expect(
      tester.getRect(inSheet(en.priorityLow)).bottom,
      lessThanOrEqualTo(description.top),
    );
  });

  testWidgets('Add gives every task the description as HTML, the labels, '
      'reminders and repeat; nothing is created before', (tester) async {
    await harness.open(tester);
    await typeLine(tester, 'Plan trip');
    await tapInSheet(tester, en.shortcutTomorrow);
    await tapInSheet(tester, en.newTaskMoreOptions);

    await tester.enterText(
      descriptionField(),
      'Pack <bags>\n\nBook https://example.com',
    );
    await tapInSheet(tester, en.taskEditAddLabel);
    expect(find.byType(LabelPicker), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Road trip'));
    await tester.pump();
    await tester.tap(find.text(en.pickerDone));
    await tester.pumpAndSettle();
    expect(inSheet('Road trip'), findsOneWidget);

    await tapInSheet(tester, en.taskEditAddReminder);
    expect(find.byType(ReminderPicker), findsOneWidget);
    // The presets refer to the sheet's due date.
    await tester.tap(
      find.text(
        en.reminderBefore(en.periodDays(1), en.reminderReferenceDueDate),
      ),
    );
    await tester.pumpAndSettle();

    await tapInSheet(tester, en.repeatModeEvery);
    await tapInSheet(tester, en.repeatPresetWeekly);
    expect(harness.data.tasks.writes, isEmpty);
    expect(harness.service.submits, isEmpty);

    await tester.ensureVisible(addButton());
    await tester.pumpAndSettle();
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    final submit = harness.service.submits.single;
    expect(submit.fallbackDueDate, DateTime(2026, 10, 11, 12).toUtc());
    expect(
      submit.extras,
      QuickAddExtras(
        description: [
          '<p>Pack &lt;bags&gt;</p>',
          '<p>Book <a target="_blank" rel="noopener noreferrer nofollow" ',
          'href="https://example.com">https://example.com</a></p>',
        ].join(),
        labels: [roadTrip],
        reminders: const [
          TaskReminder(
            relativePeriod: Duration(days: -1),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
        ],
        repeatAfter: const Duration(days: 7),
      ),
    );
    expect(find.byType(NewTaskSheet), findsNothing);
    expect(find.text(en.newTaskCreated('Plan trip')), findsOneWidget);
  });

  testWidgets('an invalid repeat keeps Add disabled', (tester) async {
    await harness.open(tester);
    await typeLine(tester, 'Water plants');
    await tapInSheet(tester, en.newTaskMoreOptions);
    await tapInSheet(tester, en.repeatModeEvery);
    expect(addEnabled(tester), isTrue);

    await tester.enterText(amountField(), '0');
    await tester.pump();
    expect(addEnabled(tester), isFalse);
  });

  testWidgets('the keyboard action with an invalid repeat adds nothing and '
      'scrolls to the repeat', (tester) async {
    await harness.open(tester);
    // A 300 dp keyboard on the 3x surface.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    await enterInvalidRepeat(tester);
    await tester.showKeyboard(composerField());
    await tester.ensureVisible(composerField());
    await tester.pumpAndSettle();
    expect(find.text(en.repeatAmountInvalid).hitTestable(), findsNothing);

    tester.takeAnnouncements();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(harness.service.submits, isEmpty);
    expect(find.byType(NewTaskSheet), findsOneWidget);
    expectInView(tester, inSheet(en.repeatAmountInvalid));
    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.repeatAmountInvalid),
    ]);
  });

  testWidgets('with Fewer options an invalid repeat leaves Add enabled, and '
      'Add opens the options at the repeat instead of adding', (tester) async {
    await harness.open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    await enterInvalidRepeat(tester);
    await tapInSheet(tester, en.newTaskFewerOptions);
    expect(inSheet(en.repeatAmountInvalid), findsNothing);
    expect(addEnabled(tester), isTrue);

    tester.takeAnnouncements();
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(harness.service.submits, isEmpty);
    expect(inSheet(en.newTaskFewerOptions), findsOneWidget);
    expectInView(tester, inSheet(en.repeatAmountInvalid));
    expect(addEnabled(tester), isFalse);
    expect(tester.takeAnnouncements(), [
      isAccessibilityAnnouncement(en.repeatAmountInvalid),
    ]);
  });

  Future<void> createLabelInPicker(WidgetTester tester, String title) async {
    await tapInSheet(tester, en.taskEditAddLabel);
    await tester.enterText(
      find.widgetWithText(TextField, en.labelPickerSearch),
      title,
    );
    await tester.pump();
    await tester.tap(find.text(en.labelPickerCreate(title)));
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, en.quickAddNewLabel(title)),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.text(en.pickerDone));
    await tester.pumpAndSettle();
  }

  testWidgets('a label made in the picker is only marked new, and a '
      'dismissed sheet leaves nothing behind', (tester) async {
    await harness.open(tester);
    await typeLine(tester, 'Plan trip');
    await tapInSheet(tester, en.newTaskMoreOptions);
    await createLabelInPicker(tester, 'Errands');

    expect(inSheet(en.quickAddNewLabel('Errands')), findsOneWidget);
    expect(harness.labels.created, isEmpty);
    expect(harness.labels.lookups, isEmpty);
    // The system's back, as the open options cover the scrim.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.taskEditDiscard));
    await tester.pumpAndSettle();

    expect(find.byType(NewTaskSheet), findsNothing);
    expect(harness.labels.created, isEmpty);
    expect(harness.service.submits, isEmpty);
  });

  testWidgets('Add hands the new label to quick add to create, beside the '
      'picked ones', (tester) async {
    await harness.open(tester);
    await typeLine(tester, 'Plan trip');
    await tapInSheet(tester, en.newTaskMoreOptions);
    await createLabelInPicker(tester, 'Errands');
    await tapInSheet(tester, en.taskEditAddLabel);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Road trip'));
    await tester.pump();
    await tester.tap(find.text(en.pickerDone));
    await tester.pumpAndSettle();

    await tester.ensureVisible(addButton());
    await tester.pumpAndSettle();
    await tester.tap(addButton());
    await tester.pumpAndSettle();

    expect(
      harness.service.submits.single.extras,
      QuickAddExtras(labels: [roadTrip], newLabels: const ['Errands']),
    );
    expect(harness.labels.created, isEmpty);
  });

  group('leaving with something typed', () {
    final question = find.text(en.newTaskDiscardTitle);
    final sheet = find.byType(NewTaskSheet);

    Rect sheetRect(WidgetTester tester) =>
        tester.getRect(find.byType(BottomSheet));

    /// From the drag handle, past the sheet's own height.
    Future<void> swipeDown(WidgetTester tester) async {
      final rect = sheetRect(tester);
      await tester.flingFrom(
        rect.topCenter + const Offset(0, 12),
        Offset(0, rect.height),
        2000,
      );
    }

    Future<void> answer(WidgetTester tester, String button) async {
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
    }

    // Not pumpAndSettle: the progress bar of an add that is held never
    // settles.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('nothing typed, Back and a swipe down close the sheet '
        'without asking; spaces alone count as nothing', (tester) async {
      await harness.open(tester);
      await typeLine(tester, '   ');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(question, findsNothing);
      expect(sheet, findsNothing);

      await openSheet(tester);
      await swipeDown(tester);
      await tester.pumpAndSettle();
      expect(question, findsNothing);
      expect(sheet, findsNothing);
    });

    testWidgets('Back with a title typed asks; Keep editing keeps the sheet '
        'and the title, Discard closes it and adds nothing', (tester) async {
      await harness.open(tester);
      await typeLine(tester, 'Buy milk');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(question, findsOneWidget);
      expect(find.text(en.newTaskDiscardBody), findsOneWidget);
      await answer(tester, en.taskEditKeepEditing);
      expect(sheet, findsOneWidget);
      expect(composerText(tester), 'Buy milk');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await answer(tester, en.taskEditDiscard);
      expect(sheet, findsNothing);
      expect(harness.service.submits, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a tap beside the sheet and a description alone ask too', (
      tester,
    ) async {
      await harness.open(tester);
      await tapInSheet(tester, en.newTaskMoreOptions);
      await tester.enterText(descriptionField(), 'Whole milk');
      await tester.pump();
      // The open options cover the scrim; closed, they keep the text.
      await tapInSheet(tester, en.newTaskFewerOptions);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(question, findsOneWidget);
      await answer(tester, en.taskEditKeepEditing);
      expect(sheet, findsOneWidget);
      await tapInSheet(tester, en.newTaskMoreOptions);
      expect(
        tester.widget<TextField>(descriptionField()).controller!.text,
        'Whole milk',
      );
    });

    testWidgets('a swipe down with a title typed brings the sheet back up '
        'and asks; after Keep editing the next swipe asks again', (
      tester,
    ) async {
      await harness.open(tester);
      await typeLine(tester, 'Buy milk');
      final open = sheetRect(tester);

      await swipeDown(tester);
      await tester.pumpAndSettle();
      expect(question, findsOneWidget);
      expect(sheetRect(tester), open);
      await answer(tester, en.taskEditKeepEditing);
      expect(sheet, findsOneWidget);
      expect(sheetRect(tester), open);
      expect(composerText(tester), 'Buy milk');

      await swipeDown(tester);
      await tester.pumpAndSettle();
      expect(question, findsOneWidget);
      await answer(tester, en.taskEditDiscard);
      expect(sheet, findsNothing);
      expect(harness.service.submits, isEmpty);
    });

    testWidgets('while an add runs, also with the title emptied meanwhile, '
        'Back and a swipe down neither close nor ask, and the add closes the '
        'sheet when done', (tester) async {
      final held = Completer<void>();
      harness.service.beforeSubmit = () => held.future;
      await harness.open(tester);
      await typeLine(tester, 'Buy milk');
      final open = sheetRect(tester);
      await tester.tap(addButton());
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      expect(question, findsNothing);
      expect(sheet, findsOneWidget);
      await tester.enterText(composerField(), '');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await swipeDown(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(question, findsNothing);
      expect(sheet, findsOneWidget);
      expect(sheetRect(tester), open);

      held.complete();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.text(en.newTaskCreated('Buy milk')), findsOneWidget);
    });

    testWidgets('an add that ends while the project picker is open closes the '
        'picker and the sheet, and shows the confirmation', (tester) async {
      final held = Completer<void>();
      harness.service.beforeSubmit = () => held.future;
      await harness.open(tester);
      await typeLine(tester, 'Buy milk');
      await tester.tap(addButton());
      await tester.pump();

      await tester.tap(projectField('Inbox'));
      await settle(tester);
      expect(find.text(en.taskEditProjectPickerTitle), findsOneWidget);

      held.complete();
      await settle(tester);
      expect(find.text(en.taskEditProjectPickerTitle), findsNothing);
      expect(sheet, findsNothing);
      expect(find.text(en.newTaskCreated('Buy milk')), findsOneWidget);
      expect(harness.service.submits.single.fallbackProjectId, 2);
      expect(
        routerOf(tester).routerDelegate.state.matchedLocation,
        AppRoutes.overview,
      );
    });

    testWidgets('an add that ends while the help is open closes the help and '
        'the sheet too', (tester) async {
      final held = Completer<void>();
      harness.service.beforeSubmit = () => held.future;
      await harness.open(tester);
      await typeLine(tester, 'Buy milk');
      await tester.tap(addButton());
      await tester.pump();

      await tester.tap(find.byTooltip(en.quickAddHelp));
      await settle(tester);
      expect(find.byType(QuickAddHelpSheet), findsOneWidget);

      held.complete();
      await settle(tester);
      expect(find.byType(QuickAddHelpSheet), findsNothing);
      expect(sheet, findsNothing);
      expect(find.text(en.newTaskCreated('Buy milk')), findsOneWidget);
    });

    testWidgets("an add that ends while a reminder's time is picked closes "
        'every picker and the sheet, and the page under them stays', (
      tester,
    ) async {
      final held = Completer<void>();
      harness.service.beforeSubmit = () => held.future;
      await harness.open(tester);
      await typeLine(tester, 'Buy milk');
      await tapInSheet(tester, en.newTaskMoreOptions);
      await tester.ensureVisible(addButton());
      await tester.pumpAndSettle();
      await tester.tap(addButton());
      await tester.pump();

      await tester.ensureVisible(inSheet(en.taskEditAddReminder));
      await tester.pump();
      await tester.tap(inSheet(en.taskEditAddReminder));
      await settle(tester);
      await tester.tap(find.text(en.reminderPickerDateTime));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(find.byType(TimePickerDialog), findsOneWidget);

      held.complete();
      await settle(tester);
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.byType(ReminderPicker), findsNothing);
      expect(sheet, findsNothing);
      expect(find.text(en.newTaskCreated('Buy milk')), findsOneWidget);
      expect(
        routerOf(tester).routerDelegate.state.matchedLocation,
        AppRoutes.overview,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('with the pin on, the sheet an add emptied closes without '
        'asking', (tester) async {
      harness.data.listPreferences.newTaskKeepOpen = true;
      await harness.open(tester);
      await typeLine(tester, 'Buy milk');
      await tester.tap(addButton());
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);

      await swipeDown(tester);
      await tester.pumpAndSettle();
      expect(question, findsNothing);
      expect(sheet, findsNothing);
    });
  });

  group('kept open', () {
    Finder pin() => find.ancestor(
      of: find.byTooltip(en.newTaskKeepOpen),
      matching: find.byType(IconButton),
    );

    bool pinned(WidgetTester tester) =>
        tester.widget<IconButton>(pin()).isSelected!;

    Future<void> tapPin(WidgetTester tester) async {
      await tester.tap(pin());
      await tester.pumpAndSettle();
    }

    bool titleFocused(WidgetTester tester) => tester
        .widget<EditableText>(
          find.descendant(
            of: composerField(),
            matching: find.byType(EditableText),
          ),
        )
        .focusNode
        .hasFocus;

    Future<void> add(WidgetTester tester) async {
      await tester.ensureVisible(addButton());
      await tester.pumpAndSettle();
      await tester.tap(addButton());
      await tester.pumpAndSettle();
    }

    testWidgets('with the pin on, Add empties the title for the next task '
        'and keeps the sheet, the focus, the project, the due date and the '
        'priority; the add is confirmed under the title and announced', (
      tester,
    ) async {
      await harness.open(tester, projectId: 3);
      expect(pinned(tester), isFalse);
      await tapPin(tester);
      expect(pinned(tester), isTrue);
      expect(harness.data.listPreferences.saves, ['newTaskKeepOpen']);

      await typeLine(tester, 'Buy milk');
      await tapInSheet(tester, en.shortcutTomorrow);
      await tapInSheet(tester, en.priorityHigh);
      tester.takeAnnouncements();
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(composerText(tester), isEmpty);
      expect(titleFocused(tester), isTrue);
      expect(addEnabled(tester), isFalse);
      expect(inSheet(en.newTaskCreated('Buy milk')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.newTaskCreated('Buy milk')),
      ]);
      expect(projectField('Garage Sale'), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(choiceChip(en.shortcutTomorrow)).selected,
        isTrue,
      );
      expect(
        tester.widget<ChoiceChip>(choiceChip(en.priorityHigh)).selected,
        isTrue,
      );

      await typeLine(tester, 'Buy eggs');
      expect(inSheet(en.newTaskCreated('Buy milk')), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(harness.service.submits, [
        for (final text in ['Buy milk', 'Buy eggs'])
          (
            text: text,
            fallbackProjectId: 3,
            fallbackDueDate: DateTime(2026, 10, 11, 12).toUtc(),
            fallbackPriority: TaskPriority.high.value,
            extras: const QuickAddExtras(),
          ),
      ]);
      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(inSheet(en.newTaskCreated('Buy eggs')), findsOneWidget);
      expect(titleFocused(tester), isTrue);
    });

    testWidgets('Add pressed from a keyboard puts the focus back in the '
        'title, not on the control focused before', (tester) async {
      harness.data.listPreferences.newTaskKeepOpen = true;
      await harness.open(tester);
      await typeLine(tester, 'Buy milk');
      void focusOn(Finder control, String label) => Focus.of(
        tester.element(
          find.descendant(of: control, matching: find.text(label)),
        ),
      ).requestFocus();
      focusOn(choiceChip(en.priorityHigh), en.priorityHigh);
      await tester.pump();
      focusOn(addButton(), en.newTaskAdd);
      await tester.pump();
      expect(titleFocused(tester), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(harness.service.submits.single.text, 'Buy milk');
      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(titleFocused(tester), isTrue);
    });

    testWidgets('the description empties, while the labels and the repeat '
        'stay for the next task', (tester) async {
      harness.data.listPreferences.newTaskKeepOpen = true;
      await harness.open(tester);
      await typeLine(tester, 'Plan trip');
      await tapInSheet(tester, en.newTaskMoreOptions);
      await tester.enterText(descriptionField(), 'Pack bags');
      await tapInSheet(tester, en.taskEditAddLabel);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Road trip'));
      await tester.pump();
      await tester.tap(find.text(en.pickerDone));
      await tester.pumpAndSettle();
      await tapInSheet(tester, en.repeatModeEvery);
      await tapInSheet(tester, en.repeatPresetWeekly);
      await add(tester);

      expect(
        tester.widget<TextField>(descriptionField()).controller!.text,
        isEmpty,
      );
      expect(inSheet('Road trip'), findsOneWidget);
      await typeLine(tester, 'Book hotel');
      await add(tester);

      expect(harness.service.submits.map((submit) => submit.extras), [
        QuickAddExtras(
          description: '<p>Pack bags</p>',
          labels: [roadTrip],
          repeatAfter: const Duration(days: 7),
        ),
        QuickAddExtras(
          labels: [roadTrip],
          repeatAfter: const Duration(days: 7),
        ),
      ]);
      expect(find.byType(NewTaskSheet), findsOneWidget);
    });

    testWidgets('what is typed while an add runs stays for the next task; '
        'only what was added leaves the title and the description', (
      tester,
    ) async {
      harness.data.listPreferences.newTaskKeepOpen = true;
      var held = Completer<void>();
      harness.service.beforeSubmit = () => held.future;
      Future<void> startAdd() async {
        await tester.ensureVisible(addButton());
        await tester.pumpAndSettle();
        await tester.tap(addButton());
        await tester.pump();
      }

      await harness.open(tester);
      await typeLine(tester, 'Buy milk');
      await tapInSheet(tester, en.newTaskMoreOptions);
      await tester.enterText(descriptionField(), 'Whole');
      await startAdd();
      expect(harness.service.submits.single.text, 'Buy milk');

      await tester.enterText(composerField(), 'Buy eggs');
      await tester.enterText(descriptionField(), 'Free range');
      await tester.pump();
      held.complete();
      await tester.pumpAndSettle();

      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(inSheet(en.newTaskCreated('Buy milk')), findsOneWidget);
      expect(composerText(tester), 'Buy eggs');
      expect(
        tester.widget<TextField>(descriptionField()).controller!.text,
        'Free range',
      );

      held = Completer<void>();
      await tester.enterText(descriptionField(), '');
      await startAdd();
      expect(harness.service.submits.last.text, 'Buy eggs');
      await setComposerText(tester, 'Buy eggs Buy bread');
      held.complete();
      await tester.pumpAndSettle();

      final title = composerController(tester).value;
      expect(title.text, 'Buy bread');
      expect(title.selection, const TextSelection.collapsed(offset: 9));
    });

    testWidgets('the warnings of an add show under the title too', (
      tester,
    ) async {
      harness.data.listPreferences.newTaskKeepOpen = true;
      harness.service.result = const QuickAddResult(
        createdTaskIds: [-1],
        labelsNotCreated: ['Errands'],
      );
      await harness.open(tester);
      await typeLine(tester, 'Plan trip');
      tester.takeAnnouncements();
      await add(tester);

      final confirmation = [
        en.newTaskCreated('Plan trip'),
        en.newTaskLabelsNotCreated('Errands'),
      ].join('\n');
      expect(inSheet(confirmation), findsOneWidget);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(confirmation),
      ]);
    });

    testWidgets('at 200 % text on a phone the warning under the title shows '
        'whole, the names at its end included', (tester) async {
      usePhoneSurface(tester);
      useAccessibilityExtremes(tester);
      harness.data.listPreferences.newTaskKeepOpen = true;
      harness.service.result = const QuickAddResult(
        createdTaskIds: [-1],
        labelsNotCreated: ['Errands', 'Groceries'],
      );
      await harness.open(tester);
      await typeLine(tester, 'Buy milk at the farm shop');
      await add(tester);

      final confirmation = [
        en.newTaskCreated('Buy milk at the farm shop'),
        en.newTaskLabelsNotCreated('Errands, Groceries'),
      ].join('\n');
      expect(inSheet(confirmation), findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(inSheet(confirmation)),
        isA<RenderParagraph>().having(
          (paragraph) => paragraph.didExceedMaxLines,
          'didExceedMaxLines',
          isFalse,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pin is remembered for the next sheet, and turned off '
        'Add closes the sheet again', (tester) async {
      await harness.open(tester);
      await tapPin(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NewTaskSheet), findsNothing);

      await openSheet(tester);
      expect(pinned(tester), isTrue);
      await tapPin(tester);
      expect(pinned(tester), isFalse);
      expect(harness.data.listPreferences.newTaskKeepOpen, isFalse);
      await typeLine(tester, 'Buy milk');
      await add(tester);

      expect(find.byType(NewTaskSheet), findsNothing);
      expect(find.text(en.newTaskCreated('Buy milk')), findsOneWidget);
    });

    testWidgets('the pin is a toggle named for what it does, beside the '
        'headline', (tester) async {
      final semantics = tester.ensureSemantics();
      await harness.open(tester);

      expect(
        tester.getSemantics(pin()),
        isSemantics(
          tooltip: en.newTaskKeepOpen,
          isButton: true,
          hasToggledState: true,
          isToggled: false,
        ),
      );
      await tapPin(tester);
      expect(
        tester.getSemantics(pin()),
        isSemantics(hasToggledState: true, isToggled: true),
      );
      final heading = tester.getSemantics(inSheet(en.newTask));
      expect(heading, isSemantics(isHeader: true));
      expect(heading.getSemanticsData().headingLevel, 1);
      final headline = tester.getRect(inSheet(en.newTask));
      expect(
        tester.getRect(pin()).center.dy,
        moreOrLessEquals(headline.center.dy, epsilon: 1),
      );
      expect(
        tester.getRect(pin()).bottom,
        lessThanOrEqualTo(tester.getRect(composerField()).top),
      );
      semantics.dispose();
    });
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await harness.pumpApp(tester);
    expect(find.text(de.newTask), findsOneWidget);
    await openSheet(tester);

    expect(find.text(de.newTaskAdd), findsOneWidget);
    expect(find.text(de.shortcutTomorrow), findsOneWidget);
    expect(find.text(de.priorityDoNow), findsOneWidget);
    await tapInSheet(tester, de.newTaskMoreOptions);
    expect(find.text(de.newTaskFewerOptions), findsOneWidget);
    expect(
      find.widgetWithText(TextField, de.taskDetailDescription),
      findsOneWidget,
    );
  });

  testWidgets('at 200 % text scale in dark mode the sheet still adds', (
    tester,
  ) async {
    useAccessibilityExtremes(tester);
    await harness.open(tester);

    await typeLine(tester, 'Big text');
    await tester.pumpAndSettle();
    await tapInSheet(tester, en.newTaskMoreOptions);
    await tapInSheet(tester, en.repeatModeEvery);
    await tester.ensureVisible(inSheet(en.repeatPresetDaily));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(addButton());
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
