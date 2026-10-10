import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/overview/application/due_date_groups.dart';

import '../../helpers/sample_data.dart';

void main() {
  // A Saturday noon, local time.
  final now = DateTime(2026, 10, 10, 12);

  test('splits tasks into the overview sections by local calendar day', () {
    final sections = groupTasksByDueDate([
      sampleTask(id: 1, title: 'later', due: now.add(const Duration(days: 8))),
      sampleTask(id: 2, title: 'none'),
      sampleTask(
        id: 3,
        title: 'overdue',
        due: now.subtract(const Duration(minutes: 1)),
      ),
      sampleTask(id: 4, title: 'tonight', due: DateTime(2026, 10, 10, 23, 59)),
      sampleTask(id: 5, title: 'week', due: DateTime(2026, 10, 17, 23, 59)),
      sampleTask(id: 6, title: 'yesterday', due: DateTime(2026, 10, 9, 23, 59)),
      sampleTask(id: 7, title: 'tomorrow', due: DateTime(2026, 10, 11)),
      sampleTask(
        id: 8,
        title: 'done late',
        due: DateTime(2026, 10, 9),
        done: true,
      ),
    ], now);

    expect(
      {
        for (final section in sections)
          section.group: section.tasks.map((t) => t.title).toList(),
      },
      {
        DueGroup.overdue: ['overdue', 'yesterday', 'done late'],
        DueGroup.today: ['tonight'],
        DueGroup.nextSevenDays: ['week', 'tomorrow'],
        DueGroup.later: ['later'],
        DueGroup.noDueDate: ['none'],
      },
    );
  });

  test('leaves out empty sections and keeps the section order', () {
    final sections = groupTasksByDueDate([
      sampleTask(id: 1, title: 'a'),
      sampleTask(id: 2, title: 'b', due: now.add(const Duration(hours: 1))),
    ], now);

    expect(sections.map((s) => s.group), [DueGroup.today, DueGroup.noDueDate]);
  });

  test('a due date just after midnight counts as that day', () {
    final sections = groupTasksByDueDate([
      sampleTask(id: 1, title: 'a', due: DateTime(2026, 10, 18, 0, 0, 1)),
    ], now);

    expect(sections.single.group, DueGroup.later);
  });

  test('nothing to group gives no sections', () {
    expect(groupTasksByDueDate(const [], now), isEmpty);
  });
}
