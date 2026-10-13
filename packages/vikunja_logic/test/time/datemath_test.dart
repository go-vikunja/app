import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/berlin.dart';

void main() {
  group('on a local Tuesday evening', () {
    final now = DateTime(2026, 10, 13, 22, 48, 55, 681);
    final cases = {
      'now': now,
      'now/d': DateTime(2026, 10, 13),
      'now/w': DateTime(2026, 10, 12),
      'now/M': DateTime(2026, 10),
      'now/y': DateTime(2026),
      'now/h': DateTime(2026, 10, 13, 22),
      'now/H': DateTime(2026, 10, 13, 22),
      'now/m': DateTime(2026, 10, 13, 22, 48),
      'now/s': DateTime(2026, 10, 13, 22, 48, 55),
      'now+1d': DateTime(2026, 10, 14, 22, 48, 55, 681),
      'now-1d': DateTime(2026, 10, 12, 22, 48, 55, 681),
      'now+2w': DateTime(2026, 10, 27, 22, 48, 55, 681),
      'now-1M': DateTime(2026, 9, 13, 22, 48, 55, 681),
      'now+1y': DateTime(2027, 10, 13, 22, 48, 55, 681),
      'now+3h': DateTime(2026, 10, 14, 1, 48, 55, 681),
      'now+3H': DateTime(2026, 10, 14, 1, 48, 55, 681),
      'now-90m': DateTime(2026, 10, 13, 21, 18, 55, 681),
      'now+30s': DateTime(2026, 10, 13, 22, 49, 25, 681),
      'now+0d': now,
      'now+007d': DateTime(2026, 10, 20, 22, 48, 55, 681),
      'now+1d+1d': DateTime(2026, 10, 15, 22, 48, 55, 681),
      'now/d+1d': DateTime(2026, 10, 14),
      // The server's own test expression: round after adding.
      'now+1d/d': DateTime(2026, 10, 14),
      'now/M-1d': DateTime(2026, 9, 30),
      'now/w-1w': DateTime(2026, 10, 5),
      'now/d+12h': DateTime(2026, 10, 13, 12),
      'now-1d/d+12h': DateTime(2026, 10, 12, 12),
      // The server trims a filter value first.
      ' now/d ': DateTime(2026, 10, 13),
    };
    for (final MapEntry(key: expression, value: expected) in cases.entries) {
      test("'$expression' is $expected", () {
        final result = evaluateDatemath(expression, now);
        expect(result, expected);
        expect(result.isUtc, isFalse);
      });
    }
  });

  group('/w is Monday 00:00 whatever the weekday', () {
    for (var day = 12; day <= 18; day++) {
      final now = DateTime(2026, 10, day, 10, 30);
      test('${now.weekday} (${now.month}-${now.day})', () {
        expect(evaluateDatemath('now/w', now), DateTime(2026, 10, 12));
      });
    }

    test('at the very edges of the week', () {
      expect(
        evaluateDatemath('now/w', DateTime(2026, 10, 12)),
        DateTime(2026, 10, 12),
      );
      expect(
        evaluateDatemath('now/w', DateTime(2026, 10, 18, 23, 59, 59, 999)),
        DateTime(2026, 10, 12),
      );
    });

    test('across a month and a year boundary', () {
      expect(
        evaluateDatemath('now/w', DateTime(2026, 11, 1, 9)),
        DateTime(2026, 10, 26),
      );
      expect(
        evaluateDatemath('now/w', DateTime(2027, 1, 2, 9)),
        DateTime(2026, 12, 28),
      );
    });
  });

  group("months and years overflow like Go's AddDate", () {
    test('January 31 plus a month is March 3', () {
      expect(
        evaluateDatemath('now+1M', DateTime(2026, 1, 31, 8)),
        DateTime(2026, 3, 3, 8),
      );
    });

    test('March 31 minus a month is March 3', () {
      expect(
        evaluateDatemath('now-1M', DateTime(2026, 3, 31, 8)),
        DateTime(2026, 3, 3, 8),
      );
    });

    test('February 29 plus a year is March 1', () {
      expect(
        evaluateDatemath('now+1y', DateTime(2028, 2, 29, 8)),
        DateTime(2029, 3, 1, 8),
      );
    });
  });

  group('a UTC now rounds in UTC (the server zone GMT, server.md §6)', () {
    final now = DateTime.utc(2026, 10, 13, 20, 48, 55);
    final cases = {
      'now/d': DateTime.utc(2026, 10, 13),
      'now/d+1d': DateTime.utc(2026, 10, 14),
      'now/w': DateTime.utc(2026, 10, 12),
      'now/M': DateTime.utc(2026, 10),
      'now/y': DateTime.utc(2026),
      'now+7d': DateTime.utc(2026, 10, 20, 20, 48, 55),
      'now/h': DateTime.utc(2026, 10, 13, 20),
    };
    for (final MapEntry(key: expression, value: expected) in cases.entries) {
      test("'$expression'", () {
        final result = evaluateDatemath(expression, now);
        expect(result, expected);
        expect(result.isUtc, isTrue);
      });
    }
  });

  group('anything else is a FormatException', () {
    for (final expression in [
      '',
      'Now',
      'NOW/d',
      'today',
      'now/',
      'now+',
      'now+d',
      'now++1d',
      'now+-1d',
      'now1d',
      'now+1.5d',
      'now+1x',
      'now/x',
      'now/b',
      'now+1b',
      'now+1fy',
      'now/fQ',
      'now/d+1',
      'now /d',
      'now/dd',
      '2026-10-13||+1d',
      '2026-10-13',
      // More digits than any sane amount; DateTime ends at ±100 000 000 days.
      'now+1234567890s',
      'now+999999999y',
      'now-999999999d',
    ]) {
      test("'$expression'", () {
        expect(
          () => evaluateDatemath(expression, DateTime(2026, 10, 13)),
          throwsFormatException,
        );
      });
    }
  });

  group('across a DST change in Europe/Berlin', skip: needsBerlin, () {
    test('a day ahead keeps the wall clock in 23 hours', () {
      final now = DateTime(2026, 3, 28, 12);
      final result = evaluateDatemath('now+1d', now);

      expect(result, DateTime(2026, 3, 29, 12));
      expect(result.difference(now), const Duration(hours: 23));
    });

    test('the spring day is 23 hours long', () {
      final now = DateTime(2026, 3, 29, 12);
      final start = evaluateDatemath('now/d', now);
      final end = evaluateDatemath('now/d+1d', now);

      expect(start, DateTime(2026, 3, 29));
      expect(end, DateTime(2026, 3, 30));
      expect(end.difference(start), const Duration(hours: 23));
    });

    test('hours add real time', () {
      final now = DateTime(2026, 3, 29, 12);

      expect(evaluateDatemath('now-12h', now), DateTime(2026, 3, 28, 23));
      expect(evaluateDatemath('now/d+3h', now), DateTime(2026, 3, 29, 4));
      expect(
        evaluateDatemath('now+24h', DateTime(2026, 3, 28, 12)),
        DateTime(2026, 3, 29, 13),
      );
    });

    test('the week of the spring change is 167 hours long', () {
      final now = DateTime(2026, 3, 29, 12);
      final start = evaluateDatemath('now/w', now);
      final end = evaluateDatemath('now/w+1w', now);

      expect(start, DateTime(2026, 3, 23));
      expect(end, DateTime(2026, 3, 30));
      expect(end.difference(start), const Duration(hours: 167));
    });

    test('the autumn day is 25 hours long', () {
      final now = DateTime(2026, 10, 25, 12);
      final start = evaluateDatemath('now/d', now);
      final end = evaluateDatemath('now/d+1d', now);

      expect(start, DateTime(2026, 10, 25));
      expect(end, DateTime(2026, 10, 26));
      expect(end.difference(start), const Duration(hours: 25));
      expect(
        evaluateDatemath('now-1d', now).difference(now),
        const Duration(hours: -25),
      );
    });

    test('three hours after midnight is the second 02:00 in autumn', () {
      final now = DateTime(2026, 10, 25, 12);

      expect(
        evaluateDatemath('now/d+3h', now).toUtc(),
        DateTime.utc(2026, 10, 25, 1),
      );
    });

    test('rounding to the hour stays in the repeated hour', () {
      // 02:30 CET, the second 02:30 of the night.
      final now = DateTime.utc(2026, 10, 25, 1, 30).toLocal();

      expect(
        evaluateDatemath('now/h', now).toUtc(),
        DateTime.utc(2026, 10, 25, 1),
      );
      expect(
        evaluateDatemath('now/m', now.add(const Duration(seconds: 42))).toUtc(),
        DateTime.utc(2026, 10, 25, 1, 30),
      );
    });

    test('server.md §6: the probe time with filter_timezone Berlin', () {
      final now = DateTime.utc(2026, 10, 13, 20, 48, 55).toLocal();

      expect(
        evaluateDatemath('now/d', now).toUtc(),
        DateTime.utc(2026, 10, 12, 22),
      );
      expect(
        evaluateDatemath('now/d+1d', now).toUtc(),
        DateTime.utc(2026, 10, 13, 22),
      );
      expect(
        evaluateDatemath('now/w', now).toUtc(),
        DateTime.utc(2026, 10, 11, 22),
      );
      expect(
        evaluateDatemath('now/M', now).toUtc(),
        DateTime.utc(2026, 9, 30, 22),
      );
    });
  });
}
