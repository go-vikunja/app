import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final view = sampleKanbanView(
    id: 5,
    projectId: 1,
    defaultBucketId: 1,
    doneBucketId: 3,
  );

  Task card(int id, double position, {bool repeats = false}) => sampleTask(
    id: id,
    title: 'Task $id',
    position: position,
    repeatAfter: repeats ? const Duration(days: 1) : Duration.zero,
  );

  BoardColumn column(
    int bucketId,
    List<Task> tasks, {
    int limit = 0,
    int? count,
    bool hasMore = false,
  }) => BoardColumn(
    bucket: Bucket(
      id: bucketId,
      viewId: 5,
      title: 'Bucket $bucketId',
      limit: limit,
      count: count ?? tasks.length,
      position: bucketId * 100,
    ),
    tasks: tasks,
    shownCount: count ?? tasks.length,
    hasMore: hasMore,
  );

  final todo = column(1, [card(1, 100), card(2, 200), card(3, 300)]);
  final doing = column(2, [card(4, 1000), card(5, 2000)]);
  final done = column(3, const []);
  final columns = [todo, doing, done];

  CardMove? move(
    Task task,
    int toBucketId,
    int index, {
    List<BoardColumn>? on,
    ProjectView? of,
  }) => planCardMove(
    view: of ?? view,
    columns: on ?? columns,
    task: task,
    toBucketId: toBucketId,
    index: index,
  );

  PlaceCard placed(int bucketId, double position, {bool? done}) => PlaceCard(
    BucketPlacement(bucketId: bucketId, position: position),
    done: done,
  );

  group('within a column', () {
    test('a card moved down goes between its new neighbours', () {
      expect(move(todo.tasks[0], 1, 1), placed(1, 250));
    });

    test('a card moved to the top goes to half the first position', () {
      expect(move(todo.tasks[2], 1, 0), placed(1, 50));
    });

    test('a card moved to the end goes 2^16 below the last one', () {
      expect(move(todo.tasks[0], 1, 2), placed(1, 300 + 65536));
    });

    test('a card dropped where it was changes nothing', () {
      expect(move(todo.tasks[1], 1, 1), isNull);
    });

    test('equal neighbours put it just after them, like the web', () {
      final same = column(1, [card(1, 100), card(2, 100), card(3, 300)]);
      expect(
        move(same.tasks[2], 1, 1, on: [same, doing, done]),
        placed(1, 100.01),
      );
    });

    test('a full column still takes its own cards', () {
      final full = column(1, todo.tasks, limit: 3);
      expect(
        move(full.tasks[0], 1, 2, on: [full, doing, done]),
        placed(1, 300 + 65536),
      );
    });
  });

  group('between columns', () {
    test('a card goes between the cards it is dropped between', () {
      expect(move(todo.tasks[0], 2, 1), placed(2, 1500));
      expect(move(todo.tasks[0], 2, 0), placed(2, 500));
      expect(move(todo.tasks[0], 2, 2), placed(2, 2000 + 65536));
    });

    test('an empty column gets 2^16, not the 0 that would make the server '
        'recalculate the view', () {
      final empty = column(4, const []);
      expect(move(todo.tasks[0], 4, 0, on: [todo, empty]), placed(4, 65536));
    });

    test('a full column refuses the card', () {
      final full = column(2, doing.tasks, limit: 2);
      expect(
        move(todo.tasks[0], 2, 0, on: [todo, full, done]),
        const ColumnFull(),
      );
    });

    test('the limit counts the cards moved here, not only the download', () {
      final crowded = column(2, doing.tasks, limit: 3, count: 3);
      expect(
        move(todo.tasks[0], 2, 0, on: [todo, crowded, done]),
        const ColumnFull(),
      );
    });

    test('into the done column marks the task done', () {
      expect(move(todo.tasks[0], 3, 0), placed(3, 65536, done: true));
    });

    test('a repeating task dropped into the done column is marked done and '
        'placed where the server reopens it, without a position', () {
      final repeating = card(9, 50, repeats: true);
      final inDoing = column(2, [repeating, ...doing.tasks]);
      final planned = move(repeating, 3, 0, on: [todo, inDoing, done]);

      expect(planned, const MarkCardDone(1));
      expect(
        (planned! as MarkCardDone).placement,
        const BucketPlacement(bucketId: 1),
      );
    });

    test('without a default column a repeating task reopens in the '
        'leftmost', () {
      final repeating = card(9, 50, repeats: true);
      final inDoing = column(2, [repeating, ...doing.tasks]);
      final noDefault = sampleKanbanView(id: 5, projectId: 1, doneBucketId: 3);

      expect(
        move(repeating, 3, 0, on: [todo, inDoing, done], of: noDefault),
        const MarkCardDone(1),
      );
    });

    test('a repeating task shown in the done column keeps no place there', () {
      final repeating = card(9, 50, repeats: true);
      final doneColumn = column(3, [card(8, 10), repeating]);

      expect(move(repeating, 3, 0, on: [todo, doing, doneColumn]), isNull);
    });

    test('a full done column refuses a repeating task too', () {
      final repeating = card(9, 50, repeats: true);
      final fullDone = column(3, [card(8, 10)], limit: 1);

      expect(
        move(
          repeating,
          3,
          0,
          on: [
            column(1, [repeating]),
            doing,
            fullDone,
          ],
        ),
        const ColumnFull(),
      );
    });

    test('out of the done column marks the task open again', () {
      final finished = sampleTask(
        id: 7,
        title: 'Finished',
        done: true,
        position: 70,
      );
      final doneColumn = column(3, [finished]);
      expect(
        move(finished, 2, 0, on: [todo, doing, doneColumn]),
        placed(2, 500, done: false),
      );
    });

    test('without a done column nothing changes the done state', () {
      final noDone = sampleKanbanView(id: 5, projectId: 1);
      expect(move(todo.tasks[0], 3, 0, of: noDone), placed(3, 65536));
    });
  });

  test('a card or column not on the board moves nowhere', () {
    expect(move(card(99, 1), 2, 0), isNull);
    expect(move(todo.tasks[0], 99, 0), isNull);
  });

  group('a column with cards not loaded yet', () {
    final partly = column(2, doing.tasks, count: 40, hasMore: true);

    test('takes a card from elsewhere no lower than above its last card', () {
      expect(
        move(todo.tasks[0], 2, 2, on: [todo, partly, done]),
        placed(2, 1500),
      );
    });

    test('moves its own card no lower than above its last card', () {
      final three = column(
        2,
        [card(4, 1000), card(5, 2000), card(6, 3000)],
        count: 40,
        hasMore: true,
      );
      expect(
        move(three.tasks[0], 2, 2, on: [todo, three, done]),
        placed(2, 2500),
      );
    });

    test('leaves its last card where it is', () {
      expect(move(partly.tasks[1], 2, 1, on: [todo, partly, done]), isNull);
    });
  });

  test('the index is kept within the column', () {
    expect(move(todo.tasks[0], 2, 10), placed(2, 2000 + 65536));
    expect(move(todo.tasks[2], 1, -3), placed(1, 50));
  });

  group('read-only and full', () {
    test('a filter-mode board or an archived project moves nothing', () {
      expect(boardIsReadOnly(view, archived: false), isFalse);
      expect(boardIsReadOnly(view, archived: true), isTrue);
      expect(
        boardIsReadOnly(
          sampleKanbanView(
            id: 6,
            projectId: 1,
            mode: BucketConfigurationMode.filter,
          ),
          archived: false,
        ),
        isTrue,
      );
    });

    test('a column is full at its limit; 0 is none', () {
      expect(columnIsFull(column(1, const [], count: 99)), isFalse);
      expect(columnIsFull(column(1, const [], limit: 3, count: 2)), isFalse);
      expect(columnIsFull(column(1, const [], limit: 3, count: 3)), isTrue);
    });
  });

  group('tasks added on top', () {
    test('one goes to half the top position', () {
      expect(positionsOnTop(1000, count: 1), [500]);
    });

    test('several keep their order below the top card', () {
      expect(positionsOnTop(900, count: 2), [300, 600]);
    });

    test('an empty column spaces them 2^16 apart', () {
      expect(positionsOnTop(null, count: 1), [65536]);
      expect(positionsOnTop(null, count: 3), [65536, 131072, 196608]);
    });
  });

  test("a board origin is its project's and view's ids", () {
    const origin = TaskBoardOrigin(projectId: 1, viewId: 5);
    expect(origin, const TaskBoardOrigin(projectId: 1, viewId: 5));
    expect(
      origin.hashCode,
      const TaskBoardOrigin(projectId: 1, viewId: 5).hashCode,
    );
    expect(origin, isNot(const TaskBoardOrigin(projectId: 1, viewId: 6)));
    expect(origin, isNot(const TaskBoardOrigin(projectId: 2, viewId: 5)));
  });

  group('column names', () {
    BoardColumn titled(int bucketId, String title) => BoardColumn(
      bucket: Bucket(
        id: bucketId,
        viewId: 5,
        title: title,
        position: bucketId * 100,
      ),
      tasks: const [],
      shownCount: 0,
      hasMore: false,
    );

    test('are the titles when each is used once', () {
      expect(columnNamesOf([titled(1, 'To do'), titled(2, 'Doing')]), {
        1: 'To do',
        2: 'Doing',
      });
    });

    test('carry their place on the board when a title repeats', () {
      expect(
        columnNamesOf([
          titled(7, 'Later'),
          titled(3, 'Now'),
          titled(9, 'Later'),
        ]),
        {7: 'Later (1)', 3: 'Now', 9: 'Later (3)'},
      );
    });
  });

  group('the columns of a source', () {
    final loadedAt = DateTime.utc(2026, 10, 10, 12);
    const buckets = [
      Bucket(id: 1, viewId: 5, title: 'To do', position: 100, count: 2),
      Bucket(id: 2, viewId: 5, title: 'Doing', position: 200, count: 1),
      Bucket(id: 3, viewId: 5, title: 'Done', position: 300),
    ];
    const snapshot = <int, BoardSlot>{
      1: (bucketId: 1, position: 100),
      2: (bucketId: 2, position: 200),
      3: (bucketId: 1, position: 300),
      5: (bucketId: 1, position: 400),
    };
    final projectTasks = [
      sampleTask(id: 6, title: 'New', created: DateTime.utc(2026, 10, 10, 13)),
      sampleTask(
        id: 7,
        title: 'On a page not downloaded',
        created: DateTime.utc(2026, 10, 10, 11),
      ),
      sampleTask(id: 1, title: 'Queued'),
      sampleTask(id: 2, title: 'Doing'),
      sampleTask(id: 3, title: 'Filtered out'),
      sampleTask(id: 4, title: 'Moved here'),
      sampleTask(id: 5, title: 'Done here', done: true),
    ];
    const queued = {1: BucketPlacement(bucketId: 2, position: 50)};
    const movedHere = {4};
    const queuedDoneChanges = {5};
    const matchingIds = {1, 2, 4, 5, 6, 7};

    BoardSource source({Set<String> without = const {}}) => BoardSource(
      view: view,
      buckets: without.contains('buckets') ? const [] : buckets,
      snapshot: without.contains('snapshot') ? const {} : snapshot,
      loadedAt: without.contains('loadedAt') ? null : loadedAt,
      projectTasks: without.contains('projectTasks') ? const [] : projectTasks,
      queued: without.contains('queued') ? const {} : queued,
      movedHere: without.contains('movedHere') ? const {} : movedHere,
      queuedDoneChanges: without.contains('queuedDoneChanges')
          ? const {}
          : queuedDoneChanges,
      matchingIds: without.contains('matchingIds') ? null : matchingIds,
    );

    List<String> shape(List<BoardColumn> columns) => [
      for (final column in columns)
        [
          column.bucket.id,
          for (final task in column.tasks) '${task.id}@${task.position}',
          column.shownCount,
          column.hasMore,
        ].join(' '),
    ];

    test("are the board's own, built from every part of it", () {
      expect(
        shape(boardColumnsOf(view, source())),
        shape(
          buildBoard(
            view: view,
            buckets: buckets,
            snapshot: snapshot,
            loadedAt: loadedAt,
            projectTasks: projectTasks,
            queued: queued,
            movedHere: movedHere,
            queuedDoneChanges: queuedDoneChanges,
            matchingIds: matchingIds,
          ),
        ),
      );
    });

    test('change with each part of it', () {
      final full = shape(boardColumnsOf(view, source()));
      for (final part in [
        'buckets',
        'snapshot',
        'loadedAt',
        'projectTasks',
        'queued',
        'movedHere',
        'queuedDoneChanges',
        'matchingIds',
      ]) {
        expect(
          shape(boardColumnsOf(view, source(without: {part}))),
          isNot(full),
          reason: part,
        );
      }
    });
  });

  group('queueing a move', () {
    late SyncFakes data;

    setUp(() {
      data = SyncFakes(now: DateTime(2026, 10, 10, 12));
      data.tasks.all = [card(1, 100), card(2, 200, repeats: true)];
    });

    test('places the card with the done state the move changes', () async {
      const placement = BucketPlacement(bucketId: 3, position: 50);
      await queueCardMove(
        data.tasks,
        1,
        viewId: 5,
        move: const PlaceCard(placement, done: true),
      );
      await queueCardMove(
        data.tasks,
        1,
        viewId: 5,
        move: const PlaceCard(BucketPlacement(bucketId: 1, position: 10)),
      );
      await queueCardMove(
        data.tasks,
        1,
        viewId: 5,
        move: const PlaceCard(placement, done: false),
      );

      expect(data.tasks.placements, [
        (1, 5, placement, true),
        (1, 5, const BucketPlacement(bucketId: 1, position: 10), null),
        (1, 5, placement, false),
      ]);
    });

    test('marks a repeating task done in the column it reopens in', () async {
      await queueCardMove(
        data.tasks,
        2,
        viewId: 5,
        move: const MarkCardDone(1),
      );

      expect(data.tasks.placements, [
        (2, 5, const BucketPlacement(bucketId: 1), true),
      ]);
    });

    test('queues nothing for a full column', () async {
      await queueCardMove(data.tasks, 1, viewId: 5, move: const ColumnFull());

      expect(data.tasks.placements, isEmpty);
      expect(data.tasks.writes, isEmpty);
    });
  });
}
