import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/move_to_column.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/screen_to_leave.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  final view = sampleKanbanView(
    id: 5,
    projectId: 1,
    defaultBucketId: 1,
    doneBucketId: 3,
  );
  const origin = TaskBoardOrigin(projectId: 1, viewId: 5);

  group('the choice', () {
    final card = sampleTask(id: 7, title: 'Report');
    const buckets = [
      Bucket(id: 1, viewId: 5, title: 'To do', position: 100, count: 1),
      Bucket(id: 2, viewId: 5, title: 'Doing', position: 200),
    ];

    BoardSource source({
      ProjectView? of,
      List<Bucket> columns = buckets,
      bool withView = true,
    }) => BoardSource(
      view: withView ? of ?? view : null,
      buckets: columns,
      snapshot: const {7: (bucketId: 1, position: 100)},
      loadedAt: now,
      projectTasks: [card],
    );

    ColumnMoveChoice? choiceFor(
      BoardSource? from, {
      Task? task,
      bool archived = false,
      bool writable = true,
      ColumnMoves? moves,
    }) => (moves ?? ColumnMoves()).choiceFor(
      task ?? card,
      origin: origin,
      source: from,
      archived: archived,
      writable: writable,
    );

    test("names the board, its columns and the card's column", () {
      final from = source();
      final choice = choiceFor(from)!;

      expect(choice.view, same(from.view));
      expect(choice.fromBucketId, 1);
      expect([for (final column in choice.columns) column.bucket.id], [1, 2]);
      expect([for (final card in choice.columns.first.tasks) card.id], [7]);
    });

    group('is none', () {
      test('before the board is read', () {
        expect(choiceFor(null), isNull);
      });

      test('while the view is not stored', () {
        expect(choiceFor(source(withView: false)), isNull);
      });

      test('for another view', () {
        final other = sampleKanbanView(id: 6, projectId: 1);
        expect(choiceFor(source(of: other)), isNull);
      });

      test('for a task moved to another project', () {
        expect(choiceFor(source(), task: card.copyWith(projectId: 2)), isNull);
      });

      test('on a board the user may not change', () {
        expect(choiceFor(source(), archived: true), isNull);
        expect(choiceFor(source(), writable: false), isNull);
        final filtered = sampleKanbanView(
          id: 5,
          projectId: 1,
          mode: BucketConfigurationMode.filter,
        );
        expect(choiceFor(source(of: filtered)), isNull);
      });

      test('with one column', () {
        expect(choiceFor(source(columns: [buckets.first])), isNull);
      });

      test('for a task no longer on the board', () {
        expect(
          choiceFor(source(), task: sampleTask(id: 8, title: 'Other')),
          isNull,
        );
      });
    });

    test('keeps the columns while the source and the view stay the same', () {
      final moves = ColumnMoves();
      final from = source();
      final first = choiceFor(from, moves: moves)!;
      final again = choiceFor(from, moves: moves)!;
      final next = choiceFor(source(), moves: moves)!;

      expect(again.columns, same(first.columns));
      expect(next.columns, isNot(same(first.columns)));
    });
  });

  group('moving', () {
    late SyncFakes data;
    late List<String> messages;
    late List<Object?> haptics;
    late Future<void> moving;
    // What the caller knows of the board at each call.
    late ColumnMoveChoice? board;

    Task card(int id, double position, {bool repeats = false}) => sampleTask(
      id: id,
      title: 'Task $id',
      position: position,
      repeatAfter: repeats ? const Duration(days: 1) : Duration.zero,
    );

    BoardColumn column(
      int bucketId,
      String title,
      List<Task> tasks, {
      int limit = 0,
    }) => BoardColumn(
      bucket: Bucket(
        id: bucketId,
        viewId: 5,
        title: title,
        limit: limit,
        count: tasks.length,
        position: bucketId * 100,
      ),
      tasks: tasks,
      shownCount: tasks.length,
      hasMore: false,
    );

    final report = card(1, 100);
    final repeating = card(2, 200, repeats: true);
    final finished = card(3, 300);
    final columns = [
      column(1, 'To do', [report, repeating]),
      column(2, 'Later', [card(4, 1000)]),
      column(3, 'Done', [finished]),
      column(4, 'Later', [card(5, 2000)], limit: 1),
    ];

    setUp(() {
      data = SyncFakes(now: now);
      data.projects.all = [sampleProject(id: 1, title: 'Work')];
      data.tasks.all = [report, repeating, finished];
      messages = [];
    });

    Future<void> pumpApp(WidgetTester tester) async {
      haptics = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      usePhoneSurface(tester, logicalSize: const Size(360, 1200));
      await pumpSignedInApp(tester, sync: data, now: now);
    }

    ColumnMoveChoice choiceOf(Task task, List<BoardColumn> columns) =>
        ColumnMoveChoice(
          view: view,
          columns: columns,
          fromBucketId: columns
              .firstWhere(
                (column) => column.tasks.any((card) => card.id == task.id),
              )
              .bucket
              .id,
        );

    /// Opens the sheet; [moving] completes once the move is done.
    Future<void> open(
      WidgetTester tester,
      Task task, {
      BuildContext? from,
    }) async {
      board = choiceOf(task, columns);
      moving = moveToColumn(
        from ?? tester.element(find.byType(Scaffold).first),
        repository: data.tasks,
        task: task,
        choice: () => board,
        showMessage: messages.add,
      );
      await tester.pumpAndSettle();
    }

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(BottomSheet), matching: finder);

    List<(String, String?)> options(WidgetTester tester) => [
      for (final tile in tester.widgetList<ListTile>(
        inSheet(find.byType(ListTile)),
      ))
        ((tile.title! as Text).data!, (tile.subtitle as Text?)?.data),
    ];

    Future<void> pick(WidgetTester tester, String name) async {
      await tester.tap(inSheet(find.text(name)));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the other columns in board order, numbered where '
        'titles repeat, with Full and the done hint', (tester) async {
      await pumpApp(tester);
      await open(tester, report);

      expect(inSheet(find.text(en.taskMoveToColumnTitle)), findsOneWidget);
      expect(options(tester), [
        ('Later (2)', null),
        ('Done', en.boardDoneColumnHint),
        ('Later (4)', en.boardColumnFull),
      ]);
    });

    testWidgets('a pick puts the card on top of the column, with a haptic '
        'and where it went', (tester) async {
      await pumpApp(tester);
      await open(tester, report);

      await pick(tester, 'Later (2)');
      await moving;

      expect(data.tasks.placements, [
        (1, 5, const BucketPlacement(bucketId: 2, position: 500), null),
      ]);
      expect(messages, [en.boardMovedTo('Later (2)')]);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('into the done column the task is done, out of it open '
        'again', (tester) async {
      await pumpApp(tester);
      await open(tester, report);
      await pick(tester, 'Done');
      await moving;
      await open(tester, finished);
      await pick(tester, 'To do');
      await moving;

      expect(data.tasks.placements, [
        (1, 5, const BucketPlacement(bucketId: 3, position: 150), true),
        (3, 5, const BucketPlacement(bucketId: 1, position: 50), false),
      ]);
      expect(messages, [en.boardMovedTo('Done'), en.boardMovedTo('To do')]);
    });

    testWidgets('a repeating task into the done column is marked done in the '
        'default column, where the server reopens it', (tester) async {
      await pumpApp(tester);
      await open(tester, repeating);

      await pick(tester, 'Done');
      await moving;

      expect(data.tasks.placements, [
        (2, 5, const BucketPlacement(bucketId: 1), true),
      ]);
      expect(messages, [en.boardMovedTo('Done')]);
    });

    testWidgets('a full column is greyed out and a tap on it neither picks '
        'nor moves', (tester) async {
      await pumpApp(tester);
      await open(tester, report);

      bool enabled(String name) => tester
          .widget<ListTile>(inSheet(find.widgetWithText(ListTile, name)))
          .enabled;
      expect(enabled('Later (4)'), isFalse);
      expect(enabled('Later (2)'), isTrue);
      expect(enabled('Done'), isTrue);
      await tester.tap(inSheet(find.text('Later (4)')), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(inSheet(find.text(en.taskMoveToColumnTitle)), findsOneWidget);
      expect(data.tasks.placements, isEmpty);
      expect(messages, isEmpty);
      expect(haptics, isEmpty);
    });

    testWidgets('a pick plans against the board as it is by then: a column '
        'filled meanwhile refuses the card', (tester) async {
      await pumpApp(tester);
      await open(tester, report);
      expect(options(tester).first, ('Later (2)', null));

      board = choiceOf(report, [
        columns[0],
        column(2, 'Later', [card(4, 1000)], limit: 1),
        ...columns.skip(2),
      ]);
      await pick(tester, 'Later (2)');
      await moving;

      expect(data.tasks.placements, isEmpty);
      expect(messages, [en.boardColumnLimitReached]);
      expect(haptics, ['HapticFeedbackType.heavyImpact']);
    });

    testWidgets('a card that may no longer move by the time of the pick '
        'moves nothing and says nothing', (tester) async {
      await pumpApp(tester);
      await open(tester, report);

      board = null;
      await pick(tester, 'Later (2)');
      await moving;

      expect(data.tasks.placements, isEmpty);
      expect(messages, isEmpty);
      expect(haptics, isEmpty);
    });

    testWidgets('without a board to move on nothing opens', (tester) async {
      await pumpApp(tester);
      moving = moveToColumn(
        tester.element(find.byType(Scaffold).first),
        repository: data.tasks,
        task: report,
        choice: () => null,
        showMessage: messages.add,
      );
      await tester.pumpAndSettle();
      await moving;

      expect(find.byType(BottomSheet), findsNothing);
      expect(data.tasks.placements, isEmpty);
    });

    testWidgets('once the screen that asked is gone the card still moves, '
        'without a haptic or a message', (tester) async {
      await pumpApp(tester);
      final screen = await ScreenToLeave.push(tester);
      await open(tester, report, from: screen.context);
      await screen.leave(tester);
      expect(find.byType(BottomSheet), findsOneWidget);

      await pick(tester, 'Later (2)');
      await moving;

      expect(data.tasks.placements, [
        (1, 5, const BucketPlacement(bucketId: 2, position: 500), null),
      ]);
      expect(messages, isEmpty);
      expect(haptics, isEmpty);

      final again = await ScreenToLeave.push(tester);
      await open(tester, report, from: again.context);
      await again.leave(tester);
      board = choiceOf(report, [
        columns[0],
        column(2, 'Later', [card(4, 1000)], limit: 1),
        ...columns.skip(2),
      ]);
      await pick(tester, 'Later (2)');
      await moving;
      expect(data.tasks.placements, hasLength(1));
      expect(messages, isEmpty);
      expect(haptics, isEmpty);
    });

    testWidgets('dismissing the sheet moves nothing', (tester) async {
      await pumpApp(tester);
      await open(tester, report);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await moving;

      expect(find.byType(BottomSheet), findsNothing);
      expect(data.tasks.placements, isEmpty);
      expect(messages, isEmpty);
      expect(haptics, isEmpty);
    });
  });
}
