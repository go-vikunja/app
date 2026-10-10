import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';

void main() {
  List<DateShortcut> keysAt(DateTime now) => [
    for (final option in buildDateShortcuts(now)) option.shortcut,
  ];

  Map<DateShortcut, DateTime> daysAt(DateTime now) => {
    for (final option in buildDateShortcuts(now)) option.shortcut: option.day,
  };

  group('buildDateShortcuts', () {
    test('the web vector for Friday 2026-09-11 10:00', () {
      expect(keysAt(DateTime(2026, 9, 11, 10)), [
        DateShortcut.today,
        DateShortcut.tomorrow,
        DateShortcut.nextMonday,
        DateShortcut.nextWeek,
        DateShortcut.nextWeekend,
        DateShortcut.endOfMonth,
        DateShortcut.inAMonth,
      ]);
      expect(daysAt(DateTime(2026, 9, 11, 10)), {
        DateShortcut.today: DateTime(2026, 9, 11),
        DateShortcut.tomorrow: DateTime(2026, 9, 12),
        DateShortcut.nextMonday: DateTime(2026, 9, 14),
        DateShortcut.nextWeek: DateTime(2026, 9, 18),
        DateShortcut.nextWeekend: DateTime(2026, 9, 19),
        DateShortcut.endOfMonth: DateTime(2026, 9, 30),
        DateShortcut.inAMonth: DateTime(2026, 10, 11),
      });
    });

    test('the web vector for Monday 2026-09-14', () {
      expect(keysAt(DateTime(2026, 9, 14, 8)), [
        DateShortcut.today,
        DateShortcut.tomorrow,
        DateShortcut.thisWeekend,
        DateShortcut.laterThisWeek,
        DateShortcut.nextWeek,
        DateShortcut.nextWeekend,
        DateShortcut.endOfMonth,
        DateShortcut.inAMonth,
      ]);
      final days = daysAt(DateTime(2026, 9, 14, 8));
      expect(days[DateShortcut.thisWeekend], DateTime(2026, 9, 19));
      expect(days[DateShortcut.laterThisWeek], DateTime(2026, 9, 16));
      expect(days[DateShortcut.nextWeekend], DateTime(2026, 9, 26));
    });

    test('the web vector for Tuesday 2026-09-15: all nine', () {
      expect(keysAt(DateTime(2026, 9, 15, 14, 30)), DateShortcut.values);
      final days = daysAt(DateTime(2026, 9, 15, 14, 30));
      expect(days[DateShortcut.nextMonday], DateTime(2026, 9, 21));
      expect(days[DateShortcut.thisWeekend], DateTime(2026, 9, 19));
      expect(days[DateShortcut.laterThisWeek], DateTime(2026, 9, 17));
      expect(days[DateShortcut.nextWeek], DateTime(2026, 9, 22));
      expect(days[DateShortcut.nextWeekend], DateTime(2026, 9, 26));
      expect(days[DateShortcut.inAMonth], DateTime(2026, 10, 15));
    });

    test('on 2026-09-30 the end of the month is today and hidden', () {
      final keys = keysAt(DateTime(2026, 9, 30, 9));
      expect(keys, contains(DateShortcut.today));
      expect(keys, isNot(contains(DateShortcut.endOfMonth)));
    });

    test('on Sunday this weekend is hidden and next weekend is the next '
        'Saturday', () {
      final now = DateTime(2026, 9, 13, 11);
      expect(now.weekday, DateTime.sunday);
      final days = daysAt(now);
      expect(days.containsKey(DateShortcut.thisWeekend), isFalse);
      expect(days[DateShortcut.nextWeekend], DateTime(2026, 9, 19));
      // Next Monday and later this week fall on days already listed.
      expect(keysAt(now), [
        DateShortcut.today,
        DateShortcut.tomorrow,
        DateShortcut.nextWeek,
        DateShortcut.nextWeekend,
        DateShortcut.endOfMonth,
        DateShortcut.inAMonth,
      ]);
    });

    test('from 21:00 today is hidden; a shortcut landing on today still '
        'shows, as on the web', () {
      expect(
        keysAt(DateTime(2026, 9, 15, 20, 59)),
        contains(DateShortcut.today),
      );
      expect(
        keysAt(DateTime(2026, 9, 15, 21)),
        isNot(contains(DateShortcut.today)),
      );
      // Friday 21:30: later this week is today and stays.
      final friday = DateTime(2026, 9, 11, 21, 30);
      expect(keysAt(friday), [
        DateShortcut.tomorrow,
        DateShortcut.nextMonday,
        DateShortcut.laterThisWeek,
        DateShortcut.nextWeek,
        DateShortcut.nextWeekend,
        DateShortcut.endOfMonth,
        DateShortcut.inAMonth,
      ]);
      expect(daysAt(friday)[DateShortcut.laterThisWeek], DateTime(2026, 9, 11));
      // Monday 21:00: next Monday is today and stays.
      expect(
        daysAt(DateTime(2026, 9, 14, 21))[DateShortcut.nextMonday],
        DateTime(2026, 9, 14),
      );
    });

    test('in a month is clamped to the last day of the month', () {
      expect(
        daysAt(DateTime(2026, 1, 31, 10))[DateShortcut.inAMonth],
        DateTime(2026, 2, 28),
      );
      expect(
        daysAt(DateTime(2026, 12, 15, 10))[DateShortcut.inAMonth],
        DateTime(2027, 1, 15),
      );
      expect(
        daysAt(DateTime(2026, 12, 15, 10))[DateShortcut.endOfMonth],
        DateTime(2026, 12, 31),
      );
    });

    test('every day is the start of its day', () {
      for (final option in buildDateShortcuts(DateTime(2026, 9, 15, 14, 30))) {
        expect(option.day.hour, 0, reason: option.toString());
        expect(option.day.minute, 0, reason: option.toString());
      }
    });
  });

  group('nearestBreakpointHour', () {
    test('matches the web examples', () {
      expect(nearestBreakpointHour(DateTime(2026, 1, 1, 5, 30)), 9);
      expect(nearestBreakpointHour(DateTime(2026, 1, 1, 9)), 9);
      expect(nearestBreakpointHour(DateTime(2026, 1, 1, 9, 1)), 12);
      expect(nearestBreakpointHour(DateTime(2026, 1, 1, 10, 15)), 12);
      expect(nearestBreakpointHour(DateTime(2026, 1, 1, 12)), 12);
      expect(nearestBreakpointHour(DateTime(2026, 1, 1, 13, 5)), 15);
      expect(nearestBreakpointHour(DateTime(2026, 1, 1, 16, 45)), 18);
      expect(nearestBreakpointHour(DateTime(2026, 1, 1, 21)), 21);
      expect(nearestBreakpointHour(DateTime(2026, 1, 1, 21, 1)), 9);
      expect(nearestBreakpointHour(DateTime(2026, 1, 1, 22, 30)), 9);
    });
  });

  group('dayWithTime', () {
    final now = DateTime(2026, 9, 15, 10, 15);

    test('gives a date-only pick the breakpoint time', () {
      expect(
        dayWithTime(DateTime(2026, 9, 20), current: null, now: now),
        DateTime(2026, 9, 20, 12),
      );
    });

    test('keeps the time already set, in local time', () {
      final current = DateTime(2026, 9, 11, 17, 45).toUtc();
      expect(
        dayWithTime(DateTime(2026, 9, 20), current: current, now: now),
        DateTime(2026, 9, 20, 17, 45),
      );
    });
  });
}
