import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/repeat_after_unit.dart';

void main() {
  group('RepeatAfterUnit.getDuration', () {
    test('maps each unit onto its duration', () {
      expect(RepeatAfterUnit.hours.getDuration(5), const Duration(hours: 5));
      expect(RepeatAfterUnit.days.getDuration(5), const Duration(days: 5));
      expect(RepeatAfterUnit.weeks.getDuration(2), const Duration(days: 14));
      expect(RepeatAfterUnit.months.getDuration(2), const Duration(days: 60));
      expect(RepeatAfterUnit.years.getDuration(2), const Duration(days: 730));
    });

    test('a zero value yields a zero duration for every unit', () {
      for (final unit in RepeatAfterUnit.values) {
        expect(unit.getDuration(0), Duration.zero, reason: '$unit');
      }
    });
  });
}
