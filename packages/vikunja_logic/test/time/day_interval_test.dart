import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

// One week, Monday 2026-09-14 to Sunday 2026-09-20.
final _days = {
  'monday': DateTime(2026, 9, 14, 10),
  'tuesday': DateTime(2026, 9, 15, 10),
  'wednesday': DateTime(2026, 9, 16, 10),
  'thursday': DateTime(2026, 9, 17, 10),
  'friday': DateTime(2026, 9, 18, 10),
  'saturday': DateTime(2026, 9, 19, 10),
  'sunday': DateTime(2026, 9, 20, 10),
};

// The web's calculateDayInterval.test.ts, per key and weekday.
const _expected = <DayInterval, List<int>>{
  DayInterval.today: [0, 0, 0, 0, 0, 0, 0],
  DayInterval.tomorrow: [1, 1, 1, 1, 1, 1, 1],
  DayInterval.nextMonday: [0, 6, 5, 4, 3, 2, 1],
  DayInterval.thisWeekend: [5, 4, 3, 2, 1, 0, 0],
  DayInterval.laterThisWeek: [2, 2, 2, 2, 0, 0, 0],
  DayInterval.laterNextWeek: [9, 9, 9, 9, 7, 7, 7],
  DayInterval.nextWeek: [7, 7, 7, 7, 7, 7, 7],
  // Not in the web's helper: the Saturday after this week's (12a).
  DayInterval.nextWeekend: [12, 11, 10, 9, 8, 7, 6],
};

void main() {
  test('the week of the table runs from Monday to Sunday', () {
    expect(_days.values.first.weekday, DateTime.monday);
    expect(_days.values.last.weekday, DateTime.sunday);
  });

  for (final MapEntry(key: interval, value: days) in _expected.entries) {
    group(interval.name, () {
      var index = 0;
      for (final MapEntry(key: name, value: now) in _days.entries) {
        final expected = days[index++];
        test('on a $name: $expected', () {
          expect(calculateDayInterval(interval, now), expected);
        });
      }
    });
  }

  test('ignores the time of day', () {
    for (final now in [
      DateTime(2026, 9, 14),
      DateTime(2026, 9, 14, 23, 59, 59, 999),
    ]) {
      expect(calculateDayInterval(DayInterval.nextMonday, now), 0);
      expect(calculateDayInterval(DayInterval.thisWeekend, now), 5);
    }
  });
}
