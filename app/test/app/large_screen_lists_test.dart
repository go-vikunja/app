import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/time/today_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_row.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';
import 'package:vikunja_mobile/features/overview/application/overview_tasks_provider.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_header.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_column.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/project_board.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_header.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/reorder_slot.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/project_timeline_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_chart.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_controls.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_header.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_row.dart';
import 'package:vikunja_mobile/features/search/presentation/search_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/timeline_day.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/upcoming_screen.dart';

import '../features/inbox/inbox_samples.dart';
import '../helpers/label_user_fakes.dart';
import '../helpers/large_screens.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/sync_fakes.dart';

typedef ListScreen = ({
  Type type,
  Future<void> Function(WidgetTester tester) open,
  Finder rows,
  double margin,
  bool root,
});

// The list screens, the table included, at readable width (840) on large
// windows, the board and timeline left at the whole width, and phones as
// they were.
void main() {
  final now = DateTime(2026, 10, 10, 12);
  final finance = sampleLabel(id: 1, title: 'Finance', hexColor: 'ffeb10');
  // List, Gantt, Table and Kanban.
  final views = defaultViews(
    1,
    firstViewId: 11,
    defaultBucketId: 21,
    doneBucketId: 25,
  );
  late SyncFakes data;

  /// 45 open tasks over both projects and every due group, every fifth a
  /// favourite, every third with the label; and one done.
  List<Task> tasks() => [
    for (var id = 1; id <= 45; id++)
      sampleTask(
        id: id,
        title: 'Task $id',
        projectId: id.isEven ? 2 : 1,
        due: switch (id % 5) {
          0 => now.subtract(const Duration(days: 1)),
          1 => now.add(Duration(hours: id % 6 + 1)),
          2 => now.add(Duration(days: id % 6 + 1)),
          3 => now.add(const Duration(days: 30)),
          _ => null,
        },
        favorite: id % 5 == 0,
        labels: id % 3 == 0 ? [finance] : const [],
      ),
    sampleTask(id: 99, title: 'Done one', done: true, doneAt: now),
  ];

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(
        id: 1,
        title: 'Work',
        identifier: 'WORK',
        position: 100,
        views: views,
      ),
      sampleProject(id: 2, title: 'Home', position: 200),
      sampleProject(id: 3, title: 'Reports', parent: 1, position: 10),
    ];
    data.tasks.all = tasks();
    data.tasks.setSnapshot(
      'view:11',
      ListSnapshot(
        positions: {
          for (final task in data.tasks.all)
            if (task.projectId == 1) task.id: task.id * 100.0,
        },
        loadedAt: now,
      ),
    );
    data.tasks.setBoard(
      views.last,
      buckets: [
        for (var id = 21; id <= 25; id++)
          Bucket(id: id, viewId: 14, title: 'Column $id', position: id * 1.0),
      ],
      snapshot: {
        for (var id = 1; id <= 45; id += 2)
          id: (bucketId: 21 + id % 5, position: id * 1.0),
      },
      loadedAt: now,
    );
    final anna = payloadUser(id: 2, username: 'anna', name: 'Anna Example');
    data.activity.notifications = [
      for (var id = 1; id <= 3; id++)
        inboxNotification(
          id: id,
          name: 'task.assigned',
          created: now.subtract(Duration(hours: id)),
          payload: {
            'doer': anna,
            'task': payloadTask(id: id, title: 'Task $id'),
            'assignee': payloadUser(id: 7, username: 'alice'),
          },
        ),
    ];
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    List<Override> overrides = const [],
    bool settle = true,
  }) async {
    useWindow(tester, size);
    await pumpSignedInApp(
      tester,
      sync: data,
      now: now,
      overrides: [
        labelRepositoryProvider.overrideWithValue(
          FakeLabelRepository(labels: [finance]),
        ),
        ...overrides,
      ],
      settle: settle,
    );
  }

  Future<void> go(WidgetTester tester, String location) async {
    containerOf(tester).read(appRouterProvider).go(location);
    await tester.pumpAndSettle();
  }

  Future<void> push(WidgetTester tester, String location) async {
    unawaited(containerOf(tester).read(appRouterProvider).push(location));
    await tester.pumpAndSettle();
  }

  Finder verticalScrollableIn(Finder screen) => find
      .descendant(
        of: screen,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      )
      .first;

  /// The screen's list spans the window beside the rail (and within
  /// [sideInset], the safe area the screen keeps clear), and every one of
  /// [rows] fills the list's middle [ReadableWidth.list] less [margin] on
  /// each side, [inset] from the list's edges where given; beside the rail
  /// it follows from the rail's measured width.
  void expectListAt(
    WidgetTester tester, {
    required Finder screen,
    required Finder rows,
    required double margin,
    double? inset,
    double sideInset = 0,
  }) {
    final window = windowSize(tester);
    final caps = WindowLayout(window).capsWidths;
    final list = tester.getRect(verticalScrollableIn(screen));
    expect(
      list.left,
      moreOrLessEquals(railRight(tester) + sideInset, epsilon: 0.5),
      reason: 'the list starts at the rail or the window edge',
    );
    expect(
      list.right,
      moreOrLessEquals(window.width - sideInset, epsilon: 0.5),
      reason: 'the list ends at the window edge',
    );
    final measured = ReadableWidth.insetFor(
      available: list.width,
      max: ReadableWidth.list,
      caps: caps,
    );
    if (inset != null) expect(measured, moreOrLessEquals(inset));
    final band = (left: list.left + measured, right: list.right - measured);
    if (caps) {
      expect(band.right - band.left, lessThanOrEqualTo(ReadableWidth.list));
    } else {
      expect(measured, 0);
    }
    final found = rows.evaluate().toList();
    expect(found, isNotEmpty);
    for (final row in found) {
      expectFillsBand(
        tester.getRect(find.byElementPredicate((e) => e == row)),
        (left: band.left + margin, right: band.right - margin),
        reason: '${row.widget.runtimeType} in ${sizeName(window)}',
      );
    }
  }

  group('the Overview', () {
    // The insets of A3; at 1280×800 beside the rail, whose labels make it
    // wider in the test font than its 80 on a device.
    final insets = <Size, double?>{
      androidPhone: 0,
      androidSmallLandscape: 0,
      androidLandscape: 0,
      androidSplit: 0,
      androidTabletPortrait: 0,
      androidTabletLandscape: null,
      iPhone: 0,
      iPhoneLandscape: 0,
      iPad11Portrait: 0,
      iPad11Landscape: 177,
      iPad13Portrait: 92,
    };
    for (final (platform, sizes) in [
      (TargetPlatform.android, androidSizes),
      (TargetPlatform.iOS, iOSSizes),
    ]) {
      for (final size in sizes) {
        final inset = insets[size];
        testWidgets('at ${sizeName(size)}: the cards in the middle, '
            '${inset?.round() ?? 'centred beside the rail'}', (tester) async {
          await pumpAt(tester, size);

          final screen = find.byType(OverviewScreen);
          expectListAt(
            tester,
            screen: screen,
            rows: find.descendant(of: screen, matching: find.byType(TaskRow)),
            margin: 16,
            inset: inset,
            sideInset: size == iPhoneLandscape ? 47 : 0,
          );
          final header = tester.getRect(find.byType(OverviewHeader));
          final firstRow = tester.getRect(find.byType(TaskRow).first);
          expect(header.left, moreOrLessEquals(firstRow.left, epsilon: 0.5));
          expect(header.right, moreOrLessEquals(firstRow.right, epsilon: 0.5));
          expect(tester.takeException(), isNull);
        }, variant: TargetPlatformVariant.only(platform));
      }
    }

    for (final (platform, size) in [
      (TargetPlatform.android, androidTabletLandscape),
      (TargetPlatform.iOS, iPad11Landscape),
    ]) {
      testWidgets('at ${sizeName(size)}: a drag in the margin scrolls the '
          'list', (tester) async {
        await pumpAt(tester, size);

        final scrollable = verticalScrollableIn(find.byType(OverviewScreen));
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));
        final list = tester.getRect(scrollable);
        final firstRow = tester.getRect(find.byType(TaskRow).first);
        final margin = Offset((list.left + firstRow.left) / 2, list.center.dy);
        expect(firstRow.left - list.left, greaterThan(100));

        await tester.dragFrom(margin, const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(position.pixels, greaterThan(0));
      }, variant: TargetPlatformVariant.only(platform));
    }

    testWidgets('at 1280×800: a pull in the margin refreshes', (tester) async {
      await pumpAt(tester, androidTabletLandscape);
      final before = data.engine.refreshCalls;

      final scrollable = verticalScrollableIn(find.byType(OverviewScreen));
      final list = tester.getRect(scrollable);
      await tester.flingFrom(
        Offset(list.left + 40, list.top + 40),
        Offset(0, list.height * 0.5),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(data.engine.refreshCalls, before + 1);
    });

    testWidgets('at 1280×800: the header keeps its place from loading to '
        'the tasks', (tester) async {
      final overview = StreamController<OverviewTasks>();
      addTearDown(overview.close);
      await pumpAt(
        tester,
        androidTabletLandscape,
        overrides: [
          overviewTasksProvider.overrideWith((ref) => overview.stream),
        ],
        settle: false,
      );
      await pumpUntil(tester, find.byType(LoadingPlaceholder));
      // Past the page transition; the spinner never settles.
      await pumpFrames(tester, 10);
      final loading = tester.getRect(find.byType(OverviewHeader));

      overview.add(
        OverviewTasks(
          tasks: [
            for (final task in tasks())
              if (!task.done) task,
          ],
        ),
      );
      await pumpUntil(tester, find.byType(TaskRow));
      await tester.pumpAndSettle();

      expect(find.byType(LoadingPlaceholder), findsNothing);
      final loaded = tester.getRect(find.byType(OverviewHeader));
      // It grows by the count of today's tasks.
      expect(loaded.topLeft, offsetMoreOrLessEquals(loading.topLeft));
      expect(loaded.right, moreOrLessEquals(loading.right, epsilon: 0.5));
      final band = readableBand(tester, ReadableWidth.list);
      expectFillsBand(loaded, (left: band.left + 16, right: band.right - 16));
    });
  });

  group('every list screen', () {
    Future<void> search(WidgetTester tester) async {
      await push(tester, AppRoutes.search);
      await tester.enterText(
        find.descendant(
          of: find.byType(SearchPage),
          matching: find.byType(TextField),
        ),
        'Task',
      );
      await tester.pumpAndSettle();
    }

    // Pages over the shell (root) take the whole window; the rest sit
    // beside the rail on Android. Rows in cards keep the cards' margin.
    final screens = <ListScreen>[
      (
        type: UpcomingScreen,
        open: (tester) => go(tester, AppRoutes.upcoming),
        // The overdue card's; a day's rows sit beside its date.
        rows: find.byElementPredicate(
          (element) =>
              element.widget is TaskRow &&
              element.findAncestorWidgetOfExactType<TimelineDay>() == null,
        ),
        margin: 16,
        root: false,
      ),
      (
        type: ProjectsScreen,
        open: (tester) => go(tester, AppRoutes.projects),
        rows: find.byType(ProjectRow),
        margin: 16,
        root: false,
      ),
      (
        type: ProjectTasksScreen,
        open: (tester) => go(tester, AppRoutes.project(1)),
        rows: find.byType(TaskRow),
        margin: 0,
        root: false,
      ),
      (
        type: SmartListScreen,
        open: (tester) => go(tester, AppRoutes.project(Project.favoritesId)),
        rows: find.byType(TaskRow),
        margin: 16,
        root: false,
      ),
      (
        type: LabelTasksScreen,
        open: (tester) => push(tester, AppRoutes.labelTasks(finance.id)),
        rows: find.byType(TaskRow),
        margin: 16,
        root: true,
      ),
      (
        type: SearchPage,
        open: search,
        rows: find.byType(TaskRow),
        margin: 16,
        root: true,
      ),
      (
        type: InboxScreen,
        open: (tester) => push(tester, AppRoutes.inbox),
        rows: find.byType(InboxRow),
        margin: 16,
        root: true,
      ),
    ];
    for (final screen in screens) {
      // Null: centred beside the rail.
      for (final (platform, size, shellInset, rootInset) in [
        (TargetPlatform.android, androidLandscape, 0.0, 0.0),
        (TargetPlatform.android, androidTabletLandscape, null, 220.0),
        (TargetPlatform.iOS, iPad11Landscape, 177.0, 177.0),
      ]) {
        final inset = screen.root ? rootInset : shellInset;
        testWidgets('${screen.type} at ${sizeName(size)}: the rows in the '
            'middle, ${inset?.round() ?? 'centred beside the rail'}', (
          tester,
        ) async {
          await pumpAt(tester, size);
          await screen.open(tester);

          final found = find.byType(screen.type);
          expect(found, findsOneWidget);
          expectListAt(
            tester,
            screen: found,
            rows: find.descendant(of: found, matching: screen.rows),
            margin: screen.margin,
            inset: inset,
          );
          expect(tester.takeException(), isNull);
        }, variant: TargetPlatformVariant.only(platform));
      }
    }
  });

  group('beside the rail at 1280×800', () {
    Finder rowOf(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(TaskRow));

    Rect liftedRect(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byType(LiftedRows),
            matching: find.byType(Material),
          )
          .first,
    );

    testWidgets("a lifted list row is as wide as the list's rows", (
      tester,
    ) async {
      await pumpAt(tester, androidTabletLandscape);
      await go(tester, AppRoutes.project(1));

      final row = tester.getRect(rowOf('Task 1'));
      final band = readableBand(tester, ReadableWidth.list);
      expectFillsBand(row, band);
      final gesture = await tester.startGesture(row.center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      expect(liftedRect(tester).width, moreOrLessEquals(row.width));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("a lifted project is as wide as the tree's rows", (
      tester,
    ) async {
      await pumpAt(tester, androidTabletLandscape);
      await openTab(tester, en.tabProjects);

      final project = find.ancestor(
        of: find.text('Home'),
        matching: find.byType(ProjectRow),
      );
      final row = tester.getRect(project);
      final band = readableBand(tester, ReadableWidth.list);
      expectFillsBand(row, (left: band.left + 16, right: band.right - 16));
      final gesture = await tester.startGesture(row.center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      expect(liftedRect(tester).width, moreOrLessEquals(row.width));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets("a project's tabs and progress stay over the list's rows "
        'whichever view shows', (tester) async {
      await pumpAt(tester, androidTabletLandscape);
      await go(tester, AppRoutes.project(1));
      final band = readableBand(tester, ReadableWidth.list);

      final listTabs = tester.getRect(find.byType(TabBar));
      expectFillsBand(listTabs, band);
      expectInBand(tester.getRect(find.byType(ProjectProgressLine)), band);

      await tester.tap(find.text(views.last.title));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(TabBar)),
        rectMoreOrLessEquals(listTabs, epsilon: 0.5),
      );
    });

    testWidgets('the controls of the list, the table and the timeline keep '
        'one place under the tabs', (tester) async {
      await pumpAt(tester, androidTabletLandscape);
      await go(tester, AppRoutes.project(1));
      final band = readableBand(tester, ReadableWidth.list);
      final under = (left: band.left + 16, right: band.right - 16);

      expectFillsBand(tester.getRect(find.byType(ProjectListControls)), under);

      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      expectFillsBand(tester.getRect(find.byType(ProjectTableControls)), under);

      await tester.tap(find.text('Gantt'));
      await tester.pumpAndSettle();
      expectFillsBand(
        tester.getRect(find.byType(ProjectTimelineControls)),
        under,
      );
    });

    testWidgets("the table's rows are as wide as the list's", (tester) async {
      await pumpAt(tester, androidTabletLandscape);
      await go(tester, AppRoutes.project(1));
      final band = readableBand(tester, ReadableWidth.list);
      final listRow = tester.getRect(rowOf('Task 1'));
      expectFillsBand(listRow, band);

      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      final rows = find.byType(TaskRow).evaluate();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        final rect = tester.getRect(find.byElementPredicate((e) => e == row));
        expectFillsBand(rect, band);
        expect(rect.width, moreOrLessEquals(listRow.width));
      }
    });

    testWidgets('the board and the timeline take the whole width', (
      tester,
    ) async {
      await pumpAt(tester, androidTabletLandscape);
      await go(tester, AppRoutes.project(1));
      final whole = (left: railRight(tester), right: windowSize(tester).width);

      await tester.tap(find.text('Gantt'));
      await tester.pumpAndSettle();
      expectFillsBand(tester.getRect(find.byType(TimelineChart)), whole);

      await tester.tap(find.text(views.last.title));
      await tester.pumpAndSettle();
      expectFillsBand(tester.getRect(find.byType(ProjectBoard)), whole);
      expect(
        tester.getRect(find.byType(BoardColumnView).last).right,
        greaterThan(readableBand(tester, ReadableWidth.list).right),
      );
    });
  });

  for (final size in [androidPhone, androidTabletLandscape]) {
    testWidgets("at ${sizeName(size)} the tabs' divider runs across the app "
        'bar, below the tabs', (tester) async {
      await pumpAt(tester, size);
      await go(tester, AppRoutes.project(1));

      final tabs = find.byType(TabBar);
      expect(tester.widget<TabBar>(tabs).dividerColor, Colors.transparent);
      final divider = find.ancestor(
        of: tabs,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              switch (widget.decoration) {
                BoxDecoration(border: Border(:final bottom)) =>
                  bottom != BorderSide.none,
                _ => false,
              },
        ),
      );
      expect(divider, findsOneWidget);
      final line = tester.getRect(divider);
      final appBar = tester.getRect(find.byType(AppBar));
      expect((line.left, line.right), (appBar.left, appBar.right));
      expect(line.bottom, tester.getRect(tabs).bottom);
      final side =
          ((tester.widget<DecoratedBox>(divider).decoration as BoxDecoration)
                      .border!
                  as Border)
              .bottom;
      expect(
        (side.width, side.color),
        (1, Theme.of(tester.element(tabs)).colorScheme.outlineVariant),
      );
    });
  }

  testWidgets(
    "the timeline in a 400 wide box takes the box's width before it scrolls",
    (tester) async {
      useWindow(tester, androidTabletLandscape);
      const gantt = ProjectView(
        id: 12,
        projectId: 1,
        title: 'Gantt',
        kind: ProjectViewKind.gantt,
        position: 200,
      );
      final scheduled = [
        sampleTask(
          id: 1,
          title: 'Scheduled',
          start: DateTime(2026, 10, 12, 10),
          end: DateTime(2026, 10, 15, 10),
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [todayProvider.overrideWithValue(DateTime(2026, 10, 10))],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  child: ProjectTimelineBody(
                    view: gantt,
                    source: ProjectListSource(
                      projectTasks: scheduled,
                      tasksById: {for (final task in scheduled) task.id: task},
                      matchingIds: {for (final task in scheduled) task.id},
                    ),
                    preferences: const ViewPreferences(),
                    offline: false,
                    downloadFailed: false,
                    header: null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TimelineHeader>(find.byType(TimelineHeader))
            .viewportWidth,
        400,
      );
      expect(
        tester.widget<TimelineRow>(find.byType(TimelineRow)).viewportWidth,
        400,
      );
    },
  );
}
