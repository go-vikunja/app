import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../a11y/sweep_data.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_detail_panes.dart';
import '../../helpers/task_edits.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  const origin = TaskBoardOrigin(projectId: 1, viewId: 14);
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

  List<Bucket> buckets({int doingLimit = 0}) => [
    bucket(21, 'To-Do', count: 3),
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

  Project work({List<ProjectView>? views, bool archived = false}) =>
      sampleProject(
        id: 1,
        title: 'Work',
        archived: archived,
        views: views ?? [listView, kanban],
      );

  late SyncFakes data;
  late int openViewId;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [work()];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Write report'),
      sampleTask(id: 2, title: 'Call Anna'),
      sampleTask(
        id: 3,
        title: 'Plan trip',
        repeatAfter: const Duration(days: 7),
      ),
      sampleTask(id: 4, title: 'Fix bike'),
      sampleTask(id: 5, title: 'Read book'),
      sampleTask(id: 6, title: 'Finished', done: true, doneAt: now),
    ];
    data.tasks.setBoard(
      kanban,
      buckets: buckets(),
      snapshot: snapshot,
      loadedAt: now,
    );
    openViewId = 14;
  });

  Future<void> pumpPhone(
    WidgetTester tester, {
    Size size = const Size(400, 800),
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
    await tester.pumpAndSettle();
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

  Finder detail() => find.byType(TaskDetailSheet);

  Finder inDetail(Finder finder) =>
      find.descendant(of: detail(), matching: finder);

  Future<void> openCard(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(inDetail(find.byTooltip(en.moreActions)));
    await tester.pumpAndSettle();
  }

  Future<void> closeMenu(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  /// The option sheet's columns as (name, the line under it).
  List<(String, String?)> columnChoices(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(
      find.descendant(
        of: find.byType(BottomSheet).last,
        matching: find.byType(ListTile),
      ),
    ))
      ((tile.title! as Text).data!, (tile.subtitle as Text?)?.data),
  ];

  Future<void> openColumns(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(find.text(en.taskMoveToColumn));
    await tester.pumpAndSettle();
  }

  Future<void> pickColumn(WidgetTester tester, String column) async {
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet).last,
        matching: find.text(column),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> moveTo(WidgetTester tester, String column) async {
    await openColumns(tester);
    await pickColumn(tester, column);
  }

  group('on a phone', () {
    testWidgets('a card opens a sheet that knows its board, whose Move to '
        "column… lists the board's other columns and puts the card on top "
        'of the one picked; the sheet stays', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpPhone(tester);
      await openCard(tester, 'Call Anna');

      expectSheet(tester, taskId: 2);
      expect(tester.widget<TaskDetailSheet>(detail()).board, origin);
      await openMenu(tester);
      expect(find.text(en.taskMoveToColumn), findsOneWidget);
      await tester.tap(find.text(en.taskMoveToColumn));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet).last,
          matching: find.text(en.taskMoveToColumnTitle),
        ),
        findsOneWidget,
      );
      expect(columnChoices(tester), [
        ('Doing', null),
        ('Done', en.boardDoneColumnHint),
      ]);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet).last,
          matching: find.text('Doing'),
        ),
      );
      await tester.pumpAndSettle();

      expect(data.tasks.placements, [
        (
          2,
          14,
          BucketPlacement(
            bucketId: 22,
            position: calculateItemPosition(null, 1000),
          ),
          null,
        ),
      ]);
      expect(haptics, contains('HapticFeedbackType.selectionClick'));
      expect(inDetail(find.text(en.boardMovedTo('Doing'))), findsOneWidget);
      expectSheet(tester, taskId: 2);

      // From where the card is now.
      await openMenu(tester);
      await tester.tap(find.text(en.taskMoveToColumn));
      await tester.pumpAndSettle();
      expect(
        [for (final (name, _) in columnChoices(tester)) name],
        ['To-Do', 'Done'],
      );
    });

    testWidgets("on iOS too the card's sheet knows its board", (tester) async {
      await pumpPhone(tester);
      await openCard(tester, 'Call Anna');

      expectSheet(tester, taskId: 2);
      expect(tester.widget<TaskDetailSheet>(detail()).board, origin);
      await openMenu(tester);
      expect(find.text(en.taskMoveToColumn), findsOneWidget);
    }, variant: iOSOnly);

    testWidgets('a full column says so and refuses the card with the limit '
        'text', (tester) async {
      final haptics = recordHaptics(tester);
      data.tasks.setBoard(
        kanban,
        buckets: buckets(doingLimit: 2),
        snapshot: snapshot,
        loadedAt: now,
      );
      await pumpPhone(tester);
      await openCard(tester, 'Call Anna');
      await openMenu(tester);
      await tester.tap(find.text(en.taskMoveToColumn));
      await tester.pumpAndSettle();

      expect(columnChoices(tester).first, ('Doing', en.boardColumnFull));
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet).last,
          matching: find.text('Doing'),
        ),
      );
      await tester.pumpAndSettle();

      expect(data.tasks.placements, isEmpty);
      expect(inDetail(find.text(en.boardColumnLimitReached)), findsOneWidget);
      expect(haptics, contains('HapticFeedbackType.heavyImpact'));
      expect(detail(), findsOneWidget);
    });

    testWidgets('a column filled while the list is open refuses the card', (
      tester,
    ) async {
      await pumpPhone(tester);
      await openCard(tester, 'Call Anna');
      await openColumns(tester);
      expect(columnChoices(tester).first, ('Doing', null));

      data.tasks.setBoard(
        kanban,
        buckets: buckets(doingLimit: 2),
        snapshot: snapshot,
        loadedAt: now,
      );
      await tester.pumpAndSettle();
      await pickColumn(tester, 'Doing');

      expect(data.tasks.placements, isEmpty);
      expect(inDetail(find.text(en.boardColumnLimitReached)), findsOneWidget);
      expect(inDetail(find.text(en.boardMovedTo('Doing'))), findsNothing);
    });

    testWidgets('a card that left the board while the list is open moves '
        'nowhere and says nothing', (tester) async {
      await pumpPhone(tester);
      await openCard(tester, 'Call Anna');
      await openColumns(tester);

      data.tasks.setBoard(
        kanban,
        buckets: buckets(),
        snapshot: {...snapshot}..remove(2),
        loadedAt: now,
      );
      data.tasks.all = [
        for (final task in data.tasks.all)
          if (task.id == 2) copyTask(task, projectId: 2) else task,
      ];
      await tester.pumpAndSettle();
      await pickColumn(tester, 'Doing');

      expect(data.tasks.placements, isEmpty);
      expect(inDetail(find.text(en.boardMovedTo('Doing'))), findsNothing);
      expect(inDetail(find.text(en.boardColumnLimitReached)), findsNothing);
    });

    testWidgets('with the comment field focused, the keyboard stays down '
        'after Move to column…', (tester) async {
      data.details.detailsByTask[2] = const TaskDetails(
        maxPermission: Permission.write,
      );
      await pumpPhone(tester, size: const Size(400, 1400));
      await openCard(tester, 'Call Anna');
      final field = inDetail(
        find.descendant(
          of: find.byType(CommentComposer),
          matching: find.byType(TextField),
        ),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);

      await moveTo(tester, 'Doing');

      expect(data.tasks.placements, hasLength(1));
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isNot(true));
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('a repeating task moved into Done is marked done and stays '
        'in the default column', (tester) async {
      await pumpPhone(tester);
      await openCard(tester, 'Plan trip');
      await moveTo(tester, 'Done');

      expect(data.tasks.placements, [
        (3, 14, const BucketPlacement(bucketId: 21), true),
      ]);
      expect(detail(), findsOneWidget);
    });

    for (final (what, arrange) in <(String, void Function())>[
      (
        'a project the user may only read',
        () => data.projects.all = [
          work().copyWith(maxPermission: Permission.read),
        ],
      ),
      ('an archived project', () => data.projects.all = [work(archived: true)]),
      (
        'a filter-mode board',
        () {
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
            buckets: [bucket(0, 'Urgent', count: 1), bucket(1, 'Later')],
            snapshot: const {2: (bucketId: 0, position: 0)},
            loadedAt: now,
          );
        },
      ),
    ]) {
      testWidgets('no Move to column… on the board of $what', (tester) async {
        arrange();
        await pumpPhone(tester);
        await openCard(tester, 'Call Anna');

        expect(tester.widget<TaskDetailSheet>(detail()).board, origin);
        await openMenu(tester);
        expect(find.text(en.taskCopyLink), findsOneWidget);
        expect(find.text(en.taskMoveToColumn), findsNothing);
      });
    }

    testWidgets('a list row opens the task without a board', (tester) async {
      openViewId = 11;
      await pumpPhone(tester);
      await tester.tap(find.widgetWithText(TaskRow, 'Call Anna'));
      await tester.pumpAndSettle();

      expect(tester.widget<TaskDetailSheet>(detail()).board, isNull);
      await openMenu(tester);
      expect(find.text(en.taskDuplicate), findsOneWidget);
      expect(find.text(en.taskMoveToColumn), findsNothing);
    });

    testWidgets('a task that left the board loses the item', (tester) async {
      await pumpPhone(tester);
      await openCard(tester, 'Call Anna');
      await openMenu(tester);
      expect(find.text(en.taskMoveToColumn), findsOneWidget);
      await closeMenu(tester);

      data.tasks.setBoard(
        kanban,
        buckets: buckets(),
        snapshot: {...snapshot}..remove(2),
        loadedAt: now,
      );
      data.tasks.all = [
        for (final task in data.tasks.all)
          if (task.id == 2) copyTask(task, projectId: 2) else task,
      ];
      await tester.pumpAndSettle();

      await openMenu(tester);
      expect(find.text(en.taskMoveToColumn), findsNothing);
    });
  });

  group('in the pane', () {
    const sweepOrigin = TaskBoardOrigin(
      projectId: workProjectId,
      viewId: kanbanViewId,
    );

    Future<void> pumpBoardInPane(WidgetTester tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      goTo(tester, AppRoutes.project(workProjectId, viewId: kanbanViewId));
      await tester.pumpAndSettle();
      await tester.tap(boardCardOf(4));
      await tester.pumpAndSettle();
    }

    TaskBoardOrigin? paneOrigin(WidgetTester tester) =>
        tester.widget<TaskDetailSheet>(paneDetail).board;

    Future<bool> paneOffersMove(WidgetTester tester) async {
      await tester.tap(paneMoreMenu);
      await tester.pumpAndSettle();
      final offered = find.text(en.taskMoveToColumn).evaluate().isNotEmpty;
      await closeMenu(tester);
      return offered;
    }

    testWidgets('the entry keeps its board through back, and a task opened '
        'inside the pane gets none', (tester) async {
      await pumpBoardInPane(tester);
      expectPane(tester, taskId: 4);
      expect(paneOrigin(tester), sweepOrigin);
      expect(await paneOffersMove(tester), isTrue);

      await openRelatedInPane(tester);
      expectPane(tester, taskId: 3);
      expect(paneOrigin(tester), isNull);
      expect(await paneOffersMove(tester), isFalse);

      await tester.tap(inPane(find.byType(BackButtonIcon)));
      await tester.pumpAndSettle();
      expectPane(tester, taskId: 4);
      expect(paneOrigin(tester), sweepOrigin);
      expect(await paneOffersMove(tester), isTrue);
    });

    testWidgets('after a switch to the list view the item stays, the same '
        "task's row clears it in place and its card sets it again", (
      tester,
    ) async {
      await pumpBoardInPane(tester);
      final entry = tester
          .widget<TaskDetailPane>(find.byType(TaskDetailPane))
          .entry;

      goTo(tester, AppRoutes.project(workProjectId, viewId: listViewId));
      await tester.pumpAndSettle();
      expectPane(tester, taskId: 4);
      expect(await paneOffersMove(tester), isTrue);

      await tapTaskRow(tester, 4);
      expectPane(tester, taskId: 4);
      expect(paneOrigin(tester), isNull);
      expect(await paneOffersMove(tester), isFalse);
      expect(
        tester.widget<TaskDetailPane>(find.byType(TaskDetailPane)).entry,
        same(entry),
      );

      goTo(tester, AppRoutes.project(workProjectId, viewId: kanbanViewId));
      await tester.pumpAndSettle();
      await tapOutsidePane(tester, boardCardOf(4));
      expect(paneOrigin(tester), sweepOrigin);
      expect(
        tester.widget<TaskDetailPane>(find.byType(TaskDetailPane)).entry,
        same(entry),
      );
    });

    testWidgets('losing the room for the pane opens the sheet with the '
        'board', (tester) async {
      await pumpBoardInPane(tester);
      expectPane(tester, taskId: 4);

      useWindow(tester, androidTabletPortrait);
      await tester.pumpAndSettle();

      expectSheet(tester, taskId: 4);
      expect(tester.widget<TaskDetailSheet>(detail()).board, sweepOrigin);
      await openMenu(tester);
      expect(find.text(en.taskMoveToColumn), findsOneWidget);
    });
  });
}
