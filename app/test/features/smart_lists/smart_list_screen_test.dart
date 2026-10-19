import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_service_provider.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';

import '../../helpers/fake_quick_add_service.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  const unreachable = NetworkFailure(NetworkProblem.unreachable);
  const filter = SavedFilterRef(projectId: -2, title: 'Due this week');
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(id: 2, title: 'Inbox', hexColor: 'e8445a'),
      sampleProject(id: 3, title: 'Old', archived: true),
    ];
    data.projects.savedFilters = [
      filter,
      const SavedFilterRef(projectId: -3, title: 'My Open Tasks'),
    ];
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Overdue star',
        due: now.subtract(const Duration(days: 1)),
        favorite: true,
      ),
      sampleTask(
        id: 2,
        title: 'Inbox star',
        projectId: 2,
        due: now.add(const Duration(hours: 2)),
        favorite: true,
      ),
      sampleTask(id: 3, title: 'Undated star', favorite: true),
      sampleTask(id: 4, title: 'Plain'),
      sampleTask(id: 5, title: 'Done star', done: true, favorite: true),
      sampleTask(id: 6, title: 'Archived star', projectId: 3, favorite: true),
    ];
    data.tasks.archivedProjectIds = {3};
  });

  List<String> headings(WidgetTester tester) => [
    for (final header in tester.widgetList<ListSectionHeader>(
      find.byType(ListSectionHeader),
    ))
      header.title,
  ];

  List<String> rowTitles(WidgetTester tester) => [
    for (final row in tester.widgetList<TaskRow>(find.byType(TaskRow)))
      row.task.title,
  ];

  Future<void> openList(
    WidgetTester tester,
    int pseudoProjectId, {
    bool settle = true,
  }) async {
    await pumpSignedInApp(
      tester,
      sync: data,
      now: now,
      overrides: [
        quickAddServiceProvider.overrideWithValue(FakeQuickAddService()),
      ],
    );
    containerOf(tester)
        .read(appRouterProvider)
        .go(AppRoutes.project(pseudoProjectId));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await pumpFrames(tester, 3);
    }
  }

  group('Favorites', () {
    testWidgets('the open favourite tasks outside archived projects, grouped '
        'like the Overview, with their projects', (tester) async {
      await openList(tester, Project.favoritesId);

      expect(find.byType(SmartListScreen), findsOneWidget);
      expect(
        find.widgetWithText(AppBar, en.projectFavouritesTitle),
        findsOneWidget,
      );
      expect(headings(tester), [
        en.sectionOverdue,
        en.sectionToday,
        en.sectionNoDueDate,
      ]);
      expect(rowTitles(tester), ['Overdue star', 'Inbox star', 'Undated star']);
      expect(
        tester
            .widget<TaskRow>(find.widgetWithText(TaskRow, 'Inbox star'))
            .projectTitle,
        en.projectInboxTitle,
      );
      expect(data.tasks.savedFilterRefreshes, isEmpty);
    });

    testWidgets('work offline: nothing is downloaded for them', (tester) async {
      data = SyncFakes(
        now: now,
        status: SyncFailed(failure: unreachable, lastSyncedAt: now),
      )..projects.all = [sampleProject(id: 1, title: 'Work')];
      data.tasks.all = [sampleTask(id: 1, title: 'Star', favorite: true)];
      data.engine.onRefresh = () async => throw unreachable;
      await openList(tester, Project.favoritesId);

      expect(rowTitles(tester), ['Star']);
      expect(
        find.textContaining(en.offlineNotice, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a task no longer a favourite leaves; one marked done stays '
        'while its Undo is offered', (tester) async {
      await openList(tester, Project.favoritesId);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(TaskRow, 'Undated star'),
          matching: find.byTooltip(en.taskRemoveFavourite),
        ),
      );
      await tester.pumpAndSettle();
      expect(data.tasks.writes, ['setFavorite 3 false']);
      expect(rowTitles(tester), ['Overdue star', 'Inbox star']);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(TaskRow, 'Overdue star'),
          matching: find.byTooltip(en.taskMarkDone),
        ),
      );
      await tester.pumpAndSettle();
      expect(data.tasks.writes.last, 'setDone 1 true');
      expect(rowTitles(tester), ['Overdue star', 'Inbox star']);
      await tester.pump(markedDoneSnackBarDuration);
      await tester.pumpAndSettle();
      expect(rowTitles(tester), ['Inbox star']);
    });

    testWidgets('without favourites says how to get some', (tester) async {
      data.tasks.all = [sampleTask(id: 4, title: 'Plain')];
      await openList(tester, Project.favoritesId);

      expect(find.text(en.favoritesEmptyTitle), findsOneWidget);
      expect(find.text(en.favoritesEmptyBody), findsOneWidget);
    });

    testWidgets('pull to refresh runs a sync', (tester) async {
      await openList(tester, Project.favoritesId);

      await pullToRefresh(tester, find.byType(CustomScrollView));

      expect(data.engine.refreshCalls, 1);
      expect(data.tasks.savedFilterRefreshes, isEmpty);
    });
  });

  group('saved filter', () {
    void serveFilter(List<int> taskIds) =>
        data.tasks.onRefreshSavedFilter = (pseudoProjectId) async =>
            data.tasks.setSavedFilterSnapshot(
              pseudoProjectId,
              ListSnapshot(
                positions: {for (final id in taskIds) id: 0},
                loadedAt: now,
              ),
            );

    testWidgets('never downloaded, it downloads on open and shows the '
        "server's answer with when it came", (tester) async {
      serveFilter([2, 4]);
      await openList(tester, filter.projectId);

      expect(find.widgetWithText(AppBar, 'Due this week'), findsOneWidget);
      expect(data.tasks.savedFilterRefreshes, [filter.projectId]);
      expect(rowTitles(tester), ['Inbox star', 'Plain']);
      expect(
        find.text(en.smartListFilterNotice(en.relativeNow)),
        findsOneWidget,
      );
    });

    testWidgets('says it is downloading while the first download runs', (
      tester,
    ) async {
      final download = Completer<void>();
      data.tasks.onRefreshSavedFilter = (_) => download.future;
      await openList(tester, filter.projectId, settle: false);

      expect(find.text(en.smartListFilterDownloadingTitle), findsOneWidget);
      expect(
        find.text(en.smartListFilterDownloadingBody('Due this week')),
        findsOneWidget,
      );

      download.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('offline and never downloaded, it loads once online', (
      tester,
    ) async {
      data.engine.onRefresh = () async => throw unreachable;
      await openList(tester, filter.projectId);

      expect(find.text(en.overviewFilterNotLoadedTitle), findsOneWidget);
      expect(
        find.text(en.smartListFilterNotLoadedBody('Due this week')),
        findsOneWidget,
      );
    });

    testWidgets('offline and never downloaded, it downloads once back '
        'online', (tester) async {
      data.engine.onRefresh = () async => throw unreachable;
      await openList(tester, filter.projectId);
      expect(find.text(en.overviewFilterNotLoadedTitle), findsOneWidget);

      data.engine.onRefresh = null;
      serveFilter([2, 4]);
      data.engine.emit(SyncIdle(lastSyncedAt: now));
      await tester.pumpAndSettle();

      expect(data.tasks.savedFilterRefreshes, [
        filter.projectId,
        filter.projectId,
      ]);
      expect(rowTitles(tester), ['Inbox star', 'Plain']);
      expect(find.text(en.overviewFilterNotLoadedTitle), findsNothing);
    });

    testWidgets('a filter deleted on the web says it is gone once the sync '
        'drops it and its tasks, and downloads nothing', (tester) async {
      data.tasks.setSavedFilterSnapshot(
        filter.projectId,
        ListSnapshot(positions: const {4: 0}, loadedAt: now),
      );
      await openList(tester, filter.projectId);
      expect(rowTitles(tester), ['Plain']);

      data.projects.savedFilters = [
        const SavedFilterRef(projectId: -3, title: 'My Open Tasks'),
      ];
      data.tasks.removeSavedFilterSnapshot(filter.projectId);
      await tester.pumpAndSettle();

      expect(find.text(en.smartListFilterGoneTitle), findsOneWidget);
      expect(find.text(en.smartListFilterGoneBody), findsOneWidget);
      expect(find.text(en.smartListFilterDownloadingTitle), findsNothing);
      expect(
        find.widgetWithText(AppBar, en.savedFilterUnknownTitle),
        findsOneWidget,
      );
      expect(data.tasks.savedFilterRefreshes, isEmpty);
    });

    testWidgets('tasks that go while the filter is still listed download '
        'again, saying so only while that runs', (tester) async {
      data.tasks.setSavedFilterSnapshot(
        filter.projectId,
        ListSnapshot(positions: const {4: 0}, loadedAt: now),
      );
      await openList(tester, filter.projectId);
      final download = Completer<void>();
      data.tasks.onRefreshSavedFilter = (_) => download.future;

      data.tasks.removeSavedFilterSnapshot(filter.projectId);
      await pumpFrames(tester, 3);
      expect(data.tasks.savedFilterRefreshes, [filter.projectId]);
      expect(find.text(en.smartListFilterDownloadingTitle), findsOneWidget);

      data.tasks.refreshSavedFilterFailure = const NotFound();
      download.complete();
      await tester.pumpAndSettle();
      expect(find.text(en.smartListFilterDownloadingTitle), findsNothing);
      expect(find.text(en.smartListFilterDownloadFailedTitle), findsOneWidget);
      expect(data.tasks.savedFilterRefreshes, hasLength(1));
    });

    testWidgets('a download the server fails says so; pulling down tries '
        'again', (tester) async {
      data.tasks.refreshSavedFilterFailure = const ServerFailure(500);
      await openList(tester, filter.projectId);

      expect(find.text(en.smartListFilterDownloadFailedTitle), findsOneWidget);

      data.tasks.refreshSavedFilterFailure = null;
      serveFilter([4]);
      await pullToRefresh(tester, find.byType(CustomScrollView));

      expect(data.tasks.savedFilterRefreshes, hasLength(2));
      expect(rowTitles(tester), ['Plain']);
    });

    testWidgets('a download from the last five minutes is not repeated on '
        'open; an older one is', (tester) async {
      data.tasks.setSavedFilterSnapshot(
        filter.projectId,
        ListSnapshot(
          positions: const {4: 0},
          loadedAt: now.subtract(const Duration(minutes: 4)),
        ),
      );
      data.tasks.setSavedFilterSnapshot(
        -3,
        ListSnapshot(
          positions: const {4: 0},
          loadedAt: now.subtract(const Duration(minutes: 6)),
        ),
      );
      await openList(tester, filter.projectId);
      expect(rowTitles(tester), ['Plain']);
      expect(data.tasks.savedFilterRefreshes, isEmpty);

      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(-3));
      await tester.pumpAndSettle();
      expect(data.tasks.savedFilterRefreshes, [-3]);
    });

    testWidgets('pull to refresh downloads it again', (tester) async {
      data.tasks.setSavedFilterSnapshot(
        filter.projectId,
        ListSnapshot(positions: const {4: 0}, loadedAt: now),
      );
      await openList(tester, filter.projectId);
      serveFilter([2, 4]);

      await pullToRefresh(tester, find.byType(CustomScrollView));

      expect(data.tasks.savedFilterRefreshes, [filter.projectId]);
      expect(rowTitles(tester), ['Inbox star', 'Plain']);
    });

    testWidgets('a task done here leaves the list after its Undo', (
      tester,
    ) async {
      data.tasks.setSavedFilterSnapshot(
        filter.projectId,
        ListSnapshot(positions: const {2: 0, 4: 0}, loadedAt: now),
      );
      await openList(tester, filter.projectId);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(TaskRow, 'Plain'),
          matching: find.byTooltip(en.taskMarkDone),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(markedDoneSnackBarDuration);
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['setDone 4 true']);
      expect(rowTitles(tester), ['Inbox star']);
    });

    testWidgets('a task of an archived project shows done and favourite '
        'without changing them, as the server refuses that', (tester) async {
      data.tasks.setSavedFilterSnapshot(
        filter.projectId,
        ListSnapshot(positions: const {4: 0, 6: 0}, loadedAt: now),
      );
      await openList(tester, filter.projectId);

      final archivedRow = tester.widget<TaskRow>(
        find.widgetWithText(TaskRow, 'Archived star'),
      );
      expect(archivedRow.onDoneChanged, isNull);
      expect(archivedRow.onFavoriteChanged, isNull);
      final plainRow = tester.widget<TaskRow>(
        find.widgetWithText(TaskRow, 'Plain'),
      );
      expect(plainRow.onDoneChanged, isNotNull);
      expect(plainRow.onFavoriteChanged, isNotNull);
    });

    testWidgets('so does a task of a project below an archived one', (
      tester,
    ) async {
      data.projects.all = [
        ...data.projects.all,
        sampleProject(id: 4, title: 'Old child', parent: 3),
      ];
      data.tasks.all = [
        ...data.tasks.all,
        sampleTask(id: 7, title: 'Inherited', projectId: 4),
      ];
      data.tasks.setSavedFilterSnapshot(
        filter.projectId,
        ListSnapshot(positions: const {4: 0, 7: 0}, loadedAt: now),
      );
      await openList(tester, filter.projectId);

      final row = tester.widget<TaskRow>(
        find.widgetWithText(TaskRow, 'Inherited'),
      );
      expect(row.onDoneChanged, isNull);
      expect(row.onFavoriteChanged, isNull);
    });

    testWidgets('downloaded and empty says nothing matches', (tester) async {
      data.tasks.setSavedFilterSnapshot(
        filter.projectId,
        ListSnapshot(loadedAt: now),
      );
      await openList(tester, filter.projectId);

      expect(find.text(en.overviewEmptyTitle), findsOneWidget);
      expect(
        find.text(en.overviewFilterEmptyBody('Due this week')),
        findsOneWidget,
      );
    });

    testWidgets('the default filter has its name in the user language; one '
        'the sync no longer sees a generic one', (tester) async {
      useLocale(tester, const Locale('de'));
      data.tasks.setSavedFilterSnapshot(-3, ListSnapshot(loadedAt: now));
      data.tasks.setSavedFilterSnapshot(-9, ListSnapshot(loadedAt: now));
      await openList(tester, -3);
      expect(
        find.widgetWithText(AppBar, de.savedFilterMyOpenTasks),
        findsOneWidget,
      );

      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(-9));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppBar, de.savedFilterUnknownTitle),
        findsOneWidget,
      );
    });

    testWidgets('New task opens the sheet without a project picked', (
      tester,
    ) async {
      data.tasks.setSavedFilterSnapshot(
        filter.projectId,
        ListSnapshot(loadedAt: now),
      );
      await openList(tester, filter.projectId);

      await tester.tap(find.byTooltip(en.newTask));
      await tester.pumpAndSettle();

      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(
        tester.widget<NewTaskSheet>(find.byType(NewTaskSheet)).projectId,
        isNull,
      );
    });
  });
}
