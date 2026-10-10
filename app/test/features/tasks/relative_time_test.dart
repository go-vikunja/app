import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/overview/application/due_date_groups.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);

  String relative(Duration offset, {bool german = false}) =>
      formatRelativeTime(german ? de : en, now.add(offset), now: now);

  test('rounds like the web for every unit, both directions', () {
    expect(relative(Duration.zero), 'now');
    expect(relative(const Duration(seconds: 44)), 'now');
    expect(relative(const Duration(seconds: -44)), 'now');
    expect(relative(const Duration(seconds: 45)), 'in 1 minute');
    expect(relative(const Duration(minutes: 5)), 'in 5 minutes');
    expect(relative(const Duration(minutes: -5)), '5 minutes ago');
    expect(relative(const Duration(minutes: 44)), 'in 44 minutes');
    expect(relative(const Duration(minutes: 45)), 'in 1 hour');
    expect(relative(const Duration(hours: 3)), 'in 3 hours');
    expect(relative(const Duration(hours: -21)), '21 hours ago');
    expect(relative(const Duration(hours: 22)), 'in 1 day');
    expect(relative(const Duration(days: 3)), 'in 3 days');
    expect(relative(const Duration(days: -2)), '2 days ago');
    expect(relative(const Duration(days: 25)), 'in 25 days');
    expect(relative(const Duration(days: 26)), 'in 1 month');
    expect(relative(const Duration(days: 60)), 'in 2 months');
    expect(relative(const Duration(days: -300)), '10 months ago');
    expect(relative(const Duration(days: 330)), 'in 1 year');
    expect(relative(const Duration(days: 800)), 'in 2 years');
  });

  test('German', () {
    expect(relative(const Duration(days: 3), german: true), 'in 3 Tagen');
    expect(relative(const Duration(days: -1), german: true), 'vor 1 Tag');
    expect(relative(const Duration(hours: -2), german: true), 'vor 2 Stunden');
  });

  test('from a day on the count follows the calendar day', () {
    String at(DateTime now, DateTime moment) =>
        formatRelativeTime(en, moment, now: now);
    final afterMidnight = DateTime(2026, 10, 10, 0, 30);
    expect(at(afterMidnight, DateTime(2026, 10, 10, 23, 59)), 'in 23 hours');
    expect(at(afterMidnight, DateTime(2026, 10, 11, 0, 30)), 'in 1 day');
    expect(at(afterMidnight, DateTime(2026, 10, 8, 23, 30)), '2 days ago');
    final morning = DateTime(2026, 10, 10, 8);
    expect(at(morning, DateTime(2026, 10, 17, 23)), 'in 7 days');
    expect(at(morning, DateTime(2026, 10, 18, 1)), 'in 8 days');
    expect(
      at(DateTime(2026, 10, 10, 23), DateTime(2026, 10, 11, 1)),
      'in 2 hours',
    );
    expect(
      formatRelativeTime(
        de,
        DateTime(2026, 10, 10, 23, 59),
        now: afterMidnight,
      ),
      'in 23 Stunden',
    );
  });

  test('agrees with the overview sections at the day boundaries', () {
    final cases = [
      (
        DateTime(2026, 10, 10, 0, 30),
        DateTime(2026, 10, 10, 23, 59),
        DueGroup.today,
        'in 23 hours',
      ),
      (
        DateTime(2026, 10, 10, 8),
        DateTime(2026, 10, 17, 23),
        DueGroup.nextSevenDays,
        'in 7 days',
      ),
      (
        DateTime(2026, 10, 10, 8),
        DateTime(2026, 10, 18, 1),
        DueGroup.later,
        'in 8 days',
      ),
      (
        DateTime(2026, 10, 10, 0, 30),
        DateTime(2026, 10, 8, 23, 30),
        DueGroup.overdue,
        '2 days ago',
      ),
    ];
    for (final (now, due, group, label) in cases) {
      final task = sampleTask(id: 1, title: 'a', due: due);
      expect(groupTasksByDueDate([task], now).single.group, group);
      expect(formatRelativeTime(en, due, now: now), label);
    }
  });
}
