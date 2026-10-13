import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/upcoming/application/upcoming_sections.dart';

import '../../helpers/sample_data.dart';

void main() {
  test('overdue first, then one section per local day in the selection '
      'order, then the tasks without a due date', () {
    final overdue = sampleTask(
      id: 1,
      title: 'Late',
      due: DateTime(2026, 10, 12),
    );
    final morning = sampleTask(
      id: 2,
      title: 'Morning',
      due: DateTime(2026, 10, 14, 8),
    );
    final evening = sampleTask(
      id: 3,
      title: 'Evening',
      due: DateTime(2026, 10, 14, 23, 30),
    );
    final later = sampleTask(
      id: 4,
      title: 'Later',
      due: DateTime(2026, 10, 16),
    );
    final undated = sampleTask(id: 5, title: 'Someday');

    final sections = upcomingSections(
      UpcomingSelection(
        overdue: [overdue],
        inRange: [morning, evening, later],
        withoutDueDate: [undated],
      ),
    );

    expect(sections, hasLength(4));
    expect(sections[0], isA<OverdueSection>());
    expect(sections[0].tasks, [overdue]);
    expect((sections[1] as DaySection).day, DateTime(2026, 10, 14));
    expect(sections[1].tasks, [morning, evening]);
    expect((sections[2] as DaySection).day, DateTime(2026, 10, 16));
    expect(sections[3], isA<WithoutDueDateSection>());
  });

  test('empty parts leave no section', () {
    expect(upcomingSections(const UpcomingSelection()), isEmpty);
  });

  test('a range ending at midnight ends the day before', () {
    expect(
      daysOf(
        DateRange(from: DateTime(2026, 10, 12), to: DateTime(2026, 10, 19)),
      ),
      (DateTime(2026, 10, 12), DateTime(2026, 10, 18)),
    );
    expect(
      daysOf(
        DateRange(
          from: DateTime(2026, 10, 13, 9, 30),
          to: DateTime(2026, 10, 20, 9, 30),
        ),
      ),
      (DateTime(2026, 10, 13), DateTime(2026, 10, 20)),
    );
    expect(
      daysOf(
        DateRange(from: DateTime(2026, 10, 13), to: DateTime(2026, 10, 14)),
      ),
      (DateTime(2026, 10, 13), DateTime(2026, 10, 13)),
    );
  });
}
