import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import '../helpers/berlin.dart';

typedef _Range = (DateTime from, DateTime to);

// Per "now" (local wall clock), the expected range of every preset in the
// web's order: today, tomorrow, lastWeek, thisWeek, restOfThisWeek,
// nextWeek, next7Days, lastMonth, thisMonth, restOfThisMonth, nextMonth,
// next30Days, thisYear, restOfThisYear.
final Map<String, (DateTime, List<_Range>)> _cases = {
  'a Sunday afternoon': (
    DateTime(2026, 10, 11, 15, 30),
    [
      (DateTime(2026, 10, 11), DateTime(2026, 10, 12)),
      (DateTime(2026, 10, 12), DateTime(2026, 10, 13)),
      (DateTime(2026, 9, 28), DateTime(2026, 10, 5)),
      (DateTime(2026, 10, 5), DateTime(2026, 10, 12)),
      (DateTime(2026, 10, 11, 15, 30), DateTime(2026, 10, 12)),
      (DateTime(2026, 10, 12), DateTime(2026, 10, 19)),
      (DateTime(2026, 10, 11, 15, 30), DateTime(2026, 10, 18, 15, 30)),
      (DateTime(2026, 9), DateTime(2026, 10)),
      (DateTime(2026, 10), DateTime(2026, 11)),
      (DateTime(2026, 10, 11, 15, 30), DateTime(2026, 11)),
      (DateTime(2026, 11), DateTime(2026, 12)),
      (DateTime(2026, 10, 11, 15, 30), DateTime(2026, 11, 10, 15, 30)),
      (DateTime(2026), DateTime(2027)),
      (DateTime(2026, 10, 11, 15, 30), DateTime(2027)),
    ],
  ),
  'Monday at midnight': (
    DateTime(2026, 10, 12),
    [
      (DateTime(2026, 10, 12), DateTime(2026, 10, 13)),
      (DateTime(2026, 10, 13), DateTime(2026, 10, 14)),
      (DateTime(2026, 10, 5), DateTime(2026, 10, 12)),
      (DateTime(2026, 10, 12), DateTime(2026, 10, 19)),
      (DateTime(2026, 10, 12), DateTime(2026, 10, 19)),
      (DateTime(2026, 10, 19), DateTime(2026, 10, 26)),
      (DateTime(2026, 10, 12), DateTime(2026, 10, 19)),
      (DateTime(2026, 9), DateTime(2026, 10)),
      (DateTime(2026, 10), DateTime(2026, 11)),
      (DateTime(2026, 10, 12), DateTime(2026, 11)),
      (DateTime(2026, 11), DateTime(2026, 12)),
      (DateTime(2026, 10, 12), DateTime(2026, 11, 11)),
      (DateTime(2026), DateTime(2027)),
      (DateTime(2026, 10, 12), DateTime(2027)),
    ],
  ),
  'the last moment of January (a Saturday)': (
    DateTime(2026, 1, 31, 23, 59, 59, 999),
    [
      (DateTime(2026, 1, 31), DateTime(2026, 2)),
      (DateTime(2026, 2), DateTime(2026, 2, 2)),
      (DateTime(2026, 1, 19), DateTime(2026, 1, 26)),
      (DateTime(2026, 1, 26), DateTime(2026, 2, 2)),
      (DateTime(2026, 1, 31, 23, 59, 59, 999), DateTime(2026, 2, 2)),
      (DateTime(2026, 2, 2), DateTime(2026, 2, 9)),
      (
        DateTime(2026, 1, 31, 23, 59, 59, 999),
        DateTime(2026, 2, 7, 23, 59, 59, 999),
      ),
      (DateTime(2025, 12), DateTime(2026)),
      (DateTime(2026), DateTime(2026, 2)),
      (DateTime(2026, 1, 31, 23, 59, 59, 999), DateTime(2026, 2)),
      (DateTime(2026, 2), DateTime(2026, 3)),
      (
        DateTime(2026, 1, 31, 23, 59, 59, 999),
        DateTime(2026, 3, 2, 23, 59, 59, 999),
      ),
      (DateTime(2026), DateTime(2027)),
      (DateTime(2026, 1, 31, 23, 59, 59, 999), DateTime(2027)),
    ],
  ),
  "New Year's Eve (a Thursday)": (
    DateTime(2026, 12, 31, 18),
    [
      (DateTime(2026, 12, 31), DateTime(2027)),
      (DateTime(2027), DateTime(2027, 1, 2)),
      (DateTime(2026, 12, 21), DateTime(2026, 12, 28)),
      (DateTime(2026, 12, 28), DateTime(2027, 1, 4)),
      (DateTime(2026, 12, 31, 18), DateTime(2027, 1, 4)),
      (DateTime(2027, 1, 4), DateTime(2027, 1, 11)),
      (DateTime(2026, 12, 31, 18), DateTime(2027, 1, 7, 18)),
      (DateTime(2026, 11), DateTime(2026, 12)),
      (DateTime(2026, 12), DateTime(2027)),
      (DateTime(2026, 12, 31, 18), DateTime(2027)),
      (DateTime(2027), DateTime(2027, 2)),
      (DateTime(2026, 12, 31, 18), DateTime(2027, 1, 30, 18)),
      (DateTime(2026), DateTime(2027)),
      (DateTime(2026, 12, 31, 18), DateTime(2027)),
    ],
  ),
  'the Sunday clocks go forward in Europe': (
    DateTime(2026, 3, 29, 12),
    [
      (DateTime(2026, 3, 29), DateTime(2026, 3, 30)),
      (DateTime(2026, 3, 30), DateTime(2026, 3, 31)),
      (DateTime(2026, 3, 16), DateTime(2026, 3, 23)),
      (DateTime(2026, 3, 23), DateTime(2026, 3, 30)),
      (DateTime(2026, 3, 29, 12), DateTime(2026, 3, 30)),
      (DateTime(2026, 3, 30), DateTime(2026, 4, 6)),
      (DateTime(2026, 3, 29, 12), DateTime(2026, 4, 5, 12)),
      (DateTime(2026, 2), DateTime(2026, 3)),
      (DateTime(2026, 3), DateTime(2026, 4)),
      (DateTime(2026, 3, 29, 12), DateTime(2026, 4)),
      (DateTime(2026, 4), DateTime(2026, 5)),
      (DateTime(2026, 3, 29, 12), DateTime(2026, 4, 28, 12)),
      (DateTime(2026), DateTime(2027)),
      (DateTime(2026, 3, 29, 12), DateTime(2027)),
    ],
  ),
  'the probe time of server.md §6 (a Tuesday)': (
    DateTime(2026, 10, 13, 22, 48, 55),
    [
      (DateTime(2026, 10, 13), DateTime(2026, 10, 14)),
      (DateTime(2026, 10, 14), DateTime(2026, 10, 15)),
      (DateTime(2026, 10, 5), DateTime(2026, 10, 12)),
      (DateTime(2026, 10, 12), DateTime(2026, 10, 19)),
      (DateTime(2026, 10, 13, 22, 48, 55), DateTime(2026, 10, 19)),
      (DateTime(2026, 10, 19), DateTime(2026, 10, 26)),
      (DateTime(2026, 10, 13, 22, 48, 55), DateTime(2026, 10, 20, 22, 48, 55)),
      (DateTime(2026, 9), DateTime(2026, 10)),
      (DateTime(2026, 10), DateTime(2026, 11)),
      (DateTime(2026, 10, 13, 22, 48, 55), DateTime(2026, 11)),
      (DateTime(2026, 11), DateTime(2026, 12)),
      (DateTime(2026, 10, 13, 22, 48, 55), DateTime(2026, 11, 12, 22, 48, 55)),
      (DateTime(2026), DateTime(2027)),
      (DateTime(2026, 10, 13, 22, 48, 55), DateTime(2027)),
    ],
  ),
};

void main() {
  test("the presets are dateRanges.ts's, in its order", () {
    expect(
      [
        for (final preset in DateRangePreset.values)
          (preset.name, preset.from, preset.to),
      ],
      [
        ('today', 'now/d', 'now/d+1d'),
        ('tomorrow', 'now/d+1d', 'now/d+2d'),
        ('lastWeek', 'now/w-1w', 'now/w'),
        ('thisWeek', 'now/w', 'now/w+1w'),
        ('restOfThisWeek', 'now', 'now/w+1w'),
        ('nextWeek', 'now/w+1w', 'now/w+2w'),
        ('next7Days', 'now', 'now+7d'),
        ('lastMonth', 'now/M-1M', 'now/M'),
        ('thisMonth', 'now/M', 'now/M+1M'),
        ('restOfThisMonth', 'now', 'now/M+1M'),
        ('nextMonth', 'now/M+1M', 'now/M+2M'),
        ('next30Days', 'now', 'now+30d'),
        ('thisYear', 'now/y', 'now/y+1y'),
        ('restOfThisYear', 'now', 'now/y+1y'),
      ],
    );
  });

  test('fromName', () {
    expect(DateRangePreset.fromName('next7Days'), DateRangePreset.next7Days);
    expect(DateRangePreset.fromName('Next7Days'), isNull);
    expect(DateRangePreset.fromName(null), isNull);
  });

  for (final MapEntry(key: name, value: (now, ranges)) in _cases.entries) {
    group('on $name', () {
      for (final (index, preset) in DateRangePreset.values.indexed) {
        final (from, to) = ranges[index];
        test(preset.name, () {
          expect(preset.resolve(now), DateRange(from: from, to: to));
        });
      }
    });
  }

  group('in Europe/Berlin', skip: needsBerlin, () {
    test('today lasts 23 hours on the spring change', () {
      final today = DateRangePreset.today.resolve(DateTime(2026, 3, 29, 12));
      expect(today.to.difference(today.from), const Duration(hours: 23));
    });

    test('today lasts 25 hours on the autumn change', () {
      final today = DateRangePreset.today.resolve(DateTime(2026, 10, 25, 12));
      expect(today.to.difference(today.from), const Duration(hours: 25));
    });

    test('next 30 days keep the wall clock across the autumn change', () {
      final now = DateTime(2026, 10, 11, 15, 30);
      final range = DateRangePreset.next30Days.resolve(now);

      expect(range.to, DateTime(2026, 11, 10, 15, 30));
      expect(range.to.difference(now), const Duration(days: 30, hours: 1));
    });

    test('this week, as the server answers with filter_timezone Berlin', () {
      final now = DateTime.utc(2026, 10, 13, 20, 48, 55).toLocal();
      final range = DateRangePreset.thisWeek.resolve(now);

      expect(range.from.toUtc(), DateTime.utc(2026, 10, 11, 22));
      expect(range.to.toUtc(), DateTime.utc(2026, 10, 18, 22));
    });
  });
}
