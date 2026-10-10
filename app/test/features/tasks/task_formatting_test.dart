import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  test('periods use the largest unit that divides evenly', () {
    expect(formatPeriod(en, const Duration(days: 14)), '2 weeks');
    expect(formatPeriod(en, const Duration(days: 30)), '30 days');
    expect(formatPeriod(en, const Duration(days: 1)), '1 day');
    expect(formatPeriod(en, const Duration(hours: 36)), '36 hours');
    expect(formatPeriod(en, const Duration(minutes: 90)), '90 minutes');
    expect(formatPeriod(en, const Duration(seconds: 90)), '90 seconds');
    expect(formatPeriod(en, Duration.zero), '0 seconds');
    expect(formatPeriod(de, const Duration(days: 7)), '1 Woche');
  });

  test('repeat summaries', () {
    String repeat(
      Duration after, {
      RepeatMode mode = RepeatMode.afterAmount,
      bool german = false,
    }) => formatRepeat(
      german ? de : en,
      sampleTask(id: 1, title: 'a', repeatAfter: after, repeatMode: mode),
    )!;

    expect(formatRepeat(en, sampleTask(id: 1, title: 'a')), isNull);
    expect(repeat(const Duration(days: 1)), 'Every day');
    expect(repeat(const Duration(days: 3)), 'Every 3 days');
    expect(repeat(const Duration(days: 7)), 'Every week');
    expect(repeat(const Duration(days: 14)), 'Every 2 weeks');
    expect(repeat(const Duration(hours: 1)), 'Every hour');
    expect(repeat(const Duration(hours: 36)), 'Every 36 hours');
    expect(repeat(const Duration(minutes: 90)), 'Every 90 minutes');
    expect(repeat(const Duration(days: 1), german: true), 'Jeden Tag');
    expect(repeat(const Duration(days: 3), german: true), 'Alle 3 Tage');
    expect(repeat(const Duration(days: 7), german: true), 'Jede Woche');
    expect(repeat(const Duration(days: 14), german: true), 'Alle 2 Wochen');
    expect(repeat(const Duration(hours: 1), german: true), 'Jede Stunde');
    expect(
      repeat(
        const Duration(days: 1),
        mode: RepeatMode.fromCurrentDate,
        german: true,
      ),
      'Jeden Tag, gerechnet ab dem Erledigen',
    );
    expect(
      formatRepeat(
        en,
        sampleTask(id: 1, title: 'a', repeatMode: RepeatMode.monthly),
      ),
      'Every month',
    );
    expect(
      formatRepeat(
        en,
        sampleTask(
          id: 1,
          title: 'a',
          repeatAfter: const Duration(days: 14),
          repeatMode: RepeatMode.fromCurrentDate,
        ),
      ),
      'Every 2 weeks, counted from completion',
    );
  });

  test('reminders, relative and absolute', () {
    String absolute(DateTime moment) => 'at ${moment.toIso8601String()}';
    expect(
      formatReminder(
        en,
        const TaskReminder(
          relativePeriod: Duration(hours: -1),
          relativeTo: ReminderRelativeTo.dueDate,
        ),
        formatAbsolute: absolute,
      ),
      '1 hour before the due date',
    );
    expect(
      formatReminder(
        en,
        const TaskReminder(
          relativePeriod: Duration(days: 2),
          relativeTo: ReminderRelativeTo.startDate,
        ),
        formatAbsolute: absolute,
      ),
      '2 days after the start date',
    );
    expect(
      formatReminder(
        en,
        const TaskReminder(relativeTo: ReminderRelativeTo.endDate),
        formatAbsolute: absolute,
      ),
      'At the end date',
    );
    expect(
      formatReminder(
        en,
        TaskReminder(reminder: DateTime.utc(2026, 10, 10, 8)),
        formatAbsolute: absolute,
      ),
      'at 2026-10-10T08:00:00.000Z',
    );
  });

  test('priority labels', () {
    expect(priorityLabel(en, TaskPriority.doNow), 'Do now');
    expect(priorityLabel(de, TaskPriority.urgent), 'Dringend');
  });
}
