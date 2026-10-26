import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

// Derived from the web's useGanttFilters.ts (scratchpad step29/
// gantt-vectors.json, derived_from_code), with GF1/GF2 of
// useGanttFilters.test.ts adapted: the app keeps the range per view in its
// preferences instead of the route.
CalendarDate _date(String text) => CalendarDate.tryParse(text)!;

void main() {
  group('the default range: 15 days back, 55 ahead, by local date', () {
    const cases = {
      '2026-10-26': ('2026-10-11', '2026-12-20'),
      '2026-03-01': ('2026-02-14', '2026-04-25'),
      '2024-02-29': ('2024-02-14', '2024-04-24'),
      '2026-01-10': ('2025-12-26', '2026-03-06'),
      '2026-12-31': ('2026-12-16', '2027-02-24'),
    };
    for (final MapEntry(key: today, value: (from, to)) in cases.entries) {
      test(today, () {
        final date = _date(today);
        final range = defaultGanttRange(
          DateTime(date.year, date.month, date.day, 13, 45),
        );

        expect(range, GanttRange(from: _date(from), to: _date(to)));
        expect(range.dayCount, 71);
      });
    }

    test('the date of the moment passed, whatever its time', () {
      expect(
        defaultGanttRange(DateTime(2026, 10, 26)).from,
        defaultGanttRange(DateTime(2026, 10, 26, 23, 59, 59)).from,
      );
      expect(
        defaultGanttRange(DateTime.utc(2026, 10, 26, 23, 30)).to,
        _date('2026-12-20'),
      );
    });
  });

  group("the web's filter text", () {
    test('the default range on 2026-10-26', () {
      expect(
        ganttFilterText(
          GanttRange(from: _date('2026-10-11'), to: _date('2026-12-20')),
        ),
        '((start_date >= "2026-10-11" && start_date <= "2026-12-20") || '
        '(end_date >= "2026-10-11" && end_date <= "2026-12-20") || '
        '(due_date >= "2026-10-11" && due_date <= "2026-12-20") || '
        '(start_date <= "2026-10-11" && end_date >= "2026-12-20"))',
      );
    });

    // GF2: dateFrom=2024-01-01&dateTo=2024-02-01 gives local midnights of
    // both days; here the stored range gives the same days and text.
    test('a stored range (GF2)', () {
      final range = GanttRange.fromJson({
        'from': '2024-01-01',
        'to': '2024-02-01',
      })!;

      expect(range.from.toDateTime(), DateTime(2024));
      expect(range.to.toDateTime(), DateTime(2024, 2));
      expect(
        ganttFilterText(range),
        '((start_date >= "2024-01-01" && start_date <= "2024-02-01") || '
        '(end_date >= "2024-01-01" && end_date <= "2024-02-01") || '
        '(due_date >= "2024-01-01" && due_date <= "2024-02-01") || '
        '(start_date <= "2024-01-01" && end_date >= "2024-02-01"))',
      );
    });

    test('the engine reads it', () {
      final parsed = parseTaskFilter(
        ganttFilterText(
          GanttRange(from: _date('2026-10-11'), to: _date('2026-12-20')),
        ),
      );

      expect(parsed, isA<FilterExpression>());
      expect((parsed as FilterExpression).fields, {
        'start_date',
        'end_date',
        'due_date',
      });
      expect(parsed.usesRelativeDates, isFalse);
    });
  });

  group('stored ranges', () {
    // The web's route query: nothing for the default range, both dates
    // otherwise. The app stores "default" instead of nothing, so that the
    // range keeps following today; fromJson answers null for it.
    test('a custom range reads back', () {
      final range = GanttRange(
        from: _date('2022-09-25'),
        to: _date('2022-11-05'),
      );

      expect(range.toJson(), {'from': '2022-09-25', 'to': '2022-11-05'});
      expect(GanttRange.fromJson(range.toJson()), range);
    });

    test('anything else is no custom range', () {
      for (final json in <Object?>[
        null,
        'default',
        <String, Object?>{},
        {'from': '2022-09-25'},
        {'from': '2022-09-25', 'to': 'abc'},
        {'from': '2022-13-01', 'to': '2022-11-05'},
        {'from': 20220925, 'to': '2022-11-05'},
        {'from': '2022-11-05', 'to': '2022-09-25'},
      ]) {
        expect(GanttRange.fromJson(json), isNull, reason: '$json');
      }
    });

    test('unpadded and rolled-over dates are read as the web reads them', () {
      expect(
        GanttRange.fromJson({'from': '2024-1-5', 'to': '2024-02-30'}),
        GanttRange(from: _date('2024-01-05'), to: _date('2024-03-01')),
      );
    });

    test('a one-day range has one column', () {
      final range = GanttRange(
        from: _date('2026-11-01'),
        to: _date('2026-11-01'),
      );

      expect(range.dayCount, 1);
      expect(range.contains(_date('2026-11-01')), isTrue);
      expect(range.contains(_date('2026-11-02')), isFalse);
      expect(range.dayAt(0), _date('2026-11-01'));
    });
  });
}
