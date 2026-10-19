import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  group('Bucket', () {
    const doing = Bucket(
      id: 2,
      viewId: 7,
      title: 'Doing',
      position: 200,
      limit: 3,
      count: 2,
    );

    test('is full once the count reaches a set limit', () {
      expect(doing.isFull, isFalse);
      expect(
        const Bucket(
          id: 2,
          viewId: 7,
          title: 'D',
          position: 0,
          limit: 3,
          count: 3,
        ).isFull,
        isTrue,
      );
      expect(
        const Bucket(
          id: 2,
          viewId: 7,
          title: 'D',
          position: 0,
          limit: 3,
          count: 5,
        ).isFull,
        isTrue,
      );
    });

    test('without a limit is never full', () {
      expect(
        const Bucket(
          id: 1,
          viewId: 7,
          title: 'To-Do',
          position: 100,
          count: 900,
        ).isFull,
        isFalse,
      );
    });

    test('defaults to no limit and no tasks', () {
      const bucket = Bucket(id: 1, viewId: 7, title: 'To-Do', position: 100);

      expect(bucket.limit, 0);
      expect(bucket.count, 0);
    });

    test('compares by value', () {
      const same = Bucket(
        id: 2,
        viewId: 7,
        title: 'Doing',
        position: 200,
        limit: 3,
        count: 2,
      );

      expect(doing, same);
      expect(doing.hashCode, same.hashCode);
      final others = [
        const Bucket(
          id: 3,
          viewId: 7,
          title: 'Doing',
          position: 200,
          limit: 3,
          count: 2,
        ),
        const Bucket(
          id: 2,
          viewId: 8,
          title: 'Doing',
          position: 200,
          limit: 3,
          count: 2,
        ),
        const Bucket(
          id: 2,
          viewId: 7,
          title: 'Done',
          position: 200,
          limit: 3,
          count: 2,
        ),
        const Bucket(
          id: 2,
          viewId: 7,
          title: 'Doing',
          position: 201,
          limit: 3,
          count: 2,
        ),
        const Bucket(
          id: 2,
          viewId: 7,
          title: 'Doing',
          position: 200,
          limit: 4,
          count: 2,
        ),
        const Bucket(
          id: 2,
          viewId: 7,
          title: 'Doing',
          position: 200,
          limit: 3,
          count: 1,
        ),
      ];
      expect(others, everyElement(isNot(doing)));
    });

    test('toString leaves the title out', () {
      expect(doing.toString(), isNot(contains('Doing')));
      expect(doing.toString(), contains('2'));
    });
  });

  group('BucketPlacement', () {
    test('compares bucket and position', () {
      expect(
        const BucketPlacement(bucketId: 2, position: 55),
        const BucketPlacement(bucketId: 2, position: 55),
      );
      expect(
        const BucketPlacement(bucketId: 2, position: 55).hashCode,
        const BucketPlacement(bucketId: 2, position: 55).hashCode,
      );
      expect(
        const BucketPlacement(bucketId: 2, position: 55),
        isNot(const BucketPlacement(bucketId: 3, position: 55)),
      );
      expect(
        const BucketPlacement(bucketId: 2, position: 55),
        isNot(const BucketPlacement(bucketId: 2)),
      );
    });

    test('without a position keeps the server one', () {
      expect(const BucketPlacement(bucketId: 2).position, isNull);
    });
  });
}
