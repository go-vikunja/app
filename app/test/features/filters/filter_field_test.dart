import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/filters/presentation/filter_field.dart';
import 'package:vikunja_mobile/features/filters/presentation/filter_text_controller.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/view_form_sheet.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/saved_filter_form_page.dart';

import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;
  late FakeLabelRepository labels;
  late FakeUserRepository users;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(
        id: 1,
        title: 'Office',
        views: [
          sampleListView(id: 10, projectId: 1),
          sampleListView(
            id: 11,
            projectId: 1,
            title: 'Chores',
            position: 200,
            filter: 'labels in 1, 2 && project = 2 && due_date < now',
          ),
          sampleListView(
            id: 12,
            projectId: 1,
            title: 'Gone label',
            position: 300,
            filter: 'labels = 9 && done = false',
          ),
        ],
      ),
      sampleProject(id: 2, title: 'Garden'),
    ];
    data.search.matchCount = 4;
    labels = FakeLabelRepository(
      labels: [
        sampleLabel(id: 1, title: 'Work', hexColor: 'e8445a'),
        sampleLabel(id: 2, title: 'Home'),
        sampleLabel(id: 3, title: 'R&D'),
      ],
    );
    users = FakeUserRepository(
      known: const [
        User(id: 7, username: 'anna', name: 'Anna'),
        User(id: 8, username: 'ben'),
      ],
    );
  });

  Future<void> pumpApp(WidgetTester tester) => pumpSignedInApp(
    tester,
    sync: data,
    now: now,
    overrides: [
      labelRepositoryProvider.overrideWithValue(labels),
      userRepositoryProvider.overrideWithValue(users),
    ],
  );

  Future<void> openNewSavedFilter(WidgetTester tester) async {
    await pumpApp(tester);
    final router = containerOf(tester).read(appRouterProvider)
      ..go(AppRoutes.projects);
    await tester.pumpAndSettle();
    unawaited(router.push(AppRoutes.savedFilterNew));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, en.projectTitleLabel),
      'Mine',
    );
    await tester.pump();
  }

  Future<void> openView(WidgetTester tester, String title) async {
    await pumpApp(tester);
    final router = containerOf(tester).read(appRouterProvider)
      ..go(AppRoutes.project(1));
    await tester.pumpAndSettle();
    unawaited(router.push(AppRoutes.projectViews(1)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, title).first);
    await tester.pumpAndSettle();
  }

  Finder filterField() => find.descendant(
    of: find.byType(FilterField),
    matching: find.byType(TextField),
  );

  String filterText(WidgetTester tester) =>
      tester.widget<TextField>(filterField()).controller!.text;

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(filterField(), text);
    await tester.pump();
  }

  Finder chip(String label) => find.widgetWithText(ActionChip, label);

  List<String> chipLabels(WidgetTester tester) => [
    for (final chip in tester.widgetList<ActionChip>(find.byType(ActionChip)))
      (chip.label as Text).data!,
  ];

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.ensureVisible(chip(label));
    await tester.tap(chip(label));
    await tester.pump();
  }

  Future<void> create(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(en.projectCreate),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool createEnabled(WidgetTester tester) =>
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.descendant(
                of: find.byType(AppBar),
                matching: find.text(en.projectCreate),
              ),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed !=
      null;

  testWidgets('highlights fields, operators, values and joins, and a word '
      'that names no field', (tester) async {
    await openNewSavedFilter(tester);
    await type(tester, 'done = false && dueDat < now');

    final context = tester.element(filterField());
    final colors = Theme.of(context).colorScheme;
    final controller =
        tester.widget<TextField>(filterField()).controller!
            as FilterTextEditingController;
    final span = controller.buildTextSpan(
      context: context,
      withComposing: false,
    );
    TextStyle? styleOf(String text) => span.children!
        .cast<TextSpan>()
        .firstWhere((child) => child.text == text)
        .style;

    expect(styleOf('done')?.color, colors.primary);
    expect(styleOf('done')?.fontWeight, FontWeight.w700);
    expect(styleOf('=')?.color, colors.tertiary);
    expect(styleOf('=')?.fontWeight, FontWeight.w700);
    expect(styleOf('false')?.color, colors.secondary);
    expect(styleOf('false')?.decorationStyle, TextDecorationStyle.dotted);
    expect(styleOf('&&')?.fontWeight, FontWeight.w900);
    expect(styleOf('dueDat')?.decorationStyle, TextDecorationStyle.wavy);
    // A background would be painted over the selection and the caret.
    expect([
      for (final child in span.children!) child.style?.backgroundColor,
    ], everyElement(isNull));

    controller.highlighted = false;
    final plain = controller.buildTextSpan(
      context: context,
      withComposing: false,
    );
    expect(plain.children, isNull);
    expect(plain.text, 'done = false && dueDat < now');
  });

  testWidgets('suggests a field, then its operators, then label titles, and '
      'saves the labels as ids', (tester) async {
    await openNewSavedFilter(tester);
    await type(tester, '');

    expect(chipLabels(tester).take(3), ['done', 'priority', 'dueDate']);
    await type(tester, 'lab');
    expect(chipLabels(tester), ['labels']);
    await choose(tester, 'labels');
    expect(filterText(tester), 'labels ');
    expect(chipLabels(tester), ['=', '!=', 'in', 'not in']);

    await choose(tester, 'in');
    expect(filterText(tester), 'labels in ');
    expect(chipLabels(tester), ['Home', 'R&D', 'Work']);
    await choose(tester, 'Work');
    expect(filterText(tester), 'labels in Work ');

    await type(tester, 'labels in Work, ho');
    expect(chipLabels(tester), ['Home']);
    await choose(tester, 'Home');
    expect(filterText(tester), 'labels in Work, Home ');
    await create(tester);

    expect(data.savedFilters.drafts.single.filter.filter, 'labels in 1, 2');
  });

  testWidgets('a title a value cannot hold goes as its id', (tester) async {
    await openNewSavedFilter(tester);
    await type(tester, 'labels = R');

    await choose(tester, 'R&D');

    expect(filterText(tester), 'labels = 3 ');
  });

  testWidgets('projects by title saved as ids, people by username', (
    tester,
  ) async {
    await openNewSavedFilter(tester);

    await type(tester, 'project = ');
    expect(chipLabels(tester), ['Office', 'Garden']);
    await choose(tester, 'Garden');
    expect(filterText(tester), 'project = Garden ');

    await type(tester, 'project = Garden && assignees = ');
    expect(chipLabels(tester), ['Anna', 'ben']);
    expect(find.byTooltip(en.assigneeUsername('anna')), findsOneWidget);
    await choose(tester, 'Anna');
    expect(filterText(tester), 'project = Garden && assignees = anna ');
    await create(tester);

    expect(
      data.savedFilters.drafts.single.filter.filter,
      'project = 2 && assignees = anna',
    );
  });

  testWidgets('values ignore accents and go in with their exact titles', (
    tester,
  ) async {
    labels = FakeLabelRepository(
      labels: [
        sampleLabel(id: 1, title: 'Café'),
        sampleLabel(id: 2, title: 'Work'),
      ],
    );
    data.projects.all = [
      ...data.projects.all,
      sampleProject(id: 3, title: 'Señora'),
    ];
    users = FakeUserRepository(
      known: const [
        User(id: 7, username: 'zoe', name: 'Zoë'),
        User(id: 8, username: 'jose', name: 'José'),
      ],
    );
    await openNewSavedFilter(tester);

    await type(tester, 'labels in cafe');
    expect(chipLabels(tester), ['Café']);
    await choose(tester, 'Café');
    expect(filterText(tester), 'labels in Café ');

    await type(tester, 'project = senora');
    expect(chipLabels(tester), ['Señora']);
    await choose(tester, 'Señora');
    expect(filterText(tester), 'project = Señora ');

    // Matched by name, inserted as the username.
    await type(tester, 'assignees = zoë');
    expect(chipLabels(tester), ['Zoë']);
    await choose(tester, 'Zoë');
    expect(filterText(tester), 'assignees = zoe ');
  });

  testWidgets('a value typed out is not offered again, ignoring case but '
      'not accents', (tester) async {
    labels = FakeLabelRepository(
      labels: [
        sampleLabel(id: 1, title: 'Café'),
        sampleLabel(id: 2, title: 'Cafeteria'),
      ],
    );
    users = FakeUserRepository(
      known: const [
        User(id: 8, username: 'jose', name: 'José'),
        User(id: 9, username: 'josefa'),
      ],
    );
    await openNewSavedFilter(tester);

    await type(tester, 'labels in CAFÉ');
    expect(chipLabels(tester), isNot(contains('Café')));
    // The filter takes only the exact title.
    await type(tester, 'labels in cafe');
    expect(chipLabels(tester), unorderedEquals(['Café', 'Cafeteria']));
    await type(tester, 'labels in cafeteria');
    expect(chipLabels(tester), isNot(contains('Cafeteria')));

    // The username is what goes in, whatever the name.
    await type(tester, 'assignees = jose');
    expect(chipLabels(tester), ['josefa']);
  });

  testWidgets('project suggestions have their coloured folders, archived '
      'ones the archive icon', (tester) async {
    data.projects.all = [
      data.projects.all.first,
      sampleProject(id: 2, title: 'Garden', hexColor: '4caf50'),
      sampleProject(id: 3, title: 'Attic', archived: true),
    ];
    await openNewSavedFilter(tester);

    await type(tester, 'project = ');

    expect(chipLabels(tester), ['Office', 'Garden', 'Attic']);
    expect(
      tester
          .widgetList<ProjectIcon>(find.byType(ProjectIcon))
          .map((icon) => icon.hexColor),
      ['', '4caf50'],
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ActionChip, 'Attic'),
        matching: find.byIcon(Icons.archive_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('relative dates, priorities by name, and joins after a value', (
    tester,
  ) async {
    await openNewSavedFilter(tester);

    await type(tester, 'dueDate < ');
    expect(chipLabels(tester), contains('now/d+1d'));
    await choose(tester, 'now/d+1d');
    expect(filterText(tester), 'dueDate < now/d+1d ');
    expect(chipLabels(tester), ['&&', '||']);
    await choose(tester, '&&');
    expect(filterText(tester), 'dueDate < now/d+1d && ');

    await type(tester, 'priority = ');
    expect(chipLabels(tester), ['1', '2', '3', '4', '5']);
    expect(find.byTooltip(en.priorityHigh), findsOneWidget);
    await create(tester);
  });

  testWidgets("the engine's verdict shows once typing pauses and keeps the "
      'form from saving at once', (tester) async {
    await openNewSavedFilter(tester);

    await type(tester, 'dueDat < now');
    expect(createEnabled(tester), isFalse);
    await tester.pump(FilterField.errorDelay);
    expect(
      find.text(en.filterErrorUnknownFieldNamed('dueDat')),
      findsOneWidget,
    );

    await type(tester, 'labels = Wrok');
    await tester.pump(FilterField.errorDelay);
    expect(find.text(en.filterErrorLabelValue('Wrok')), findsOneWidget);

    await type(tester, 'dueDate < tomorrow');
    await tester.pump(FilterField.errorDelay);
    // Named as the suggestions spell it.
    expect(
      find.text(en.filterErrorFieldValue('tomorrow', 'dueDate')),
      findsOneWidget,
    );

    // Vikunja 2.8.0's limit on the business days of a whole filter.
    await type(tester, 'dueDate < now+6000b || startDate > now-4001b');
    await tester.pump(FilterField.errorDelay);
    expect(
      find.text(en.filterErrorFieldValue('now-4001b', 'startDate')),
      findsOneWidget,
    );
    expect(createEnabled(tester), isFalse);

    await type(tester, 'done = true &&');
    await tester.pump(FilterField.errorDelay);
    expect(find.text(en.filterErrorSyntax), findsOneWidget);
    expect(createEnabled(tester), isFalse);

    await type(tester, 'done = true && labels = work');
    expect(find.text(en.filterErrorSyntax), findsNothing);
    expect(createEnabled(tester), isTrue);
    await create(tester);
    expect(
      data.savedFilters.drafts.single.filter.filter,
      'done = true && labels = 1',
    );
  });

  testWidgets('half-typed conditions get no message while typing, a fixed '
      'one loses it at once, and leaving the field shows it', (tester) async {
    await openNewSavedFilter(tester);

    await type(tester, 'done = ');
    await tester.pump(FilterField.errorDelay ~/ 2);
    await type(tester, 'done = true && labels in ');
    await tester.pump(FilterField.errorDelay ~/ 2);
    expect(find.text(en.filterErrorSyntax), findsNothing);
    expect(createEnabled(tester), isFalse);
    final suggestion = tester.getRect(chip('Work'));

    await tester.pump(FilterField.errorDelay);
    expect(find.text(en.filterErrorSyntax), findsOneWidget);
    // The message comes under the suggestions, which stay where they were.
    expect(tester.getRect(chip('Work')), suggestion);
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text(en.filterErrorSyntax)),
      isSemantics(isLiveRegion: true),
    );
    semantics.dispose();

    await type(tester, 'done = true && labels in Work');
    expect(find.text(en.filterErrorSyntax), findsNothing);
    expect(createEnabled(tester), isTrue);

    await type(tester, 'done = maybe');
    expect(find.text(en.filterErrorFieldValue('maybe', 'done')), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(
      find.text(en.filterErrorFieldValue('maybe', 'done')),
      findsOneWidget,
    );
  });

  testWidgets('date suggestions have names, and the count is announced', (
    tester,
  ) async {
    await openNewSavedFilter(tester);
    final semantics = tester.ensureSemantics();

    await type(tester, 'dueDate < ');
    expect(find.byTooltip(en.filterDateStartOfTomorrow), findsOneWidget);
    expect(find.bySemanticsLabel(en.filterDateStartOfTomorrow), findsWidgets);
    expect(find.bySemanticsLabel(en.filterDateSevenDaysAgo), findsWidgets);

    await type(tester, 'priority >= 3');
    await tester.pump(FilterField.countDelay);
    await tester.pump();
    expect(
      tester.getSemantics(find.text(en.filterMatchCount(4))),
      isSemantics(isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets("how many of this device's tasks match, like a saved filter "
      'would count them', (tester) async {
    await openNewSavedFilter(tester);

    await type(tester, 'priority >= 3');
    await tester.pump(FilterField.countDelay);
    await tester.pump();

    expect(find.text(en.filterMatchCount(4)), findsOneWidget);
    expect(data.search.counts.last, (
      const ViewFilter(filter: 'priority >= 3', includeNulls: true),
      null,
    ));

    data.search.matchCount = null;
    await tester.ensureVisible(find.text(en.savedFilterIncludeNulls));
    await tester.tap(find.text(en.savedFilterIncludeNulls));
    await tester.pump();
    await tester.pump(FilterField.countDelay);
    await tester.pump();
    expect(data.search.counts.last, (
      const ViewFilter(filter: 'priority >= 3'),
      null,
    ));
    expect(find.text(en.filterNotCountable), findsOneWidget);
  });

  testWidgets("a view counts within its project, with its form's show done "
      'switch', (tester) async {
    await openView(tester, 'List');
    await tester.pump(FilterField.countDelay);
    await tester.pump();
    expect(data.search.counts.last, (
      const ViewFilter(filter: 'done = false'),
      1,
    ));

    await type(tester, 'priority >= 3');
    await tester.pump(FilterField.countDelay);
    await tester.pump();
    expect(data.search.counts.last.$1.filter, 'done = false && priority >= 3');

    await tester.tap(find.text(en.projectViewShowDone));
    await tester.pump();
    await tester.pump(FilterField.countDelay);
    expect(data.search.counts.last.$1.filter, 'priority >= 3');
    expect(find.text(en.filterMatchCount(4)), findsOneWidget);
  });

  testWidgets('a stored filter shows label and project titles and goes back '
      'as ids', (tester) async {
    await openView(tester, 'Chores');

    expect(
      filterText(tester),
      'labels in Work, Home && project = Garden && dueDate < now',
    );

    await tester.enterText(
      filterField(),
      'labels in Work, Home && project = Garden && dueDate < now/d',
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(ViewFormSheet),
        matching: find.widgetWithText(TextButton, en.projectSave),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      data.views.drafts.single.filter?.filter,
      'labels in 1, 2 && project = 2 && due_date < now/d',
    );
  });

  testWidgets('an id nothing here has a title for, or one a suggestion put '
      'in, stays that id where a title is the same number', (tester) async {
    // Label 9 is not stored here; label 4 is titled "9", label 5 "3".
    labels = FakeLabelRepository(
      labels: [
        sampleLabel(id: 1, title: 'Work'),
        sampleLabel(id: 3, title: 'R&D'),
        sampleLabel(id: 4, title: '9'),
        sampleLabel(id: 5, title: '3'),
      ],
    );
    await openView(tester, 'Gone label');
    expect(filterText(tester), 'labels = 9 && done = false');

    await type(tester, 'labels = 9 && done = true && labels = R');
    await choose(tester, 'R&D');
    expect(filterText(tester), 'labels = 9 && done = true && labels = 3 ');
    await tester.tap(
      find.descendant(
        of: find.byType(ViewFormSheet),
        matching: find.widgetWithText(TextButton, en.projectSave),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      data.views.drafts.single.filter?.filter,
      'labels = 9 && done = true && labels = 3',
    );
  });

  group('with the keyboard up, the suggestions show above it', () {
    const keyboard = 280.0;

    Future<void> checkRevealed(WidgetTester tester) async {
      await tester.tap(filterField());
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await type(tester, 'labels in ');
      await tester.pumpAndSettle();

      expect(
        tester.getRect(chip('Work')).bottom,
        lessThanOrEqualTo(phoneSize.height - keyboard),
      );
      final scrollable = find
          .ancestor(of: filterField(), matching: find.byType(Scrollable))
          .first;
      final text = find.descendant(
        of: filterField(),
        matching: find.byType(EditableText),
      );
      expect(
        tester.getRect(text).top,
        greaterThanOrEqualTo(tester.getRect(scrollable).top),
      );
    }

    for (final scale in const [1.0, 2.0]) {
      testWidgets('in the views form at ${(scale * 100).round()} %', (
        tester,
      ) async {
        usePhoneSurface(tester);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openView(tester, 'List');

        await checkRevealed(tester);
      });

      testWidgets('in the saved filter form at ${(scale * 100).round()} %', (
        tester,
      ) async {
        usePhoneSurface(tester);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openNewSavedFilter(tester);

        await checkRevealed(tester);
      });
    }
  });

  testWidgets('no suggestions while the field does not have the focus', (
    tester,
  ) async {
    await pumpApp(tester);
    final router = containerOf(tester).read(appRouterProvider)
      ..go(AppRoutes.projects);
    await tester.pumpAndSettle();
    unawaited(router.push(AppRoutes.savedFilterNew));
    await tester.pumpAndSettle();

    expect(find.byType(SavedFilterFormPage), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
  });
}
