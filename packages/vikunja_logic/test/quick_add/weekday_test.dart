import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'parse_helpers.dart';

void main() {
  const days = {
    'monday': 1,
    'Monday': 1,
    'mon': 1,
    'Mon': 1,
    'tuesday': 2,
    'Tuesday': 2,
    'tue': 2,
    'Tue': 2,
    'wednesday': 3,
    'Wednesday': 3,
    'wed': 3,
    'Wed': 3,
    'thursday': 4,
    'Thursday': 4,
    'thu': 4,
    'Thu': 4,
    'friday': 5,
    'Friday': 5,
    'fri': 5,
    'Fri': 5,
    'saturday': 6,
    'Saturday': 6,
    'sat': 6,
    'Sat': 6,
    'sunday': 7,
    'Sunday': 7,
    'sun': 7,
    'Sun': 7,
  };

  // One moment on each weekday, Monday 2026-09-14 to Sunday 2026-09-20, at
  // times with different default times.
  final nows = [
    DateTime(2026, 9, 14, 8, 1, 2, 3),
    DateTime(2026, 9, 15, 10, 15),
    DateTime(2026, 9, 16, 12),
    DateTime(2026, 9, 17, 13, 30, 45),
    DateTime(2026, 9, 18, 17, 59),
    DateTime(2026, 9, 19, 20, 0, 1),
    DateTime(2026, 9, 20, 23, 30),
  ];

  // The web's distance: today when the day is today. QA-12: `next` on
  // the day itself is a week ahead (the web changes nothing); `this` goes
  // with the weekday, as in the web's open fix. QA-7: at the default
  // time, not the clock time of now.
  DateTime expectedFor(DateTime now, int weekday, {required bool next}) {
    final days = (weekday - now.weekday) % 7;
    return atDefaultTime(
      DateTime(now.year, now.month, now.day + (next && days == 0 ? 7 : days)),
      now: now,
    );
  }

  for (final prefix in ['next ', 'this ', '']) {
    group('$prefix<weekday>', () {
      for (final MapEntry(key: name, value: weekday) in days.entries) {
        test('$prefix$name at the end', () {
          for (final now in nows) {
            final result = parse('Lorem Ipsum $prefix$name', now: now);
            expect(result.text, 'Lorem Ipsum', reason: '$now');
            expect(
              result.date,
              expectedFor(now, weekday, next: prefix == 'next '),
              reason: '$now',
            );
            expect(result.datePhrases, ['$prefix$name'], reason: '$now');
          }
        });

        test('$prefix$name at the start', () {
          for (final now in nows) {
            final result = parse('$prefix$name Lorem Ipsum', now: now);
            expect(result.text, 'Lorem Ipsum', reason: '$now');
            expect(
              result.date,
              expectedFor(now, weekday, next: prefix == 'next '),
              reason: '$now',
            );
          }
        });
      }
    });
  }

  group('only standalone weekdays', () {
    for (final name in days.keys) {
      test('not $name with a space before it but none after it', () {
        final text = 'Lorem Ipsum ${name}ipsum';
        expect(parse(text), ParsedTaskText(text: text));
      });

      test('not $name with a space after it but none before it', () {
        final text = 'Lorem ipsum$name dolor';
        expect(parse(text), ParsedTaskText(text: text));
      });

      test('not $name without a space before or after it', () {
        final text = 'Lorem Ipsum lorem${name}ipsum';
        expect(parse(text), ParsedTaskText(text: text));
      });
    }
  });

  test('the web vector: thu at 14:00', () {
    final result = parse('Lorem Ipsum thu at 14:00');
    expect(result.text, 'Lorem Ipsum');
    expect(result.date, DateTime(2021, 6, 24, 14));
  });

  group('QA-7: the default time, not the clock time of now', () {
    test('a weekday', () {
      final result = parse(
        'x fri',
        now: DateTime(2021, 6, 24, 12, 34, 56, 789),
      );
      // The web says 2021-06-25 12:34:56.789.
      expect(result.date, DateTime(2021, 6, 25, 15));
    });

    test('the day itself after 21:00 is today at 23:59, as 09:00 has '
        'passed (QA-8)', () {
      expect(
        parse('x thu', now: DateTime(2021, 6, 24, 22)).date,
        DateTime(2021, 6, 24, 23, 59),
      );
    });

    test('an explicit time still wins', () {
      expect(
        parse('x next mon at 3pm', now: DateTime(2021, 6, 24, 12, 34)).date,
        DateTime(2021, 6, 28, 15),
      );
    });

    test("the user's default due time wins over the breakpoint", () {
      expect(
        parse(
          'x fri',
          now: DateTime(2021, 6, 24, 12, 34, 56),
          defaultTime: const ClockTime(17, 45),
        ).date,
        DateTime(2021, 6, 25, 17, 45),
      );
    });
  });

  test('the first weekday counts; every occurrence of it is removed', () {
    final first = parse('x mon tue');
    expect(first.text, 'x  tue');
    expect(ymd(first.date), '2021-6-28');
    expect(parse('x fri y fri').text, 'x  y');
  });

  test('next needs exactly one space', () {
    final result = parse('x next  fri');
    expect(result.text, 'x next');
    expect(ymd(result.date), '2021-6-25');
  });

  test('a weekday needs a space or the end after it, as on the web', () {
    expect(parse('x Fri.').date, isNull);
    expect(parse('x mon,').date, isNull);
  });

  test('QA-6: removing a weekday leaves longer words alone', () {
    // The web gives "Lorem  sbee" and "floor day".
    expect(parse('Lorem fri frisbee').text, 'Lorem  frisbee');
    expect(parse('mon floor monday').text, 'floor monday');
  });
}
