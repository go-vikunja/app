import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vikunja_logic/vikunja_logic.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('tryParse, like the web reads a date from its URL (parseDateProp)', () {
    const vectors = <String?, CalendarDate?>{
      '2024-01-01': CalendarDate(2024, 1, 1),
      '2024-1-5': CalendarDate(2024, 1, 5),
      '2024-02-30': CalendarDate(2024, 3, 1),
      '2024-13-01': null,
      '2024-01': null,
      'abc': null,
      '': null,
      null: null,
    };
    for (final MapEntry(key: text, value: expected) in vectors.entries) {
      test(text ?? 'null', () {
        expect(CalendarDate.tryParse(text), expected);
      });
    }

    test('refuses a day outside 1–31 and other shapes', () {
      for (final text in [
        '2024-01-00',
        '2024-01-32',
        '2024-00-10',
        '2024-001-10',
        '2024/01/10',
        '2024-01-10T00:00',
        '20240110',
      ]) {
        expect(CalendarDate.tryParse(text), isNull, reason: text);
      }
    });
  });

  test('prints padded YYYY-MM-DD and reads it back', () {
    const date = CalendarDate(812, 3, 4);

    expect('$date', '0812-03-04');
    expect(CalendarDate.tryParse('$date'), date);
    expect('${const CalendarDate(2026, 12, 20)}', '2026-12-20');
  });

  group('calendar days', () {
    test('across month and year ends and a leap day', () {
      const date = CalendarDate(2024, 2, 29);

      expect(date.addDays(1), const CalendarDate(2024, 3, 1));
      expect(date.addDays(-60), const CalendarDate(2023, 12, 31));
      expect(date.addDays(366), const CalendarDate(2025, 3, 1));
      expect(const CalendarDate(2025, 3, 1).daysSince(date), 366);
      expect(date.daysSince(const CalendarDate(2025, 3, 1)), -366);
    });

    test('a DST change is still one day', () {
      // Europe/Berlin and America/Los_Angeles change in these weeks.
      const march = CalendarDate(2026, 3, 28);
      const october = CalendarDate(2026, 10, 24);
      const november = CalendarDate(2026, 10, 31);

      expect(march.addDays(2), const CalendarDate(2026, 3, 30));
      expect(const CalendarDate(2026, 3, 30).daysSince(march), 2);
      expect(october.addDays(2), const CalendarDate(2026, 10, 26));
      expect(november.addDays(2), const CalendarDate(2026, 11, 2));
      expect(
        const CalendarDate(
          2027,
          1,
          31,
        ).daysSince(const CalendarDate(2026, 9, 1)),
        152,
      );
    });

    test('order and weekday', () {
      const a = CalendarDate(2026, 10, 26);
      const b = CalendarDate(2026, 11, 1);

      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect(a.compareTo(a), 0);
      expect([b, a]..sort(), [a, b]);
      expect(a.weekday, DateTime.monday);
      expect(b.weekday, DateTime.sunday);
    });
  });

  group('zones', () {
    test('the date of an instant on the zone wall clock', () {
      final instant = DateTime.utc(2026, 10, 10, 23, 30);

      expect(
        CalendarDate.inZone(instant, tz.UTC),
        const CalendarDate(2026, 10, 10),
      );
      expect(
        CalendarDate.inZone(instant, tz.getLocation('Europe/Berlin')),
        const CalendarDate(2026, 10, 11),
      );
      expect(
        CalendarDate.inZone(
          DateTime.utc(2026, 12, 20, 5),
          tz.getLocation('America/Los_Angeles'),
        ),
        const CalendarDate(2026, 12, 19),
      );
    });

    test('midnight in a zone, on both sides of a DST change', () {
      final berlin = tz.getLocation('Europe/Berlin');

      expect(
        const CalendarDate(2026, 10, 11).startIn(berlin).toUtc(),
        DateTime.utc(2026, 10, 10, 22),
      );
      expect(
        const CalendarDate(2026, 12, 20).startIn(berlin).toUtc(),
        DateTime.utc(2026, 12, 19, 23),
      );
    });

    test('of reads the fields as given; toDateTime is local midnight', () {
      expect(
        CalendarDate.of(DateTime(2026, 10, 26, 23, 59)),
        const CalendarDate(2026, 10, 26),
      );
      expect(
        const CalendarDate(2026, 10, 26).toDateTime(),
        DateTime(2026, 10, 26),
      );
    });
  });
}
