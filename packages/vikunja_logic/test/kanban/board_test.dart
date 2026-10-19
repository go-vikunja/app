import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/tasks.dart';

const _toDo = 10;
const _doing = 20;
const _done = 30;

const _kanban = ProjectView(
  id: 7,
  projectId: 1,
  title: 'Kanban',
  kind: ProjectViewKind.kanban,
  bucketConfigurationMode: BucketConfigurationMode.manual,
  defaultBucketId: _toDo,
  doneBucketId: _done,
);

ProjectView _view({
  int defaultBucketId = _toDo,
  int doneBucketId = _done,
  BucketConfigurationMode mode = BucketConfigurationMode.manual,
  String? filter,
}) => ProjectView(
  id: 7,
  projectId: 1,
  title: 'Kanban',
  kind: ProjectViewKind.kanban,
  bucketConfigurationMode: mode,
  defaultBucketId: defaultBucketId,
  doneBucketId: doneBucketId,
  filter: filter == null ? null : ViewFilter(filter: filter),
);

Bucket _bucket(int id, double position, {int count = 0, int limit = 0}) =>
    Bucket(
      id: id,
      viewId: 7,
      title: 'Bucket $id',
      position: position,
      count: count,
      limit: limit,
    );

final List<Bucket> _buckets = [
  _bucket(_doing, 200, count: 1),
  _bucket(_done, 300),
  _bucket(_toDo, 100, count: 3),
];

final _loadedAt = DateTime.utc(2026, 10, 19, 12);
final DateTime _before = _loadedAt.subtract(const Duration(hours: 1));
final DateTime _after = _loadedAt.add(const Duration(minutes: 1));

// A downloaded board: To-Do holds 1, 2, 3 and Doing holds 4.
final _snapshot = <int, ({int bucketId, double position})>{
  1: (bucketId: _toDo, position: 100),
  2: (bucketId: _toDo, position: 200),
  3: (bucketId: _toDo, position: 300),
  4: (bucketId: _doing, position: 50),
};

Task _old(int id, {bool done = false, int projectId = 1}) => task(
  id,
  done: done,
  projectId: projectId,
  created: _before,
  updated: _before,
);

final List<Task> _downloadedTasks = [_old(1), _old(2), _old(3), _old(4)];

List<BoardColumn> _build({
  ProjectView view = _kanban,
  List<Bucket>? buckets,
  Map<int, ({int bucketId, double position})>? snapshot,
  DateTime? loadedAt,
  bool neverLoaded = false,
  List<Task>? tasks,
  Map<int, BucketPlacement> queued = const {},
  Set<int> movedHere = const {},
}) => buildBoard(
  view: view,
  buckets: buckets ?? _buckets,
  snapshot: snapshot ?? _snapshot,
  loadedAt: neverLoaded ? null : loadedAt ?? _loadedAt,
  projectTasks: tasks ?? _downloadedTasks,
  queued: queued,
  movedHere: movedHere,
);

Map<int, List<int>> _idsByBucket(List<BoardColumn> board) => {
  for (final column in board) column.bucket.id: idsOf(column.tasks),
};

BoardColumn _column(List<BoardColumn> board, int bucketId) =>
    board.singleWhere((column) => column.bucket.id == bucketId);

void main() {
  group('columns', () {
    test('follow the bucket positions', () {
      final board = _build();

      expect([for (final c in board) c.bucket.id], [_toDo, _doing, _done]);
    });

    test('with equal positions follow the bucket ids', () {
      final board = _build(
        buckets: [_bucket(3, 100), _bucket(1, 100), _bucket(2, 50)],
        snapshot: const {},
        tasks: const [],
      );

      expect([for (final c in board) c.bucket.id], [2, 1, 3]);
    });

    test('are none without buckets', () {
      expect(_build(buckets: const []), isEmpty);
    });

    test('carry their bucket unchanged', () {
      expect(_column(_build(), _doing).bucket, _bucket(_doing, 200, count: 1));
    });
  });

  group("a task's column", () {
    test('is its downloaded bucket', () {
      expect(_idsByBucket(_build()), {
        _toDo: [1, 2, 3],
        _doing: [4],
        _done: <int>[],
      });
    });

    test('is its queued placement for this view first', () {
      final board = _build(
        queued: {2: const BucketPlacement(bucketId: _doing, position: 60)},
      );

      expect(_idsByBucket(board), {
        _toDo: [1, 3],
        _doing: [4, 2],
        _done: <int>[],
      });
    });

    test('ignores a queued placement into a bucket the board lacks', () {
      final board = _build(queued: {2: const BucketPlacement(bucketId: 99)});

      expect(_idsByBucket(board)[_toDo], [1, 2, 3]);
    });

    test('is the done bucket for a done task', () {
      final board = _build(
        tasks: [_old(1), _old(2, done: true), _old(3), _old(4, done: true)],
      );

      expect(_idsByBucket(board), {
        _toDo: [1, 3],
        _doing: <int>[],
        _done: [4, 2],
      });
    });

    test('stays the downloaded bucket for a done task in a view without '
        'a done bucket', () {
      final board = _build(
        view: _view(doneBucketId: 0),
        tasks: [_old(1), _old(2, done: true), _old(3), _old(4)],
      );

      expect(_idsByBucket(board)[_toDo], [1, 2, 3]);
    });

    test('is the default bucket for an open task downloaded in the done '
        'bucket', () {
      final board = _build(
        snapshot: {..._snapshot, 5: (bucketId: _done, position: 10)},
        tasks: [..._downloadedTasks, _old(5)],
      );

      expect(_idsByBucket(board)[_toDo], [5, 1, 2, 3]);
      expect(_idsByBucket(board)[_done], isEmpty);
    });

    test('falls back to the leftmost bucket without a default bucket', () {
      final board = _build(
        view: _view(defaultBucketId: 0),
        snapshot: {..._snapshot, 5: (bucketId: _done, position: 10)},
        tasks: [..._downloadedTasks, _old(5)],
      );

      expect(_idsByBucket(board)[_toDo], [5, 1, 2, 3]);
    });

    test('falls back to the leftmost bucket when the default bucket is '
        'not on the board', () {
      final board = _build(
        view: _view(defaultBucketId: 99),
        buckets: [_bucket(_doing, 50), ..._buckets.skip(1)],
        snapshot: {..._snapshot, 5: (bucketId: _done, position: 10)},
        tasks: [..._downloadedTasks, _old(5)],
      );

      expect(_idsByBucket(board)[_doing], [5, 4]);
    });

    test('is the default bucket when the downloaded one is gone', () {
      final board = _build(
        snapshot: {..._snapshot, 5: (bucketId: 99, position: 10)},
        tasks: [..._downloadedTasks, _old(5)],
      );

      expect(_idsByBucket(board)[_toDo], [5, 1, 2, 3]);
    });

    test('is a queued placement even against the done rules', () {
      final board = _build(
        snapshot: {..._snapshot, 5: (bucketId: _done, position: 10)},
        tasks: [_old(1), _old(2, done: true), _old(3), _old(4), _old(5)],
        queued: {
          2: const BucketPlacement(bucketId: _doing, position: 70),
          5: const BucketPlacement(bucketId: _done, position: 20),
        },
      );

      expect(_idsByBucket(board), {
        _toDo: [1, 3],
        _doing: [4, 2],
        _done: [5],
      });
    });
  });

  group('tasks the download did not list', () {
    test('a temporary id goes on top of the default bucket, done ones on '
        'top of the done bucket', () {
      final board = _build(
        tasks: [..._downloadedTasks, task(-1), task(-2, done: true)],
      );

      expect(_idsByBucket(board)[_toDo], [-1, 1, 2, 3]);
      expect(_idsByBucket(board)[_done], [-2]);
    });

    test('a task created after the download is newer', () {
      final board = _build(
        tasks: [
          ..._downloadedTasks,
          task(9, created: _after, updated: _after),
        ],
      );

      expect(_idsByBucket(board)[_toDo], [9, 1, 2, 3]);
    });

    test('a task updated after the download (moved into the project) is '
        'newer', () {
      final board = _build(
        tasks: [
          ..._downloadedTasks,
          task(8, created: _before, updated: _after),
        ],
      );

      expect(_idsByBucket(board)[_toDo], [8, 1, 2, 3]);
    });

    test('an older one whose move into the project is not sent yet is '
        'newer, done ones on top of the done bucket', () {
      final board = _build(
        tasks: [..._downloadedTasks, _old(8), _old(9, done: true)],
        movedHere: {8, 9},
      );

      expect(_idsByBucket(board)[_toDo], [8, 1, 2, 3]);
      expect(_idsByBucket(board)[_done], [9]);
    });

    test('an older one is on a page not downloaded yet and stays hidden', () {
      final board = _build(tasks: [..._downloadedTasks, _old(8)]);

      expect(_idsByBucket(board)[_toDo], [1, 2, 3]);
      expect(board.expand((c) => c.tasks).map((t) => t.id), isNot(contains(8)));
    });

    test('are newest first, temporary ids before server ids', () {
      final board = _build(
        tasks: [
          ..._downloadedTasks,
          task(9, created: _after),
          task(-1),
          task(12, created: _after),
          task(-3),
        ],
      );

      expect(_idsByBucket(board)[_toDo], [-3, -1, 12, 9, 1, 2, 3]);
    });

    test('without a download every one counts as newer', () {
      final board = _build(
        neverLoaded: true,
        snapshot: const {},
        tasks: [_old(1), _old(2, done: true)],
      );

      expect(_idsByBucket(board), {
        _toDo: [1],
        _doing: <int>[],
        _done: [2],
      });
    });

    test('a newer one with a queued placement goes where it was placed', () {
      final board = _build(
        tasks: [..._downloadedTasks, task(-1)],
        queued: {-1: const BucketPlacement(bucketId: _doing, position: 25)},
      );

      expect(_idsByBucket(board)[_doing], [-1, 4]);
      expect(_idsByBucket(board)[_toDo], [1, 2, 3]);
    });

    test('a done one goes to the default bucket in a view without a done '
        'bucket', () {
      final board = _build(
        view: _view(doneBucketId: 0),
        tasks: [..._downloadedTasks, task(-1, done: true)],
      );

      expect(_idsByBucket(board)[_toDo], [-1, 1, 2, 3]);
    });
  });

  group('hidden tasks', () {
    test('a task moved to another project is hidden', () {
      final board = _build(
        tasks: [_old(1), _old(2, projectId: 2), _old(3), _old(4)],
      );

      expect(_idsByBucket(board)[_toDo], [1, 3]);
    });

    test('a newer task of another project is hidden', () {
      final board = _build(
        tasks: [..._downloadedTasks, task(-1, projectId: 2)],
      );

      expect(_idsByBucket(board)[_toDo], [1, 2, 3]);
    });

    test('a downloaded task deleted here is hidden', () {
      final board = _build(tasks: [_old(1), _old(3), _old(4)]);

      expect(_idsByBucket(board)[_toDo], [1, 3]);
    });
  });

  group('order in a column', () {
    test('is by downloaded position, then id', () {
      final board = _build(
        snapshot: {
          1: (bucketId: _toDo, position: 300),
          2: (bucketId: _toDo, position: 100),
          3: (bucketId: _toDo, position: 100),
        },
        tasks: [_old(3), _old(1), _old(2)],
      );

      expect(_idsByBucket(board)[_toDo], [2, 3, 1]);
    });

    test('takes a queued position over the downloaded one', () {
      final board = _build(
        queued: {3: const BucketPlacement(bucketId: _toDo, position: 150)},
      );

      expect(_idsByBucket(board)[_toDo], [1, 3, 2]);
    });

    test('puts a task placed without a position on top', () {
      final board = _build(queued: {3: const BucketPlacement(bucketId: _toDo)});

      expect(_idsByBucket(board)[_toDo], [3, 1, 2]);
    });

    test('puts newer tasks and those placed without a position on top, '
        'newest first', () {
      final board = _build(
        tasks: [
          ..._downloadedTasks,
          task(9, created: _after),
          task(-1),
        ],
        queued: {
          2: const BucketPlacement(bucketId: _toDo),
          4: const BucketPlacement(bucketId: _toDo),
        },
      );

      expect(_idsByBucket(board)[_toDo], [-1, 9, 4, 2, 1, 3]);
    });

    test('keeps a moved task at its downloaded position', () {
      final withDone = _build(
        tasks: [
          _old(1),
          _old(2),
          _old(3, done: true),
          _old(4),
          _old(5, done: true),
          _old(6, done: true),
        ],
        snapshot: {
          ..._snapshot,
          5: (bucketId: _done, position: 250),
          6: (bucketId: _done, position: 350),
        },
      );
      expect(_idsByBucket(withDone)[_done], [5, 3, 6]);
    });
  });

  group('positions of the cards', () {
    test('are the queued or downloaded ones', () {
      final board = _build(
        queued: {2: const BucketPlacement(bucketId: _doing, position: 60)},
      );

      expect(
        [for (final t in _column(board, _toDo).tasks) t.position],
        [100, 300],
      );
      expect(
        [for (final t in _column(board, _doing).tasks) t.position],
        [50, 60],
      );
    });

    test('are spread below the first positioned card for the cards on top', () {
      final board = _build(tasks: [..._downloadedTasks, task(-1), task(-2)]);

      expect(
        [for (final t in _column(board, _toDo).tasks) t.position],
        [100 / 3, 200 / 3, 100, 200, 300],
      );
    });

    test('are multiples of 2^16 in a column of cards without positions', () {
      final board = _build(
        tasks: [
          ..._downloadedTasks,
          task(-1, done: true),
          task(-2, done: true),
        ],
      );

      expect(
        [for (final t in _column(board, _done).tasks) t.position],
        [65536, 131072],
      );
    });

    test('leave the rest of the task as it is', () {
      final local = task(1, title: 'Local title', created: _before);
      final board = _build(tasks: [local]);

      final shown = _column(board, _toDo).tasks.single;
      expect(shown.title, 'Local title');
      expect(shown, local.copyWith(position: 100));
    });

    test('drop between neighbours with calculateItemPosition', () {
      final tasks = _column(_build(), _toDo).tasks;

      expect(calculateItemPosition(tasks[0].position, tasks[1].position), 150);
    });
  });

  group('counts', () {
    test('are the server counts when nothing moved', () {
      final board = _build();

      expect([for (final c in board) c.shownCount], [3, 1, 0]);
    });

    test('follow the cards moved in and out here', () {
      final board = _build(
        queued: {2: const BucketPlacement(bucketId: _doing, position: 60)},
      );

      expect(_column(board, _toDo).shownCount, 2);
      expect(_column(board, _doing).shownCount, 2);
    });

    test('count a newer task in', () {
      final board = _build(tasks: [..._downloadedTasks, task(-1)]);

      expect(_column(board, _toDo).shownCount, 4);
    });

    test('count a task the done rule moved', () {
      final board = _build(
        tasks: [_old(1), _old(2), _old(3), _old(4, done: true)],
      );

      expect(_column(board, _doing).shownCount, 0);
      expect(_column(board, _done).shownCount, 1);
    });

    test('count a hidden downloaded task out', () {
      final board = _build(tasks: [_old(1), _old(3), _old(4)]);

      expect(_column(board, _toDo).shownCount, 2);
    });

    test('include the tasks not downloaded yet', () {
      final board = _build(
        buckets: [
          _bucket(_toDo, 100, count: 120),
          _bucket(_doing, 200, count: 1),
          _bucket(_done, 300),
        ],
        queued: {1: const BucketPlacement(bucketId: _done, position: 1)},
      );

      expect(_column(board, _toDo).shownCount, 119);
      expect(_column(board, _done).shownCount, 1);
    });

    test('are never fewer than the cards shown', () {
      final board = _build(
        buckets: [_bucket(_toDo, 100), _bucket(_doing, 200)],
      );

      expect(_column(board, _toDo).shownCount, 3);
      expect(_column(board, _doing).shownCount, 1);
    });
  });

  group('hasMore', () {
    test('is false when every task of a bucket was downloaded', () {
      expect([for (final c in _build()) c.hasMore], [false, false, false]);
    });

    test('is true while the server holds more than was downloaded', () {
      final board = _build(
        buckets: [
          _bucket(_toDo, 100, count: 4),
          _bucket(_doing, 200, count: 1),
        ],
      );

      expect(_column(board, _toDo).hasMore, isTrue);
      expect(_column(board, _doing).hasMore, isFalse);
    });

    test('ignores the cards moved here', () {
      final board = _build(
        buckets: [
          _bucket(_toDo, 100, count: 4),
          _bucket(_doing, 200, count: 1),
        ],
        queued: {1: const BucketPlacement(bucketId: _doing, position: 1)},
        tasks: [..._downloadedTasks, task(-1)],
      );

      expect(_column(board, _toDo).hasMore, isTrue);
      expect(_column(board, _doing).hasMore, isFalse);
    });
  });

  group('a filter-mode view', () {
    final byState = _view(
      mode: BucketConfigurationMode.filter,
      defaultBucketId: 0,
      doneBucketId: 1,
    );
    final synthetic = [_bucket(0, 0, count: 2), _bucket(1, 1, count: 1)];
    final snapshot = <int, ({int bucketId, double position})>{
      1: (bucketId: 0, position: 10),
      2: (bucketId: 0, position: 20),
      3: (bucketId: 1, position: 30),
    };

    test('shows the download as it is', () {
      final board = _build(
        view: byState,
        buckets: synthetic,
        snapshot: snapshot,
        tasks: [_old(1, done: true), _old(2), _old(3)],
      );

      expect(_idsByBucket(board), {
        0: [1, 2],
        1: [3],
      });
    });

    test('ignores queued placements and newer tasks', () {
      final board = _build(
        view: byState,
        buckets: synthetic,
        snapshot: snapshot,
        tasks: [_old(1), _old(2), _old(3), task(-1)],
        queued: {1: const BucketPlacement(bucketId: 1, position: 1)},
      );

      expect(_idsByBucket(board), {
        0: [1, 2],
        1: [3],
      });
    });

    test('hides a task listed in a bucket the board lacks', () {
      final board = _build(
        view: byState,
        buckets: synthetic,
        snapshot: {...snapshot, 4: (bucketId: 5, position: 1)},
        tasks: [_old(1), _old(2), _old(3), _old(4)],
      );

      expect(board.expand((c) => c.tasks).map((t) => t.id), [1, 2, 3]);
    });
  });

  group('a view filter', () {
    test('done = false hides done tasks, listed or newer', () {
      final board = _build(
        view: _view(filter: 'done = false'),
        tasks: [
          _old(1),
          _old(2, done: true),
          _old(3),
          _old(4),
          task(-1, done: true),
        ],
      );

      expect(_idsByBucket(board), {
        _toDo: [1, 3],
        _doing: [4],
        _done: <int>[],
      });
    });

    test('done = true hides open tasks', () {
      final board = _build(
        view: _view(filter: 'done = true'),
        tasks: [_old(1), _old(2, done: true), _old(3), _old(4), task(-1)],
      );

      expect(_idsByBucket(board), {
        _toDo: <int>[],
        _doing: <int>[],
        _done: [2],
      });
    });

    test('the device cannot evaluate keeps the download and waits for the '
        'next one for newer tasks', () {
      final board = _build(
        view: _view(filter: 'priority >= 3'),
        tasks: [
          ..._downloadedTasks,
          task(-1),
          task(9, created: _after),
        ],
      );

      expect(_idsByBucket(board)[_toDo], [1, 2, 3]);
    });
  });
}
