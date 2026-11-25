import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  final due = DateTime.utc(2026, 10, 12, 9, 30);

  TaskReminder relative(Duration period, ReminderRelativeTo to) =>
      TaskReminder(relativePeriod: period, relativeTo: to);

  group('sameness', () {
    test('relative by date and period, whatever instant is stored', () {
      expect(
        sameReminder(
          TaskReminder(
            reminder: DateTime.utc(2026, 10, 11, 9, 30),
            relativePeriod: const Duration(days: -1),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
          relative(const Duration(days: -1), ReminderRelativeTo.dueDate),
        ),
        isTrue,
      );
      expect(
        sameReminder(
          relative(const Duration(days: -1), ReminderRelativeTo.dueDate),
          relative(const Duration(days: -1), ReminderRelativeTo.startDate),
        ),
        isFalse,
      );
      expect(
        sameReminder(
          relative(const Duration(days: -1), ReminderRelativeTo.dueDate),
          relative(const Duration(days: 1), ReminderRelativeTo.dueDate),
        ),
        isFalse,
      );
    });

    test('absolute by instant, whatever the time zone', () {
      final local = DateTime(2026, 10, 11, 12);
      expect(
        sameReminder(
          TaskReminder(reminder: local),
          TaskReminder(reminder: local.toUtc()),
        ),
        isTrue,
      );
      expect(
        sameReminder(
          TaskReminder(reminder: local),
          relative(Duration.zero, ReminderRelativeTo.dueDate),
        ),
        isFalse,
      );
    });

    test('lists compare as multisets', () {
      final a = relative(const Duration(days: -1), ReminderRelativeTo.dueDate);
      final b = TaskReminder(reminder: due);
      expect(sameReminders([a, b], [b, a]), isTrue);
      expect(sameReminders([a, a], [a, b]), isFalse);
      expect(sameReminders([a], [a, a]), isFalse);
      expect(sameReminders(const [], const []), isTrue);
    });
  });

  group('relative period', () {
    test('a period beyond ten thousand years either way is cut to them', () {
      expect(reminderPeriodOf(9000000000000), TaskReminder.maxRelativePeriod);
      expect(reminderPeriodOf(-9000000000000), -TaskReminder.maxRelativePeriod);
      expect(
        reminderPeriodOf(9223372036854775807),
        TaskReminder.maxRelativePeriod,
      );
      expect(reminderPeriodOf(-3600), const Duration(hours: -1));
    });

    test('any date a server writes moved by the longest period is still a '
        'date', () {
      expect(
        relativeReminderInstant(
          DateTime.utc(9999, 12, 31),
          TaskReminder.maxRelativePeriod,
        ),
        DateTime.utc(19999, 12, 31),
      );
      expect(
        relativeReminderInstant(
          DateTime.utc(1),
          -TaskReminder.maxRelativePeriod,
        ),
        DateTime.utc(-9999),
      );
    });

    test('a moment past the dates a DateTime holds is none, whatever the '
        'period', () {
      expect(
        relativeReminderInstant(
          DateTime.utc(275760, 9, 12),
          const Duration(days: 1),
        ),
        DateTime.utc(275760, 9, 13),
      );
      expect(
        relativeReminderInstant(
          DateTime.utc(275760, 9, 12),
          const Duration(days: 2),
        ),
        isNull,
      );
      expect(
        relativeReminderInstant(
          DateTime.utc(-271821, 4, 21),
          const Duration(days: -2),
        ),
        isNull,
      );
      expect(
        relativeReminderInstant(
          DateTime.utc(2026),
          const Duration(microseconds: 9223372036854775807),
        ),
        isNull,
      );
      expect(relativeReminderInstant(null, const Duration(days: 1)), isNull);
    });
  });
}
