import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/db/chunks.dart';

void main() {
  // The loop TasksDao had before chunksOf, as the reference.
  List<List<int>> loopSlices(List<int> all, int size) => [
    for (var start = 0; start < all.length; start += size)
      all.sublist(start, (start + size).clamp(0, all.length)),
  ];

  test('gives the same slices as the loop it replaces', () {
    for (final length in [0, 1, 499, 500, 501, 1000, 1001, 1500]) {
      final all = [for (var i = 0; i < length; i++) i];

      final slices = chunksOf(all).toList();

      expect(slices, loopSlices(all, 500), reason: '$length');
      expect(slices.expand((slice) => slice), all, reason: '$length');
      expect(
        slices.every((slice) => slice.isNotEmpty && slice.length <= 500),
        isTrue,
        reason: '$length',
      );
    }
  });

  test('slice counts at the edges of the default size', () {
    final counts = {0: 0, 1: 1, 500: 1, 501: 2, 1000: 2, 1001: 3};
    for (final MapEntry(key: length, value: count) in counts.entries) {
      expect(chunksOf(List.filled(length, 0)).length, count, reason: '$length');
    }
  });

  test('takes another size', () {
    expect(chunksOf([1, 2, 3, 4, 5], 2).toList(), [
      [1, 2],
      [3, 4],
      [5],
    ]);
  });

  test('a slice is a copy, so changing the list later leaves it alone', () {
    final all = [1, 2, 3];
    final first = chunksOf(all, 2).first;

    all[0] = 9;

    expect(first, [1, 2]);
  });
}
