import 'dart:async';
import 'dart:io';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/common/presentation/count_badge.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_card.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_column.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/column_menu.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/new_column_tile.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/announcer_region.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_edits.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  /// The view the project opens on; the kanban view unless a test clears it.
  int? openViewId;

  final listView = sampleListView(id: 11, projectId: 1);
  final kanban = sampleKanbanView(
    id: 14,
    projectId: 1,
    defaultBucketId: 21,
    doneBucketId: 23,
  );
  const anna = User(id: 9, username: 'anna', name: 'Anna');

  Bucket bucket(int id, String title, {int count = 0, int limit = 0}) => Bucket(
    id: id,
    viewId: 14,
    title: title,
    count: count,
    limit: limit,
    position: (id - 20) * 100.0,
  );

  List<Bucket> buckets({int doingLimit = 0, int todoCount = 3}) => [
    bucket(21, 'To-Do', count: todoCount),
    bucket(22, 'Doing', count: 2, limit: doingLimit),
    bucket(23, 'Done', count: 1),
  ];

  const snapshot = <int, ({int bucketId, double position})>{
    1: (bucketId: 21, position: 100),
    2: (bucketId: 21, position: 200),
    3: (bucketId: 21, position: 300),
    4: (bucketId: 22, position: 1000),
    5: (bucketId: 22, position: 2000),
    6: (bucketId: 23, position: 500),
  };

  List<Task> tasks() => [
    sampleTask(
      id: 1,
      title: 'Write report',
      identifier: 'WORK-1',
      due: now.subtract(const Duration(days: 1)),
      priority: TaskPriority.high,
      labels: [sampleLabel(id: 1, title: 'Office')],
      assignees: const [anna],
      description: [
        '<li data-checked="true">a</li>',
        '<li data-checked="false">b</li>',
      ].join(),
      percentDone: 0.5,
      hexColor: 'e8445a',
    ),
    sampleTask(id: 2, title: 'Call Anna'),
    sampleTask(id: 3, title: 'Plan trip', repeatAfter: const Duration(days: 7)),
    sampleTask(id: 4, title: 'Fix bike'),
    sampleTask(id: 5, title: 'Read book'),
    sampleTask(id: 6, title: 'Finished', done: true, doneAt: now),
  ];

  Project work({List<ProjectView>? views, bool archived = false}) =>
      sampleProject(
        id: 1,
        title: 'Work',
        archived: archived,
        views: views ?? [listView, kanban],
      );

  void storeBoard({
    ProjectView? view,
    List<Bucket>? columns,
    Map<int, ({int bucketId, double position})> cards = snapshot,
    DateTime? loadedAt,
  }) => data.tasks.setBoard(
    view ?? kanban,
    buckets: columns ?? buckets(),
    snapshot: cards,
    loadedAt: loadedAt ?? now,
  );

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [work()];
    data.tasks.all = tasks();
    openViewId = 14;
    storeBoard();
  });

  /// Wide enough for the three columns side by side, below the width that
  /// puts the project tree beside the board.
  const wide = Size(1100, 900);

  Future<void> pumpBoard(
    WidgetTester tester, {
    Size size = wide,
    bool settle = true,
  }) async {
    usePhoneSurface(tester, logicalSize: size);
    await pumpSignedInApp(
      tester,
      sync: data,
      now: now,
      overrides: [
        labelRepositoryProvider.overrideWithValue(FakeLabelRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    containerOf(tester)
        .read(appRouterProvider)
        .go(AppRoutes.project(1, viewId: openViewId));
    if (settle) await tester.pumpAndSettle();
  }

  Finder columnOf(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(BoardColumnView),
  );

  /// The scroll view of [column]'s cards.
  Finder cardsOfColumn(String column) => find
      .descendant(of: columnOf(column), matching: find.byType(CustomScrollView))
      .first;

  Finder headerOf(String column) =>
      find.descendant(of: columnOf(column), matching: find.text(column)).first;

  Finder cardOf(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(BoardCard));

  List<String> columnTitles(WidgetTester tester) => [
    for (final column in tester.widgetList<BoardColumnView>(
      find.byType(BoardColumnView),
    ))
      column.column.bucket.title,
  ];

  List<String> cardsIn(WidgetTester tester, String column) => [
    for (final card in tester.widgetList<BoardCard>(
      find.descendant(of: columnOf(column), matching: find.byType(BoardCard)),
    ))
      card.task.title,
  ];

  Text countIn(WidgetTester tester, String column) => tester.widget<Text>(
    find.descendant(
      of: find.descendant(
        of: columnOf(column),
        matching: find.byType(CountBadge),
      ),
      matching: find.byType(Text),
    ),
  );

  /// Long-presses [title]'s card and moves it to [to] in steps, so the
  /// board follows the finger, then lets go.
  Future<void> dragCard(WidgetTester tester, String title, Offset to) async {
    final from = tester.getCenter(cardOf(title));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    for (var step = 1; step <= 6; step++) {
      await gesture.moveTo(Offset.lerp(from, to, step / 6)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// Between the cards [above] and [below], or under [above] when [below]
  /// is null.
  Offset gapBelow(WidgetTester tester, String above, {String? below}) {
    final upper = tester.getRect(cardOf(above));
    final lower = below == null ? null : tester.getRect(cardOf(below));
    return Offset(
      upper.center.dx,
      lower == null ? upper.bottom + 4 : (upper.bottom + lower.top) / 2,
    );
  }

  Offset aboveCard(WidgetTester tester, String title) {
    final rect = tester.getRect(cardOf(title));
    return Offset(rect.center.dx, rect.top + 8);
  }

  List<String> actionsOf(WidgetTester tester, String title) => [
    for (final id
        in tester
                .getSemantics(find.text(title))
                .getSemanticsData()
                .customSemanticsActionIds ??
            const <int>[])
      CustomSemanticsAction.getAction(id)!.label!,
  ];

  void performAction(WidgetTester tester, String title, String label) {
    final node = tester.getSemantics(find.text(title));
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label)),
    );
  }

  List<Object?> recordHaptics(WidgetTester tester) {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  group('the view', () {
    testWidgets('the tabs offer the kanban view among the list views, the '
        'default name translated', (tester) async {
      useLocale(tester, const Locale('de'));
      openViewId = null;
      await pumpBoard(tester);

      expect(find.widgetWithText(Tab, de.projectViewList), findsOne);
      expect(find.widgetWithText(Tab, de.projectViewKanban), findsOne);
      expect(find.byType(TaskRow), findsWidgets);

      await tester.tap(find.widgetWithText(Tab, de.projectViewKanban));
      await tester.pumpAndSettle();

      expect(find.byType(TaskRow), findsNothing);
      expect(columnTitles(tester), ['To-Do', 'Doing', 'Done']);
      expect(data.listPreferences.saves, ['lastView 1']);
      expect(data.listPreferences.lastViews, {1: 14});
    });

    testWidgets('the board last left in opens again, before default_view '
        'list', (tester) async {
      openViewId = null;
      data.shared.settings = const UserSettings(
        defaultViewKind: ProjectViewKind.list,
      );
      data.listPreferences.lastViews[1] = 14;
      await pumpBoard(tester);

      expect(columnTitles(tester), ['To-Do', 'Doing', 'Done']);
      expect(find.byType(TaskRow), findsNothing);
      expect(data.listPreferences.saves, isEmpty);
    });

    testWidgets('default_view kanban opens the board', (tester) async {
      openViewId = null;
      data.shared.settings = const UserSettings(
        defaultViewKind: ProjectViewKind.kanban,
      );
      await pumpBoard(tester);

      expect(columnTitles(tester), ['To-Do', 'Doing', 'Done']);
      expect(data.tasks.boardWatches.last, (1, 14));
    });

    testWidgets('a project with only a kanban view opens it without tabs', (
      tester,
    ) async {
      data.projects.all = [
        work(views: [kanban]),
      ];
      await pumpBoard(tester);

      expect(find.byType(TabBar), findsNothing);
      expect(columnTitles(tester), ['To-Do', 'Doing', 'Done']);
    });

    testWidgets('the menu keeps refresh and follow; no sort and show done '
        'chips', (tester) async {
      await pumpBoard(tester);

      expect(find.byIcon(Icons.sort), findsNothing);
      expect(find.text(en.projectShowDoneChip), findsNothing);
      await tester.tap(find.byTooltip(en.moreActions));
      await tester.pumpAndSettle();
      expect(find.text(en.refresh), findsOneWidget);
      expect(find.text(en.followProject), findsOneWidget);
    });
  });

  group('rendering', () {
    testWidgets('columns in order with their cards; the header counts, the '
        'limit and the done marker', (tester) async {
      data.tasks.setBoard(
        kanban,
        buckets: [
          bucket(21, 'To-Do', count: 3),
          bucket(22, 'Doing', count: 2, limit: 2),
          bucket(23, 'Done', count: 1),
        ],
        snapshot: snapshot,
        loadedAt: now,
      );
      await pumpBoard(tester);
      final colors = Theme.of(tester.element(find.byType(BoardCard).first))
          .colorScheme;

      expect(cardsIn(tester, 'To-Do'), [
        'Write report',
        'Call Anna',
        'Plan trip',
      ]);
      expect(cardsIn(tester, 'Doing'), ['Fix bike', 'Read book']);
      expect(cardsIn(tester, 'Done'), ['Finished']);

      expect(countIn(tester, 'To-Do').data, '3');
      expect(
        countIn(tester, 'To-Do').style?.color,
        colors.onSecondaryContainer,
      );
      // Full: in the error colours, as on the web.
      expect(countIn(tester, 'Doing').data, '2/2');
      expect(countIn(tester, 'Doing').style?.color, colors.onError);
      expect(
        find.descendant(
          of: columnOf('Done'),
          matching: find.byIcon(Icons.done_all),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(find.byTooltip(en.boardDoneColumnHint), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('a card is lighter than its column in ${brightness.name} '
          'mode', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        data.tasks.setBoard(
          kanban,
          buckets: [bucket(21, 'To-Do', count: 3)],
          snapshot: snapshot,
          loadedAt: now,
        );
        await pumpBoard(tester);
        final theme = Theme.of(tester.element(find.byType(BoardCard).first));
        expect(theme.brightness, brightness);

        final card = tester.widget<Card>(
          find.descendant(
            of: cardOf('Write report'),
            matching: find.byType(Card),
          ),
        );
        expect(
          card.color!.computeLuminance(),
          greaterThan(theme.colorScheme.surfaceContainerLow.computeLuminance()),
        );
      });
    }

    testWidgets('an open task downloaded in the done column stays there '
        'until it is reopened here', (tester) async {
      data.tasks.all = [
        for (final task in tasks())
          if (task.id == 6) sampleTask(id: 6, title: 'Finished') else task,
      ];
      await pumpBoard(tester);

      expect(cardsIn(tester, 'Done'), ['Finished']);

      data.tasks.setQueuedDoneChanges({6});
      await tester.pumpAndSettle();

      expect(cardsIn(tester, 'Done'), isEmpty);
      expect(cardsIn(tester, 'To-Do'), contains('Finished'));
    });

    testWidgets('a header reads title, count, limit and done hint as one '
        'heading', (tester) async {
      final semantics = tester.ensureSemantics();
      data.tasks.setBoard(
        kanban,
        buckets: [
          bucket(21, 'To-Do', count: 3),
          bucket(22, 'Doing', count: 2, limit: 2),
          bucket(23, 'Done', count: 1),
        ],
        snapshot: snapshot,
        loadedAt: now,
      );
      await pumpBoard(tester);

      expect(
        tester.getSemantics(headerOf('Doing')),
        matchesSemantics(
          label:
              'Doing\n${en.boardColumnTaskCountOfLimit(2, 2)}\n'
              '${en.boardColumnFull}',
          isHeader: true,
        ),
      );
      expect(
        tester.getSemantics(headerOf('Done')),
        matchesSemantics(
          label:
              'Done\n${en.boardColumnTaskCount(1)}\n${en.boardDoneColumnHint}',
          isHeader: true,
        ),
      );
      expect(en.boardColumnTaskCountOfLimit(1, 1), '1 of at most 1 task');
      expect(de.boardColumnTaskCountOfLimit(1, 1), '1 von höchstens 1 Aufgabe');
      expect(
        de.boardColumnTaskCountOfLimit(2, 3),
        '2 von höchstens 3 Aufgaben',
      );
      semantics.dispose();
    });

    testWidgets("a card shows the web card's content and reads as one node "
        'with the row label', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBoard(tester);
      final card = cardOf('Write report');
      final colors = Theme.of(tester.element(card)).colorScheme;

      for (final text in ['Office', en.priorityHigh, '1/2']) {
        expect(find.descendant(of: card, matching: find.text(text)), findsOne);
      }
      expect(
        find.descendant(of: card, matching: find.textContaining('WORK-1')),
        findsNothing,
      );
      final due = find.descendant(
        of: card,
        matching: find.text(en.relativeYesterday),
      );
      expect(tester.widget<Text>(due).style?.color, colors.error);
      expect(
        find.descendant(of: card, matching: find.byIcon(Icons.notes)),
        findsOne,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOne,
      );
      expect(
        find.descendant(
          of: cardOf('Plan trip'),
          matching: find.byIcon(Icons.repeat),
        ),
        findsOne,
      );
      expect(
        find.descendant(
          of: cardOf('Finished'),
          matching: find.text(en.taskDoneSemantics),
        ),
        findsOne,
      );
      // No done control and no star, as on the web.
      expect(find.byType(TaskDoneControl), findsNothing);

      final node = tester.getSemantics(find.text('Write report'));
      expect(tester.getSemantics(find.text('Office')), same(node));
      final label = node.getSemanticsData().label;
      expect(
        label,
        startsWith(
          'Write report\n'
          '${en.taskOverdueSemantics(en.relativeYesterday)}\n',
        ),
      );
      expect(label, isNot(contains('WORK-1')));
      expect(label, contains(en.taskAssigneesSemantics('Anna')));
      expect(label, contains(en.taskPercentDone(50)));
      expect(
        tester.getSemantics(find.text('Finished')).getSemanticsData().label,
        contains(en.taskDoneSemantics),
      );
      semantics.dispose();
    });

    testWidgets('a card is a button at least 48 dp tall, a one-line card '
        "too, and each column's add button names its column", (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBoard(tester, size: const Size(1600, 900));

      final cards = find.byType(BoardCard);
      expect(cards, findsWidgets);
      for (final card in cards.evaluate()) {
        final size = (card.renderObject! as RenderBox).size;
        expect(size.height, greaterThanOrEqualTo(48), reason: '${card.widget}');
        final title = (card.widget as BoardCard).task.title;
        expect(
          tester
              .getSemantics(find.text(title))
              .getSemanticsData()
              .flagsCollection
              .isButton,
          isTrue,
          reason: title,
        );
      }
      for (final column in ['To-Do', 'Doing', 'Done']) {
        final name = en.boardAddAnotherTaskTo(column);
        expect(name, startsWith(en.boardAddAnotherTask));
        expect(find.bySemanticsLabel(name), findsOneWidget, reason: column);
      }
      semantics.dispose();
    });

    testWidgets('on a phone the board settles on a column, with the next one '
        'peeking in', (tester) async {
      await pumpBoard(tester, size: const Size(400, 800));
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(tester.getSize(columnOf('To-Do')).width, 280);
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('Call Anna'),
                matching: find.byType(BoardCard),
              ),
            )
            .width,
        280 - 2 * 8,
        reason: 'a card fills its column, whatever its content',
      );

      await tester.timedDrag(
        headerOf('To-Do'),
        const Offset(-200, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();

      expect(position.pixels, 280 + 12);
    });

    testWidgets('in landscape the first column and the tile after the last '
        'stay clear of the notch', (tester) async {
      tester.view.padding = const FakeViewPadding(left: 47 * 3, right: 47 * 3);
      addTearDown(tester.view.resetPadding);
      storeBoard(columns: [...buckets(), bucket(24, 'Later')]);
      await pumpBoard(tester, size: const Size(844, 390));

      expect(tester.getRect(columnOf('To-Do')).left, 47 + 16);
      final board = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      board.position.jumpTo(board.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(NewColumnTile)).right, 844 - 47 - 16);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a tap opens the task', (tester) async {
      await pumpBoard(tester);

      await tester.tap(find.text('Call Anna'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsOneWidget);
    });

    testWidgets('on a phone a tap opens the task in a sheet', (tester) async {
      await pumpBoard(tester, size: const Size(400, 800));

      await tester.tap(find.text('Call Anna'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TaskDetailSheet),
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty columns offer to add a task; "Add another task" '
        'where there are cards; the spoken name starts with the shown '
        'text', (tester) async {
      final semantics = tester.ensureSemantics();
      storeBoard(columns: [...buckets(), bucket(24, 'Later')]);
      await pumpBoard(tester, size: const Size(1600, 900));

      expect(
        find.descendant(
          of: find.byType(BoardColumnView).last,
          matching: find.text(en.boardAddTask),
        ),
        findsOne,
      );
      expect(find.text(en.boardAddAnotherTask), findsNWidgets(3));
      final emptyName = en.boardAddTaskTo('Later');
      expect(emptyName, startsWith(en.boardAddTask));
      expect(find.bySemanticsLabel(emptyName), findsOneWidget);
      expect(
        find.bySemanticsLabel(en.boardAddAnotherTaskTo('Later')),
        findsNothing,
      );
      semantics.dispose();
    });
  });

  group('drag and drop', () {
    testWidgets('a card dropped between two cards of another column takes '
        'the position between them, with a haptic and an announcement', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await pumpBoard(tester);

      await dragCard(
        tester,
        'Call Anna',
        gapBelow(tester, 'Fix bike', below: 'Read book'),
      );

      expect(data.tasks.placements, [
        (2, 14, const BucketPlacement(bucketId: 22, position: 1500), null),
      ]);
      expect(cardsIn(tester, 'Doing'), ['Fix bike', 'Call Anna', 'Read book']);
      expect(haptics, contains('HapticFeedbackType.selectionClick'));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardMovedTo('Doing')),
      ]);
    });

    testWidgets('a drop the device cannot store says so, and never that the '
        'card moved', (tester) async {
      await pumpBoard(tester);
      data.tasks.beforeWrite = () async =>
          throw const FileSystemException('No space left on device');

      await dragCard(
        tester,
        'Call Anna',
        gapBelow(tester, 'Fix bike', below: 'Read book'),
      );

      expect(tester.takeAnnouncements(), isEmpty);
      expect(find.text(en.localChangeFailed), findsOneWidget);
      expect(cardsIn(tester, 'Doing'), ['Fix bike', 'Read book']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a drop into one of two columns of the same title names it '
        'by its place, as the screen-reader actions do', (tester) async {
      storeBoard(
        columns: [
          bucket(21, 'To-Do', count: 3),
          bucket(22, 'Later', count: 2),
          bucket(23, 'Later', count: 1),
        ],
      );
      await pumpBoard(tester);

      await dragCard(
        tester,
        'Call Anna',
        gapBelow(tester, 'Fix bike', below: 'Read book'),
      );

      expect(data.tasks.placements.single.$3.bucketId, 22);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardMovedTo('Later (2)')),
      ]);
    });

    testWidgets('within a column a card goes between its new neighbours', (
      tester,
    ) async {
      await pumpBoard(tester);

      await dragCard(tester, 'Write report', gapBelow(tester, 'Plan trip'));

      expect(data.tasks.placements, [
        (
          1,
          14,
          const BucketPlacement(bucketId: 21, position: 300 + 65536),
          null,
        ),
      ]);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.movedDown),
      ]);
    });

    testWidgets('a card dropped where it was changes nothing', (tester) async {
      await pumpBoard(tester);

      await dragCard(
        tester,
        'Call Anna',
        gapBelow(tester, 'Write report', below: 'Call Anna'),
      );

      expect(data.tasks.placements, isEmpty);
    });

    group('a card a sync takes out of its column while held', () {
      /// Holds 'Call Anna' over the gap between 'Fix bike' and 'Read book',
      /// then [sync] runs.
      Future<TestGesture> holdThenSync(
        WidgetTester tester,
        VoidCallback sync,
      ) async {
        final from = tester.getCenter(cardOf('Call Anna'));
        final to = gapBelow(tester, 'Fix bike', below: 'Read book');
        final gesture = await tester.startGesture(from);
        await tester.pump(const Duration(milliseconds: 600));
        for (var step = 1; step <= 6; step++) {
          await gesture.moveTo(Offset.lerp(from, to, step / 6)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.widget<BoardColumnView>(columnOf('Doing')).dropIndex, 1);
        sync();
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        return gesture;
      }

      void expectNoDrag(WidgetTester tester) {
        for (final column in tester.widgetList<BoardColumnView>(
          find.byType(BoardColumnView),
        )) {
          expect(column.draggedTaskId, isNull);
          expect(column.dropIndex, isNull);
        }
      }

      testWidgets('to another column is not dropped where the finger was', (
        tester,
      ) async {
        await pumpBoard(tester);

        final gesture = await holdThenSync(
          tester,
          () => storeBoard(
            cards: {...snapshot, 2: (bucketId: 23, position: 600)},
          ),
        );
        await gesture.up();
        await tester.pumpAndSettle();

        expect(data.tasks.placements, isEmpty);
        expect(cardsIn(tester, 'Doing'), ['Fix bike', 'Read book']);
        expect(cardsIn(tester, 'Done'), ['Finished', 'Call Anna']);
        expectNoDrag(tester);
      });

      testWidgets('as deleted ends the drag, also let go beside the board', (
        tester,
      ) async {
        await pumpBoard(tester);

        final gesture = await holdThenSync(tester, () {
          data.tasks.all = [
            for (final task in tasks())
              if (task.id != 2) task,
          ];
          storeBoard(
            cards: {
              for (final MapEntry(:key, :value) in snapshot.entries)
                if (key != 2) key: value,
            },
          );
        });
        expect(cardsIn(tester, 'To-Do'), ['Write report', 'Plan trip']);
        expectNoDrag(tester);
        await gesture.moveTo(const Offset(550, 20));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(data.tasks.placements, isEmpty);
        expectNoDrag(tester);
      });
    });

    testWidgets('into the done column the task is marked done', (tester) async {
      await pumpBoard(tester);

      await dragCard(tester, 'Write report', aboveCard(tester, 'Finished'));

      expect(data.tasks.placements, [
        (1, 14, const BucketPlacement(bucketId: 23, position: 250), true),
      ]);
      expect(cardsIn(tester, 'Done'), ['Write report', 'Finished']);
    });

    testWidgets('a repeating task dropped into the done column is marked '
        'done and placed in the default column, where the server reopens '
        'it', (tester) async {
      storeBoard(
        cards: {...snapshot, 3: (bucketId: 22, position: 3000)},
        columns: [
          bucket(21, 'To-Do', count: 2),
          bucket(22, 'Doing', count: 3),
          bucket(23, 'Done', count: 1),
        ],
      );
      await pumpBoard(tester);
      expect(cardsIn(tester, 'Doing'), contains('Plan trip'));

      await dragCard(tester, 'Plan trip', aboveCard(tester, 'Finished'));

      expect(data.tasks.placements, [
        (3, 14, const BucketPlacement(bucketId: 21), true),
      ]);
      expect(cardsIn(tester, 'To-Do').first, 'Plan trip');
      // Not by the column's title: the card's done badge reads "Done" too.
      final doneColumn = tester
          .widgetList<BoardColumnView>(find.byType(BoardColumnView))
          .last
          .column;
      expect([for (final task in doneColumn.tasks) task.title], ['Finished']);
    });

    testWidgets('out of the done column the task is open again', (
      tester,
    ) async {
      await pumpBoard(tester);

      await dragCard(tester, 'Finished', aboveCard(tester, 'Write report'));

      expect(data.tasks.placements, [
        (6, 14, const BucketPlacement(bucketId: 21, position: 50), false),
      ]);
    });

    testWidgets('a card dropped above a task without a place on the board '
        'stays there, as that task gets the place it showed at', (
      tester,
    ) async {
      data.tasks.all = [...tasks(), sampleTask(id: -5, title: 'Added here')];
      await pumpBoard(tester);
      expect(cardsIn(tester, 'To-Do').first, 'Added here');

      await dragCard(tester, 'Call Anna', aboveCard(tester, 'Added here'));

      expect(data.tasks.placements, [
        (-5, 14, const BucketPlacement(bucketId: 21, position: 50), null),
        (2, 14, const BucketPlacement(bucketId: 21, position: 25), null),
      ]);
      expect(cardsIn(tester, 'To-Do'), [
        'Call Anna',
        'Added here',
        'Write report',
        'Plan trip',
      ]);
    });

    testWidgets('a task created on the web since the download is never '
        'placed, as the server may hold it in another column', (tester) async {
      data.tasks.all = [
        ...tasks(),
        sampleTask(
          id: 7,
          title: 'Added on the web',
          created: now.add(const Duration(minutes: 1)),
        ),
      ];
      await pumpBoard(tester);
      expect(cardsIn(tester, 'To-Do').first, 'Added on the web');

      await dragCard(
        tester,
        'Call Anna',
        aboveCard(tester, 'Added on the web'),
      );

      expect(data.tasks.placements, [
        (2, 14, const BucketPlacement(bucketId: 21, position: 25), null),
      ]);
      expect(cardsIn(tester, 'To-Do').take(2), [
        'Added on the web',
        'Call Anna',
      ]);
    });

    testWidgets('a full column refuses the card with a heavy haptic and the '
        "web's limit text", (tester) async {
      final haptics = recordHaptics(tester);
      storeBoard(columns: buckets(doingLimit: 2));
      await pumpBoard(tester);

      await dragCard(
        tester,
        'Call Anna',
        gapBelow(tester, 'Fix bike', below: 'Read book'),
      );

      expect(data.tasks.placements, isEmpty);
      expect(cardsIn(tester, 'To-Do'), contains('Call Anna'));
      expect(haptics, contains('HapticFeedbackType.heavyImpact'));
      expect(find.text(en.boardColumnLimitReached), findsOneWidget);
    });

    testWidgets('the board holds still under a held card and settles on a '
        'column after the drop, which goes where the finger is', (
      tester,
    ) async {
      await pumpBoard(tester, size: const Size(400, 800));
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;

      final from = tester.getCenter(cardOf('Call Anna'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(Offset(395, from.dy));
      for (var i = 0; i < 40 && position.pixels < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.moveTo(Offset(330, from.dy));
      // The scroll step under way ends, and the board would settle then.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final held = position.pixels;
      expect(held, greaterThan(0));
      expect(held % (280 + 12), isNot(0));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(position.pixels, held);
      final underFinger = tester.getRect(columnOf('Doing')).left <= 330
          ? 22
          : 21;

      await gesture.up();
      await tester.pumpAndSettle();

      expect(data.tasks.placements.single.$3.bucketId, underFinger);
      expect(position.pixels % (280 + 12), 0);
    });

    testWidgets('after a drop into the next column, the board settles on '
        'that column', (tester) async {
      await pumpBoard(tester, size: const Size(400, 800));
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;

      final from = tester.getCenter(cardOf('Call Anna'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(Offset(395, from.dy));
      for (var i = 0; i < 40 && position.pixels < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.moveTo(Offset(330, from.dy + 40));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Nearer the first column, where the board would settle by itself.
      expect(position.pixels, lessThan((280 + 12) / 2));
      expect(tester.getRect(columnOf('Doing')).left, lessThan(330));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(data.tasks.placements.single.$3.bucketId, 22);
      expect(position.pixels, 280 + 12);
    });

    for (final (name, features) in [
      ('without reduced motion', null),
      (
        "with iOS's Reduce Motion",
        const FakeAccessibilityFeatures(
          reduceMotion: true,
          supportsAnnounce: true,
        ),
      ),
      (
        "with Android's Remove animations",
        const FakeAccessibilityFeatures(
          disableAnimations: true,
          supportsAnnounce: true,
        ),
      ),
    ]) {
      testWidgets('$name the board ${features == null ? 'glides' : 'jumps'} '
          'to the column a drop settles on', (tester) async {
        if (features != null) {
          tester.platformDispatcher.accessibilityFeaturesTestValue = features;
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await pumpBoard(tester, size: const Size(400, 800));
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(SingleChildScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;

        final from = tester.getCenter(cardOf('Call Anna'));
        final gesture = await tester.startGesture(from);
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(Offset(395, from.dy));
        for (var i = 0; i < 40 && position.pixels < 80; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.moveTo(Offset(330, from.dy + 40));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(position.pixels, lessThan(280 + 12));
        await gesture.up();
        await tester.pump();

        if (features == null) {
          expect(position.pixels, lessThan(280 + 12));
        } else {
          expect(position.pixels, 280 + 12);
        }
        await tester.pumpAndSettle();
        expect(position.pixels, 280 + 12);
      });
    }

    testWidgets('below the last card loaded of a column with more, a card '
        'goes above it', (tester) async {
      storeBoard(
        columns: [
          bucket(21, 'To-Do', count: 3),
          bucket(22, 'Doing', count: 30),
          bucket(23, 'Done', count: 1),
        ],
      );
      await pumpBoard(tester);

      await dragCard(tester, 'Call Anna', gapBelow(tester, 'Read book'));

      expect(data.tasks.placements, [
        (2, 14, const BucketPlacement(bucketId: 22, position: 1500), null),
      ]);
    });

    testWidgets('the board scrolls sideways while a card is held near its '
        'edge on a phone', (tester) async {
      await pumpBoard(tester, size: const Size(400, 800));
      final board = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(board.first).position;
      expect(position.pixels, 0);

      final from = tester.getCenter(cardOf('Call Anna'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(Offset(395, from.dy));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(position.pixels, greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a column scrolls while a card is held near its bottom, and '
        'the drop follows the cards moving under the finger', (tester) async {
      data.tasks.all = [
        for (var id = 100; id < 112; id++)
          sampleTask(id: id, title: 'Card $id'),
      ];
      storeBoard(
        columns: [
          bucket(21, 'To-Do', count: 12),
          bucket(22, 'Doing'),
          bucket(23, 'Done'),
        ],
        cards: {
          for (var id = 100; id < 112; id++)
            id: (bucketId: 21, position: id * 10.0),
        },
      );
      await pumpBoard(tester, size: const Size(1100, 500));
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: cardsOfColumn('To-Do'),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(position.pixels, 0);
      expect(position.maxScrollExtent, greaterThan(0));

      final from = tester.getCenter(cardOf('Card 100'));
      final column = tester.getRect(cardsOfColumn('To-Do'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600));
      final to = Offset(from.dx, column.bottom - 10);
      for (var step = 1; step <= 6; step++) {
        await gesture.moveTo(Offset.lerp(from, to, step / 6)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(position.pixels, position.maxScrollExtent);
      await gesture.up();
      await tester.pumpAndSettle();
      final (taskId, _, placement, _) = data.tasks.placements.single;
      expect(taskId, 100);
      expect(placement.bucketId, 21);
      expect(placement.position, greaterThan(1110));
    });
  });

  group('the drop line', () {
    Future<Rect> pumpLine(
      WidgetTester tester, {
      required TextDirection direction,
      required List<Task> cards,
      required int dropIndex,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  height: 400,
                  child: BoardColumnView(
                    column: BoardColumn(
                      bucket: bucket(21, 'To-Do', count: cards.length),
                      tasks: cards,
                      shownCount: cards.length,
                      hasMore: false,
                    ),
                    width: 280,
                    isDoneColumn: false,
                    cardBuilder: (context, task, index) =>
                        SizedBox(height: 60, child: Text(task.title)),
                    loadingMore: false,
                    onLoadMore: () {},
                    onNearEnd: () {},
                    dropIndex: dropIndex,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final line = find.descendant(
        of: find.byType(BoardColumnView),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 3,
        ),
      );
      expect(line, findsOneWidget);
      final column = tester.getRect(find.byType(BoardColumnView));
      final rect = tester.getRect(line);
      return Rect.fromLTRB(
        rect.left - column.left,
        rect.top,
        column.right - rect.right,
        rect.bottom,
      );
    }

    for (final direction in TextDirection.values) {
      testWidgets('keeps 8 from both sides of a column, ${direction.name}', (
        tester,
      ) async {
        final between = await pumpLine(
          tester,
          direction: direction,
          cards: [
            sampleTask(id: 1, title: 'One'),
            sampleTask(id: 2, title: 'Two'),
          ],
          dropIndex: 1,
        );
        expect((between.left, between.right), (8, 8));

        final empty = await pumpLine(
          tester,
          direction: direction,
          cards: const [],
          dropIndex: 0,
        );
        expect((empty.left, empty.right), (8, 8));
      });
    }
  });

  group('screen reader actions', () {
    testWidgets('a card moves to every other column and up and down in its '
        'own, announced', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBoard(tester);

      expect(
        actionsOf(tester, 'Write report'),
        unorderedEquals([
          en.boardMoveTo('Doing'),
          en.boardMoveTo('Done'),
          en.moveDown,
        ]),
      );
      expect(
        actionsOf(tester, 'Call Anna'),
        unorderedEquals([
          en.boardMoveTo('Doing'),
          en.boardMoveTo('Done'),
          en.moveUp,
          en.moveDown,
        ]),
      );
      expect(
        actionsOf(tester, 'Read book'),
        unorderedEquals([
          en.boardMoveTo('To-Do'),
          en.boardMoveTo('Done'),
          en.moveUp,
        ]),
      );

      performAction(tester, 'Call Anna', en.boardMoveTo('Doing'));
      await tester.pumpAndSettle();
      expect(data.tasks.placements.last, (
        2,
        14,
        const BucketPlacement(bucketId: 22, position: 500),
        null,
      ));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardMovedTo('Doing')),
      ]);

      performAction(tester, 'Read book', en.moveUp);
      await tester.pumpAndSettle();
      expect(data.tasks.placements.last, (
        5,
        14,
        const BucketPlacement(bucketId: 22, position: 750),
        null,
      ));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.movedUp),
      ]);

      performAction(tester, 'Write report', en.boardMoveTo('Done'));
      await tester.pumpAndSettle();
      expect(data.tasks.placements.last, (
        1,
        14,
        const BucketPlacement(bucketId: 23, position: 250),
        true,
      ));
      semantics.dispose();
    });

    testWidgets('without platform announcements, as on Android, a move is '
        'said by the live region', (tester) async {
      useLiveRegionAnnouncements(tester);
      await pumpBoard(tester);

      performAction(tester, 'Call Anna', en.boardMoveTo('Doing'));
      await tester.pumpAndSettle();

      expect(data.tasks.placements.last.$1, 2);
      expect(tester.takeAnnouncements(), isEmpty);
      final region = announcerRegion(tester)!;
      expect(region.label, en.boardMovedTo('Doing'));
      expect(region.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('columns of the same title are told apart by their place', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      storeBoard(
        columns: [
          bucket(21, 'To-Do', count: 3),
          bucket(22, 'Later', count: 2),
          bucket(23, 'Later', count: 1),
        ],
      );
      await pumpBoard(tester);

      expect(
        actionsOf(tester, 'Write report'),
        unorderedEquals([
          en.boardMoveTo('Later (2)'),
          en.boardMoveTo('Later (3)'),
          en.moveDown,
        ]),
      );

      performAction(tester, 'Write report', en.boardMoveTo('Later (2)'));
      await tester.pumpAndSettle();
      expect(data.tasks.placements.last.$3.bucketId, 22);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardMovedTo('Later (2)')),
      ]);
      semantics.dispose();
    });

    testWidgets('nothing moves below the last card loaded of a column with '
        'more, nor reorders a repeating task in the done column', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      storeBoard(
        cards: {...snapshot, 3: (bucketId: 23, position: 100)},
        columns: [
          bucket(21, 'To-Do', count: 2),
          bucket(22, 'Doing', count: 30),
          bucket(23, 'Done', count: 2),
        ],
      );
      data.tasks.all = [
        for (final task in tasks())
          if (task.id == 3) copyTask(task, done: true, doneAt: now) else task,
      ];
      await pumpBoard(tester);

      expect(actionsOf(tester, 'Fix bike'), isNot(contains(en.moveDown)));
      expect(actionsOf(tester, 'Read book'), contains(en.moveUp));
      expect(
        actionsOf(tester, 'Plan trip'),
        unorderedEquals([en.boardMoveTo('To-Do'), en.boardMoveTo('Doing')]),
      );
      semantics.dispose();
    });

    testWidgets('a move to a full column is refused', (tester) async {
      final semantics = tester.ensureSemantics();
      storeBoard(columns: buckets(doingLimit: 2));
      await pumpBoard(tester);

      performAction(tester, 'Call Anna', en.boardMoveTo('Doing'));
      await tester.pumpAndSettle();

      expect(data.tasks.placements, isEmpty);
      expect(find.text(en.boardColumnLimitReached), findsOneWidget);
      semantics.dispose();
    });
  });

  group('paging', () {
    Map<int, ({int bucketId, double position})> manyCards() => {
      for (var id = 100; id < 112; id++)
        id: (bucketId: 21, position: id * 10.0),
    };

    void storeManyCards() {
      data.tasks.all = [
        for (var id = 100; id < 112; id++)
          sampleTask(id: id, title: 'Card $id'),
      ];
      storeBoard(
        columns: [
          bucket(21, 'To-Do', count: 40),
          bucket(22, 'Doing'),
          bucket(23, 'Done'),
        ],
        cards: manyCards(),
      );
    }

    testWidgets('scrolling near the end of a column loads its next page', (
      tester,
    ) async {
      storeManyCards();
      await pumpBoard(tester, size: const Size(400, 800));

      await tester.drag(cardsOfColumn('To-Do'), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(data.tasks.bucketLoads, [(1, 14, 21)]);
    });

    testWidgets('after a background download that timed out while online, '
        'a pull that gets through lets scrolling load more again', (
      tester,
    ) async {
      storeManyCards();
      storeBoard(
        columns: [
          bucket(21, 'To-Do', count: 40),
          bucket(22, 'Doing'),
          bucket(23, 'Done'),
        ],
        cards: manyCards(),
        loadedAt: now.subtract(const Duration(minutes: 10)),
      );
      data.tasks.refreshBoardFailure = const NetworkFailure(
        NetworkProblem.timeout,
      );
      await pumpBoard(tester, size: const Size(400, 800));
      expect(data.tasks.boardRefreshes, [(1, 14)]);

      await tester.drag(cardsOfColumn('To-Do'), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(data.tasks.bucketLoads, isEmpty, reason: 'as if offline');

      data.tasks.refreshBoardFailure = null;
      await tester.drag(cardsOfColumn('To-Do'), const Offset(0, 4000));
      await tester.pumpAndSettle();
      await pullToRefresh(tester, cardsOfColumn('To-Do'));
      expect(data.tasks.boardRefreshes, [(1, 14), (1, 14)]);

      await tester.drag(cardsOfColumn('To-Do'), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(data.tasks.bucketLoads, [(1, 14, 21)]);
    });

    testWidgets('"Load more" below the cards loads the next page, also '
        'offline', (tester) async {
      storeManyCards();
      data.tasks.loadMoreOfBucketFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
      await pumpBoard(tester, size: const Size(400, 2400));

      await tester.tap(find.text(en.boardLoadMore));
      await tester.pumpAndSettle();

      expect(data.tasks.bucketLoads, [(1, 14, 21)]);
      expect(find.text(en.boardLoadMoreFailed), findsOneWidget);
    });
  });

  group('add a task per column', () {
    Future<void> addFrom(
      WidgetTester tester,
      String column,
      String label, {
      String text = 'Buy milk',
    }) async {
      await tester.tap(
        find.descendant(of: columnOf(column), matching: find.text(label)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NewTaskSheet), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(NewTaskSheet),
          matching: find.byType(TextField),
        ),
        text,
      );
      await tester.pumpAndSettle();
      if (text.contains('\n')) {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else {
        await tester.tap(find.widgetWithText(FilledButton, en.newTaskAdd));
      }
      await tester.pumpAndSettle();
    }

    testWidgets('a line naming another project leaves its task there', (
      tester,
    ) async {
      data.projects.all = [work(), sampleProject(id: 2, title: 'Home')];
      await pumpBoard(tester);

      await addFrom(
        tester,
        'Doing',
        en.boardAddAnotherTask,
        text: 'Buy milk +Home',
      );

      expect(data.tasks.creates.single.projectId, 2);
      expect(data.tasks.placements, isEmpty);
    });

    testWidgets('the new task is placed on top of that column', (tester) async {
      await pumpBoard(tester);

      await addFrom(tester, 'Doing', en.boardAddAnotherTask);

      expect(data.tasks.writes.first, startsWith('create -1 Buy milk'));
      expect(data.tasks.placements, [
        (-1, 14, const BucketPlacement(bucketId: 22, position: 500), null),
      ]);
      expect(cardsIn(tester, 'Doing').first, 'Buy milk');
    });

    testWidgets('the new task goes above the tasks without a place on the '
        'board, which get the places they showed at', (tester) async {
      data.tasks.all = [...tasks(), sampleTask(id: -5, title: 'Added here')];
      await pumpBoard(tester);

      await addFrom(tester, 'To-Do', en.boardAddAnotherTask);

      expect(data.tasks.placements, [
        (-5, 14, const BucketPlacement(bucketId: 21, position: 50), null),
        (-1, 14, const BucketPlacement(bucketId: 21, position: 25), null),
      ]);
      expect(cardsIn(tester, 'To-Do').take(3), [
        'Buy milk',
        'Added here',
        'Write report',
      ]);
    });

    testWidgets('a task without a place that left the column while the sheet '
        'was open is not placed back', (tester) async {
      data.tasks.all = [...tasks(), sampleTask(id: -5, title: 'Added here')];
      await pumpBoard(tester);
      await tester.tap(
        find.descendant(
          of: columnOf('To-Do'),
          matching: find.text(en.boardAddAnotherTask),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(NewTaskSheet),
          matching: find.byType(TextField),
        ),
        'Buy milk',
      );
      data.tasks.all = tasks();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, en.newTaskAdd));
      await tester.pumpAndSettle();

      expect(data.tasks.placements, [
        (-1, 14, const BucketPlacement(bucketId: 21, position: 50), null),
      ]);
    });

    testWidgets('a task without a place that cannot be placed holds back '
        "none of the new task's placement", (tester) async {
      data.tasks.all = [...tasks(), sampleTask(id: -5, title: 'Added here')];
      data.tasks.beforeWrite = () async {
        if (data.tasks.writes.last.startsWith('place -5 ')) {
          throw const FileSystemException('No space left on device');
        }
      };
      await pumpBoard(tester);

      await addFrom(tester, 'To-Do', en.boardAddAnotherTask);

      expect(data.tasks.placements.last, (
        -1,
        14,
        const BucketPlacement(bucketId: 21, position: 25),
        null,
      ));
    });

    testWidgets('with the sheet kept open, each task goes on top of the one '
        'added before it', (tester) async {
      data.listPreferences.newTaskKeepOpen = true;
      await pumpBoard(tester);

      await addFrom(tester, 'Doing', en.boardAddAnotherTask);
      expect(find.byType(NewTaskSheet), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(NewTaskSheet),
          matching: find.byType(TextField),
        ),
        'Buy eggs',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, en.newTaskAdd));
      await tester.pumpAndSettle();

      expect(data.tasks.placements, [
        (-1, 14, const BucketPlacement(bucketId: 22, position: 500), null),
        (-2, 14, const BucketPlacement(bucketId: 22, position: 250), null),
      ]);
      expect(cardsIn(tester, 'Doing').take(2), ['Buy eggs', 'Buy milk']);
    });

    testWidgets('in the done column it is created done', (tester) async {
      await pumpBoard(tester);

      await addFrom(tester, 'Done', en.boardAddAnotherTask);

      expect(data.tasks.placements, [
        (-1, 14, const BucketPlacement(bucketId: 23, position: 250), true),
      ]);
    });

    testWidgets('a repeating task added to the done column is marked done '
        'and placed where the server reopens it', (tester) async {
      await pumpBoard(tester);

      await addFrom(
        tester,
        'Done',
        en.boardAddAnotherTask,
        text: 'Pay rent every week',
      );

      expect(data.tasks.creates.single.repeatAfter, const Duration(days: 7));
      expect(data.tasks.placements, [
        (-1, 14, const BucketPlacement(bucketId: 21), true),
      ]);
    });

    testWidgets('lines beyond the limit of the column stay in the default '
        'column, and the snackbar says so', (tester) async {
      storeBoard(columns: buckets(doingLimit: 3));
      await pumpBoard(tester);

      await addFrom(
        tester,
        'Doing',
        en.boardAddAnotherTask,
        text: 'One\nTwo\nThree',
      );

      expect(data.tasks.creates.map((task) => task.title), [
        'One',
        'Two',
        'Three',
      ]);
      expect(data.tasks.placements, [
        (-1, 14, const BucketPlacement(bucketId: 22, position: 500), null),
      ]);
      expect(find.text(en.boardTasksLeftInDefaultColumn(2, 'To-Do')), findsOne);
      expect(countIn(tester, 'Doing').data, '3/3');
    });

    testWidgets('the default column takes every line whatever its limit, as '
        'the server puts new tasks there', (tester) async {
      storeBoard(
        columns: [
          bucket(21, 'To-Do', count: 3, limit: 4),
          bucket(22, 'Doing', count: 2),
          bucket(23, 'Done', count: 1),
        ],
      );
      await pumpBoard(tester);

      await addFrom(tester, 'To-Do', en.boardAddAnotherTask, text: 'One\nTwo');

      expect(data.tasks.placements.map((placed) => placed.$3.bucketId), [
        21,
        21,
      ]);
      expect(
        find.textContaining(en.boardTasksLeftInDefaultColumn(1, 'To-Do')),
        findsNothing,
      );
    });

    testWidgets('an empty column places it at 2^16', (tester) async {
      storeBoard(
        columns: [bucket(21, 'To-Do'), bucket(22, 'Doing'), bucket(23, 'Done')],
        cards: const {},
      );
      data.tasks.all = [];
      await pumpBoard(tester);

      await addFrom(tester, 'Doing', en.boardAddTask);

      expect(data.tasks.placements, [
        (-1, 14, const BucketPlacement(bucketId: 22, position: 65536), null),
      ]);
    });

    testWidgets('a full column takes no new task', (tester) async {
      storeBoard(columns: buckets(doingLimit: 2));
      await pumpBoard(tester);

      final button = find.descendant(
        of: columnOf('Doing'),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      );
      expect(tester.widget<TextButton>(button.last).onPressed, isNull);
      expect(find.byTooltip(en.boardColumnLimitReached), findsOneWidget);
    });

    testWidgets('the floating action button adds to the default column '
        'without a placement', (tester) async {
      await pumpBoard(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(NewTaskSheet),
          matching: find.byType(TextField),
        ),
        'Buy milk',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, en.newTaskAdd));
      await tester.pumpAndSettle();

      expect(data.tasks.placements, isEmpty);
      expect(cardsIn(tester, 'To-Do').first, 'Buy milk');
    });
  });

  group('read-only boards', () {
    testWidgets('a filter-mode board moves and adds nothing and says why', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final byFilter = sampleKanbanView(
        id: 14,
        projectId: 1,
        mode: BucketConfigurationMode.filter,
      );
      data.projects.all = [
        work(views: [listView, byFilter]),
      ];
      data.tasks.setBoard(
        byFilter,
        buckets: [bucket(0, 'Urgent', count: 1), bucket(1, 'Later', count: 1)],
        snapshot: const {
          2: (bucketId: 0, position: 0),
          4: (bucketId: 1, position: 1),
        },
        loadedAt: now,
      );
      await pumpBoard(tester);

      expect(columnTitles(tester), ['Urgent', 'Later']);
      expect(find.text(en.boardFilterColumnsNote), findsOneWidget);
      expect(find.text(en.boardAddTask), findsNothing);
      expect(find.text(en.boardAddAnotherTask), findsNothing);
      expect(actionsOf(tester, 'Call Anna'), isEmpty);
      expect(find.byType(ColumnMenuButton), findsNothing);
      expect(find.byType(NewColumnTile), findsNothing);
      expect(actionsOf(tester, 'Urgent'), isEmpty);

      await dragCard(tester, 'Call Anna', aboveCard(tester, 'Fix bike'));
      expect(data.tasks.placements, isEmpty);
      semantics.dispose();
    });

    testWidgets("an archived project's board moves and adds nothing", (
      tester,
    ) async {
      data.projects.all = [work(archived: true)];
      await pumpBoard(tester);

      expect(find.text(en.projectArchivedNote), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text(en.boardAddAnotherTask), findsNothing);
      expect(find.byType(ColumnMenuButton), findsNothing);
      expect(find.byType(NewColumnTile), findsNothing);

      await dragCard(tester, 'Call Anna', aboveCard(tester, 'Fix bike'));
      expect(data.tasks.placements, isEmpty);
    });
  });

  group('downloads', () {
    testWidgets('a fresh board does not download when it opens', (
      tester,
    ) async {
      await pumpBoard(tester);
      expect(data.tasks.boardRefreshes, isEmpty);
    });

    testWidgets('a board older than five minutes downloads when it opens', (
      tester,
    ) async {
      storeBoard(loadedAt: now.subtract(const Duration(minutes: 6)));
      await pumpBoard(tester);

      expect(data.tasks.boardRefreshes, [(1, 14)]);
      expect(data.tasks.projectListRefreshes, isEmpty);
    });

    testWidgets('a board turned into a list elsewhere while it shows '
        'downloads the list, and the list turned back into a board '
        'downloads the board', (tester) async {
      await pumpBoard(tester);
      expect(data.tasks.boardRefreshes, isEmpty);

      data.projects.all = [
        work(
          views: [
            listView,
            sampleListView(id: 14, projectId: 1, title: 'Kanban'),
          ],
        ),
      ];
      await tester.pumpAndSettle();
      expect(data.tasks.projectListRefreshes, [(1, 14)]);

      data.tasks.setBoard(kanban);
      data.projects.all = [work()];
      await tester.pumpAndSettle();
      expect(data.tasks.boardRefreshes, [(1, 14)]);
    });

    testWidgets('a board stamped ahead of the clock, which was set back '
        'since, downloads when it opens', (tester) async {
      storeBoard(loadedAt: now.add(const Duration(hours: 2)));
      await pumpBoard(tester);

      expect(data.tasks.boardRefreshes, [(1, 14)]);
    });

    testWidgets('never downloaded, it says it is downloading, then shows the '
        'board', (tester) async {
      data.tasks.setBoard(kanban);
      final download = Completer<void>();
      data.tasks.onRefreshBoard = (_, _) => download.future;
      await pumpBoard(tester);

      expect(find.text(en.projectViewDownloadingTitle), findsOneWidget);
      expect(find.text(en.boardDownloadingBody), findsOneWidget);

      storeBoard();
      download.complete();
      await tester.pumpAndSettle();
      expect(columnTitles(tester), ['To-Do', 'Doing', 'Done']);
    });

    testWidgets('never downloaded and offline, it loads once back online', (
      tester,
    ) async {
      data.tasks.setBoard(kanban);
      data.engine.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await pumpBoard(tester);
      expect(find.text(en.projectViewNotLoadedTitle), findsOneWidget);
      expect(find.text(en.boardNotLoadedBody), findsOneWidget);

      data.engine.onRefresh = null;
      data.tasks.onRefreshBoard = (_, _) async => storeBoard();
      data.engine.emit(SyncIdle(lastSyncedAt: now));
      await tester.pumpAndSettle();

      expect(data.tasks.boardRefreshes, [(1, 14), (1, 14)]);
      expect(columnTitles(tester), ['To-Do', 'Doing', 'Done']);
    });

    testWidgets('a failed download of a board never downloaded says so', (
      tester,
    ) async {
      data.tasks.setBoard(kanban);
      data.tasks.refreshBoardFailure = const NotFound();
      await pumpBoard(tester);

      expect(find.text(en.projectViewDownloadFailedTitle), findsOneWidget);
      expect(find.text(en.boardDownloadFailedBody), findsOneWidget);
    });

    testWidgets('pulling down on a column and Refresh in the menu download '
        'the board', (tester) async {
      await pumpBoard(tester, size: const Size(400, 800));

      await pullToRefresh(tester, cardsOfColumn('To-Do'));
      expect(data.tasks.boardRefreshes, [(1, 14)]);

      await tester.tap(find.byTooltip(en.moreActions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.refresh));
      await tester.pumpAndSettle();
      expect(data.tasks.boardRefreshes, [(1, 14), (1, 14)]);
    });

    testWidgets('a placement left failed holds back no download after the '
        'moves sent since', (tester) async {
      data.tasks.setQueuedPlacements(14, const {
        5: BucketPlacement(bucketId: 21, position: 1),
      });
      await pumpBoard(tester);

      await dragCard(tester, 'Call Anna', aboveCard(tester, 'Fix bike'));
      expect(data.tasks.queuedPlacements[14]!.keys, unorderedEquals([5, 2]));
      await tester.pump(const Duration(seconds: 3));
      expect(data.tasks.boardRefreshes, isEmpty);

      data.tasks.setQueuedPlacements(14, const {
        5: BucketPlacement(bucketId: 21, position: 1),
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(data.tasks.boardRefreshes, [(1, 14)]);
    });

    testWidgets('two seconds after its own moves were sent the board '
        'downloads again', (tester) async {
      await pumpBoard(tester);

      await dragCard(
        tester,
        'Call Anna',
        gapBelow(tester, 'Fix bike', below: 'Read book'),
      );
      expect(data.tasks.queuedPlacements[14], isNotEmpty);
      await tester.pump(const Duration(seconds: 3));
      expect(data.tasks.boardRefreshes, isEmpty);

      data.tasks.setQueuedPlacements(14, const {});
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(data.tasks.boardRefreshes, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(data.tasks.boardRefreshes, [(1, 14)]);
    });

    testWidgets('the download after its own moves were sent runs once more '
        'when another one was under way, which may have read the board '
        'before the move', (tester) async {
      storeBoard(loadedAt: now.subtract(const Duration(minutes: 6)));
      final first = Completer<void>();
      data.tasks.onRefreshBoard = (_, _) => first.future;
      await pumpBoard(tester);
      expect(data.tasks.boardRefreshes, [(1, 14)]);

      await dragCard(
        tester,
        'Call Anna',
        gapBelow(tester, 'Fix bike', below: 'Read book'),
      );
      data.tasks.setQueuedPlacements(14, const {});
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(data.tasks.boardRefreshes, [(1, 14)]);

      data.tasks.onRefreshBoard = null;
      first.complete();
      await tester.pumpAndSettle();
      expect(data.tasks.boardRefreshes, [(1, 14), (1, 14)]);
    });
  });
}
