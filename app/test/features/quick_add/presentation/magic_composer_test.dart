import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_spans.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_suggestions.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/magic_text_controller.dart';
import 'package:vikunja_mobile/features/quick_add/presentation/quick_add_help_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';

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

  /// The chip [label] names, also while it shows its time after it.
  Finder choiceChip(String label) => find.ancestor(
    of: find.textContaining(RegExp('^${RegExp.escape(label)}( |\$)')),
    matching: find.byType(ChoiceChip),
  );

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
        en.repeatEveryWeek,
        'Work',
        'urgent',
        en.quickAddNewLabel('neu'),
        'Sam Example',
        en.prioritySemantics(en.priorityHigh),
        en.reminderBefore(en.periodDays(1), en.reminderReferenceDueDate),
      ]) {
        expect(chip(label), findsOneWidget, reason: label);
      }
      // Compact density would shrink the chips to 40 dp.
      for (final chip in find.byType(Chip).evaluate()) {
        final size = tester.getSize(find.byWidget(chip.widget));
        expect(size.height, greaterThanOrEqualTo(48), reason: '$size');
      }
    });

    testWidgets("a typed project's chip and the project field show the "
        "project's colour, the text's green only marks the text", (
      tester,
    ) async {
      harness.data.projects.all = [
        work.copyWith(hexColor: '1973ff'),
        inbox,
        garageSale,
        gardening,
      ];
      await harness.open(tester);
      await typeLine(tester, 'Plan +Work');

      List<String> colours(Finder of) => [
        for (final icon in tester.widgetList<ProjectIcon>(
          find.descendant(of: of, matching: find.byType(ProjectIcon)),
        ))
          icon.hexColor,
      ];
      expect(colours(chip('Work')), ['1973ff']);
      expect(colours(projectField('Work')), ['1973ff']);
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
      await removeChip(tester, en.repeatEveryWeek);
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

    testWidgets('after an unclosed quote, the next label is read and '
        'marked, and its chip removes its own token', (tester) async {
      await harness.open(tester);
      await typeLine(tester, 'Buy *"milk *urgent');

      expect(highlighted(tester), [
        ('*"milk', MagicSpanKind.label, FontWeight.w700),
        ('*urgent', MagicSpanKind.label, FontWeight.w700),
      ]);
      await removeChip(tester, 'urgent');
      expect(composerText(tester), 'Buy *"milk');
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

    testWidgets('a new label is created on Add, offline too: its chip says '
        'so either way', (tester) async {
      final semantics = tester.ensureSemantics();
      await harness.open(tester);
      await typeLine(tester, 'Fix bike *neu');

      expect(chip(en.quickAddNewLabel('neu')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp('^${RegExp.escape(en.quickAddNewLabelSemantics('neu'))}'),
        ),
        findsOneWidget,
      );

      harness.data.engine.emit(
        SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: composerNow,
        ),
      );
      await tester.pump();

      final created = chip(en.quickAddNewLabel('neu'));
      expect(created, findsOneWidget);
      expect(
        find.descendant(
          of: created,
          matching: find.byIcon(Icons.cloud_off_outlined),
        ),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets('a new label longer than the server allows stays in the '
        'title', (tester) async {
      await harness.open(tester);
      final long = 'x' * 251;
      await typeLine(tester, 'Fix bike *$long');

      expect(chip(en.quickAddLabelStaysInTitle(long)), findsOneWidget);
      expect(chip(en.quickAddNewLabel(long)), findsNothing);
    });

    testWidgets('a new label is judged without the NUL characters the server '
        'drops, as on Add', (tester) async {
      await harness.open(tester);
      final longest = '${'x' * 250}\u0000';
      await typeLine(tester, 'Fix bike *$longest');

      expect(chip(en.quickAddNewLabel(longest)), findsOneWidget);
      expect(chip(en.quickAddLabelStaysInTitle(longest)), findsNothing);
    });

    testWidgets("a guest's new label stays in the title, online too", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      usePhoneSurface(tester);
      await pumpSignedInApp(
        tester,
        sync: harness.data,
        now: composerNow,
        overrides: [
          ...harness.overrides,
          activeAccountIsGuestProvider.overrideWithValue(true),
        ],
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await typeLine(tester, 'Fix bike *neu');

      final kept = chip(en.quickAddLabelStaysInTitle('neu'));
      expect(kept, findsOneWidget);
      expect(
        find.descendant(
          of: kept,
          matching: find.byIcon(Icons.label_off_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            '^${RegExp.escape(en.quickAddLabelStaysInTitleSemantics('neu'))}',
          ),
        ),
        findsOneWidget,
      );
      expect(chip(en.quickAddNewLabel('neu')), findsNothing);
      semantics.dispose();
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
      // Compact density would shrink the chips to 40 dp.
      for (final chip in find.byType(ActionChip).evaluate()) {
        final size = tester.getSize(find.byWidget(chip.widget));
        expect(size.height, greaterThanOrEqualTo(48), reason: '$size');
      }

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
      harness.data.projects.all = [
        work,
        inbox,
        garageSale.copyWith(hexColor: 'e8445a'),
        gardening,
      ];
      await harness.open(tester);
      await typeLine(tester, 'Sell +gar');

      expect(suggestion('Gardening'), findsNothing);
      expect(
        tester
            .widget<ProjectIcon>(
              find.descendant(
                of: suggestion('Garage Sale'),
                matching: find.byType(ProjectIcon),
              ),
            )
            .hexColor,
        'e8445a',
      );
      await tester.tap(suggestion('Garage Sale'));
      await tester.pump();
      expect(composerText(tester), 'Sell +"Garage Sale" ');

      await typeLine(tester, 'Report +wrk');
      expect(suggestion('Work'), findsOneWidget);
    });

    testWidgets('never projects the user may only read; naming one warns '
        'that it is read only', (tester) async {
      harness.data.projects.all = [
        work,
        inbox,
        garageSale.copyWith(maxPermission: Permission.read),
      ];
      await harness.open(tester);
      await typeLine(tester, 'Sell +gar');

      expect(suggestion('Garage Sale'), findsNothing);

      await typeLine(tester, 'Sell +"Garage Sale"');
      expect(chip(en.quickAddProjectReadOnly('Garage Sale')), findsOneWidget);
      expect(chip(en.quickAddProjectNotFound('Garage Sale')), findsNothing);
    });

    testWidgets('labels, projects and people ignore accents', (tester) async {
      await harness.open(tester);

      await typeLine(tester, 'Pack *RÖAD');
      await tester.pump();
      expect(suggestion('Road trip'), findsOneWidget);
      await typeLine(tester, 'Report +wörk');
      expect(suggestion('Work'), findsOneWidget);
      await typeLine(tester, 'Call @sàm');
      await tester.pump();
      expect(suggestion('Sam Example'), findsOneWidget);
      await tester.pump(MagicSuggestions.debounce);
      await tester.pump();
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

    testWidgets('a token that names its item in full suggests it no more, '
        'unless its quote is still open', (tester) async {
      await harness.open(tester);

      await typeLine(tester, 'Plan +wor');
      expect(suggestion('Work'), findsOneWidget);
      await typeLine(tester, 'Plan +work');
      expect(suggestion('Work'), findsNothing);

      await typeLine(tester, 'Sell +"Garage Sa');
      expect(suggestion('Garage Sale'), findsOneWidget);
      await typeLine(tester, 'Sell +"garage sale"');
      expect(suggestion('Garage Sale'), findsNothing);

      await typeLine(tester, 'Pack *urgen');
      await tester.pump();
      expect(suggestion('urgent'), findsOneWidget);
      await typeLine(tester, 'Pack *urgent');
      expect(suggestion('urgent'), findsNothing);

      await typeLine(tester, 'Ask @sa');
      await tester.pump();
      expect(suggestion('Sam Example'), findsOneWidget);
      await typeLine(tester, 'Ask @sam');
      await tester.pump();
      expect(suggestion('Sam Example'), findsNothing);
      await tester.pump(MagicSuggestions.debounce);
      await tester.pump();
      expect(suggestion('Sam Example'), findsNothing);
    });

    testWidgets('projects show and match their display title, and a tap '
        "completes the server's", (tester) async {
      useLocale(tester, const Locale('de'));
      await harness.open(tester);

      await typeLine(tester, 'Kaufen +eing');
      expect(suggestion(de.projectInboxTitle), findsOneWidget);
      await tester.tap(suggestion(de.projectInboxTitle));
      await tester.pump();
      expect(composerText(tester), 'Kaufen +Inbox ');
      expect(chip(de.projectInboxTitle), findsOneWidget);

      await typeLine(tester, 'Kaufen +inb');
      expect(suggestion(de.projectInboxTitle), findsOneWidget);
      expect(suggestion('Inbox'), findsNothing);
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

  group('help', () {
    testWidgets('the button at the end of the title field opens it, also '
        'with the field empty', (tester) async {
      await harness.open(tester);

      expect(
        find.descendant(
          of: composerField(),
          matching: find.byTooltip(en.quickAddHelp),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip(en.quickAddHelp));
      await tester.pumpAndSettle();
      expect(find.byType(QuickAddHelpSheet), findsOneWidget);
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
      expect(find.text(en.quickAddHelpLabelsCreated('@')), findsOneWidget);
      // The 27th of next month, never a date in the past.
      for (final example in ['nov 27', '27/11', '27.11.', '2026-11-27']) {
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
        find.text(en.quickAddHelpMode('Todoist')),
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

    testWidgets('the Dates section starts with the note that date words are '
        'English', (tester) async {
      await harness.open(tester);
      await tester.tap(find.byTooltip(en.quickAddHelp));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('today'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(QuickAddHelpSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );

      final heading = tester.getRect(find.text(en.quickAddHelpDatesTitle));
      final note = tester.getRect(find.text(en.quickAddHelpEnglish));
      final examples = tester.getRect(find.text(en.quickAddHelpDatesBody));
      expect(note.top, greaterThan(heading.bottom));
      expect(note.bottom, lessThanOrEqualTo(examples.top));
      expect(
        find.descendant(
          of: find.byType(QuickAddHelpSheet),
          matching: find.text(en.quickAddHelpEnglish),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a guest reads that new labels stay in the title, since a '
        'guest cannot create them', (tester) async {
      usePhoneSurface(tester);
      await pumpSignedInApp(
        tester,
        sync: harness.data,
        now: composerNow,
        overrides: [
          ...harness.overrides,
          activeAccountIsGuestProvider.overrideWithValue(true),
        ],
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(en.quickAddHelp));
      await tester.pumpAndSettle();

      expect(find.text(en.quickAddHelpLabelsBodyGuest('*')), findsOneWidget);
      expect(find.text(en.quickAddHelpLabelsCreated('*')), findsNothing);
    });
  });

  group('modes', () {
    testWidgets('todoist prefixes everywhere', (tester) async {
      harness.settings = const UserSettings(
        quickAddMagicMode: QuickAddMagicMode.todoist,
      );
      await harness.open(tester);

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

      expect(find.byTooltip(en.quickAddHelp), findsNothing);
      await typeLine(tester, 'Buy *milk tomorrow');
      expect(composerController(tester).highlighter, isNull);
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(MagicSuggestions), findsNothing);
      await tester.tap(addButton());
      await tester.pumpAndSettle();
      expect(harness.service.submits.single.text, 'Buy *milk tomorrow');
    });

    testWidgets('with magic off the priority chips still give the priority', (
      tester,
    ) async {
      harness.settings = const UserSettings(
        quickAddMagicMode: QuickAddMagicMode.disabled,
      );
      await harness.open(tester);
      await typeLine(tester, 'Buy milk !5');
      await tapInSheet(tester, en.priorityMedium);

      expect(
        tester.widget<ChoiceChip>(choiceChip(en.priorityMedium)).selected,
        isTrue,
      );
      expect(chip(en.prioritySemantics(en.priorityMedium)), findsNothing);
      await tester.tap(addButton());
      await tester.pumpAndSettle();
      expect(harness.service.submits.single.fallbackPriority, 2);
    });
  });

  group('fallback chips', () {
    testWidgets('a date in the text shows on the due chips, which wait '
        'until it is removed', (tester) async {
      await harness.open(tester);
      await typeLine(tester, 'Call Sam tomorrow');

      var tomorrow = tester.widget<ChoiceChip>(choiceChip(en.shortcutTomorrow));
      expect(tomorrow.selected, isTrue);
      expect(tomorrow.onSelected, isNull);
      expect(tester.widget<ActionChip>(pickDateChip()).onPressed, isNull);

      await removeChip(
        tester,
        en.quickAddDueLabel('Sun, Oct 11 12:00 PM', en.relativeTomorrow),
      );
      expect(composerText(tester), 'Call Sam');
      tomorrow = tester.widget<ChoiceChip>(choiceChip(en.shortcutTomorrow));
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
        choiceChip(en.shortcutTomorrow),
      );
      expect(tomorrow.selected, isFalse);
      expect(tomorrow.onSelected, isNotNull);
      expect(
        tester.widget<ProjectField>(projectField('Inbox')).onPressed,
        isNotNull,
      );

      await typeLine(tester, 'Call mom tomorrow +Work\nBuy milk +Work friday');
      expect(
        tester.widget<ChoiceChip>(choiceChip(en.shortcutTomorrow)).onSelected,
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
      await tapInSheet(tester, en.shortcutTomorrow);
      await typeLine(tester, 'Buy milk\nCall Sam friday');
      await tester.tap(addButton(2));
      await tester.pumpAndSettle();

      expect(harness.service.submits, [
        (
          text: 'Buy milk\nCall Sam friday',
          fallbackProjectId: 2,
          fallbackDueDate: DateTime(2026, 10, 11, 12).toUtc(),
          fallbackPriority: null,
          extras: const QuickAddExtras(),
        ),
      ]);
      expect(harness.data.tasks.updates, isEmpty);
    });

    testWidgets('a priority in the text shows on the priority chips, which '
        'wait until it is removed', (tester) async {
      await harness.open(tester);
      await tapInSheet(tester, en.priorityLow);
      await typeLine(tester, 'Call Sam !3');

      var high = tester.widget<ChoiceChip>(choiceChip(en.priorityHigh));
      expect(high.selected, isTrue);
      expect(high.onSelected, isNull);
      expect(
        tester.widget<ChoiceChip>(choiceChip(en.priorityLow)).selected,
        isFalse,
      );

      await removeChip(tester, en.prioritySemantics(en.priorityHigh));
      expect(composerText(tester), 'Call Sam');
      high = tester.widget<ChoiceChip>(choiceChip(en.priorityHigh));
      expect(high.selected, isFalse);
      expect(high.onSelected, isNotNull);
      final low = tester.widget<ChoiceChip>(choiceChip(en.priorityLow));
      expect(low.selected, isTrue);
      // The sheet's own priority shows on its row only.
      expect(chip(en.prioritySemantics(en.priorityLow)), findsNothing);
    });

    testWidgets("the sheet's own date shows on its row only, the text's "
        'gets a chip', (tester) async {
      await harness.open(tester);
      await tapInSheet(tester, en.shortcutTomorrow);
      await typeLine(tester, 'Call Sam');

      expect(find.byType(Chip), findsNothing);
      expect(
        tester.widget<ChoiceChip>(choiceChip(en.shortcutTomorrow)).selected,
        isTrue,
      );
      await typeLine(tester, 'Call Sam tomorrow at 9:00');
      expect(chip(mixedDue), findsOneWidget);
    });

    testWidgets("the sheet's priority goes to the lines without their own, "
        'and stays choosable until every line has one', (tester) async {
      harness.service.result = const QuickAddResult(createdTaskIds: [-1, -2]);
      await harness.open(tester);
      await tapInSheet(tester, en.priorityUrgent);
      await typeLine(tester, 'Buy milk !1\nCall Sam');

      expect(
        tester.widget<ChoiceChip>(choiceChip(en.priorityUrgent)).onSelected,
        isNotNull,
      );
      await typeLine(tester, 'Buy milk !1\nCall Sam !2');
      expect(
        tester.widget<ChoiceChip>(choiceChip(en.priorityUrgent)).onSelected,
        isNull,
      );
      expect(
        tester.widget<ChoiceChip>(choiceChip(en.priorityLow)).selected,
        isTrue,
      );

      await typeLine(tester, 'Buy milk !1\nCall Sam');
      await tester.tap(addButton(2));
      await tester.pumpAndSettle();
      expect(harness.service.submits.single.fallbackPriority, 4);
    });

    testWidgets('a locked row says that the title sets it, beside its '
        'heading or in the field', (tester) async {
      final semantics = tester.ensureSemantics();
      await harness.open(tester);
      final note = inSheet(en.newTaskSetInTitle);

      await typeLine(tester, 'Call Sam tomorrow');
      expect(note, findsOneWidget);
      // Beside the heading where there is room, else under it.
      expect(
        tester.getRect(note).top,
        greaterThanOrEqualTo(tester.getRect(inSheet(en.taskDetailDueDate)).top),
      );
      expect(
        tester.getRect(note).bottom,
        lessThanOrEqualTo(tester.getRect(choiceChip(en.shortcutToday)).top),
      );

      await typeLine(tester, 'Call Sam tomorrow at 9:00 !3 +Work');
      expect(note, findsNWidgets(3));
      final project = find.byType(ProjectField);
      expect(
        find.descendant(of: project, matching: find.text(en.newTaskSetInTitle)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: project,
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
        findsNothing,
      );
      expect(tester.getSemantics(project).hint, en.newTaskSetInTitle);

      await typeLine(tester, 'Call Sam');
      expect(note, findsNothing);
      expect(tester.getSemantics(project).hint, isEmpty);

      await typeLine(tester, 'Call mom tomorrow +Work\nBuy milk +Work friday');
      expect(note, findsNWidgets(2));
      semantics.dispose();
    });
  });

  group('hints', () {
    testWidgets('a German date word without a date says that the date words '
        'are English, as a live region', (tester) async {
      final semantics = tester.ensureSemantics();
      await harness.open(tester);
      await typeLine(tester, 'Zahnarzt morgen um 17 Uhr');

      final hint = inSheet(en.quickAddHintEnglishDates('tomorrow at 17:00'));
      expect(hint, findsOneWidget);
      expect(
        find.ancestor(
          of: hint,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && (widget.properties.liveRegion ?? false),
          ),
        ),
        findsOneWidget,
      );

      await typeLine(tester, 'Zahnarzt tomorrow at 17:00');
      expect(hint, findsNothing);
      semantics.dispose();
    });

    testWidgets('a clock time after the date without at says to add it', (
      tester,
    ) async {
      await harness.open(tester);
      await typeLine(tester, 'Call Sam tomorrow 5pm');

      final hint = inSheet(en.quickAddHintAddAt('5pm'));
      expect(hint, findsOneWidget);
      await typeLine(tester, 'Call Sam tomorrow at 5pm');
      expect(hint, findsNothing);
    });

    testWidgets('with magic off there are no hints', (tester) async {
      harness.settings = const UserSettings(
        quickAddMagicMode: QuickAddMagicMode.disabled,
      );
      await harness.open(tester);
      await typeLine(tester, 'Zahnarzt morgen um 17 Uhr');

      expect(
        inSheet(en.quickAddHintEnglishDates('tomorrow at 17:00')),
        findsNothing,
      );
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
        (
          text: mixed,
          fallbackProjectId: 3,
          fallbackDueDate: null,
          fallbackPriority: null,
          extras: const QuickAddExtras(),
        ),
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
        (
          text: text,
          fallbackProjectId: 2,
          fallbackDueDate: null,
          fallbackPriority: null,
          extras: const QuickAddExtras(),
        ),
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

    testWidgets('the confirmation names labels kept in the title, labels of '
        'the sheet not created and people not found', (tester) async {
      harness.service.result = const QuickAddResult(
        createdTaskIds: [-1],
        createdTitles: ['Fix bike @bob *neu'],
        labelsNotCreated: ['Errands'],
        labelsKept: ['*neu'],
        unresolvedAssignees: ['bob'],
      );
      await harness.open(tester);
      await typeLine(tester, 'Fix bike *neu @bob');
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(
        find.text(en.newTaskCreated('Fix bike @bob *neu')),
        findsOneWidget,
      );
      expect(find.text(en.newTaskLabelsKept('*neu')), findsOneWidget);
      expect(find.text(en.newTaskLabelsNotCreated('Errands')), findsOneWidget);
      expect(find.text(en.newTaskNamesKept('@bob')), findsOneWidget);
    });

    testWidgets('a label kept that the title holds already shows once', (
      tester,
    ) async {
      harness.service.result = const QuickAddResult(
        createdTaskIds: [-1],
        labelsKept: ["*'road trip"],
      );
      await harness.open(tester);
      await typeLine(tester, "Fix bike *'road trip");
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(
        find.text(en.newTaskCreated("Fix bike *'road trip")),
        findsOneWidget,
      );
      expect(find.text(en.newTaskLabelsKept("*'road trip")), findsOneWidget);
    });

    testWidgets('names the server found leave the confirmed title', (
      tester,
    ) async {
      harness.service.result = await harness.submitted(
        'Fix bike @alex',
        fallbackProjectId: inbox.id,
      );
      await harness.open(tester);
      await typeLine(tester, 'Fix bike @alex');
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.text(en.newTaskCreated('Fix bike')), findsOneWidget);
    });

    testWidgets('a title over the limit is confirmed as cut', (tester) async {
      final line = 'https://example.com/${'a' * Task.maxTitleLength}';
      harness.service.result = await harness.submitted(
        line,
        fallbackProjectId: inbox.id,
      );
      await harness.open(tester);
      // Too long without a space: the title is the address's host.
      await typeLine(tester, line);
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.text(en.newTaskCreated('example.com')), findsOneWidget);
    });

    testWidgets('a person known here whom the server did not accept stays '
        'in the confirmed title', (tester) async {
      // The server finds nobody in Garage Sale.
      harness.service.result = await harness.submitted(
        'Fix bike @sam',
        fallbackProjectId: garageSale.id,
      );
      await harness.open(tester);
      await typeLine(tester, 'Fix bike @sam');
      expect(chip('Sam Example'), findsOneWidget);
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      expect(find.text(en.newTaskCreated('Fix bike @sam')), findsOneWidget);
    });

    testWidgets('the confirmation names the title the service created: a '
        'name the server found before punctuation leaves it, where the '
        'plan kept it', (tester) async {
      const line = 'Call @alex tomorrow.';
      harness.service.result = await harness.submitted(
        line,
        fallbackProjectId: inbox.id,
      );
      expect(harness.service.result.createdTitles, ['Call .']);
      await harness.open(tester);
      await typeLine(tester, line);
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      // The sheet used to name its own reading, "Call @alex.".
      expect(find.text(en.newTaskCreated('Call .')), findsOneWidget);
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

    testWidgets('the further fields go with every line of a paste', (
      tester,
    ) async {
      harness.service.result = const QuickAddResult(createdTaskIds: [-1, -2]);
      await harness.open(tester);
      await typeLine(tester, 'Buy milk *urgent\nCall Sam');
      await tapInSheet(tester, en.newTaskMoreOptions);
      await tester.enterText(
        find.widgetWithText(TextField, en.taskDetailDescription),
        'For the weekend',
      );
      await tester.pump();
      await tapInSheet(tester, en.repeatModeEvery);
      await tapInSheet(tester, en.repeatPresetDaily);
      await tester.ensureVisible(addButton(2));
      await tester.pumpAndSettle();
      await tester.tap(addButton(2));
      await tester.pumpAndSettle();

      expect(harness.service.submits.single.text, 'Buy milk *urgent\nCall Sam');
      expect(
        harness.service.submits.single.extras,
        const QuickAddExtras(
          description: '<p>For the weekend</p>',
          repeatAfter: Duration(days: 1),
        ),
      );
      expect(find.text(en.newTaskCreatedMany(2)), findsOneWidget);
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

      expect(find.byTooltip(de.quickAddHelp), findsOneWidget);
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
