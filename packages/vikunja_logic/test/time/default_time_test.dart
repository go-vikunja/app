import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

void main() {
  group('nearestBreakpointHour', () {
    // The web's calculateNearestTime.test.ts.
    final cases = {
      '5:00': (5, 0, 9),
      '7:00': (7, 0, 9),
      '7:41': (7, 41, 9),
      '9:00': (9, 0, 9),
      '9:01': (9, 1, 12),
      '10:00': (10, 0, 12),
      '12:00': (12, 0, 12),
      '12:30': (12, 30, 15),
      '13:00': (13, 0, 15),
      '15:00': (15, 0, 15),
      '15:54': (15, 54, 18),
      '16:00': (16, 0, 18),
      '18:00': (18, 0, 18),
      '18:45': (18, 45, 21),
      '19:00': (19, 0, 21),
      '21:00': (21, 0, 21),
      '21:30': (21, 30, 9),
      '22:00': (22, 0, 9),
      '22:40': (22, 40, 9),
      '0:00': (0, 0, 9),
      '23:59': (23, 59, 9),
    };
    for (final MapEntry(key: label, value: (hour, minute, expected))
        in cases.entries) {
      test('$label gives $expected', () {
        expect(
          nearestBreakpointHour(DateTime(2026, 8, 4, hour, minute)),
          expected,
        );
      });
    }

    test('seconds past a full hour still count as that hour', () {
      expect(nearestBreakpointHour(DateTime(2026, 8, 4, 12, 0, 59)), 12);
    });
  });

  group('atDefaultTime', () {
    test('puts the day at the breakpoint for now, seconds dropped', () {
      expect(
        atDefaultTime(
          DateTime(2026, 9, 20, 7, 33, 12, 5),
          now: DateTime(2026, 8, 4, 10, 15, 30),
        ),
        DateTime(2026, 9, 20, 12),
      );
    });

    test('after 21:00 it is 09:00 of the day, even today (D38-6)', () {
      final now = DateTime(2026, 8, 4, 22, 30);
      expect(atDefaultTime(now, now: now), DateTime(2026, 8, 4, 9));
    });
  });
}
