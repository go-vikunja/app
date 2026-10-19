import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

// The vectors of the web's calculateTaskPosition.test.ts at e7d7f17.
void main() {
  test('between two neighbours is the midpoint', () {
    expect(calculateItemPosition(10, 100), 55);
  });

  test('without a neighbour above is half the one below', () {
    expect(calculateItemPosition(null, 100), 50);
  });

  test('without a neighbour below is 2^16 after the one above', () {
    expect(calculateItemPosition(10, null), 65546);
  });

  test('without any neighbour is 2^16, where the web sends 0', () {
    expect(calculateItemPosition(null, null), 65536);
    expect(calculateItemPosition(null, null), greaterThan(minPositionSpacing));
  });

  test('between equal neighbours nudges by the minimum spacing', () {
    expect(calculateItemPosition(100, 100), 100.01);
    expect(calculateItemPosition(100, 100), greaterThan(100));
    expect(calculateItemPosition(100, 100), lessThan(101));
  });

  test('between neighbours at zero is above zero', () {
    expect(calculateItemPosition(0, 0), 0.01);
  });

  test('survives a JSON round trip', () {
    final position = calculateItemPosition(100, 100);

    expect(jsonDecode(jsonEncode(position)), position);
  });

  test('a fractional midpoint keeps its fraction', () {
    expect(calculateItemPosition(1, 2), 1.5);
    expect(calculateItemPosition(null, 1), 0.5);
  });
}
