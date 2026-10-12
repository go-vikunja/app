import 'package:flutter_test/flutter_test.dart';

import 'parse_helpers.dart';

void main() {
  // The web's cases compare with the real clock; these pin them for four
  // moments. The time is the default time of `now`.
  final expectations = <DateTime, Map<String, DateTime>>{
    // Monday 08:00, default 09:00.
    DateTime(2026, 9, 14, 8): {
      'today': DateTime(2026, 9, 14, 9),
      'tonight': DateTime(2026, 9, 14, 21),
      'tomorrow': DateTime(2026, 9, 15, 9),
      // D38-6: next Monday is today on a Monday.
      'next monday': DateTime(2026, 9, 14, 9),
      'this weekend': DateTime(2026, 9, 19, 9),
      'later this week': DateTime(2026, 9, 16, 9),
      'later next week': DateTime(2026, 9, 23, 9),
      'next week': DateTime(2026, 9, 21, 9),
      'next month': DateTime(2026, 10, 1, 9),
      'end of month': DateTime(2026, 9, 30, 9),
    },
    // Thursday 12:34:56, default 15:00.
    DateTime(2021, 6, 24, 12, 34, 56): {
      'today': DateTime(2021, 6, 24, 15),
      'tonight': DateTime(2021, 6, 24, 21),
      'tomorrow': DateTime(2021, 6, 25, 15),
      'next monday': DateTime(2021, 6, 28, 15),
      'this weekend': DateTime(2021, 6, 26, 15),
      'later this week': DateTime(2021, 6, 26, 15),
      'later next week': DateTime(2021, 7, 3, 15),
      'next week': DateTime(2021, 7, 1, 15),
      'next month': DateTime(2021, 7, 1, 15),
      // Web parity: the default time of the last day's midnight.
      'end of month': DateTime(2021, 6, 30, 9),
    },
    // Saturday 18:00 on the last of the month, default 18:00.
    DateTime(2026, 10, 31, 18): {
      'today': DateTime(2026, 10, 31, 18),
      'tonight': DateTime(2026, 10, 31, 21),
      'tomorrow': DateTime(2026, 11, 1, 18),
      'next monday': DateTime(2026, 11, 2, 18),
      'this weekend': DateTime(2026, 10, 31, 18),
      'later this week': DateTime(2026, 10, 31, 18),
      'later next week': DateTime(2026, 11, 7, 18),
      'next week': DateTime(2026, 11, 7, 18),
      'next month': DateTime(2026, 11, 1, 18),
      // Web parity: the default time of the last day's midnight.
      'end of month': DateTime(2026, 10, 31, 9),
    },
    // Sunday 22:30 on the last of the year: D38-6, after 21:00 the
    // default time is 09:00 of the same day.
    DateTime(2028, 12, 31, 22, 30): {
      'today': DateTime(2028, 12, 31, 9),
      'tonight': DateTime(2028, 12, 31, 21),
      'tomorrow': DateTime(2029, 1, 1, 9),
      'next monday': DateTime(2029, 1, 1, 9),
      'this weekend': DateTime(2028, 12, 31, 9),
      'later this week': DateTime(2028, 12, 31, 9),
      'later next week': DateTime(2029, 1, 7, 9),
      'next week': DateTime(2029, 1, 7, 9),
      'next month': DateTime(2029, 1, 1, 9),
      'end of month': DateTime(2028, 12, 31, 9),
    },
  };

  test('the moments are the weekdays they claim', () {
    expect(
      [for (final now in expectations.keys) now.weekday],
      [DateTime.monday, DateTime.thursday, DateTime.saturday, DateTime.sunday],
    );
  });

  for (final MapEntry(key: now, value: dates) in expectations.entries) {
    group('at $now', () {
      for (final MapEntry(key: keyword, value: expected) in dates.entries) {
        test('$keyword at the end', () {
          final result = parse('Lorem Ipsum $keyword', now: now);
          expect(result.text, 'Lorem Ipsum');
          expect(result.date, expected);
          expect(result.datePhrases, [keyword]);
        });

        test('$keyword at the start', () {
          final result = parse('$keyword Lorem Ipsum', now: now);
          expect(result.text, 'Lorem Ipsum');
          expect(result.date, expected);
        });

        test('$keyword in the middle leaves both spaces', () {
          expect(parse('Lorem $keyword Ipsum', now: now).text, 'Lorem  Ipsum');
        });
      }
    });
  }

  group('casing is ignored', () {
    test('ToDay', () {
      final result = parse('Lorem Ipsum ToDay');
      expect(result.text, 'Lorem Ipsum');
      expect(ymd(result.date), '2021-6-24');
      expect(result.datePhrases, ['ToDay']);
    });

    test('Tomorrow', () {
      final result = parse('Lorem Ipsum Tomorrow');
      expect(result.text, 'Lorem Ipsum');
      expect(ymd(result.date), '2021-6-25');
    });

    test('nExt Monday', () {
      final result = parse('Lorem Ipsum nExt Monday');
      expect(result.text, 'Lorem Ipsum');
      expect(ymd(result.date), '2021-6-28');
    });

    test('END OF MONTH', () {
      expect(ymd(parse('x END OF MONTH').date), '2021-6-30');
    });
  });

  test('tonight has no seconds', () {
    final result = parse('x tonight', now: DateTime(2021, 6, 24, 12, 3, 4, 5));
    expect(result.date, DateTime(2021, 6, 24, 21));
  });

  test('next month from the 31st is the 1st of the next month', () {
    expect(
      parse('x next month', now: DateTime(2026, 1, 31, 10)).date,
      DateTime(2026, 2, 1, 12),
    );
  });

  test('end of month in a leap February', () {
    expect(
      parse('x end of month', now: DateTime(2028, 2, 3, 10)).date,
      DateTime(2028, 2, 29, 9),
    );
  });

  test('the rule order: later next week before next week', () {
    final result = parse('x later next week', now: DateTime(2026, 9, 14, 8));
    expect(result.date, DateTime(2026, 9, 23, 9));
    expect(result.text, 'x');
  });

  test('only the first date phrase counts', () {
    final result = parse('x today @ 9 tomorrow');
    expect(result.text, 'x  tomorrow');
    expect(result.date, DateTime(2021, 6, 24, 9));
  });

  test('every occurrence of the phrase is removed', () {
    expect(parse('x tomorrow y TOMORROW').text, 'x  y');
  });

  group('today with a time (the web table)', () {
    final cases = {
      'at 15:00': '15:0',
      '@ 15:00': '15:0',
      'at 15:30': '15:30',
      '@ 3pm': '15:0',
      'at 3pm': '15:0',
      'at 3 pm': '15:0',
      'at 3am': '3:0',
      'at 3:12 am': '3:12',
      'at 3:12 pm': '15:12',
      'at 3:12 AM': '3:12',
      'at 3:12 PM': '15:12',
      'at 3:12 Am': '3:12',
      'at 3:12 Pm': '15:12',
      'at 12:00 pm': '12:0',
      'at 12:00 am': '0:0',
    };
    for (final MapEntry(key: time, value: expected) in cases.entries) {
      test(time, () {
        final result = parse(
          'Lorem Ipsum today $time',
          now: DateTime(2021, 6, 24, 12, 34, 56, 789),
        );
        expect(result.text, 'Lorem Ipsum');
        expect(ymd(result.date), '2021-6-24');
        expect(hm(result.date), expected);
        expect(result.date!.second, 0);
        expect(result.date!.millisecond, 0);
        expect(result.datePhrases, ['today', time]);
      });
    }
  });

  group('D19-3: the keywords need a word boundary after them', () {
    for (final text in [
      'Read todays paper',
      'Collect tomorrows mail',
      'Plan next weekend trip',
      'Celebrate tonights win',
      'Fix end of months report',
      'Prepare next mondays meeting',
      'Recall this weekends plans',
      'Book next months flights',
      'Note later this weeks tasks',
      'Note later next weeks tasks',
    ]) {
      test(text, () {
        final result = parse(text);
        expect(result.text, text);
        expect(result.date, isNull);
      });
    }

    test('a keyword after the same word with a suffix', () {
      final result = parse('Read todays paper today');
      expect(result.text, 'Read todays paper');
      expect(ymd(result.date), '2021-6-24');
    });

    test('punctuation is a boundary, as on the web', () {
      final result = parse('Buy milk today, urgent');
      expect(result.text, 'Buy milk , urgent');
      expect(ymd(result.date), '2021-6-24');
      expect(parse("x today's").text, "x 's");
    });

    test('the web turned next weekend into next week and left "end"', () {
      // D19-3: the web gives 2021-7-1 and the text "Plan end trip".
      expect(parse('Plan next weekend trip').text, 'Plan next weekend trip');
    });
  });

  test('the keyword needs the start or a space before it', () {
    for (final text in ['@today', 'x-today', 'notoday', 'x/tomorrow']) {
      expect(parse('Lorem $text').date, isNull, reason: text);
    }
  });
}
