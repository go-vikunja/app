import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/berlin.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('on a local Tuesday evening', () {
    final now = DateTime(2026, 10, 13, 22, 48, 55, 681);
    final cases = {
      'now': now,
      'now/d': DateTime(2026, 10, 13),
      'now/w': DateTime(2026, 10, 12),
      'now/M': DateTime(2026, 10),
      'now/y': DateTime(2026),
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
      // Values without a zone take now's.
      '2026-10-20': DateTime(2026, 10, 20),
      '2026-10-20T07:30': DateTime(2026, 10, 20, 7, 30),
    };
    for (final MapEntry(key: expression, value: expected) in cases.entries) {
      test("'$expression' is $expected", () {
        final result = evaluateDatemath(expression, now);
        expect(result, expected);
        expect(result.isUtc, isFalse);
      });
    }

    // Go's Truncate: the local hour unless the zone's offset has minutes.
    test("'now/h' cuts the instant to the hour", () {
      final microseconds = now.microsecondsSinceEpoch;
      final expected = DateTime.fromMicrosecondsSinceEpoch(
        microseconds - microseconds % Duration.microsecondsPerHour,
      );

      expect(evaluateDatemath('now/h', now), expected);
      expect(evaluateDatemath('now/H', now), expected);
    });
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

  group('the rest of go-datemath on a UTC Tuesday', () {
    final now = DateTime.utc(2026, 10, 13, 20, 48, 55);
    final cases = {
      // A missing count is one.
      'now+d': DateTime.utc(2026, 10, 14, 20, 48, 55),
      'now-w': DateTime.utc(2026, 10, 6, 20, 48, 55),
      'now/Q': DateTime.utc(2026, 10),
      'now+1Q': DateTime.utc(2027, 1, 13, 20, 48, 55),
      'now-1Q/Q': DateTime.utc(2026, 7),
      // Vikunja sets no fiscal year start, so fy and fQ are y and Q.
      'now/fy': DateTime.utc(2026),
      'now+1fy': DateTime.utc(2027, 10, 13, 20, 48, 55),
      'now/fQ': DateTime.utc(2026, 10),
      'now-2fQ': DateTime.utc(2026, 4, 13, 20, 48, 55),
      'now+0b': now,
      'now+1b': DateTime.utc(2026, 10, 14, 20, 48, 55),
      'now+3b': DateTime.utc(2026, 10, 16, 20, 48, 55),
      'now+4b': DateTime.utc(2026, 10, 19, 20, 48, 55),
      'now+5b': DateTime.utc(2026, 10, 20, 20, 48, 55),
      'now-1b': DateTime.utc(2026, 10, 12, 20, 48, 55),
      'now-2b': DateTime.utc(2026, 10, 9, 20, 48, 55),
      'now+260b': DateTime.utc(2027, 10, 12, 20, 48, 55),
      // Ten digits are fine when the result stays in range.
      'now+1234567890s': now.add(const Duration(seconds: 1234567890)),
      '2026': DateTime.utc(2026),
      '2026-10': DateTime.utc(2026, 10),
      '2026-10-20': DateTime.utc(2026, 10, 20),
      // Two digits are an hour on 1970-01-01, five or more epoch millis.
      '12': DateTime.utc(1970, 1, 1, 12),
      '12:30': DateTime.utc(1970, 1, 1, 12, 30),
      '12:30:15.5': DateTime.utc(1970, 1, 1, 12, 30, 15, 500),
      '1544500000': DateTime.utc(1970, 1, 18, 21, 1, 40),
      '12345': DateTime.utc(1970, 1, 1, 0, 0, 12, 345),
      '2026-10-20T07': DateTime.utc(2026, 10, 20, 7),
      '2026-10-20T07:30:05.123': DateTime.utc(2026, 10, 20, 7, 30, 5, 123),
      '2026-10-20T07:30Z': DateTime.utc(2026, 10, 20, 7, 30),
      '2026-10-20T07:30+02:00': DateTime.utc(2026, 10, 20, 5, 30),
      '2026-10-20T07:30-05:30': DateTime.utc(2026, 10, 20, 13),
      '2028-02-29': DateTime.utc(2028, 2, 29),
      '0000-01-01': DateTime.utc(0),
      // Month and day 00 pass go-datemath and roll back.
      '2026-00-15': DateTime.utc(2025, 12, 15),
      '2026-03-00': DateTime.utc(2026, 2, 28),
      '2026-00-15T10:00': DateTime.utc(2025, 12, 15, 10),
      // Offsets are not range-checked.
      '2026-10-20T07:30+25:00': DateTime.utc(2026, 10, 19, 6, 30),
      // Numbers wrap at 64 bits instead of failing.
      '18446744073709551617': DateTime.utc(1970, 1, 1, 0, 0, 0, 1),
      'now+18446744073709551617d': DateTime.utc(2026, 10, 14, 20, 48, 55),
      '2026-10-20||': DateTime.utc(2026, 10, 20),
      '2026-10-20||+1d': DateTime.utc(2026, 10, 21),
      '2026-10-20||/M': DateTime.utc(2026, 10),
      '2026-10-20T07:30||+1h/d': DateTime.utc(2026, 10, 20),
      '1544500000||+1d': DateTime.utc(1970, 1, 19, 21, 1, 40),
    };
    for (final MapEntry(key: expression, value: expected) in cases.entries) {
      test("'$expression' is $expected", () {
        final result = evaluateDatemath(expression, now);
        expect(result, expected);
        expect(result.isUtc, isTrue);
      });
    }

    test('business days from a weekend skip to the next weekday', () {
      final saturday = DateTime.utc(2026, 10, 17, 12);

      expect(
        evaluateDatemath('now+1b', saturday),
        DateTime.utc(2026, 10, 19, 12),
      );
      expect(
        evaluateDatemath('now-1b', saturday),
        DateTime.utc(2026, 10, 16, 12),
      );
      expect(
        evaluateDatemath('now+5b', saturday),
        DateTime.utc(2026, 10, 23, 12),
      );
      expect(
        evaluateDatemath('now+6b', saturday),
        DateTime.utc(2026, 10, 26, 12),
      );
      expect(evaluateDatemath('now+0b', saturday), saturday);
    });

    test('business days far ahead match stepping day by day', () {
      for (var start = 12; start <= 18; start++) {
        final from = DateTime.utc(2026, 10, start, 9);
        for (final amount in [-23, -7, -5, 1, 4, 5, 6, 11, 17]) {
          var stepped = from;
          var left = amount.abs();
          while (left > 0) {
            stepped = stepped.add(Duration(days: amount.sign));
            if (stepped.weekday < DateTime.saturday) left--;
          }
          expect(
            evaluateDatemath('now${amount < 0 ? '' : '+'}${amount}b', from),
            stepped,
            reason: '$from $amount',
          );
        }
      }
    });
  });

  group('in a Location', () {
    late tz.Location berlin;
    late tz.Location newYork;
    setUp(() {
      berlin = tz.getLocation('Europe/Berlin');
      newYork = tz.getLocation('America/New_York');
    });

    test('rounds and places wall times in its zone, whatever now is', () {
      // 22:48:55 CEST on Tuesday, given as a UTC instant.
      final now = DateTime.utc(2026, 10, 13, 20, 48, 55);
      DateTime at(String expression) =>
          evaluateDatemath(expression, now, location: berlin).toUtc();

      expect(at('now'), now);
      expect(at('now/d'), DateTime.utc(2026, 10, 12, 22));
      expect(at('now/d+1d'), DateTime.utc(2026, 10, 13, 22));
      expect(at('now/w'), DateTime.utc(2026, 10, 11, 22));
      expect(at('now/M'), DateTime.utc(2026, 9, 30, 22));
      expect(at('now/y'), DateTime.utc(2025, 12, 31, 23));
      expect(at('2026-10-20'), DateTime.utc(2026, 10, 19, 22));
      expect(at('2026-10-20T07:30'), DateTime.utc(2026, 10, 20, 5, 30));
      expect(at('2026-10-20T07:30Z'), DateTime.utc(2026, 10, 20, 7, 30));
      expect(at('12'), DateTime.utc(1970, 1, 1, 11));
      expect(at('1544500000'), DateTime.utc(1970, 1, 18, 21, 1, 40));
    });

    test('answers a TZDateTime in the location', () {
      final result = evaluateDatemath(
        'now/d',
        DateTime.utc(2026, 10, 13, 20),
        location: berlin,
      );

      expect(result, isA<tz.TZDateTime>());
      expect((result as tz.TZDateTime).location, berlin);
      expect(result.hour, 0);
    });

    test('days keep the wall clock across DST, hours add real time', () {
      final now = DateTime.utc(2026, 3, 28, 11);
      final start = evaluateDatemath('now/d+1d', now, location: berlin);
      final end = evaluateDatemath('now/d+2d', now, location: berlin);

      expect(
        evaluateDatemath('now+1d', now, location: berlin).difference(now),
        const Duration(hours: 23),
      );
      expect(end.difference(start), const Duration(hours: 23));
      expect(
        evaluateDatemath('now+24h', now, location: berlin).difference(now),
        const Duration(hours: 24),
      );
      expect(
        evaluateDatemath(
          'now/w+1w',
          now.add(const Duration(days: 1)),
          location: berlin,
        ).difference(
          evaluateDatemath(
            'now/w',
            now.add(const Duration(days: 1)),
            location: berlin,
          ),
        ),
        const Duration(hours: 167),
      );
    });

    // Go's time.Date: a time in the spring gap moves on by the gap's length
    // for zones east of UTC, back for zones west of it; the repeated autumn
    // hour reads as the second one in Berlin and the first in New York.
    test('times in DST gaps and repeats resolve like Go', () {
      final now = DateTime.utc(2026);

      expect(
        evaluateDatemath('2026-03-29T02:30', now, location: berlin).toUtc(),
        DateTime.utc(2026, 3, 29, 1, 30),
      );
      expect(
        evaluateDatemath('2026-10-25T02:30', now, location: berlin).toUtc(),
        DateTime.utc(2026, 10, 25, 1, 30),
      );
      expect(
        evaluateDatemath('2026-03-08T02:30', now, location: newYork).toUtc(),
        DateTime.utc(2026, 3, 8, 6, 30),
      );
      expect(
        evaluateDatemath('2026-11-01T01:30', now, location: newYork).toUtc(),
        DateTime.utc(2026, 11, 1, 5, 30),
      );
    });

    test("rounding to the hour cuts the instant like Go's Truncate", () {
      // 02:18:55 in Kolkata (UTC+5:30): the hour starts at 01:30 there.
      final now = DateTime.utc(2026, 10, 13, 20, 48, 55);
      final kolkata = tz.getLocation('Asia/Kolkata');

      expect(
        evaluateDatemath('now/h', now, location: kolkata).toUtc(),
        DateTime.utc(2026, 10, 13, 20),
      );
      expect(
        evaluateDatemath('now/m', now, location: kolkata).toUtc(),
        DateTime.utc(2026, 10, 13, 20, 48),
      );
      expect(
        evaluateDatemath('now/d', now, location: kolkata).toUtc(),
        DateTime.utc(2026, 10, 13, 18, 30),
      );
    });

    test('a TZDateTime now without a location rounds in its own zone', () {
      final now = tz.TZDateTime(berlin, 2026, 10, 13, 22, 48);

      expect(
        evaluateDatemath('now/d', now).toUtc(),
        DateTime.utc(2026, 10, 12, 22),
      );
    });

    test('date range presets resolve in it', () {
      final range = DateRangePreset.today.resolve(
        DateTime.utc(2026, 10, 13, 22, 30),
        location: berlin,
      );

      expect(range.from.toUtc(), DateTime.utc(2026, 10, 13, 22));
      expect(range.to.toUtc(), DateTime.utc(2026, 10, 14, 22));
    });
  });

  group('anything else is a FormatException', () {
    for (final expression in [
      '',
      'Now',
      'NOW/d',
      'today',
      'now/',
      'now+',
      'now++1d',
      'now+-1d',
      'now1d',
      'now+1.5d',
      'now+1x',
      'now/x',
      'now/F',
      'now+1f',
      'now/d+1',
      'now /d',
      'now/dd',
      'now||+1d',
      '2026-10-13+1d',
      '2026-10-13|+1d',
      '2026-10-13 ||+1d',
      '2026-1-13',
      '2026-10-1',
      '2026-13-01',
      '2026-02-29',
      '2026-10-13T24:00',
      '2026-10-13T10:60',
      '2026-10-13T10:00:00.1234',
      '2026-10-13T10:00:00+0200',
      '2026-10-13T10:00:00+02',
      '2026-10-13t10:00',
      '2026-10-13T10:00z',
      '10:00Z',
      '1',
      '123',
      '+12345',
      '-12345',
      '1544500000.5',
      // go-datemath panics rounding to business days.
      'now/b',
      '2026-13-00',
      '2026-02-30',
      // DateTime ends at ±100 000 000 days.
      'now+9999999999999999999d',
      'now+999999999y',
      'now-999999999d',
      '9999999999999999',
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
