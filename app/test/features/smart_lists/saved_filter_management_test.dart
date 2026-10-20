import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/saved_filter_form_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_screen.dart';

import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  const urgent = SavedFilterRef(
    projectId: -2,
    title: 'Urgent',
    description: 'What burns',
    definition: SavedFilterDefinition(
      filter: ViewFilter(
        filter: 'done = false && priority >= 4',
        search: 'kept',
        sortBy: ['due_date'],
        orderBy: ['desc'],
      ),
    ),
  );
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.projects.savedFilters = [urgent];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Fire', priority: TaskPriority.doNow),
      sampleTask(id: 2, title: 'Calm'),
    ];
    data.tasks.setSavedFilterMatches(urgent.projectId, {1});
  });

  Future<void> pumpAt(
    WidgetTester tester,
    String location, {
    bool settle = true,
  }) async {
    await pumpSignedInApp(
      tester,
      sync: data,
      now: now,
      overrides: [
        labelRepositoryProvider.overrideWithValue(FakeLabelRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    final router = containerOf(tester).read(appRouterProvider);
    if (location.startsWith('${AppRoutes.home}/filters')) {
      router.go(AppRoutes.projects);
      await tester.pumpAndSettle();
      unawaited(router.push(location));
    } else {
      router.go(location);
    }
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await pumpFrames(tester, 3);
    }
  }

  Finder formField(String label) => find.descendant(
    of: find.byType(SavedFilterFormPage),
    matching: find.widgetWithText(TextField, label),
  );

  String fieldText(WidgetTester tester, String label) =>
      tester.widget<TextField>(formField(label)).controller!.text;

  Finder appBarButton(String label) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(label));

  bool enabled(WidgetTester tester, String label) =>
      tester
          .widget<TextButton>(
            find.ancestor(
              of: appBarButton(label),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed !=
      null;

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip(en.moreActions),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseItem(WidgetTester tester, String label) async {
    await tester.tap(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('entry points', () {
    testWidgets('the Saved filters section ends with New saved filter', (
      tester,
    ) async {
      await pumpAt(tester, AppRoutes.projects);

      await tester.tap(find.text(en.savedFilterNew));
      await tester.pumpAndSettle();

      expect(find.byType(SavedFilterFormPage), findsOneWidget);
      expect(find.widgetWithText(AppBar, en.savedFilterNew), findsOneWidget);
    });

    testWidgets("the Projects tab's menu has it too, also without saved "
        'filters', (tester) async {
      data.projects.savedFilters = const [];
      await pumpAt(tester, AppRoutes.projects);
      expect(find.text(en.savedFilterNew), findsNothing);

      await tester.tap(find.byTooltip(en.moreActions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.savedFilterNew));
      await tester.pumpAndSettle();

      expect(find.byType(SavedFilterFormPage), findsOneWidget);
    });

    testWidgets("a saved filter's menu offers edit, favourite and delete; "
        'the Favorites list has no menu', (tester) async {
      await pumpAt(tester, AppRoutes.project(urgent.projectId));
      await openMenu(tester);

      expect(find.text(en.projectEdit), findsOneWidget);
      expect(find.text(en.projectAddToFavourites), findsOneWidget);
      expect(find.text(en.projectDelete), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      containerOf(tester)
          .read(appRouterProvider)
          .go(AppRoutes.project(Project.favoritesId));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip(en.moreActions),
        ),
        findsNothing,
      );
    });
  });

  group('new saved filter', () {
    testWidgets("starts like the web's: open tasks, tasks without a value "
        'included', (tester) async {
      await pumpAt(tester, AppRoutes.savedFilterNew);

      expect(fieldText(tester, en.filterLabel), 'done = false');
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, en.savedFilterIncludeNulls),
            )
            .value,
        isTrue,
      );
      expect(enabled(tester, en.projectCreate), isFalse);
    });

    testWidgets('creates it with the web sort and opens it', (tester) async {
      await pumpAt(tester, AppRoutes.savedFilterNew);

      await tester.enterText(formField(en.projectTitleLabel), ' Big ones ');
      await tester.enterText(
        formField(en.savedFilterDescriptionLabel),
        'Only the large',
      );
      await tester.enterText(formField(en.filterLabel), 'priority >= 3');
      await tester.pump();
      await tester.tap(find.text(en.savedFilterFavourite));
      await tester.pumpAndSettle();
      await tester.tap(appBarButton(en.projectCreate));
      await tester.pumpAndSettle();

      expect(data.savedFilters.calls, ['create Big ones']);
      expect(
        data.savedFilters.drafts.single,
        const SavedFilterDraft(
          title: 'Big ones',
          description: '<p>Only the large</p>',
          filter: ViewFilter(
            filter: 'priority >= 3',
            sortBy: ['done', 'id'],
            orderBy: ['asc', 'desc'],
            includeNulls: true,
          ),
          isFavorite: true,
        ),
      );
      expect(find.byType(SavedFilterFormPage), findsNothing);
      expect(find.byType(SmartListScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Big ones'), findsOneWidget);
      expect(find.text(en.savedFilterCreated), findsOneWidget);
    });

    testWidgets('needs a title and a filter', (tester) async {
      await pumpAt(tester, AppRoutes.savedFilterNew);

      await tester.enterText(formField(en.projectTitleLabel), 'Some');
      await tester.pump();
      expect(enabled(tester, en.projectCreate), isTrue);

      await tester.enterText(formField(en.filterLabel), '');
      await tester.pump();
      expect(find.text(en.savedFilterFilterRequired), findsOneWidget);
      expect(enabled(tester, en.projectCreate), isFalse);

      await tester.enterText(formField(en.filterLabel), 'done = true');
      await tester.enterText(formField(en.projectTitleLabel), '  ');
      await tester.pump();
      expect(find.text(en.projectTitleRequired), findsOneWidget);
      expect(enabled(tester, en.projectCreate), isFalse);
    });

    testWidgets('offline it stays open and says why', (tester) async {
      data.savedFilters.failure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpAt(tester, AppRoutes.savedFilterNew);

      await tester.enterText(formField(en.projectTitleLabel), 'Some');
      await tester.pump();
      await tester.tap(appBarButton(en.projectCreate));
      await tester.pumpAndSettle();

      expect(find.byType(SavedFilterFormPage), findsOneWidget);
      expect(find.text(en.savedFilterChangeNeedsConnection), findsOneWidget);
    });

    testWidgets('a filter the server refuses is explained at its field and '
        'announced', (tester) async {
      const message = "The task filter value 'x' for field 'labels' is invalid";
      data.savedFilters.failures['create'] = const DomainError(
        400,
        code: 4019,
        message: message,
      );
      await pumpAt(tester, AppRoutes.savedFilterNew);

      await tester.enterText(formField(en.projectTitleLabel), 'Some');
      await tester.pump();
      await tester.tap(appBarButton(en.projectCreate));
      await tester.pumpAndSettle();

      expect(find.text(en.projectViewFilterInvalid(message)), findsOneWidget);
      expect(
        tester.takeAnnouncements(),
        contains(
          isAccessibilityAnnouncement(en.projectViewFilterInvalid(message)),
        ),
      );
    });

    testWidgets('leaving with edits asks first', (tester) async {
      await pumpAt(tester, AppRoutes.savedFilterNew);
      await tester.enterText(formField(en.projectTitleLabel), 'Some');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(en.savedFilterEditDiscardBody), findsOneWidget);
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();

      expect(find.byType(SavedFilterFormPage), findsNothing);
      expect(find.byType(ProjectsScreen), findsOneWidget);
      expect(data.savedFilters.calls, isEmpty);
    });
  });

  group('edit', () {
    testWidgets('from the menu, with what is stored; save replaces it and '
        'keeps the search and sort the form does not show', (tester) async {
      await pumpAt(tester, AppRoutes.project(urgent.projectId));
      await openMenu(tester);
      await chooseItem(tester, en.projectEdit);

      expect(find.byType(SavedFilterFormPage), findsOneWidget);
      expect(fieldText(tester, en.projectTitleLabel), 'Urgent');
      expect(fieldText(tester, en.savedFilterDescriptionLabel), 'What burns');
      expect(
        fieldText(tester, en.filterLabel),
        'done = false && priority >= 4',
      );
      expect(enabled(tester, en.projectSave), isFalse);

      await tester.enterText(formField(en.projectTitleLabel), 'On fire');
      await tester.tap(find.text(en.savedFilterIncludeNulls));
      await tester.pumpAndSettle();
      await tester.tap(appBarButton(en.projectSave));
      await tester.pumpAndSettle();

      expect(data.savedFilters.calls, ['update -2 On fire']);
      expect(
        data.savedFilters.drafts.single,
        const SavedFilterDraft(
          title: 'On fire',
          description: 'What burns',
          filter: ViewFilter(
            filter: 'done = false && priority >= 4',
            search: 'kept',
            sortBy: ['due_date'],
            orderBy: ['desc'],
            includeNulls: true,
          ),
        ),
      );
      expect(find.byType(SavedFilterFormPage), findsNothing);
      expect(find.widgetWithText(AppBar, 'On fire'), findsOneWidget);
      expect(find.text(en.savedFilterSaved), findsOneWidget);
    });

    testWidgets("the web's rich-text description shows as text and goes back "
        'as stored unless it is edited', (tester) async {
      const rich = SavedFilterRef(
        projectId: -2,
        title: 'Urgent',
        description: '<p>What <strong>burns</strong> &amp; smokes</p>',
        definition: SavedFilterDefinition(
          filter: ViewFilter(filter: 'done = false'),
        ),
      );
      data.projects.savedFilters = [rich];
      await pumpAt(tester, AppRoutes.savedFilterEdit(rich.projectId));

      expect(
        fieldText(tester, en.savedFilterDescriptionLabel),
        'What burns & smokes',
      );
      await tester.enterText(formField(en.projectTitleLabel), 'On fire');
      await tester.pump();
      await tester.tap(appBarButton(en.projectSave));
      await tester.pumpAndSettle();
      expect(data.savedFilters.drafts.last.description, rich.description);

      await pumpAt(tester, AppRoutes.savedFilterEdit(rich.projectId));
      await tester.enterText(
        formField(en.savedFilterDescriptionLabel),
        'Fire <now> & "smoke"\nlater',
      );
      await tester.pump();
      await tester.tap(appBarButton(en.projectSave));
      await tester.pumpAndSettle();
      expect(
        data.savedFilters.drafts.last.description,
        '<p>Fire &lt;now&gt; &amp; &quot;smoke&quot;</p><p>later</p>',
      );
    });

    testWidgets('a definition this device does not know is read first', (
      tester,
    ) async {
      final read = Completer<void>();
      data.projects.savedFilters = const [
        SavedFilterRef(projectId: -2, title: 'Urgent'),
      ];
      data.savedFilters
        ..online[-2] = const SavedFilter(
          id: 1,
          title: 'Urgent',
          filter: ViewFilter(filter: 'priority = 5'),
        )
        ..beforeCall = (call) => read.future;
      await pumpAt(tester, AppRoutes.savedFilterEdit(-2), settle: false);

      expect(find.text(en.savedFilterLoading), findsOneWidget);
      read.complete();
      await tester.pumpAndSettle();

      expect(data.savedFilters.calls, ['read -2']);
      expect(fieldText(tester, en.filterLabel), 'priority = 5');
    });

    testWidgets('a failed read says so and can be tried again', (tester) async {
      data.projects.savedFilters = const [
        SavedFilterRef(projectId: -2, title: 'Urgent'),
      ];
      data.savedFilters
        ..online[-2] = const SavedFilter(
          id: 1,
          title: 'Urgent',
          filter: ViewFilter(filter: 'priority = 5'),
        )
        ..failure = const NetworkFailure(NetworkProblem.unreachable);
      await pumpAt(tester, AppRoutes.savedFilterEdit(-2));

      expect(find.text(en.savedFilterLoadFailed), findsOneWidget);
      expect(find.text(en.savedFilterChangeNeedsConnection), findsOneWidget);

      data.savedFilters.failure = null;
      await tester.tap(find.text(en.retry));
      await tester.pumpAndSettle();
      expect(fieldText(tester, en.filterLabel), 'priority = 5');
    });
  });

  group('menu', () {
    testWidgets('adds to and removes from the favourites', (tester) async {
      await pumpAt(tester, AppRoutes.project(urgent.projectId));

      await openMenu(tester);
      await chooseItem(tester, en.projectAddToFavourites);
      expect(data.savedFilters.calls, ['setFavorite -2 true']);
      expect(find.text(en.projectFavourited), findsOneWidget);

      await openMenu(tester);
      await chooseItem(tester, en.projectRemoveFromFavourites);
      expect(data.savedFilters.calls.last, 'setFavorite -2 false');
    });

    testWidgets('delete asks first, then goes back to the Projects tab', (
      tester,
    ) async {
      await pumpAt(tester, AppRoutes.project(urgent.projectId));

      await openMenu(tester);
      await chooseItem(tester, en.projectDelete);
      expect(find.text(en.savedFilterDeleteTitle('Urgent')), findsOneWidget);
      expect(find.text(en.savedFilterDeleteBody), findsOneWidget);
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(data.savedFilters.calls, isEmpty);

      await openMenu(tester);
      await chooseItem(tester, en.projectDelete);
      await tester.tap(find.text(en.projectDelete).last);
      await tester.pumpAndSettle();

      expect(data.savedFilters.calls, ['delete -2']);
      expect(find.byType(ProjectsScreen), findsOneWidget);
      expect(find.text(en.savedFilterDeleted), findsOneWidget);
      expect(find.text('Urgent'), findsNothing);
    });

    testWidgets('offline nothing changes and a message says why', (
      tester,
    ) async {
      data.savedFilters.failure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpAt(tester, AppRoutes.project(urgent.projectId));

      await openMenu(tester);
      await chooseItem(tester, en.projectAddToFavourites);

      expect(find.text(en.savedFilterChangeNeedsConnection), findsOneWidget);
      expect(data.projects.savedFilters.single.isFavorite, isFalse);
    });

    testWidgets("another user's saved filter cannot be changed, which the "
        'refusal says', (tester) async {
      data.savedFilters.failure = const Forbidden();
      await pumpAt(tester, AppRoutes.project(urgent.projectId));

      await openMenu(tester);
      await chooseItem(tester, en.projectAddToFavourites);

      expect(find.text(en.savedFilterChangeForbidden), findsOneWidget);
    });
  });
}
