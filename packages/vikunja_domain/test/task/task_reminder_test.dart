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
}
