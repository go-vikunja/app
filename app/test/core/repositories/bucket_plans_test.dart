import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository.dart';

void main() {
  const todo = Bucket(
    id: 1,
    viewId: 8,
    title: 'To-Do',
    count: 2,
    position: 100,
  );
  const doing = Bucket(
    id: 2,
    viewId: 8,
    title: 'Doing',
    count: 1,
    position: 200,
  );
  const done = Bucket(id: 3, viewId: 8, title: 'Done', position: 300);
  const board = [done, todo, doing];

  group('a deletion', () {
    (int, bool)? plan(
      int bucketId,
      int defaultBucketId, {
      List<Bucket>? of,
      bool holdsTasks = true,
    }) {
      final deletion = planBucketDeletion(
        of ?? board,
        bucketId,
        defaultBucketId: defaultBucketId,
        holdsTasks: holdsTasks,
      );
      return deletion == null
          ? null
          : (deletion.tasksGoTo.id, deletion.defaultFirst);
    }

    bool? isFallback(int bucketId, int defaultBucketId) => planBucketDeletion(
      board,
      bucketId,
      defaultBucketId: defaultBucketId,
      holdsTasks: false,
    )?.isFallback;

    test('sends the tasks to the default bucket while it stays', () {
      expect(plan(2, 1), (1, false));
      expect(plan(3, 2), (2, false));
      expect(plan(1, 3), (3, false));
    });

    test('of the default bucket right of others sends them to the '
        'leftmost, which the server picks itself', () {
      expect(plan(2, 2), (1, false));
    });

    test('of the leftmost bucket holding tasks while no other default is '
        'set needs the next one as the default first', () {
      expect(plan(1, 1), (2, true));
      expect(plan(1, 0), (2, true));
      expect(plan(1, 99), (2, true), reason: 'a default the board lacks');
    });

    test('of a leftmost bucket without tasks needs no new default, '
        'whatever its count', () {
      expect(plan(1, 0, holdsTasks: false), (2, false));
      expect(plan(1, 1, holdsTasks: false), (2, false));
      expect(
        plan(
          1,
          0,
          of: const [
            Bucket(id: 1, viewId: 8, title: 'To-Do', position: 100),
            doing,
          ],
        ),
        (2, true),
        reason: 'a stored count of 0 can miss newer tasks',
      );
    });

    test('marks the bucket the tasks would fall back to, with tasks or '
        'not', () {
      expect(isFallback(1, 0), isTrue);
      expect(isFallback(1, 1), isTrue);
      expect(isFallback(2, 0), isFalse);
      expect(isFallback(2, 2), isFalse);
      expect(isFallback(1, 2), isFalse);
    });

    test('follows the board order, ties by id', () {
      const tied = [
        Bucket(id: 5, viewId: 8, title: 'B', position: 0),
        Bucket(id: 4, viewId: 8, title: 'A', position: 0),
      ];
      expect(plan(4, 0, of: tied), (5, true));
      expect(plan(5, 0, of: tied), (4, false));
    });

    test('of the last bucket or one the board lacks has no plan', () {
      expect(plan(1, 1, of: const [todo]), isNull);
      expect(plan(9, 1), isNull);
    });
  });

  group('a move', () {
    test('lands between the new neighbours as the web computes it', () {
      expect(planBucketMove(board, 3, 0), 50);
      expect(planBucketMove(board, 1, 1), 250);
      expect(planBucketMove(board, 1, 2), 65836);
      expect(planBucketMove(board, 3, 1), 150);
    });

    test('clamps the index and is null where the bucket is already or for '
        'one the board lacks', () {
      expect(planBucketMove(board, 2, 9), 65836);
      expect(planBucketMove(board, 1, -3), isNull);
      expect(planBucketMove(board, 2, 1), isNull);
      expect(planBucketMove(board, 9, 0), isNull);
      expect(planBucketMove(const [todo], 1, 1), isNull);
    });

    group('next to columns at 0 or sharing a position', () {
      Bucket at(int id, double position) =>
          Bucket(id: id, viewId: 8, title: '$id', position: position);

      List<int> movedOrder(List<Bucket> buckets, int bucketId, double to) => [
        for (final bucket in [
          for (final bucket in buckets)
            if (bucket.id == bucketId) at(bucketId, to) else bucket,
        ]..sort(compareBucketOrder))
          bucket.id,
      ];

      test('goes 65536 below a first column at 0 or less', () {
        final zero = [at(1, 0), at(2, 200), at(3, 300)];
        expect(planBucketMove(zero, 2, 0), -65536);
        expect(movedOrder(zero, 2, -65536), [2, 1, 3]);
        expect(planBucketMove([at(1, -10), at(2, 200)], 2, 0), -65546);
      });

      test('takes the shared position when the id sorts between', () {
        final tied = [at(1, 0), at(3, 0), at(2, 100)];
        expect(planBucketMove(tied, 2, 1), 0);
        expect(movedOrder(tied, 2, 0), [1, 2, 3]);
      });

      test('is null when no position would put it there', () {
        final tied = [at(1, 0), at(2, 0), at(3, 0)];
        expect(planBucketMove(tied, 3, 1), isNull);
        expect(planBucketMove(tied, 1, 1), isNull);
        expect(planBucketMove(tied, 3, 0), -65536);
        expect(planBucketMove(tied, 1, 2), 65536);
      });
    });
  });
}
