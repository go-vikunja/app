import 'package:flutter_test/flutter_test.dart';

import 'parse_helpers.dart';

void main() {
  group('datePhrases are the date parts as typed, in the order found', () {
    final cases = {
      'x Tomorrow': ['Tomorrow'],
      'x tomorrow at 9:00': ['tomorrow', 'at 9:00'],
      'x at 9:00 tomorrow': ['tomorrow', 'at 9:00'],
      'x Next Fri @ 3pm': ['Next Fri', '@ 3pm'],
      'x 17th SEP at 10:00': ['17th', 'SEP', 'at 10:00'],
      'x in 2 Weeks': ['in 2 Weeks'],
      'meeting 9/11 at 10:00': ['9/11', 'at 10:00'],
      'x Dec 12': ['Dec 12'],
      'x at 3 PM': ['at 3 PM'],
      'x': <String>[],
      'x every day': <String>[],
    };
    for (final MapEntry(key: input, value: phrases) in cases.entries) {
      test(input, () {
        expect(parse(input).datePhrases, phrases);
      });
    }
  });

  group('repeatPhrase', () {
    test('as typed', () {
      expect(parse('x Every 2 Weeks at 9').repeatPhrase, 'Every 2 Weeks');
      expect(parse('weekly x').repeatPhrase, 'weekly');
    });

    test('null without a repeat', () {
      expect(parse('x tomorrow').repeatPhrase, isNull);
    });
  });

  test('every phrase is part of the input', () {
    const input = 'Pay rent *bills +Home !2 every month 1st at 9am';
    final result = parse(input);
    for (final phrase in [...result.datePhrases, result.repeatPhrase!]) {
      expect(input, contains(phrase));
    }
    expect(result.text, 'Pay rent');
    expect(result.date, DateTime(2021, 7, 1, 9));
  });
}
