import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';

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

  Finder choiceChip(String label) =>
      find.ancestor(of: inSheet(label), matching: find.byType(ChoiceChip));

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
                widget is SingleChildScrollView &&
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

  testWidgets('tapping a selected shortcut again clears the due date', (
    tester,
  ) async {
    await harness.open(tester);
    Finder tomorrowChip() => choiceChip(en.shortcutTomorrow);

    await typeLine(tester, 'Buy milk');
    await tapInSheet(tester, en.shortcutTomorrow);
    expect(tester.widget<ChoiceChip>(tomorrowChip()).selected, isTrue);
    await tapInSheet(tester, en.shortcutTomorrow);

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
    void expectRowsInView() {
      for (final row in [
        [
          en.shortcutToday,
          en.shortcutTomorrow,
          en.shortcutNextWeek,
          en.newTaskPickDate,
        ],
        [
          en.priorityLow,
          en.priorityMedium,
          en.priorityHigh,
          en.priorityUrgent,
          en.priorityDoNow,
        ],
      ]) {
        final rects = [for (final label in row) tester.getRect(inSheet(label))];
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
    // A date in the text adds a chip under the field; the sheet's own
    // priority and date repeat none.
    await typeLine(tester, 'Buy milk tomorrow');
    await tester.pumpAndSettle();
    expectRowsInView();
    await typeLine(tester, '');
    await tester.pumpAndSettle();
    await tapInSheet(tester, en.priorityHigh);
    await tapInSheet(tester, en.shortcutTomorrow);
    await typeLine(tester, 'Buy milk');
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsNothing);
    expectRowsInView();
    await typeLine(tester, 'Buy milk tomorrow');
    await tester.pumpAndSettle();
    expectRowsInView();
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
