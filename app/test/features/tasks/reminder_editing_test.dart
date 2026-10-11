import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/application/reminder_editing.dart';

void main() {
  final due = DateTime.utc(2026, 10, 12, 9, 30);
  final start = DateTime.utc(2026, 10, 11, 8);
  final end = DateTime.utc(2026, 10, 14, 17);

  TaskReminder relative(Duration period, ReminderRelativeTo to) =>
      TaskReminder(relativePeriod: period, relativeTo: to);

  group('period parts', () {
    ReminderPeriodParts parts(
      int amount,
      ReminderUnit unit,
      ReminderDirection direction,
    ) => ReminderPeriodParts(amount: amount, unit: unit, direction: direction);

    test('take the largest whole unit and keep the sign', () {
      expect(
        ReminderPeriodParts.fromPeriod(const Duration(minutes: -90)),
        parts(90, ReminderUnit.minutes, ReminderDirection.before),
      );
      expect(
        ReminderPeriodParts.fromPeriod(const Duration(days: 2)),
        parts(2, ReminderUnit.days, ReminderDirection.after),
      );
      expect(
        ReminderPeriodParts.fromPeriod(const Duration(days: -14)),
        parts(2, ReminderUnit.weeks, ReminderDirection.before),
      );
      expect(
        ReminderPeriodParts.fromPeriod(const Duration(hours: 36)),
        parts(36, ReminderUnit.hours, ReminderDirection.after),
      );
      expect(
        ReminderPeriodParts.fromPeriod(const Duration(hours: -2)),
        parts(2, ReminderUnit.hours, ReminderDirection.before),
      );
    });

    test('zero is "on the date"; a period of odd seconds rounds to '
        'minutes', () {
      expect(ReminderPeriodParts.fromPeriod(Duration.zero).amount, 0);
      expect(
        ReminderPeriodParts.fromPeriod(Duration.zero).period,
        Duration.zero,
      );
      expect(
        ReminderPeriodParts.fromPeriod(const Duration(seconds: 150)),
        parts(3, ReminderUnit.minutes, ReminderDirection.after),
      );
    });

    test('convert to signed seconds', () {
      expect(
        parts(90, ReminderUnit.minutes, ReminderDirection.before).period,
        const Duration(seconds: -5400),
      );
      expect(
        parts(3, ReminderUnit.weeks, ReminderDirection.after).period,
        const Duration(seconds: 1814400),
      );
      expect(
        parts(0, ReminderUnit.days, ReminderDirection.after).period,
        Duration.zero,
      );
    });

    test('survive a round trip', () {
      for (final period in const [
        Duration(minutes: -5),
        Duration(hours: 5),
        Duration(days: -3),
        Duration(days: 21),
        Duration(minutes: 1441),
      ]) {
        expect(ReminderPeriodParts.fromPeriod(period).period, period);
      }
    });
  });

  test('presets are the web ones relative to the given date', () {
    expect(reminderPresets(ReminderRelativeTo.startDate), [
      relative(Duration.zero, ReminderRelativeTo.startDate),
      relative(const Duration(hours: -2), ReminderRelativeTo.startDate),
      relative(const Duration(days: -1), ReminderRelativeTo.startDate),
      relative(const Duration(days: -3), ReminderRelativeTo.startDate),
      relative(const Duration(days: -7), ReminderRelativeTo.startDate),
      relative(const Duration(days: -30), ReminderRelativeTo.startDate),
    ]);
  });

  test('the default reference is the due date, else start, else end', () {
    expect(
      defaultReminderReference((due: due, start: start, end: end)),
      ReminderRelativeTo.dueDate,
    );
    expect(
      defaultReminderReference((due: null, start: start, end: end)),
      ReminderRelativeTo.startDate,
    );
    expect(
      defaultReminderReference((due: null, start: null, end: end)),
      ReminderRelativeTo.endDate,
    );
    expect(
      defaultReminderReference((due: null, start: null, end: null)),
      isNull,
    );
  });

  test('the instant comes from the draft dates, null without the date', () {
    final dates = (due: due, start: null, end: end);
    expect(
      reminderInstant(
        relative(const Duration(hours: -2), ReminderRelativeTo.dueDate),
        dates,
      ),
      DateTime.utc(2026, 10, 12, 7, 30),
    );
    expect(
      reminderInstant(
        TaskReminder(
          reminder: DateTime.utc(2026, 1, 2),
          relativePeriod: const Duration(days: 1),
          relativeTo: ReminderRelativeTo.endDate,
        ),
        dates,
      ),
      DateTime.utc(2026, 10, 15, 17),
    );
    expect(
      reminderInstant(
        relative(Duration.zero, ReminderRelativeTo.startDate),
        dates,
      ),
      isNull,
    );
    expect(reminderInstant(TaskReminder(reminder: start), dates), start);
  });

  group('adding', () {
    final dayBefore = relative(
      const Duration(days: -1),
      ReminderRelativeTo.dueDate,
    );
    final absolute = TaskReminder(reminder: due);

    test('appends a new reminder', () {
      expect(withReminder([dayBefore], absolute), [dayBefore, absolute]);
    });

    test('refuses one the list already has', () {
      expect(
        withReminder([
          dayBefore,
        ], relative(const Duration(days: -1), ReminderRelativeTo.dueDate)),
        isNull,
      );
    });

    test('replaces in place, also with itself', () {
      final weekBefore = relative(
        const Duration(days: -7),
        ReminderRelativeTo.dueDate,
      );
      expect(withReminder([dayBefore, absolute], weekBefore, replacing: 0), [
        weekBefore,
        absolute,
      ]);
      expect(withReminder([dayBefore, absolute], dayBefore, replacing: 0), [
        dayBefore,
        absolute,
      ]);
      expect(
        withReminder([dayBefore, absolute], absolute, replacing: 0),
        isNull,
      );
    });
  });
}
