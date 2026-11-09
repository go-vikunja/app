import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'parse_helpers.dart';

QuickAddRepeat _repeat(int amount, QuickAddRepeatUnit unit) =>
    QuickAddRepeat(amount: amount, unit: unit);

void main() {
  group('recurring dates (the web table)', () {
    const hours = QuickAddRepeatUnit.hours;
    const days = QuickAddRepeatUnit.days;
    const weeks = QuickAddRepeatUnit.weeks;
    const months = QuickAddRepeatUnit.months;
    const years = QuickAddRepeatUnit.years;
    final cases = {
      'every 1 hour': _repeat(1, hours),
      'every hour': _repeat(1, hours),
      'every 5 hours': _repeat(5, hours),
      'every 12 hours': _repeat(12, hours),
      'every day': _repeat(1, days),
      'every 1 day': _repeat(1, days),
      'every 2 days': _repeat(2, days),
      'every week': _repeat(1, weeks),
      'every 1 week': _repeat(1, weeks),
      'every 3 weeks': _repeat(3, weeks),
      'every month': _repeat(1, months),
      'every 1 month': _repeat(1, months),
      'every 2 months': _repeat(2, months),
      'every year': _repeat(1, years),
      'every 1 year': _repeat(1, years),
      'every 4 years': _repeat(4, years),
      'every one hour': _repeat(1, hours),
      'every two hours': _repeat(2, hours),
      'every three hours': _repeat(3, hours),
      'every four hours': _repeat(4, hours),
      'every five hours': _repeat(5, hours),
      'every six hours': _repeat(6, hours),
      'every seven hours': _repeat(7, hours),
      'every eight hours': _repeat(8, hours),
      'every nine hours': _repeat(9, hours),
      'every ten hours': _repeat(10, hours),
      'annually': _repeat(1, years),
      'biannually': _repeat(6, months),
      'semiannually': _repeat(6, months),
      'biennially': _repeat(2, years),
      'daily': _repeat(1, days),
      'hourly': _repeat(1, hours),
      'monthly': _repeat(1, months),
      'weekly': _repeat(1, weeks),
      'yearly': _repeat(1, years),
    };

    for (final MapEntry(key: phrase, value: repeat) in cases.entries) {
      test('$phrase is every ${repeat.amount} ${repeat.unit.name}', () {
        final result = parse('Lorem Ipsum $phrase');
        expect(result.text, 'Lorem Ipsum');
        expect(result.repeats, repeat);
        expect(result.repeatPhrase, phrase);
        expect(result.date, isNull);
      });

      test('$phrase at 11:42 is today at 11:42', () {
        final result = parse('Lorem Ipsum $phrase at 11:42');
        expect(result.text, 'Lorem Ipsum');
        expect(result.repeats, repeat);
        expect(result.date, DateTime(2021, 6, 24, 11, 42));
      });
    }

    for (final word in [
      'annually',
      'biannually',
      'semiannually',
      'biennially',
      'daily',
      'hourly',
      'monthly',
      'weekly',
      'yearly',
    ]) {
      test('ignores $word inside a word', () {
        final result = parse('Lorem Ipsum word${word}notword');
        expect(result.text, 'Lorem Ipsum word${word}notword');
        expect(result.repeats, isNull);
      });
    }
  });

  group('D19-2: keywords in any case mean what they mean in lower case', () {
    final cases = {
      'Daily': _repeat(1, QuickAddRepeatUnit.days),
      'Every Day': _repeat(1, QuickAddRepeatUnit.days),
      'EVERY DAY': _repeat(1, QuickAddRepeatUnit.days),
      'Weekly': _repeat(1, QuickAddRepeatUnit.weeks),
      'Monthly': _repeat(1, QuickAddRepeatUnit.months),
      'Yearly': _repeat(1, QuickAddRepeatUnit.years),
      'Hourly': _repeat(1, QuickAddRepeatUnit.hours),
      'Biennially': _repeat(2, QuickAddRepeatUnit.years),
      'Every 2 Weeks': _repeat(2, QuickAddRepeatUnit.weeks),
      'Every Two Days': _repeat(2, QuickAddRepeatUnit.days),
      'Each Month': _repeat(1, QuickAddRepeatUnit.months),
      'every TEN Hours': _repeat(10, QuickAddRepeatUnit.hours),
    };
    for (final MapEntry(key: phrase, value: repeat) in cases.entries) {
      test(phrase, () {
        final result = parse('Lorem Ipsum $phrase');
        expect(result.text, 'Lorem Ipsum');
        expect(result.repeats, repeat);
        expect(result.repeatPhrase, phrase);
      });
    }
  });

  group('the phrase', () {
    test('at the start', () {
      final result = parse('every day Lorem');
      expect(result.text, 'Lorem');
      expect(result.repeats, _repeat(1, QuickAddRepeatUnit.days));
    });

    test('in the middle, leaving one space', () {
      expect(parse('x weekly y').text, 'x y');
    });

    test('each is every', () {
      expect(
        parse('x each week').repeats,
        _repeat(1, QuickAddRepeatUnit.weeks),
      );
    });

    test('a unit without its plural s', () {
      expect(
        parse('x every 2 hour').repeats,
        _repeat(2, QuickAddRepeatUnit.hours),
      );
      expect(
        parse('x every days').repeats,
        _repeat(1, QuickAddRepeatUnit.days),
      );
    });

    test('only the first phrase counts; the others stay', () {
      final result = parse('x every day every week');
      expect(result.text, 'x every week');
      expect(result.repeats, _repeat(1, QuickAddRepeatUnit.days));
      expect(parse('x daily daily').text, 'x daily');
    });

    test('needs a space or the end after it', () {
      expect(parse('x weekly, y').repeats, isNull);
      expect(parse('x weekly!').repeats, isNull);
      expect(parse('x every dayz').repeats, isNull);
    });

    test('amounts are digits or one to twelve', () {
      expect(
        parse('x every 11 days').repeats,
        _repeat(11, QuickAddRepeatUnit.days),
      );
      expect(
        parse('x every eleven days').repeats,
        _repeat(11, QuickAddRepeatUnit.days),
      );
      expect(
        parse('x every twelve months').repeats,
        _repeat(12, QuickAddRepeatUnit.months),
      );
      expect(parse('x every thirteen days').repeats, isNull);
      expect(parse('x every 1.5 days').repeats, isNull);
    });

    test('number words in any case', () {
      final result = parse('Clean gutters Each Twelve weeks');
      expect(result.text, 'Clean gutters');
      expect(result.repeats, _repeat(12, QuickAddRepeatUnit.weeks));
      expect(result.repeatPhrase, 'Each Twelve weeks');
      expect(
        parse('x every ELEVEN hours').repeats,
        _repeat(11, QuickAddRepeatUnit.hours),
      );
    });

    test('a and an are no repeat amounts', () {
      for (final text in ['x every a week', 'x each an hour']) {
        final result = parse(text);
        expect(result.repeats, isNull, reason: text);
        expect(result.text, text, reason: text);
      }
    });

    test('every with a weekday is no repeat but the weekday', () {
      final result = parse('x every monday');
      expect(result.repeats, isNull);
      expect(result.text, 'x every');
      expect(ymd(result.date), '2021-6-28');
    });

    test('web parity: every 0 days is a repeat of 0', () {
      expect(
        parse('x every 0 days').repeats,
        _repeat(0, QuickAddRepeatUnit.days),
      );
    });

    test('D38-9: an amount above 100000 is text', () {
      expect(
        parse('x every 100000 years').repeats,
        _repeat(100000, QuickAddRepeatUnit.years),
      );
      final result = parse('x every 100001 years');
      expect(result.repeats, isNull);
      expect(result.text, 'x every 100001 years');
    });

    test('with a spelled-out date after it', () {
      final result = parse('Water lawn every two weeks in three days');
      expect(result.text, 'Water lawn');
      expect(result.repeats, _repeat(2, QuickAddRepeatUnit.weeks));
      expect(result.date, DateTime(2021, 6, 27, 12));
    });

    test('with a date before or after it', () {
      final before = parse('x tomorrow at 10:00 every 2 days');
      expect(before.text, 'x');
      expect(before.date, DateTime(2021, 6, 25, 10));
      expect(before.repeats, _repeat(2, QuickAddRepeatUnit.days));
      final after = parse('x every week at 9 tomorrow');
      expect(after.text, 'x');
      expect(after.date, DateTime(2021, 6, 25, 9));
      expect(after.repeats, _repeat(1, QuickAddRepeatUnit.weeks));
    });

    test('a repeat is no date of its own', () {
      expect(parse('Call mom every day').date, isNull);
    });

    test('the web flow vectors', () {
      final monthly = parse('Task every month');
      expect(monthly.text, 'Task');
      expect(monthly.repeats!.toTaskRepeat(), (
        repeatAfter: Duration.zero,
        mode: RepeatMode.monthly,
      ));
      final timed = parse(
        'Call mom every day at 11:42',
        now: DateTime(2026, 9, 23, 9, 15),
      );
      expect(timed.text, 'Call mom');
      expect(timed.date, DateTime(2026, 9, 23, 11, 42));
    });
  });

  group('toTaskRepeat', () {
    const afterAmount = RepeatMode.afterAmount;
    final cases = <String, ({Duration repeatAfter, RepeatMode mode})>{
      'every hour': (repeatAfter: const Duration(hours: 1), mode: afterAmount),
      'every 12 hours': (
        repeatAfter: const Duration(hours: 12),
        mode: afterAmount,
      ),
      'hourly': (repeatAfter: const Duration(hours: 1), mode: afterAmount),
      'every day': (repeatAfter: const Duration(days: 1), mode: afterAmount),
      'daily': (repeatAfter: const Duration(days: 1), mode: afterAmount),
      'every 3 days': (repeatAfter: const Duration(days: 3), mode: afterAmount),
      'weekly': (repeatAfter: const Duration(days: 7), mode: afterAmount),
      'every 3 weeks': (
        repeatAfter: const Duration(days: 21),
        mode: afterAmount,
      ),
      'every month': (repeatAfter: Duration.zero, mode: RepeatMode.monthly),
      'every 1 month': (repeatAfter: Duration.zero, mode: RepeatMode.monthly),
      'monthly': (repeatAfter: Duration.zero, mode: RepeatMode.monthly),
      // D38-1: the web sends no repeat for the rest of this table.
      'every 2 months': (
        repeatAfter: const Duration(days: 60),
        mode: afterAmount,
      ),
      'every 7 months': (
        repeatAfter: const Duration(days: 210),
        mode: afterAmount,
      ),
      'biannually': (repeatAfter: const Duration(days: 180), mode: afterAmount),
      'semiannually': (
        repeatAfter: const Duration(days: 180),
        mode: afterAmount,
      ),
      'every year': (repeatAfter: const Duration(days: 365), mode: afterAmount),
      'yearly': (repeatAfter: const Duration(days: 365), mode: afterAmount),
      'annually': (repeatAfter: const Duration(days: 365), mode: afterAmount),
      'every 4 years': (
        repeatAfter: const Duration(days: 1460),
        mode: afterAmount,
      ),
      'biennially': (repeatAfter: const Duration(days: 730), mode: afterAmount),
    };
    for (final MapEntry(key: phrase, value: expected) in cases.entries) {
      test(phrase, () {
        expect(parse('x $phrase').repeats!.toTaskRepeat(), expected);
      });
    }

    test('an amount of 0 is no repeat (web parity)', () {
      expect(_repeat(0, QuickAddRepeatUnit.months).toTaskRepeat(), (
        repeatAfter: Duration.zero,
        mode: afterAmount,
      ));
    });

    test('the largest amount fits a Duration', () {
      expect(
        _repeat(100000, QuickAddRepeatUnit.years).toTaskRepeat().repeatAfter,
        const Duration(days: 36500000),
      );
    });
  });
}
