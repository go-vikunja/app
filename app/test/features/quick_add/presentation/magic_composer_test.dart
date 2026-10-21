import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_spans.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_suggestions.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_text_controller.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_toolbar.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/quick_add_help_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/sample_data.dart';
import 'composer_harness.dart';

void main() {
  late ComposerHarness harness;

  setUp(() => harness = ComposerHarness());

  const mixed =
      'Reifen wechseln *urgent *neu +Work @sam !3 tomorrow at 9:00 '
      'every week';
  final mixedDue = en.quickAddDueLabel('Sun, Oct 11 9:00 AM', 'in 21 hours');

  List<(String, MagicSpanKind?, FontWeight?)> highlighted(WidgetTester tester) {
    final context = tester.element(composerField());
    final span = composerController(tester)
        .buildTextSpan(context: context, withComposing: false);
    final kinds = {
      for (final kind in MagicSpanKind.values)
        MagicColors.of(context, kind).$2: kind,
    };
    return [
      for (final child in span.children ?? const <InlineSpan>[])
        if (child case TextSpan(:final text?, :final style?))
          (text, kinds[style.backgroundColor], style.fontWeight),
    ];
  }

  Finder chip(String label) => find.widgetWithText(Chip, label);

  Future<void> removeChip(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: chip(label), matching: find.byIcon(Icons.close)),
    );
    await tester.pump();
  }

  Finder suggestion(String label) => find.descendant(
    of: find.byType(MagicSuggestions),
    matching: find.widgetWithText(ActionChip, label),
  );

  Finder addButton([int count = 1]) => find.widgetWithText(
    FilledButton,
    count == 1 ? en.newTaskAdd : en.newTaskAddMany(count),
  );

  bool fieldFocused(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

  Finder projectField(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ProjectField));

  Finder pickDateChip() => find.ancestor(
    of: find.text(en.newTaskPickDate),
    matching: find.byType(ActionChip),
  );

  Finder shortcutChip(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));

  group('highlighting', () {
    testWidgets('each recognised part in its colour and a heavier weight', (
      tester,
    ) async {
      await harness.open(tester);
      await typeLine(tester, mixed);

      expect(highlighted(tester), [
        ('*urgent', MagicSpanKind.label, FontWeight.w700),
        ('*neu', MagicSpanKind.label, FontWeight.w700),
        ('+Work', MagicSpanKind.project, FontWeight.w700),
        ('@sam', MagicSpanKind.assignee, FontWeight.w700),
        ('!3', MagicSpanKind.priority, FontWeight.w700),
        ('tomorrow at 9:00', MagicSpanKind.date, FontWeight.w700),
        ('every week', MagicSpanKind.repeat, FontWeight.w700),
      ]);
    });

    testWidgets('an unknown project is underlined, warned about and the '
        'fallback project stays choosable', (tester) async {
      await harness.open(tester);
      await typeLine(tester, 'Call +Nowhere');

      final context = tester.element(composerField());
      final span = composerController(tester)
          .buildTextSpan(context: context, withComposing: false);
      final marked = span.children!.cast<TextSpan>().singleWhere(
        (child) => child.text == '+Nowhere',
      );
      expect(marked.style?.decorationStyle, TextDecorationStyle.wavy);
      expect(marked.style?.fontWeight, FontWeight.w700);
      expect(chip(en.quickAddProjectNotFound('Nowhere')), findsOneWidget);
      expect(
        tester.widget<ProjectField>(projectField('Inbox')).onPressed,
        isNotNull,
      );
    });

    testWidgets('nothing while the line is only magic', (tester) async {
      await harness.open(tester);
      await typeLine(tester, '*urgent tomorrow');

      expect(highlighted(tester), isEmpty);
      expect(find.text(en.quickAddMagicOnly('*urgent tomorrow')), findsOne);
    });
  });

  group('preview', () {
    testWidgets('chips for everything the line creates', (tester) async {
      harness.settings = const UserSettings(
        quickAddDefaultReminders: [Duration(days: -1)],
      );
      await harness.open(tester);
      await typeLine(tester, mixed);

      for (final label in [
        mixedDue,
        en.repeatEveryWeeks(1),
        'Work',
        'urgent',
        en.quickAddNewLabel('neu'),
        'Sam Example',
        en.prioritySemantics(en.priorityHigh),
        en.reminderBefore(en.periodDays(1), en.reminderReferenceDueDate),
      ]) {
        expect(chip(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('people not known here are looked up when adding', (
      tester,
    ) async {
      await harness.open(tester);
      await typeLine(tester, 'Ask @bob');

      expect(chip(en.quickAddLookedUp('@bob')), findsOneWidget);
    });

    testWidgets('each chip removes its part and the field keeps the focus', (
      tester,
    ) async {
      await harness.open(tester);
      await typeLine(tester, mixed);

      await removeChip(tester, 'urgent');
      expect(
        composerText(tester),
        'Reifen wechseln *neu +Work @sam !3 tomorrow at 9:00 every week',
      );
      await removeChip(tester, mixedDue);
      expect(
        composerText(tester),
        'Reifen wechseln *neu +Work @sam !3 every week',
      );
      await removeChip(tester, en.repeatEveryWeeks(1));
      expect(composerText(tester), 'Reifen wechseln *neu +Work @sam !3');
      await removeChip(tester, 'Work');
      expect(composerText(tester), 'Reifen wechseln *neu @sam !3');
      await removeChip(tester, 'Sam Example');
      expect(composerText(tester), 'Reifen wechseln *neu !3');
      await removeChip(tester, en.prioritySemantics(en.priorityHigh));
      expect(composerText(tester), 'Reifen wechseln *neu');
      await removeChip(tester, en.quickAddNewLabel('neu'));
      expect(composerText(tester), 'Reifen wechseln');
      expect(find.byType(Chip), findsNothing);
      expect(fieldFocused(tester), isTrue);
    });

    testWidgets('a due date from a repeat alone has nothing to remove', (
      tester,
    ) async {
      await harness.open(tester);
      await typeLine(tester, 'Water plants every 3 days');

      final due = en.quickAddDueLabel('Sat, Oct 10 12:00 PM', en.relativeNow);
      expect(chip(due), findsOneWidget);
      expect(tester.widget<Chip>(chip(due)).onDeleted, isNull);
      expect(chip(en.repeatEveryDays(3)), findsOneWidget);
    });

    testWidgets('chips read out what they stand for', (tester) async {
      final semantics = tester.ensureSemantics();
      await harness.open(tester);
      await typeLine(tester, 'Call Sam tomorrow at 9:00 *urgent');

      final due = en.quickAddDueSemantics('Sun, Oct 11 9:00 AM', 'in 21 hours');
      expect(
        find.bySemanticsLabel(RegExp('^${RegExp.escape(due)}')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^${en.labelSemantics('urgent')}')),
        findsOneWidget,
      );
      expect(find.byTooltip(en.quickAddRemovePart(due)), findsOneWidget);
      expect(
        find.byTooltip(en.quickAddRemovePart(en.labelSemantics('urgent'))),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('suggestions', () {
    testWidgets('labels complete the token, quoted when it has spaces', (
      tester,
    ) async {
      await harness.open(tester);
      await typeLine(tester, 'Pack *ro');
      await tester.pump();

      expect(suggestion('urgent'), findsNothing);
      await tester.tap(suggestion('Road trip'));
      await tester.pump();

      expect(composerText(tester), 'Pack *"Road trip" ');
      expect(
        composerController(tester).selection,
        const TextSelection.collapsed(offset: 18),
      );
      expect(find.byType(MagicSuggestions), findsNothing);
      expect(fieldFocused(tester), isTrue);
    });

    testWidgets('projects by title or identifier, never archived ones', (
      tester,
    ) async {
      await harness.open(tester);
      await typeLine(tester, 'Sell +gar');

      expect(suggestion('Gardening'), findsNothing);
      await tester.tap(suggestion('Garage Sale'));
      await tester.pump();
      expect(composerText(tester), 'Sell +"Garage Sale" ');

      await typeLine(tester, 'Report +wrk');
      expect(suggestion('Work'), findsOneWidget);
    });

    testWidgets('projects of the same title show their parents and complete '
        'what tells them apart', (tester) async {
      harness.data.projects.all = [
        ...harness.data.projects.all,
        sampleProject(id: 7, title: 'Backlog', parent: 1, identifier: 'WB'),
        sampleProject(id: 8, title: 'Backlog', parent: 3, identifier: 'GB'),
      ];
      await harness.open(tester);
      await typeLine(tester, 'Fix fence +back');

      expect(suggestion('Work › Backlog'), findsOneWidget);
      await tester.ensureVisible(suggestion('Garage Sale › Backlog'));
      await tester.pump();
      await tester.tap(suggestion('Garage Sale › Backlog'));
      await tester.pump();

      expect(composerText(tester), 'Fix fence +GB ');
      expect(chip('Garage Sale › Backlog'), findsOneWidget);
      expect(projectField('Garage Sale › Backlog'), findsOneWidget);
    });

    testWidgets('a title several projects share without anything telling '
        'them apart is warned about', (tester) async {
      harness.data.projects.all = [
        ...harness.data.projects.all,
        sampleProject(id: 7, title: 'Backlog', parent: 1),
        sampleProject(id: 8, title: 'Backlog', parent: 3),
      ];
      await harness.open(tester);
      await typeLine(tester, 'Fix fence +Backlog');

      expect(chip('Work › Backlog'), findsOneWidget);
      expect(chip(en.quickAddProjectAmbiguous('Backlog')), findsOneWidget);
    });

    testWidgets('people known here at once, the server search once typing '
        'pauses, and only the latest query counts', (tester) async {
      final firstAnswer = Completer<void>();
      harness.users.beforeAnswer = (query) =>
          query == 'a' ? firstAnswer.future : Future.value();
      await harness.open(tester);

      await typeLine(tester, 'Ask @a');
      await tester.pump();
      expect(suggestion('Sam Example'), findsOneWidget);
      expect(suggestion('Alex Doe'), findsNothing);
      expect(harness.users.searches, isEmpty);

      await tester.pump(MagicSuggestions.debounce);
      expect(harness.users.searches, [(2, 'a')]);
      await typeLine(tester, 'Ask @al');
      await tester.pump(MagicSuggestions.debounce ~/ 2);
      expect(harness.users.searches, [(2, 'a')]);
      await tester.pump(MagicSuggestions.debounce);
      await tester.pump();
      expect(harness.users.searches, [(2, 'a'), (2, 'al')]);
      expect(suggestion('Alex Doe'), findsOneWidget);
      expect(suggestion('Sam Example'), findsNothing);

      firstAnswer.complete();
      await tester.pump();
      expect(suggestion('Sam Example'), findsNothing);
      await tester.tap(suggestion('Alex Doe'));
      await tester.pump();
      expect(composerText(tester), 'Ask @alex ');
    });

    testWidgets('people search in the project the line names', (tester) async {
      await harness.open(tester);
      await typeLine(tester, 'Plan +Work @s');
      await tester.pump(MagicSuggestions.debounce);

      expect(harness.users.searches, [(1, 's')]);
    });

    testWidgets('offline the people known here still show', (tester) async {
      harness.users.searchFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await harness.open(tester);
      await typeLine(tester, 'Ask @s');
      await tester.pump(MagicSuggestions.debounce);
      await tester.pump();

      expect(suggestion('Sam Example'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('toolbar', () {
    testWidgets('inserts the prefixes at the caret and sets the priority', (
      tester,
    ) async {
      await harness.open(tester);
      await setComposerText(tester, 'Buy milk', caret: 3);

      await tester.tap(find.byTooltip(en.quickAddInsertLabel('*')));
      await tester.pump();
      await tester.pump();
      expect(composerText(tester), 'Buy * milk');
      expect(composerController(tester).selection.baseOffset, 5);
      expect(suggestion('urgent'), findsOneWidget);
      expect(suggestion('Road trip'), findsOneWidget);

      await setComposerText(tester, 'Buy milk');
      await tester.tap(find.byTooltip(en.quickAddInsertProject('+')));
      await tester.pump();
      expect(composerText(tester), 'Buy milk +');

      await setComposerText(tester, 'Buy milk');
      await tester.tap(find.byTooltip(en.quickAddInsertAssignee('@')));
      await tester.pump();
      expect(composerText(tester), 'Buy milk @');

      await setComposerText(tester, 'Buy milk');
      await tester.tap(find.byTooltip(en.quickAddSetPriority('!')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.priorityHigh));
      await tester.pumpAndSettle();
      expect(composerText(tester), 'Buy milk !3 ');

      // A second priority replaces the first.
      await tester.tap(find.byTooltip(en.quickAddSetPriority('!')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.priorityDoNow));
      await tester.pumpAndSettle();
      expect(composerText(tester), 'Buy milk !5 ');
      expect(fieldFocused(tester), isTrue);
    });

    testWidgets('a selected word becomes the item of the prefix', (
      tester,
    ) async {
      await harness.open(tester);
      composerController(tester).value = const TextEditingValue(
        text: 'Buy oat milk',
        selection: TextSelection(baseOffset: 4, extentOffset: 12),
      );
      await tester.pump();

      await tester.tap(find.byTooltip(en.quickAddInsertLabel('*')));
      await tester.pump();
      expect(composerText(tester), 'Buy *"oat milk"');

      composerController(tester).value = const TextEditingValue(
        text: 'Buy milk',
        selection: TextSelection(baseOffset: 4, extentOffset: 8),
      );
      await tester.pump();
      await tester.tap(find.byTooltip(en.quickAddSetPriority('!')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.priorityHigh));
      await tester.pumpAndSettle();
      expect(composerText(tester), 'Buy milk !3 ');
    });

    testWidgets('help explains the syntax in the prefixes of the mode', (
      tester,
    ) async {
      harness.settings = const UserSettings(
        quickAddMagicMode: QuickAddMagicMode.todoist,
      );
      await harness.open(tester);
      await tester.tap(find.byTooltip(en.quickAddHelp));
      await tester.pumpAndSettle();

      expect(find.byType(QuickAddHelpSheet), findsOneWidget);
      expect(
        find.text(
          '${en.quickAddHelpExampleTask} @car #Home !3 tomorrow at 9:00 '
          'every week',
        ),
        findsOneWidget,
      );
      expect(find.text(en.quickAddHelpLabelsBody('@')), findsOneWidget);
      // The 27th of next month, never a date in the past.
      for (final example in ['nov 27', '27/11', '2026-11-27']) {
        await tester.scrollUntilVisible(
          find.text(example),
          200,
          scrollable: find
              .descendant(
                of: find.byType(QuickAddHelpSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      await tester.scrollUntilVisible(
        find.text(en.quickAddHelpEnglish),
        200,
        scrollable: find
            .descendant(
              of: find.byType(QuickAddHelpSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(en.quickAddHelpMode('Todoist')), findsOneWidget);
    });
  });

  group('modes', () {
    testWidgets('todoist prefixes everywhere', (tester) async {
      harness.settings = const UserSettings(
        quickAddMagicMode: QuickAddMagicMode.todoist,
      );
      await harness.open(tester);

      expect(find.byTooltip(en.quickAddInsertLabel('@')), findsOneWidget);
      expect(find.byTooltip(en.quickAddInsertProject('#')), findsOneWidget);
      expect(find.byTooltip(en.quickAddInsertAssignee('+')), findsOneWidget);
      await typeLine(tester, 'Buy milk @ro');
      await tester.pump();
      expect(suggestion('Road trip'), findsOneWidget);

      await typeLine(tester, 'Buy milk @urgent #Work +sam tomorrow');
      expect(highlighted(tester), [
        ('@urgent', MagicSpanKind.label, FontWeight.w700),
        ('#Work', MagicSpanKind.project, FontWeight.w700),
        ('+sam', MagicSpanKind.assignee, FontWeight.w700),
        ('tomorrow', MagicSpanKind.date, FontWeight.w700),
      ]);
    });

    testWidgets('with magic off the field is plain', (tester) async {
      harness.settings = const UserSettings(
        quickAddMagicMode: QuickAddMagicMode.disabled,
      );
      await harness.open(tester);

      expect(find.byType(MagicToolbar), findsNothing);
      await typeLine(tester, 'Buy *milk tomorrow');
      expect(composerController(tester).highlighter, isNull);
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(MagicSuggestions), findsNothing);
      await tester.tap(addButton());
      await tester.pumpAndSettle();
      expect(harness.service.submits.single.text, 'Buy *milk tomorrow');
    });
  });

  group('fallback chips', () {
    testWidgets('a date in the text shows on the due chips, which wait '
        'until it is removed', (tester) async {
      await harness.open(tester);
      await typeLine(tester, 'Call Sam tomorrow');

      var tomorrow = tester.widget<ChoiceChip>(
        shortcutChip(en.shortcutTomorrow),
      );
      expect(tomorrow.selected, isTrue);
      expect(tomorrow.onSelected, isNull);
      expect(tester.widget<ActionChip>(pickDateChip()).onPressed, isNull);

      await removeChip(
        tester,
        en.quickAddDueLabel('Sun, Oct 11 12:00 PM', en.relativeInDays(1)),
      );
      expect(composerText(tester), 'Call Sam');
      tomorrow = tester.widget<ChoiceChip>(shortcutChip(en.shortcutTomorrow));
      expect(tomorrow.selected, isFalse);
      expect(tomorrow.onSelected, isNotNull);
    });

    testWidgets('a +project in the text shows on the project field, which '
        'waits until it is removed', (tester) async {
      await harness.open(tester);
      await typeLine(tester, 'Plan +Work ');

      expect(
        tester.widget<ProjectField>(projectField('Work')).onPressed,
        isNull,
      );
      await typeLine(tester, 'Plan');
      expect(
        tester.widget<ProjectField>(projectField('Inbox')).onPressed,
        isNotNull,
      );
    });

    testWidgets('with several lines the fallbacks stay choosable until '
        'every line has its own', (tester) async {
      await harness.open(tester);
      await typeLine(tester, 'Call mom tomorrow +Work\nBuy milk\nPay rent');

      final tomorrow = tester.widget<ChoiceChip>(
        shortcutChip(en.shortcutTomorrow),
      );
      expect(tomorrow.selected, isFalse);
      expect(tomorrow.onSelected, isNotNull);
      expect(
        tester.widget<ProjectField>(projectField('Inbox')).onPressed,
        isNotNull,
      );

      await typeLine(tester, 'Call mom tomorrow +Work\nBuy milk +Work friday');
      expect(
        tester.widget<ChoiceChip>(shortcutChip(en.shortcutTomorrow)).onSelected,
        isNull,
      );
      expect(
        tester.widget<ProjectField>(projectField('Work')).onPressed,
        isNull,
      );
    });

    testWidgets('the due chip goes to quick add for the lines without a '
        'date of their own', (tester) async {
      harness.service.result = const QuickAddResult(createdTaskIds: [-1, -2]);
      await harness.open(tester);
      await tester.tap(find.text(en.shortcutTomorrow));
      await tester.pump();
      await typeLine(tester, 'Buy milk\nCall Sam friday');
      await tester.tap(addButton(2));
      await tester.pumpAndSettle();

      expect(harness.service.submits, [
        (
          text: 'Buy milk\nCall Sam friday',
          fallbackProjectId: 2,
          fallbackDueDate: DateTime(2026, 10, 11, 12).toUtc(),
        ),
      ]);
      expect(harness.data.tasks.updates, isEmpty);
    });
  });

  group('adding', () {
    testWidgets('hands the text and the fallback project to quick add and '
        'confirms', (tester) async {
      await harness.open(tester, projectId: 3);
      await typeLine(tester, mixed);
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(harness.service.submits, [
        (text: mixed, fallbackProjectId: 3, fallbackDueDate: null),
      ]);
      expect(find.byType(NewTaskSheet), findsNothing);
      expect(find.text(en.newTaskCreated('Reifen wechseln')), findsOneWidget);
    });

    testWidgets('several lines make several tasks', (tester) async {
      harness.service.result = const QuickAddResult(
        createdTaskIds: [-1, -2, -3],
      );
      await harness.open(tester);
      const text = 'Buy milk *urgent\n\n- Call Sam\n- Water plants';
      await typeLine(tester, text);

      expect(addButton(3), findsOneWidget);
      expect(find.text(en.newTaskLineCount(3)), findsOneWidget);
      expect(chip('urgent'), findsOneWidget);
      expect(highlighted(tester), [
        ('*urgent', MagicSpanKind.label, FontWeight.w700),
      ]);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(harness.service.submits, [
        (text: text, fallbackProjectId: 2, fallbackDueDate: null),
      ]);
      expect(find.text(en.newTaskCreatedMany(3)), findsOneWidget);
    });

    testWidgets('a pasted plain list says only how many tasks it makes', (
      tester,
    ) async {
      await harness.open(tester);
      await typeLine(tester, 'Milk\nEggs\nBread');

      expect(find.text(en.newTaskLineCountOnly(3)), findsOneWidget);
      expect(find.text(en.newTaskLineCount(3)), findsNothing);
    });

    testWidgets('an add that fails partway keeps only the lines not added', (
      tester,
    ) async {
      harness.service.submitError = const QuickAddPartlyFailed(
        createdTaskIds: [-1, -2],
        lineCount: 4,
        remainingText: 'Three\nFour',
        cause: Forbidden(message: 'No access'),
      );
      await harness.open(tester);
      await typeLine(tester, 'One\nTwo\nThree\nFour');
      await tester.tap(addButton(4));
      await tester.pumpAndSettle();

      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(composerText(tester), 'Three\nFour');
      expect(
        find.text(
          '${en.newTaskAddedPartly(2, 4)} ${en.newTaskAddFailed('No access')}',
        ),
        findsOneWidget,
      );
      expect(addButton(2), findsOneWidget);
    });

    testWidgets('the confirmation names labels not created and people not '
        'found', (tester) async {
      harness.service.result = const QuickAddResult(
        createdTaskIds: [-1],
        labelsNotCreated: ['neu'],
        unresolvedAssignees: ['bob'],
      );
      await harness.open(tester);
      await typeLine(tester, 'Fix bike *neu @bob');
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.text(en.newTaskCreated('Fix bike @bob')), findsOneWidget);
      expect(find.text(en.newTaskLabelsNotCreated('neu')), findsOneWidget);
      expect(find.text(en.newTaskNamesKept('@bob')), findsOneWidget);
    });

    testWidgets('names the server found leave the confirmed title', (
      tester,
    ) async {
      harness.service.result = const QuickAddResult(createdTaskIds: [-1]);
      await harness.open(tester);
      await typeLine(tester, 'Fix bike @alex');
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.text(en.newTaskCreated('Fix bike')), findsOneWidget);
    });

    testWidgets('a person known here whom the server did not accept stays '
        'in the confirmed title', (tester) async {
      harness.service.result = const QuickAddResult(
        createdTaskIds: [-1],
        unresolvedAssignees: ['sam'],
      );
      await harness.open(tester);
      await typeLine(tester, 'Fix bike @sam');
      expect(chip('Sam Example'), findsOneWidget);
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.text(en.newTaskCreated('Fix bike @sam')), findsOneWidget);
    });

    testWidgets('a failed add says why and keeps the text', (tester) async {
      harness.service.submitError = const Forbidden(message: 'No access');
      await harness.open(tester);
      await typeLine(tester, 'Fix bike');
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(find.text(en.newTaskAddFailed('No access')), findsOneWidget);
      expect(composerText(tester), 'Fix bike');
    });

    testWidgets('without any project it says so and cannot add', (
      tester,
    ) async {
      harness.data.projects.all = [];
      await harness.open(tester);
      await typeLine(tester, 'Fix bike');

      expect(find.text(en.newTaskNoProjectError), findsOneWidget);
      expect(tester.widget<FilledButton>(addButton()).onPressed, isNull);
    });

    testWidgets('More options adds through quick add and opens the first '
        'task', (tester) async {
      harness.service.beforeSubmit = () async {
        await harness.data.tasks.createTask(
          const NewTask(projectId: 2, title: 'Plan trip'),
        );
      };
      await harness.open(tester);
      await typeLine(tester, 'Plan trip *urgent');
      await tester.tap(find.text(en.newTaskMoreOptions));
      await tester.pumpAndSettle();

      expect(harness.service.submits.single.text, 'Plan trip *urgent');
      expect(find.byType(TaskEditPage), findsOneWidget);
      expect(
        containerOf(tester).read(appRouterProvider).state.uri.toString(),
        AppRoutes.taskEdit(-1),
      );
      expect(find.text(en.newTaskCreated('Plan trip')), findsNothing);
    });
  });

  group('accessibility', () {
    testWidgets('at 200 % text in dark mode with the keyboard up it fits '
        'and adds', (tester) async {
      useAccessibilityExtremes(tester);
      await harness.open(tester);
      // A 300 dp keyboard on the 3x surface.
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpAndSettle();

      await typeLine(tester, '$mixed *ro');
      await tester.pump();
      expect(find.byType(MagicSuggestions), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(addButton());
      await tester.pumpAndSettle();
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(harness.service.submits.single.text, '$mixed *ro');
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 200 % text the chips wrap instead of cutting off', (
      tester,
    ) async {
      useAccessibilityExtremes(tester);
      await harness.open(tester);
      await typeLine(tester, 'Call mom tomorrow at 9:00 +Nowhere');

      for (final label in [mixedDue, en.quickAddProjectNotFound('Nowhere')]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.descendant(of: chip(label), matching: find.text(label)),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        expect(paragraph.debugHasOverflowShader, isFalse, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('is in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await harness.open(tester);

      expect(find.byTooltip(de.quickAddInsertLabel('*')), findsOneWidget);
      await typeLine(tester, 'Reifen wechseln *neu tomorrow');
      expect(chip(de.quickAddNewLabel('neu')), findsOneWidget);
      await typeLine(tester, 'Reifen wechseln\nÖl prüfen');
      expect(
        find.widgetWithText(FilledButton, de.newTaskAddMany(2)),
        findsOneWidget,
      );
    });
  });
}
