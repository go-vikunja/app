import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'parse_helpers.dart';

void main() {
  group('partial keywords in words are no dates (the web list)', () {
    for (final text in [
      'renewed',
      'github',
      'fix monitor stand',
      'order wedding cake',
      'investigate thumping noise',
      'iron frilly napkins',
      'take photo of saturn',
      'fix sunglasses',
      'monitor blood pressure',
      'Monitor blood pressure',
      'buy almonds',
      'Renovation',
      'Remark',
      'Renovation - 2nd Floor Bath',
      'Remark - 13th floor',
      '13th floor - remark',
    ]) {
      test('$text at the beginning', () {
        expect(
          parse('$text dolor sit amet'),
          ParsedTaskText(text: '$text dolor sit amet'),
        );
      });

      test('$text at the end', () {
        expect(
          parse('Lorem Ipsum $text'),
          ParsedTaskText(text: 'Lorem Ipsum $text'),
        );
      });

      test('$text in the middle', () {
        expect(
          parse('Lorem Ipsum $text dolor'),
          ParsedTaskText(text: 'Lorem Ipsum $text dolor'),
        );
      });

      test('$text alone', () {
        expect(parse(text), ParsedTaskText(text: text));
      });
    }
  });

  group('dates in the middle of the text', () {
    for (final text in [
      'The 9/11 Report',
      'The 01/02 Report',
      'a]7/8 debate',
    ]) {
      test(text, () {
        expect(parse(text), ParsedTaskText(text: text));
      });
    }

    test('a dot-separated date', () {
      expect(
        parse('The 1.2 formula'),
        const ParsedTaskText(text: 'The 1.2 formula'),
      );
    });
  });

  test('numbers without spaces around them', () {
    expect(
      parse('Lorem Ispum v1.1.1'),
      const ParsedTaskText(text: 'Lorem Ispum v1.1.1'),
    );
  });

  test('dates in urls', () {
    const text = 'https://some-url.org/blog/2019/1/233526-some-more-text';
    expect(parse(text), const ParsedTaskText(text: text));
  });

  group('D19-4: day-and-month dates need whole words', () {
    for (final text in [
      'buy 12 decorations',
      'buy 12 decorations for the party',
      'Run my 13th marathon',
      'Party 3rd juneteenth',
      'Pay the 2nd novelist',
      'Send sep 17th tasks',
      'Meet 2 mayors',
      'Clean jun 30th room',
      'Order 5 marchers',
      'Fix dec 123',
    ]) {
      test(text, () {
        expect(parse(text), ParsedTaskText(text: text));
      });
    }

    test('`12 dec` and `dec 12` still parse', () {
      final now = DateTime(2021, 6, 24, 12);
      final before = parse('buy 12 dec', now: now);
      expect(before.text, 'buy');
      expect(before.date, DateTime(2021, 12, 12));
      final after = parse('buy dec 12', now: now);
      expect(after.text, 'buy');
      expect(after.date, DateTime(2021, 12, 12));
      expect(parse('buy 12 dec, quick', now: now).text, 'buy , quick');
    });

    test('D38-9: a day no month has stays text (the web drops it)', () {
      for (final text in ['x dec 45', 'x 0 oct', 'x jan 0', '45 nov']) {
        expect(parse(text), ParsedTaskText(text: text), reason: text);
      }
    });
  });

  group('D38-9: the in rule needs whole words', () {
    test('within 2 days', () {
      // Before 2.8.0 the web gave 2021-6-26 and the text "Reply with".
      expect(
        parse('Reply within 2 days'),
        const ParsedTaskText(text: 'Reply within 2 days'),
      );
    });

    test('in 2 daysx', () {
      expect(parse('x in 2 daysx'), const ParsedTaskText(text: 'x in 2 daysx'));
    });

    test('one space between the words', () {
      expect(parse('x in  2 days').date, isNull);
      expect(parse('x in  two days').date, isNull);
      expect(parse('x in 2days').date, isNull);
      expect(parse('x in aweek').date, isNull);
    });

    test('the unit is a whole word', () {
      for (final text in [
        'Book the cabin in two weekends',
        'Buy in an hourglass',
        'x in 3 minutesx',
        'x in a yearbook',
      ]) {
        expect(parse(text), ParsedTaskText(text: text), reason: text);
      }
    });

    test('in ends a longer word', () {
      for (final text in ['Clean the cabin 3 days', 'Fix the bin a week']) {
        expect(parse(text), ParsedTaskText(text: text), reason: text);
      }
    });

    test('an apostrophe after the unit (the web wants a space)', () {
      for (final text in [
        "All in a day's work",
        "Finish in 2 days' time",
        'Done in a day’s time',
        'Ship in two weeks’',
      ]) {
        expect(parse(text), ParsedTaskText(text: text), reason: text);
      }
    });
  });

  group('amounts the in rule does not know', () {
    for (final text in [
      'x in thirteen days',
      'x in a few days',
      'x in another day',
      'x in twenty minutes',
      'x in 1.5 hours',
      'x in -2 days',
    ]) {
      test(text, () => expect(parse(text).date, isNull));
    }
  });

  group('an in date after the year 9999 (the server refuses it)', () {
    for (final text in [
      'Time capsule in 9000 years',
      'x in 8000 years',
      'x in 7979 years',
      'x in 100000 years',
      'x in 100000 months',
      'x in 95743 months',
    ]) {
      test(text, () => expect(parse(text), ParsedTaskText(text: text)));
    }

    test('a time after it still counts, as for too large amounts', () {
      final result = parse('x in 8000 years at 5pm');
      expect(result.text, 'x in 8000 years');
      expect(result.date, DateTime(2021, 6, 24, 17));
    });
  });

  test('a bare 5pm without at is no time', () {
    expect(parse('call 5pm').date, isNull);
  });

  test('a time at the very start has no space before at', () {
    expect(parse('at 15:00 call'), const ParsedTaskText(text: 'at 15:00 call'));
  });

  test('@15:00 without a space is an assignee', () {
    final result = parse('x @15:00');
    expect(result.date, isNull);
    expect(result.assignees, ['15:00']);
  });

  test('a non-breaking space is no space', () {
    expect(parse('x today').date, isNull);
  });
}
