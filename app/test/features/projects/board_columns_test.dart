import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/count_badge.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_card.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/board_column.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/column_changes.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/column_menu.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/column_sheets.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/new_column_tile.dart';

import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;
  final listView = sampleListView(id: 11, projectId: 1);
  final kanban = sampleKanbanView(
    id: 14,
    projectId: 1,
    defaultBucketId: 21,
    doneBucketId: 23,
  );

  Bucket bucket(int id, String title, {int count = 0, int limit = 0}) => Bucket(
    id: id,
    viewId: 14,
    title: title,
    count: count,
    limit: limit,
    position: (id - 20) * 100.0,
  );

  // Titles no card shares: a done card's badge reads "Done".
  List<Bucket> buckets() => [
    bucket(21, 'Backlog', count: 3),
    bucket(22, 'Doing', count: 2),
    bucket(23, 'Complete', count: 1),
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
    sampleTask(id: 1, title: 'Write report'),
    sampleTask(id: 2, title: 'Call Anna'),
    sampleTask(id: 3, title: 'Plan trip'),
    sampleTask(id: 4, title: 'Fix bike'),
    sampleTask(id: 5, title: 'Read book'),
    sampleTask(id: 6, title: 'Finished', done: true, doneAt: now),
  ];

  void storeBoard({
    ProjectView? view,
    List<Bucket>? columns,
    Map<int, ({int bucketId, double position})> cards = snapshot,
    Permission? permission,
  }) {
    final shown = view ?? kanban;
    data.projects.all = [
      sampleProject(
        id: 1,
        title: 'Work',
        views: [listView, shown],
      ).copyWith(maxPermission: permission),
    ];
    data.tasks.setBoard(
      shown,
      buckets: columns ?? buckets(),
      snapshot: cards,
      loadedAt: now,
    );
  }

  setUp(() {
    data = SyncFakes(now: now);
    data.tasks.all = tasks();
    storeBoard();
  });

  /// Wide enough for the three columns and the tile after them.
  const wide = Size(1600, 900);

  Future<void> pumpBoard(WidgetTester tester, {Size size = wide}) async {
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
        .go(AppRoutes.project(1, viewId: 14));
    await tester.pumpAndSettle();
  }

  Finder columnOf(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(BoardColumnView),
  );

  Finder headerOf(String column) =>
      find.descendant(of: columnOf(column), matching: find.text(column)).first;

  Finder menuButtonOf(String column) =>
      find.byTooltip(en.boardColumnOptionsFor(column));

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

  Future<void> openMenuOf(WidgetTester tester, String column) async {
    await tester.tap(menuButtonOf(column));
    await tester.pumpAndSettle();
  }

  Future<void> closeMenu(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  Finder itemOf(ColumnAction action) => find.byWidgetPredicate(
    (widget) => widget is PopupMenuItem<ColumnAction> && widget.value == action,
  );

  Future<void> choose(
    WidgetTester tester,
    String column,
    ColumnAction action,
  ) async {
    await openMenuOf(tester, column);
    await tester.tap(itemOf(action));
    await tester.pumpAndSettle();
  }

  List<ColumnAction> menuItems(WidgetTester tester) => [
    for (final item in tester.widgetList<PopupMenuItem<ColumnAction>>(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<ColumnAction>),
    ))
      item.value!,
  ];

  PopupMenuItem<ColumnAction> menuItem(
    WidgetTester tester,
    ColumnAction action,
  ) => tester.widget<PopupMenuItem<ColumnAction>>(
    find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuItem<ColumnAction> && widget.value == action,
    ),
  );

  Finder sheetField() => find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is ColumnTitleSheet || widget is ColumnLimitSheet,
    ),
    matching: find.byType(TextField),
  );

  TextButton sheetAction(WidgetTester tester, String label) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, label));

  List<String> headerActionsOf(WidgetTester tester, String column) => [
    for (final id
        in tester
                .getSemantics(headerOf(column))
                .getSemanticsData()
                .customSemanticsActionIds ??
            const <int>[])
      CustomSemanticsAction.getAction(id)!.label!,
  ];

  void performHeaderAction(WidgetTester tester, String column, String label) {
    final node = tester.getSemantics(headerOf(column));
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

  group('the header menu', () {
    testWidgets("every header has an options button with the web's items in "
        'its order, moves only where the column can go', (tester) async {
      await pumpBoard(tester);

      for (final title in ['Backlog', 'Doing', 'Complete']) {
        expect(
          find.descendant(of: columnOf(title), matching: menuButtonOf(title)),
          findsOne,
        );
      }

      await openMenuOf(tester, 'Backlog');
      expect(menuItems(tester), [
        ColumnAction.rename,
        ColumnAction.limit,
        ColumnAction.done,
        ColumnAction.defaultColumn,
        ColumnAction.moveRight,
        ColumnAction.delete,
      ]);
      expect(
        find.text(en.boardColumnLimit(en.boardColumnLimitNotSet)),
        findsOne,
      );
      expect(find.text(en.boardDoneColumnHintExtended), findsOne);
      expect(find.text(en.boardDefaultColumnHint), findsOne);
      final done = menuItem(tester, ColumnAction.done);
      final defaultColumn = menuItem(tester, ColumnAction.defaultColumn);
      expect((done as CheckedPopupMenuItem).checked, isFalse);
      expect((defaultColumn as CheckedPopupMenuItem).checked, isTrue);
      await closeMenu(tester);

      await openMenuOf(tester, 'Doing');
      expect(menuItems(tester), [
        ColumnAction.rename,
        ColumnAction.limit,
        ColumnAction.done,
        ColumnAction.defaultColumn,
        ColumnAction.moveLeft,
        ColumnAction.moveRight,
        ColumnAction.delete,
      ]);
      await closeMenu(tester);

      await openMenuOf(tester, 'Complete');
      expect(menuItems(tester), [
        ColumnAction.rename,
        ColumnAction.limit,
        ColumnAction.done,
        ColumnAction.defaultColumn,
        ColumnAction.moveLeft,
        ColumnAction.delete,
      ]);
      expect(
        (menuItem(tester, ColumnAction.done) as CheckedPopupMenuItem).checked,
        isTrue,
      );
    });

    testWidgets('with write but no admin rights it offers no done or default '
        'column, which change the view', (tester) async {
      storeBoard(permission: Permission.write);
      await pumpBoard(tester);

      await openMenuOf(tester, 'Doing');
      expect(menuItems(tester), [
        ColumnAction.rename,
        ColumnAction.limit,
        ColumnAction.moveLeft,
        ColumnAction.moveRight,
        ColumnAction.delete,
      ]);
      expect(find.text(en.boardDoneColumn), findsNothing);
      expect(find.text(en.boardDefaultColumn), findsNothing);
    });

    testWidgets('a limit shows in the menu', (tester) async {
      storeBoard(
        columns: [
          bucket(21, 'Backlog', count: 3),
          bucket(22, 'Doing', count: 2, limit: 4),
          bucket(23, 'Complete', count: 1),
        ],
      );
      await pumpBoard(tester);

      await openMenuOf(tester, 'Doing');
      expect(find.text(en.boardColumnLimit('4')), findsOne);
    });

    testWidgets('the only column offers no delete and says why', (
      tester,
    ) async {
      storeBoard(
        columns: [bucket(21, 'Backlog', count: 3)],
        cards: const {
          1: (bucketId: 21, position: 100),
          2: (bucketId: 21, position: 200),
          3: (bucketId: 21, position: 300),
        },
      );
      await pumpBoard(tester);

      await openMenuOf(tester, 'Backlog');
      expect(menuItems(tester), isNot(contains(ColumnAction.moveLeft)));
      expect(menuItems(tester), isNot(contains(ColumnAction.moveRight)));
      expect(menuItem(tester, ColumnAction.delete).enabled, isFalse);
      expect(find.text(en.boardColumnDeleteLast), findsOne);

      await tester.tap(itemOf(ColumnAction.delete), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(en.boardDeleteColumnTitle), findsNothing);
      expect(data.buckets.calls, isEmpty);
    });
  });

  group('rename', () {
    testWidgets('the sheet starts with the title and saves it trimmed, '
        'announced with a haptic', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.rename);
      expect(find.text(en.boardColumnRenameTitle), findsOne);
      expect(tester.widget<TextField>(sheetField()).controller!.text, 'Doing');
      await tester.enterText(sheetField(), '  In progress  ');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, en.boardColumnSave));
      await tester.pumpAndSettle();

      expect(data.buckets.calls, ['rename 1 14 22 In progress']);
      expect(columnTitles(tester), ['Backlog', 'In progress', 'Complete']);
      expect(haptics, contains('HapticFeedbackType.selectionClick'));
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardColumnRenamed),
      ]);
    });

    testWidgets('an empty title is refused, also from the keyboard', (
      tester,
    ) async {
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.rename);
      await tester.enterText(sheetField(), '   ');
      await tester.pump();

      expect(sheetAction(tester, en.boardColumnSave).onPressed, isNull);
      expect(find.text(en.boardColumnTitleEmpty), findsOne);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(ColumnTitleSheet), findsOne);
      expect(data.buckets.calls, isEmpty);
    });

    testWidgets('the same title sends nothing', (tester) async {
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.rename);
      await tester.tap(find.widgetWithText(TextButton, en.boardColumnSave));
      await tester.pumpAndSettle();

      expect(find.byType(ColumnTitleSheet), findsNothing);
      expect(data.buckets.calls, isEmpty);
    });
  });

  group('limit', () {
    testWidgets('the sheet tells the count, takes digits only and saves; '
        'empty sets none', (tester) async {
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.limit);
      expect(find.text(en.boardColumnLimitHelp(2)), findsOne);
      expect(tester.widget<TextField>(sheetField()).controller!.text, '');
      await tester.enterText(sheetField(), '-3.5');
      await tester.pump();
      expect(tester.widget<TextField>(sheetField()).controller!.text, '35');
      await tester.enterText(sheetField(), '3');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, en.boardColumnSave));
      await tester.pumpAndSettle();

      expect(data.buckets.calls, ['setLimit 1 14 22 3']);
      expect(
        find.descendant(of: columnOf('Doing'), matching: find.text('2/3')),
        findsOne,
      );

      await choose(tester, 'Doing', ColumnAction.limit);
      expect(tester.widget<TextField>(sheetField()).controller!.text, '3');
      await tester.enterText(sheetField(), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(data.buckets.calls.last, 'setLimit 1 14 22 0');
      expect(
        find.descendant(of: columnOf('Doing'), matching: find.text('2')),
        findsOne,
      );
    });

    testWidgets('a limit below the count is allowed, said in the sheet and '
        'red in the header', (tester) async {
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.limit);
      await tester.enterText(sheetField(), '1');
      await tester.pump();
      expect(find.text(en.boardColumnLimitBelowCount), findsOne);
      await tester.tap(find.widgetWithText(TextButton, en.boardColumnSave));
      await tester.pumpAndSettle();

      expect(data.buckets.calls, ['setLimit 1 14 22 1']);
      final count = tester.widget<CountBadge>(
        find.descendant(
          of: columnOf('Doing'),
          matching: find.byType(CountBadge),
        ),
      );
      expect((count.count, count.limit, count.alert), (2, 1, true));
    });

    testWidgets('0 is no limit, and the same limit sends nothing', (
      tester,
    ) async {
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.limit);
      await tester.enterText(sheetField(), '0');
      await tester.tap(find.widgetWithText(TextButton, en.boardColumnSave));
      await tester.pumpAndSettle();

      expect(data.buckets.calls, isEmpty);
    });
  });

  group('done and default column', () {
    testWidgets('choosing the done column moves the marker; choosing it '
        'again clears it', (tester) async {
      await pumpBoard(tester);

      await choose(tester, 'Backlog', ColumnAction.done);
      expect(data.buckets.calls, ['setDoneBucket 1 14 21']);
      expect(
        find.descendant(
          of: columnOf('Backlog'),
          matching: find.byIcon(Icons.done_all),
        ),
        findsOne,
      );
      expect(find.byIcon(Icons.done_all), findsOne);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardDoneColumnSaved),
      ]);

      await choose(tester, 'Backlog', ColumnAction.done);
      expect(data.buckets.calls.last, 'setDoneBucket 1 14 null');
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('choosing the default column; choosing the checked one '
        'clears it', (tester) async {
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.defaultColumn);
      expect(data.buckets.calls, ['setDefaultBucket 1 14 22']);
      await openMenuOf(tester, 'Doing');
      expect(
        (menuItem(
          tester,
          ColumnAction.defaultColumn,
        ) as CheckedPopupMenuItem).checked,
        isTrue,
      );
      await tester.tap(itemOf(ColumnAction.defaultColumn));
      await tester.pumpAndSettle();

      expect(data.buckets.calls.last, 'setDefaultBucket 1 14 null');
      expect(
        tester.takeAnnouncements().last.message,
        en.boardDefaultColumnSaved,
      );
    });
  });

  group('move', () {
    testWidgets('Move left and Move right put the column one place over, '
        'announced', (tester) async {
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.moveLeft);
      expect(data.buckets.calls, ['move 1 14 22 to 0']);
      expect(columnTitles(tester), ['Doing', 'Backlog', 'Complete']);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardColumnMovedLeft),
      ]);

      await choose(tester, 'Backlog', ColumnAction.moveRight);
      expect(data.buckets.calls.last, 'move 1 14 21 to 2');
      expect(columnTitles(tester), ['Doing', 'Complete', 'Backlog']);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardColumnMovedRight),
      ]);
    });

    testWidgets('the header offers the moves to screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBoard(tester);

      expect(headerActionsOf(tester, 'Backlog'), [en.boardColumnMoveRight]);
      expect(
        headerActionsOf(tester, 'Doing'),
        unorderedEquals([en.boardColumnMoveLeft, en.boardColumnMoveRight]),
      );
      expect(headerActionsOf(tester, 'Complete'), [en.boardColumnMoveLeft]);

      performHeaderAction(tester, 'Complete', en.boardColumnMoveLeft);
      await tester.pumpAndSettle();

      expect(data.buckets.calls, ['move 1 14 23 to 1']);
      expect(columnTitles(tester), ['Backlog', 'Complete', 'Doing']);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardColumnMovedLeft),
      ]);
      semantics.dispose();
    });

    testWidgets('a board that does not snap scrolls a column moved out of '
        'view back in', (tester) async {
      await pumpBoard(tester, size: const Size(844, 600));
      final position = tester
          .state<ScrollableState>(
            find
                .ancestor(
                  of: columnOf('Backlog'),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(position.axis, Axis.horizontal);
      expect(position.pixels, 0);

      await choose(tester, 'Doing', ColumnAction.moveRight);

      expect(columnTitles(tester), ['Backlog', 'Complete', 'Doing']);
      expect(position.pixels, greaterThan(0));
      final board = tester.getRect(
        find
            .ancestor(of: columnOf('Doing'), matching: find.byType(Scrollable))
            .first,
      );
      final doing = tester.getRect(columnOf('Doing'));
      expect(doing.right, lessThanOrEqualTo(board.right));
      expect(doing.left, greaterThanOrEqualTo(board.left));
    });

    testWidgets('a move no position can make is not offered', (tester) async {
      final semantics = tester.ensureSemantics();
      Bucket atZero(int id, String title) =>
          Bucket(id: id, viewId: 14, title: title, position: 0);
      storeBoard(
        columns: [
          atZero(21, 'Backlog'),
          atZero(22, 'Doing'),
          atZero(23, 'Complete'),
        ],
      );
      await pumpBoard(tester);

      expect(headerActionsOf(tester, 'Backlog'), isEmpty);
      expect(
        headerActionsOf(tester, 'Doing'),
        unorderedEquals([en.boardColumnMoveLeft, en.boardColumnMoveRight]),
      );
      expect(headerActionsOf(tester, 'Complete'), isEmpty);
      await openMenuOf(tester, 'Complete');
      expect(menuItems(tester), isNot(contains(ColumnAction.moveLeft)));
      await closeMenu(tester);

      await choose(tester, 'Doing', ColumnAction.moveLeft);
      expect(columnTitles(tester), ['Doing', 'Backlog', 'Complete']);
      semantics.dispose();
    });

    testWidgets('on a phone the board follows the moved column', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
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

      performHeaderAction(tester, 'Backlog', en.boardColumnMoveRight);
      await tester.pumpAndSettle();

      expect(columnTitles(tester), ['Doing', 'Backlog', 'Complete']);
      expect(position.pixels, 280 + 12);
      semantics.dispose();
    });
  });

  group('delete', () {
    testWidgets('the confirmation names where the tasks go; they move there '
        'with the column gone', (tester) async {
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.delete);
      expect(find.text(en.boardDeleteColumnTitle), findsOne);
      expect(
        find.text(
          '${en.boardDeleteColumnBody('Doing')}\n'
          '${en.boardDeleteColumnTasksMove('Backlog')}',
        ),
        findsOne,
      );
      await tester.tap(
        find.widgetWithText(TextButton, en.boardDeleteColumnConfirm),
      );
      await tester.pumpAndSettle();

      expect(data.buckets.calls, ['delete 1 14 22']);
      expect(columnTitles(tester), ['Backlog', 'Complete']);
      expect(
        cardsIn(tester, 'Backlog'),
        containsAll(['Fix bike', 'Read book']),
      );
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardColumnDeleted),
      ]);
    });

    testWidgets('cancelled, nothing is sent', (tester) async {
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.delete);
      await tester.tap(find.widgetWithText(TextButton, en.cancel));
      await tester.pumpAndSettle();

      expect(data.buckets.calls, isEmpty);
      expect(columnTitles(tester), ['Backlog', 'Doing', 'Complete']);
    });

    testWidgets('the default column with tasks names the leftmost other '
        'column, which becomes the default and keeps its tasks on the '
        'board', (tester) async {
      await pumpBoard(tester);

      await choose(tester, 'Backlog', ColumnAction.delete);
      expect(
        find.text(
          '${en.boardDeleteColumnBody('Backlog')}\n'
          '${en.boardDeleteColumnTasksMove('Doing')}\n'
          '${en.boardDeleteColumnBecomesDefault('Doing')}',
        ),
        findsOne,
      );
      await tester.tap(
        find.widgetWithText(TextButton, en.boardDeleteColumnConfirm),
      );
      await tester.pumpAndSettle();

      expect(data.buckets.calls, ['delete 1 14 21']);
      expect(columnTitles(tester), ['Doing', 'Complete']);
      expect(
        cardsIn(tester, 'Doing'),
        containsAll(['Write report', 'Call Anna', 'Plan trip']),
      );
    });

    testWidgets('without a default the tasks go to the leftmost column', (
      tester,
    ) async {
      storeBoard(
        view: sampleKanbanView(id: 14, projectId: 1, doneBucketId: 23),
      );
      await pumpBoard(tester);

      await choose(tester, 'Complete', ColumnAction.delete);
      expect(
        find.text(
          '${en.boardDeleteColumnBody('Complete')}\n'
          '${en.boardDeleteColumnTasksMove('Backlog')}',
        ),
        findsOne,
      );
    });

    testWidgets('an empty column says nothing about tasks', (tester) async {
      storeBoard(columns: [...buckets(), bucket(24, 'Later')]);
      await pumpBoard(tester, size: const Size(2000, 900));

      await choose(tester, 'Later', ColumnAction.delete);
      expect(find.text(en.boardDeleteColumnBody('Later')), findsOne);
    });
  });

  group('new column', () {
    testWidgets('the tile after the last column creates one there, '
        'announced', (tester) async {
      await pumpBoard(tester);

      final tile = find.byType(NewColumnTile);
      expect(
        tester.getRect(tile).left,
        greaterThan(tester.getRect(columnOf('Complete')).right),
      );
      expect(tester.getSize(tile).width, 280);
      await tester.tap(find.text(en.boardCreateColumn));
      await tester.pumpAndSettle();
      expect(find.text(en.boardNewColumn), findsOne);
      expect(
        sheetAction(tester, en.boardNewColumnCreate).onPressed,
        isNull,
        reason: 'nothing typed yet',
      );
      await tester.enterText(sheetField(), 'Review');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(TextButton, en.boardNewColumnCreate),
      );
      await tester.pumpAndSettle();

      expect(data.buckets.calls, ['create 1 14 Review']);
      expect(columnTitles(tester), ['Backlog', 'Doing', 'Complete', 'Review']);
      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement(en.boardColumnCreated),
      ]);
    });

    testWidgets('a blank title creates nothing', (tester) async {
      await pumpBoard(tester);

      await tester.tap(find.text(en.boardCreateColumn));
      await tester.pumpAndSettle();
      await tester.enterText(sheetField(), '  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text(en.boardColumnTitleEmpty), findsOne);
      expect(data.buckets.calls, isEmpty);
    });

    testWidgets('on a phone the tile is a column wide, so the board still '
        'settles column by column', (tester) async {
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
      expect(tester.getSize(find.byType(NewColumnTile)).width, 280);

      for (final (title, settled) in [
        ('Backlog', 280.0 + 12),
        ('Doing', 2 * (280.0 + 12)),
      ]) {
        await tester.timedDrag(
          headerOf(title),
          const Offset(-200, 0),
          const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();
        expect(position.pixels, settled);
      }
      await tester.timedDrag(
        headerOf('Complete'),
        const Offset(-200, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(tester.getRect(find.byType(NewColumnTile)).right, 400 - 16);
    });
  });

  group('while a change is on its way', () {
    testWidgets("the column's button turns into progress and nothing else "
        'changes columns', (tester) async {
      final hold = Completer<void>();
      data.buckets.beforeCall = (_) => hold.future;
      await pumpBoard(tester);

      await openMenuOf(tester, 'Doing');
      await tester.tap(itemOf(ColumnAction.defaultColumn));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(menuButtonOf('Doing'), findsNothing);
      expect(
        find.descendant(
          of: columnOf('Doing'),
          matching: find.bySemanticsLabel(en.boardColumnSaving),
        ),
        findsOne,
      );
      for (final button in tester.widgetList<PopupMenuButton<ColumnAction>>(
        find.byWidgetPredicate(
          (widget) => widget is PopupMenuButton<ColumnAction>,
        ),
      )) {
        expect(button.enabled, isFalse);
      }
      expect(
        tester.widget<NewColumnTile>(find.byType(NewColumnTile)).onPressed,
        isNull,
      );

      hold.complete();
      await tester.pumpAndSettle();
      expect(menuButtonOf('Doing'), findsOne);
      expect(
        tester.widget<NewColumnTile>(find.byType(NewColumnTile)).onPressed,
        isNotNull,
      );
    });
  });

  group('failures', () {
    testWidgets('offline the change fails with a heavy haptic and the '
        'reason, and nothing changes', (tester) async {
      final haptics = recordHaptics(tester);
      data.buckets.failure = const NetworkFailure(NetworkProblem.unreachable);
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.rename);
      await tester.enterText(sheetField(), 'In progress');
      await tester.tap(find.widgetWithText(TextButton, en.boardColumnSave));
      await tester.pumpAndSettle();

      expect(data.buckets.calls, ['rename 1 14 22 In progress']);
      expect(find.text(en.boardColumnNeedsConnection), findsOne);
      expect(haptics, contains('HapticFeedbackType.heavyImpact'));
      expect(columnTitles(tester), ['Backlog', 'Doing', 'Complete']);
      expect(tester.takeAnnouncements(), isEmpty);
    });

    testWidgets('a refused done column says only admins choose it', (
      tester,
    ) async {
      data.buckets.failures['setDoneBucket'] = const Forbidden();
      await pumpBoard(tester);

      await choose(tester, 'Doing', ColumnAction.done);

      expect(find.text(en.boardColumnAdminOnly), findsOne);
      expect(
        find.descendant(
          of: columnOf('Complete'),
          matching: find.byIcon(Icons.done_all),
        ),
        findsOne,
      );
    });

    testWidgets('a delete that failed after its new default, which stayed, '
        'names the new default', (tester) async {
      data.buckets.failures['delete'] = DeleteFailedAfterNewDefault(
        const NetworkFailure(NetworkProblem.unreachable),
        bucket: bucket(21, 'Backlog', count: 3),
        newDefault: bucket(22, 'Doing', count: 2),
      );
      await pumpBoard(tester);

      await choose(tester, 'Backlog', ColumnAction.delete);
      await tester.tap(
        find.widgetWithText(TextButton, en.boardDeleteColumnConfirm),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(en.boardColumnDeleteFailedNewDefault('Doing', 'Backlog')),
        findsOne,
      );
    });

    testWidgets('a refused delete of the column new tasks go to says only '
        'admins may', (tester) async {
      data.buckets.failures['delete'] = const Forbidden();
      await pumpBoard(tester);

      await choose(tester, 'Backlog', ColumnAction.delete);
      await tester.tap(
        find.widgetWithText(TextButton, en.boardDeleteColumnConfirm),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.boardColumnDeleteAdminOnly), findsOne);
      expect(columnTitles(tester), ['Backlog', 'Doing', 'Complete']);
    });
  });

  group('failure wording', () {
    test('per failure and change', () {
      String text(Object error, [ColumnChange change = ColumnChange.rename]) =>
          columnChangeFailureText(en, error, change);

      expect(
        text(const NetworkFailure(NetworkProblem.unreachable)),
        en.boardColumnNeedsConnection,
      );
      expect(
        text(const NetworkFailure(NetworkProblem.timeout)),
        en.boardColumnUnconfirmed,
      );
      expect(
        text(const Forbidden(), ColumnChange.defaultColumn),
        en.boardColumnAdminOnly,
      );
      expect(
        text(const Forbidden(), ColumnChange.deleteAfterNewDefault),
        en.boardColumnDeleteAdminOnly,
      );
      expect(
        text(const Forbidden(), ColumnChange.delete),
        en.boardColumnForbidden,
      );
      expect(
        text(const DomainError(412, code: 10003), ColumnChange.delete),
        en.boardColumnLastOne,
      );
      expect(
        text(
          const DomainError(
            412,
            code: 10007,
            message: 'A project view can have at most 100 buckets.',
          ),
          ColumnChange.create,
        ),
        en.boardColumnsAtMaximum,
      );
      expect(text(const NotFound(code: 10001)), en.syncProblemColumnMissing);
      expect(text(const DomainError(412, code: 3008)), en.boardColumnArchived);
      expect(text(const ValidationFailed()), en.boardColumnInvalid);
      expect(text(const DomainError(412, code: 2002)), en.boardColumnInvalid);
      expect(text(const NotFound(code: 3014)), en.projectViewGone);
      expect(text(const NotFound(code: 3001)), en.projectGone);
      expect(text(const NotFound(code: 3018)), en.projectGone);
      expect(
        text(const DomainError(400, code: 9999, message: ' Oops ')),
        en.boardColumnChangeRefused('Oops'),
      );
      expect(
        text(const ServerFailure(500, message: 'Internal Server Error')),
        en.actionFailureServerError,
      );
      expect(text(const ServerFailure(500)), en.actionFailureServerError);
      expect(text(const UnexpectedResponse(502)), en.boardColumnChangeFailed);
      expect(text(StateError('x')), en.boardColumnChangeFailed);
      expect(
        text(
          DeleteFailedAfterNewDefault(
            const NetworkFailure(NetworkProblem.timeout),
            bucket: bucket(21, 'Backlog'),
            newDefault: bucket(22, 'Doing'),
          ),
          ColumnChange.deleteAfterNewDefault,
        ),
        '“Doing” is now the default column; deleting “Backlog” failed.',
      );
      expect(
        de.boardDeleteColumnBecomesDefault('Doing'),
        '„Doing“ wird zur Standardspalte.',
      );
      expect(
        de.boardColumnAdminOnly,
        'Nur Projekt-Admins können die Erledigt- oder Standardspalte '
        'festlegen.',
      );
    });

    test('mapped server codes in German', () {
      String text(Object error) =>
          columnChangeFailureText(de, error, ColumnChange.rename);

      expect(text(const NotFound(code: 3014)), de.projectViewGone);
      expect(text(const NotFound(code: 3001)), de.projectGone);
      expect(text(const ServerFailure(503)), de.actionFailureServerError);
      expect(
        text(const DomainError(412, code: 10007, message: 'at most 100')),
        de.boardColumnsAtMaximum,
      );
      expect(
        text(const DomainError(400, code: 9999, message: 'Oops')),
        de.boardColumnChangeRefused('Oops'),
      );
    });
  });

  group('semantics', () {
    testWidgets('the header stays one heading node and the button is a node '
        'of its own', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBoard(tester);

      final header = tester.getSemantics(headerOf('Doing'));
      expect(
        header,
        matchesSemantics(
          label: 'Doing\n${en.boardColumnTaskCount(2)}',
          isHeader: true,
          customActions: [
            CustomSemanticsAction(label: en.boardColumnMoveLeft),
            CustomSemanticsAction(label: en.boardColumnMoveRight),
          ],
        ),
      );
      expect(
        tester.getSemantics(
          find.descendant(of: columnOf('Doing'), matching: find.text('2')),
        ),
        same(header),
      );
      final button = tester.getSemantics(menuButtonOf('Doing'));
      expect(button.id, isNot(header.id));
      expect(
        button,
        isSemantics(
          tooltip: en.boardColumnOptionsFor('Doing'),
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });
}
