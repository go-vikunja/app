import 'package:flutter_test/flutter_test.dart';

import 'parse_helpers.dart';

void main() {
  group('date from text (the web table, now 2021-06-24)', () {
    // A clock time with a default time of its own (15:00) shows which rule
    // gave the time: absolute and day-and-month dates are at 00:00,
    // ordinal days at the default time (D38-5; the web keeps 12:34).
    final now = DateTime(2021, 6, 24, 12, 34);
    final cases = <String, DateTime?>{
      '06/08/2021': DateTime(2021, 6, 8),
      '6/7/21': DateTime(2021, 6, 7),
      '27/07/2021,': null,
      '2021/07/06': DateTime(2021, 7, 6),
      '2021-07-06': DateTime(2021, 7, 6),
      '27 jan': DateTime(2022, 1, 27),
      '27/1': DateTime(2022, 1, 27),
      '27/01': DateTime(2022, 1, 27),
      '16/12': DateTime(2021, 12, 16),
      '01/27': DateTime(2022, 1, 27),
      '1/27': DateTime(2022, 1, 27),
      'jan 27': DateTime(2022, 1, 27),
      'Jan 27': DateTime(2022, 1, 27),
      'january 27': DateTime(2022, 1, 27),
      'January 27': DateTime(2022, 1, 27),
      'feb 21': DateTime(2022, 2, 21),
      'Feb 21': DateTime(2022, 2, 21),
      'february 21': DateTime(2022, 2, 21),
      'February 21': DateTime(2022, 2, 21),
      'mar 21': DateTime(2022, 3, 21),
      'Mar 21': DateTime(2022, 3, 21),
      'march 21': DateTime(2022, 3, 21),
      'March 21': DateTime(2022, 3, 21),
      'apr 21': DateTime(2022, 4, 21),
      'Apr 21': DateTime(2022, 4, 21),
      'april 21': DateTime(2022, 4, 21),
      'April 21': DateTime(2022, 4, 21),
      'may 21': DateTime(2022, 5, 21),
      'May 21': DateTime(2022, 5, 21),
      'jun 21': DateTime(2022, 6, 21),
      'Jun 21': DateTime(2022, 6, 21),
      'june 21': DateTime(2022, 6, 21),
      'June 21': DateTime(2022, 6, 21),
      // Ordinals: D38-5, and a past date stays past (web parity).
      '21st June': DateTime(2021, 6, 21, 15),
      '2nd March': DateTime(2021, 3, 2, 15),
      '2nd march': DateTime(2021, 3, 2, 15),
      '3rd April': DateTime(2021, 4, 3, 15),
      '1st January': DateTime(2021, 1, 1, 15),
      '22nd December': DateTime(2021, 12, 22, 15),
      '23rd October': DateTime(2021, 10, 23, 15),
      '4th July': DateTime(2021, 7, 4, 15),
      '15th August': DateTime(2021, 8, 15, 15),
      '31st December': DateTime(2021, 12, 31, 15),
      '5th Mar': DateTime(2021, 3, 5, 15),
      '12th Sep': DateTime(2021, 9, 12, 15),
      'jul 21': DateTime(2021, 7, 21),
      'Jul 21': DateTime(2021, 7, 21),
      'july 21': DateTime(2021, 7, 21),
      'July 21': DateTime(2021, 7, 21),
      'aug 21': DateTime(2021, 8, 21),
      'Aug 21': DateTime(2021, 8, 21),
      'august 21': DateTime(2021, 8, 21),
      'August 21': DateTime(2021, 8, 21),
      'sep 21': DateTime(2021, 9, 21),
      'Sep 21': DateTime(2021, 9, 21),
      'september 21': DateTime(2021, 9, 21),
      'September 21': DateTime(2021, 9, 21),
      'oct 21': DateTime(2021, 10, 21),
      'Oct 21': DateTime(2021, 10, 21),
      'october 21': DateTime(2021, 10, 21),
      'October 21': DateTime(2021, 10, 21),
      'nov 21': DateTime(2021, 11, 21),
      'Nov 21': DateTime(2021, 11, 21),
      'november 21': DateTime(2021, 11, 21),
      'November 21': DateTime(2021, 11, 21),
      'dec 21': DateTime(2021, 12, 21),
      'Dec 21': DateTime(2021, 12, 21),
      'december 21': DateTime(2021, 12, 21),
      '01.02.2021': DateTime(2021, 2),
      '01.02': DateTime(2022, 2),
      '01.10': DateTime(2021, 10),
      '01.02.25': DateTime(2025, 2),
    };

    for (final MapEntry(key: phrase, value: expected) in cases.entries) {
      test('$phrase at the end', () {
        final result = parse('Lorem Ipsum $phrase', now: now);
        expect(result.date, expected);
        if (expected != null) expect(result.text, 'Lorem Ipsum');
      });

      test('$phrase at the beginning', () {
        final result = parse('$phrase Lorem Ipsum', now: now);
        expect(result.date, expected);
        if (expected != null) expect(result.text, 'Lorem Ipsum');
      });
    }
  });

  group('dates at text boundaries (the web table, now 2021-06-24)', () {
    final cases = {
      '9/11 meeting': ('2021-9-11', 'meeting'),
      'meeting 9/11': ('2021-9-11', 'meeting'),
      'meeting 9/11 at 10:00': ('2021-9-11', 'meeting'),
      'meeting 9/11 @ 15:00': ('2021-9-11', 'meeting'),
      '2021-06-24 Lorem Ipsum': ('2021-6-24', 'Lorem Ipsum'),
      'Lorem Ipsum 06/26/2021': ('2021-6-26', 'Lorem Ipsum'),
      '01.02 Lorem Ipsum': ('2022-2-1', 'Lorem Ipsum'),
      'Lorem Ipsum 01.02': ('2022-2-1', 'Lorem Ipsum'),
      'The 9/11 Report due 10/12': ('2021-10-12', 'The 9/11 Report due'),
    };
    for (final MapEntry(key: input, value: (date, text)) in cases.entries) {
      test(input, () {
        final result = parse(input);
        expect(result.text, text);
        expect(ymd(result.date), date);
      });
    }

    test('a date in the middle needs at or @ after it, in any case', () {
      expect(parse('x 9/11 AT 10:00 y').date, DateTime(2021, 9, 11, 10));
      expect(parse('x 1.2 @ 9 y').date, DateTime(2022, 2, 1, 9));
      expect(parse('x 9/11 at y').date, DateTime(2021, 9, 11));
      expect(parse('x 9/11 atx y').date, isNull);
      expect(parse('x 9/11  y').date, isNull);
      expect(parse('x 10/12 y').date, isNull);
    });

    test('one space before counts as the start, one after as the end', () {
      expect(parse(' 9/11 x').date, DateTime(2021, 9, 11));
      expect(parse('  9/11 x').date, isNull);
      expect(parse('x 9/11 ').date, DateTime(2021, 9, 11));
    });

    test('the first date at a boundary wins', () {
      final result = parse('9/11 x 10/12');
      expect(result.text, 'x 10/12');
      expect(result.date, DateTime(2021, 9, 11));
    });

    test('the first accepted M/D wins even when it is impossible', () {
      expect(parse('13/13 x 1/27').date, isNull);
    });

    test('an impossible date falls back to the next format', () {
      expect(parse('13/13 x 01.02').date, DateTime(2022, 2));
      expect(parse('13/13 x jan 27').date, DateTime(2022, 1, 27));
    });

    test('formats are tried in order: M/D, Y/M/D, Y-M-D, D.M', () {
      expect(parse('1/2 x 2021-06-30').date, DateTime(2022, 1, 2));
      expect(parse('x 2021-06-24 2021/06/25').date, DateTime(2021, 6, 25));
      expect(parse('x 1/2/2021 3.4.2021').date, DateTime(2021, 4, 3));
    });

    test('every occurrence of the date is removed', () {
      expect(parse('x 9/11 y 9/11').text, 'x  y');
    });
  });

  group('what JS Date makes of the numbers', () {
    final cases = <String, DateTime?>{
      // Days up to 31 overflow into the next month.
      'x 02/30/2021': DateTime(2021, 3, 2),
      'x 02/31/2021': DateTime(2021, 3, 3),
      'x 02/32/2021': null,
      'x 1/0/2021': null,
      'x 0/0': null,
      'x 00/12': null,
      'x 12/00': null,
      // An impossible month swaps day and month.
      'x 13/12/2021': DateTime(2021, 12, 13),
      'x 2021/13/12': DateTime(2021, 12, 13),
      'x 1.13': DateTime(2022, 1, 13),
      'x 13.1': DateTime(2022, 1, 13),
      'x 13/13': null,
      // Two-digit years: 0-49 are 20xx, 50-99 19xx; so are 4-digit ones.
      'x 6/7/49': DateTime(2049, 6, 7),
      'x 6/7/50': DateTime(1950, 6, 7),
      'x 6/7/99': DateTime(1999, 6, 7),
      'x 01.02.50': DateTime(1950, 2),
      'x 12/12/12': DateTime(2012, 12, 12),
      'x 1/1/0049': DateTime(2049),
      'x 0049-01-01': DateTime(2049),
      'x 202-07-06': DateTime(202, 7, 6),
      // Years have 2 or 4 digits, Y/M/D days 2.
      'x 1/1/1': null,
      'x 1/1/123': null,
      'x 1/1/12345': null,
      'x 1.1.1': null,
      'x 2021-7-06': DateTime(2021, 7, 6),
      'x 2021-07-6': null,
      'x 2021/7/06': DateTime(2021, 7, 6),
      'x 2021/07/6': null,
      'x 21-07-06': null,
      'x 20210-07-06': null,
      // Day-and-month names overflow too.
      'x feb 31': DateTime(2022, 3, 3),
      'x 31 feb': DateTime(2022, 3, 3),
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test(input, () {
        final result = parse(input);
        expect(result.date, expected);
        expect(result.text, expected == null ? input : 'x');
      });
    }

    test('a leap day without a year rolls on from the overflowed date', () {
      final now = DateTime(2023, 6, 1, 10);
      expect(parse('x 2/29', now: now).date, DateTime(2024, 3));
      expect(parse('x feb 29', now: now).date, DateTime(2024, 3));
      expect(parse('x 29.2', now: now).date, DateTime(2024, 3));
    });
  });

  group('without a year the next such date', () {
    test('a later date is this year', () {
      expect(parse('x 06/25').date, DateTime(2021, 6, 25));
      expect(parse('x jun 25').date, DateTime(2021, 6, 25));
    });

    test('web parity: today at midnight is already past, so next year', () {
      expect(parse('x 06/24').date, DateTime(2022, 6, 24));
      expect(parse('x jun 24 at 13:00').date, DateTime(2022, 6, 24, 13));
      expect(parse('x 24.6').date, DateTime(2022, 6, 24));
    });

    test('a given year never rolls', () {
      expect(parse('x 6/24/2021').date, DateTime(2021, 6, 24));
      expect(parse('x 1/1/2020').date, DateTime(2020));
    });
  });

  group('ordinal days', () {
    test('a day still ahead is this month', () {
      final tomorrow = DateTime(2022, 1, 16);
      final result = parse('Lorem Ipsum 16th', now: DateTime(2022, 1, 15, 10));
      expect(result.text, 'Lorem Ipsum');
      expect(result.date, DateTime(2022, 1, 16, 12));
      expect(result.date!.day, tomorrow.day);
    });

    test('today is today, whatever the clock says', () {
      expect(
        parse('x 24th', now: DateTime(2021, 6, 24, 20, 59)).date,
        DateTime(2021, 6, 24, 21),
      );
      expect(
        parse('x 24th at 11:00', now: DateTime(2021, 6, 24, 12)).date,
        DateTime(2021, 6, 24, 11),
      );
    });

    test('a day already past is next month (the web vector)', () {
      final result = parse('Lorem Ipsum 14th', now: DateTime(2022, 1, 15));
      expect(result.text, 'Lorem Ipsum');
      expect(ymd(result.date), '2022-2-14');
    });

    test('a past day with February next (the web vector)', () {
      final result = parse('Lorem Ipsum 29th', now: DateTime(2022, 1, 30));
      expect(result.text, 'Lorem Ipsum');
      expect(ymd(result.date), '2022-3-29');
    });

    test('a day the next month lacks (the web vector)', () {
      final result = parse('Lorem Ipsum 31st', now: DateTime(2022, 4));
      expect(result.text, 'Lorem Ipsum');
      expect(ymd(result.date), '2022-5-31');
    });

    test('roll-over cases', () {
      final cases = <(DateTime, String), String>{
        (DateTime(2022, 1, 31), '30th'): '2022-3-30',
        (DateTime(2022, 1, 31), '31st'): '2022-1-31',
        (DateTime(2022, 1, 31), '31st feb'): '2022-3-3',
        (DateTime(2022, 1, 31), '30th apr'): '2022-4-30',
        (DateTime(2021, 2, 28), '30th'): '2021-3-30',
        (DateTime(2021, 2, 28), '15th'): '2021-3-15',
        (DateTime(2021, 2, 28), '15th jan'): '2021-1-15',
        (DateTime(2021, 3, 31), '30th'): '2021-4-30',
        (DateTime(2021, 3, 31), '31st feb'): '2021-3-3',
        (DateTime(2021, 12, 31), '30th'): '2022-1-30',
        (DateTime(2021, 12, 31), '15th jan'): '2022-1-15',
        (DateTime(2021, 12, 31), '31st feb'): '2021-3-3',
        (DateTime(2021, 2, 15), '31st'): '2021-3-31',
        (DateTime(2021, 6, 24), '30th feb'): '2021-3-2',
      };
      for (final MapEntry(key: (now, phrase), value: expected)
          in cases.entries) {
        expect(
          ymd(parse('x $phrase', now: now).date),
          expected,
          reason: '$phrase at $now',
        );
      }
    });

    test('suffixes and forms', () {
      for (final phrase in ['5th', '05th', '5.', '05.', '5TH', '5St']) {
        expect(ymd(parse('x $phrase').date), '2021-7-5', reason: phrase);
      }
    });

    test('needs the end, at, @ or a month after it', () {
      expect(parse('x 3rd y').date, isNull);
      expect(parse('x 3rd at').date, isNull);
      expect(parse('x 3. ').date, isNull);
      expect(parse('x 3rd. jan').date, isNull);
      expect(parse('x 32nd').date, isNull);
      expect(parse('x 00th').date, isNull);
      expect(parse('x 3rd @ 9').date, DateTime(2021, 7, 3, 9));
      expect(parse('x 1. sep').date, DateTime(2021, 9, 1, 12));
    });

    test('the month may stand anywhere and goes with the first one', () {
      final anywhere = parse('x 3rd at 10:00 jan');
      expect(anywhere.text, 'x');
      expect(anywhere.date, DateTime(2021, 1, 3, 10));
      expect(anywhere.datePhrases, ['3rd', 'jan', 'at 10:00']);
      final first = parse('x 3rd jan feb');
      expect(first.text, 'x   feb');
      expect(first.date, DateTime(2021, 1, 3, 12));
    });

    test('every occurrence of the month word is removed', () {
      expect(parse('x 3rd May and MAY').text, 'x   and');
    });

    test('D38-9: the month word only where it is a whole word', () {
      // The web gives "x   or" and "Rek".
      expect(parse('x 3rd may mayor').text, 'x   mayor');
      expect(parse('5th mar Remark').text, 'Remark');
    });

    test('web parity: a month anywhere in the text joins the day', () {
      final result = parse('I may do it 3rd');
      expect(result.text, 'I  do it');
      expect(result.date, DateTime(2021, 5, 3, 12));
    });

    test('the web vectors: replace in title case and lower case', () {
      // D38-5: noon is its own default time, so the web's 12:00 holds.
      for (final text in ['Some task Mar 8th', 'Some task mar 8th']) {
        final result = parse(text, now: DateTime(2021, 6, 24, 12));
        expect(result.date, DateTime(2021, 3, 8, 12));
        expect(result.text, 'Some task');
      }
    });

    test('D38-5: the default time, not the clock time of now', () {
      // The web says 2021-07-03 12:34:56.
      expect(
        parse('x 3rd', now: DateTime(2021, 6, 24, 12, 34, 56)).date,
        DateTime(2021, 7, 3, 15),
      );
    });

    test('D38-5: a past ordinal and month stays past (web parity)', () {
      expect(
        parse('Something sep 17th', now: DateTime(2026, 10, 8, 10)).date,
        DateTime(2026, 9, 17, 12),
      );
    });

    test('web parity: a day a month lacks overflows', () {
      expect(
        parse('x 29th feb', now: DateTime(2026, 1, 10, 10)).date,
        DateTime(2026, 3, 1, 12),
      );
    });

    test('D19-4: a month word must be whole', () {
      expect(parse('x 3rd sept').date, isNull);
      expect(parse('x 17th september').date, DateTime(2021, 9, 17, 12));
    });
  });

  group('in N units (the web table, now 2021-06-24 12:00)', () {
    final now = DateTime(2021, 6, 24, 12);
    final cases = {
      'Lorem Ipsum in 1 hour': DateTime(2021, 6, 24, 13),
      'in 2 hours': DateTime(2021, 6, 24, 14),
      'in 1 day': DateTime(2021, 6, 25, 12),
      'in 2 days': DateTime(2021, 6, 26, 12),
      'in 1 week': DateTime(2021, 7, 1, 12),
      'in 2 weeks': DateTime(2021, 7, 8, 12),
      'in 4 weeks': DateTime(2021, 7, 22, 12),
      'in 1 month': DateTime(2021, 7, 24, 12),
      'in 3 months': DateTime(2021, 9, 24, 12),
      'Something in 5 days at 10:00': DateTime(2021, 6, 29, 10),
      'Something 17th at 10:00': DateTime(2021, 7, 17, 10),
      'Something sep 17 at 10:00': DateTime(2021, 9, 17, 10),
      'Something sep 17th at 10:00': DateTime(2021, 9, 17, 10),
      'Something at 10:00 in 5 days': DateTime(2021, 6, 29, 10),
      'Something at 10:00 17th': DateTime(2021, 7, 17, 10),
      'Something at 10:00 sep 17th': DateTime(2021, 9, 17, 10),
      '2nd March at 5': DateTime(2021, 3, 2, 5),
      '2nd March at 5pm': DateTime(2021, 3, 2, 17),
      '2nd March @ 14:00': DateTime(2021, 3, 2, 14),
      '3rd April at 10:30': DateTime(2021, 4, 3, 10, 30),
      '15th August @ 9am': DateTime(2021, 8, 15, 9),
      '21st June at 18:45': DateTime(2021, 6, 21, 18, 45),
      '5th Mar at 3pm': DateTime(2021, 3, 5, 15),
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test(input, () {
        final result = parse(input, now: now);
        expect(result.date, expected);
        expect(result.text, switch (input.split(' ').first) {
          'Lorem' => 'Lorem Ipsum',
          'Something' => 'Something',
          _ => '',
        });
      });
    }
  });

  group('in N units', () {
    final now = DateTime(2021, 6, 24, 12, 34, 56, 789);

    test('adds to now, seconds included (D38-5 keeps this)', () {
      expect(
        parse('x in 3 days', now: now).date,
        DateTime(2021, 6, 27, 12, 34, 56, 789),
      );
      expect(
        parse('x in 1 hours', now: now).date,
        DateTime(2021, 6, 24, 13, 34, 56, 789),
      );
      expect(parse('x in 0 days', now: now).date, now);
    });

    test('a month from the 31st overflows like JS', () {
      expect(
        parse('x in 1 month', now: DateTime(2021, 1, 31, 9)).date,
        DateTime(2021, 3, 3, 9),
      );
    });

    test('hours carry into the next day', () {
      expect(
        parse('x in 12 hours', now: DateTime(2021, 6, 24, 20)).date,
        DateTime(2021, 6, 25, 8),
      );
    });

    test('an explicit time sets the time of that day', () {
      expect(
        parse('x in 2 hours at 9', now: now).date,
        DateTime(2021, 6, 24, 9),
      );
      expect(
        parse('x in 2 weeks at 3pm', now: now).date,
        DateTime(2021, 7, 8, 15),
      );
    });

    test('the unit in any case (the web since 2.8.0)', () {
      expect(
        parse('x IN 2 Days', now: now).date,
        DateTime(2021, 6, 26, 12, 34, 56, 789),
      );
      expect(
        parse('x in 1 Month', now: now).date,
        DateTime(2021, 7, 24, 12, 34, 56, 789),
      );
    });

    test('in the middle', () {
      final result = parse('x in 3 days y', now: now);
      expect(result.text, 'x  y');
      expect(result.datePhrases, ['in 3 days']);
    });

    test('D38-9: an amount above 100000 is text', () {
      expect(parse('x in 100001 hours', now: now).date, isNull);
      expect(
        parse('x in 100000 weeks', now: now).date,
        DateTime(2021, 6, 24 + 700000, 12, 34, 56, 789),
      );
      expect(parse('x in 100001 minutes', now: now).date, isNull);
      expect(parse('x in 100001 years', now: now).date, isNull);
    });

    test('a date up to the year 9999', () {
      expect(
        parse('x in 7000 years', now: now).date,
        DateTime(9021, 6, 24, 12, 34, 56, 789),
      );
      expect(
        parse('x in 7978 years', now: now).date,
        DateTime(9999, 6, 24, 12, 34, 56, 789),
      );
      expect(
        parse('x in 95742 months', now: now).date,
        DateTime(9999, 12, 24, 12, 34, 56, 789),
      );
    });

    test('D38-9: punctuation may follow the unit (the web wants a space)', () {
      final comma = parse('Pay rent in 2 days, then call', now: now);
      expect(comma.date, DateTime(2021, 6, 26, 12, 34, 56, 789));
      expect(comma.text, 'Pay rent , then call');
      final stop = parse('Call back in 4 Hours.', now: now);
      expect(stop.date, DateTime(2021, 6, 24, 16, 34, 56, 789));
      expect(stop.text, 'Call back .');
      for (final text in ['x in 1 week; y', 'x in 1 week!', 'x in 1 week)']) {
        expect(
          parse(text, now: now).date,
          DateTime(2021, 7, 1, 12, 34, 56, 789),
          reason: text,
        );
      }
    });
  });

  group('in N units, the forms of 2.8.0 (now Tue 2026-03-10 08:15:30)', () {
    final now = DateTime(2026, 3, 10, 8, 15, 30);
    final cases = {
      'Water plants in three days': DateTime(2026, 3, 13, 8, 15, 30),
      'Plan trip in one month': DateTime(2026, 4, 10, 8, 15, 30),
      'Renew passport in Eleven Months': DateTime(2027, 2, 10, 8, 15, 30),
      'Repaint fence in twelve weeks': DateTime(2026, 6, 2, 8, 15, 30),
      'Nap in five Hours': DateTime(2026, 3, 10, 13, 15, 30),
      'Stretch in a minute': DateTime(2026, 3, 10, 8, 16, 30),
      'Fetch parcel IN AN HOUR': DateTime(2026, 3, 10, 9, 15, 30),
      'Defrost in A Day': DateTime(2026, 3, 11, 8, 15, 30),
      'Rotate tyres in a month': DateTime(2026, 4, 10, 8, 15, 30),
      'Order filters in 45 minutes': DateTime(2026, 3, 10, 9, 0, 30),
      'Call in seven Minutes': DateTime(2026, 3, 10, 8, 22, 30),
      'Check warranty in 2 years': DateTime(2028, 3, 10, 8, 15, 30),
      'Book dentist in a year': DateTime(2027, 3, 10, 8, 15, 30),
      'Taxes in ten Years': DateTime(2036, 3, 10, 8, 15, 30),
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test(input, () {
        final result = parse(input, now: now);
        final at = input.toLowerCase().indexOf(' in ');
        expect(result.date, expected);
        expect(result.text, input.substring(0, at));
        expect(result.datePhrases, [input.substring(at + 1)]);
      });
    }

    test('at the start and in the middle', () {
      final start = parse('in two weeks water plants', now: now);
      expect(start.text, 'water plants');
      expect(start.date, DateTime(2026, 3, 24, 8, 15, 30));
      final middle = parse('x in Two Weeks y', now: now);
      expect(middle.text, 'x  y');
      expect(middle.datePhrases, ['in Two Weeks']);
    });

    test('an explicit time sets the time of that day', () {
      expect(
        parse('Dentist in two days at 16:30', now: now).date,
        DateTime(2026, 3, 12, 16, 30),
      );
      expect(
        parse('Dentist at 9am in a year', now: now).date,
        DateTime(2027, 3, 10, 9),
      );
      expect(
        parse('x in 20 minutes at 7', now: now).date,
        DateTime(2026, 3, 10, 7),
      );
    });

    test('minutes carry into the next day', () {
      expect(
        parse('x in 90 minutes', now: DateTime(2026, 12, 31, 23)).date,
        DateTime(2027, 1, 1, 0, 30),
      );
    });

    test('a year from 29 February overflows like JS', () {
      final leapDay = DateTime(2024, 2, 29, 10);
      expect(parse('x in 1 year', now: leapDay).date, DateTime(2025, 3, 1, 10));
      expect(
        parse('x in four years', now: leapDay).date,
        DateTime(2028, 2, 29, 10),
      );
    });

    test('web parity: the article is not checked', () {
      expect(
        parse('x in an day', now: now).date,
        DateTime(2026, 3, 11, 8, 15, 30),
      );
      expect(
        parse('x in a hours', now: now).date,
        DateTime(2026, 3, 10, 9, 15, 30),
      );
    });
  });

  group('times', () {
    final now = DateTime(2021, 6, 24, 12, 34, 56);

    test('alone it is today at that time', () {
      final result = parse('x at 15:00', now: now);
      expect(result.text, 'x');
      expect(result.date, DateTime(2021, 6, 24, 15));
      expect(result.datePhrases, ['at 15:00']);
    });

    test('a past time today stays today', () {
      expect(parse('x at 9', now: now).date, DateTime(2021, 6, 24, 9));
    });

    test('overflowing hours and minutes roll on', () {
      expect(parse('x at 25:00', now: now).date, DateTime(2021, 6, 25, 1));
      expect(parse('x at 10:75', now: now).date, DateTime(2021, 6, 24, 11, 15));
      expect(parse('x at 13pm', now: now).date, DateTime(2021, 6, 25, 1));
    });

    test('am and pm', () {
      expect(parse('x at 0am', now: now).date, DateTime(2021, 6, 24));
      expect(parse('x at 12am', now: now).date, DateTime(2021, 6, 24));
      expect(parse('x at 12 pm', now: now).date, DateTime(2021, 6, 24, 12));
      expect(parse('x AT 3PM', now: now).date, DateTime(2021, 6, 24, 15));
    });

    test('found before or after the date', () {
      expect(parse('x at 12 am today', now: now).date, DateTime(2021, 6, 24));
      expect(
        parse('x tomorrow at 9 today', now: now).date,
        DateTime(2021, 6, 24, 9),
      );
    });

    test('in the middle', () {
      final result = parse('x at 3:05pm y', now: now);
      expect(result.text, 'x y');
      expect(result.date, DateTime(2021, 6, 24, 15, 5));
    });

    test('tonight with a time is that time', () {
      expect(parse('x tonight at 8', now: now).date, DateTime(2021, 6, 24, 8));
    });

    test('the first time counts; every occurrence of it is removed', () {
      expect(parse('x at 9 y at 10', now: now).text, 'x y at 10');
      expect(parse('x AT 9 y at 9', now: now).text, 'x y');
    });

    group('web parity', () {
      test('any number after at is an hour', () {
        final result = parse('x at 10 people', now: now);
        expect(result.text, 'x people');
        expect(result.date, DateTime(2021, 6, 24, 10));
      });

      test('minutes need two digits', () {
        final result = parse('x at 3:5', now: now);
        expect(result.text, 'x:5');
        expect(result.date, DateTime(2021, 6, 24, 3));
      });
    });
  });
}
