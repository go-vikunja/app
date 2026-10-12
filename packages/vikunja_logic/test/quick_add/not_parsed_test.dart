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
      // The web gives 2021-6-26 and the text "Reply with".
      expect(
        parse('Reply within 2 days'),
        const ParsedTaskText(text: 'Reply within 2 days'),
      );
    });

    test('in 2 daysx', () {
      expect(parse('x in 2 daysx'), const ParsedTaskText(text: 'x in 2 daysx'));
    });

    test('in two days and in 1 year are not supported', () {
      expect(parse('x in two days').date, isNull);
      expect(parse('x in 1 year').date, isNull);
      expect(parse('x in  2 days').date, isNull);
      expect(parse('x in 2days').date, isNull);
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
