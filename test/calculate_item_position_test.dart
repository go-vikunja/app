import 'dart:math';
import 'package:test/test.dart';
import 'package:vikunja_app/core/utils/calculate_item_position.dart';

void main() {
  group('Calculate item position tests', () {
    test('Both positions null should return 0', () {
      expect(
        calculateItemPosition(positionBefore: null, positionAfter: null),
        0,
      );
    });

    test('Only positionAfter provided should return half of positionAfter', () {
      expect(
        calculateItemPosition(positionBefore: null, positionAfter: 10.0),
        5.0,
      );
      expect(
        calculateItemPosition(positionBefore: null, positionAfter: 100.0),
        50.0,
      );
      expect(
        calculateItemPosition(positionBefore: null, positionAfter: 1.0),
        0.5,
      );
    });

    test(
      'Only positionBefore provided should return positionBefore + 2^16',
      () {
        double expected = 10.0 + pow(2.0, 16.0);
        expect(
          calculateItemPosition(positionBefore: 10.0, positionAfter: null),
          expected,
        );

        expected = 100.0 + pow(2.0, 16.0);
        expect(
          calculateItemPosition(positionBefore: 100.0, positionAfter: null),
          expected,
        );
      },
    );

    test('Both positions provided should return average', () {
      expect(
        calculateItemPosition(positionBefore: 10.0, positionAfter: 20.0),
        15.0,
      );
      expect(
        calculateItemPosition(positionBefore: 0.0, positionAfter: 10.0),
        5.0,
      );
      expect(
        calculateItemPosition(positionBefore: 50.0, positionAfter: 100.0),
        75.0,
      );
    });

    test('Edge cases with very small and large numbers', () {
      expect(
        calculateItemPosition(positionBefore: 0.001, positionAfter: 0.002),
        0.0015,
      );
      expect(
        calculateItemPosition(
          positionBefore: 1000000.0,
          positionAfter: 2000000.0,
        ),
        1500000.0,
      );
    });

    test('Same positions should return same value', () {
      expect(
        calculateItemPosition(positionBefore: 10.0, positionAfter: 10.0),
        10.0,
      );
      expect(
        calculateItemPosition(positionBefore: 0.0, positionAfter: 0.0),
        0.0,
      );
    });
  });
}
