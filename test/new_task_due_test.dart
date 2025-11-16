import 'package:test/test.dart';
import 'package:vikunja_app/domain/entities/new_task_due.dart';

void main() {
  group('NewTaskDue.calculateDate', () {
    test('none returns null', () {
      final now = DateTime(2025, 11, 10, 8, 30);
      expect(NewTaskDue.none.calculateDate(now), isNull);
    });

    test('today returns date with rounded hour', () {
      final base = DateTime(2025, 11, 10, 10, 15); // Monday 10:15 -> nearest 12
      final result = NewTaskDue.today.calculateDate(base);
      expect(result, isNotNull);
      expect(result!.year, base.year);
      expect(result.month, base.month);
      expect(result.day, base.day);
      expect(result.hour, 12);
      expect(result.minute, 0);
    });

    test('tomorrow adds one day preserving rounded hour', () {
      final base = DateTime(2025, 11, 10, 16, 0); // Monday 16:00 -> nearest 18
      final result = NewTaskDue.tomorrow.calculateDate(base);
      expect(result!.day, base.day + 1);
      expect(result.hour, 18);
    });

    test('next_monday when today is Monday returns same day', () {
      final monday = DateTime(2025, 11, 10, 7, 0); // Monday 07:00 -> nearest 9
      final result = NewTaskDue.next_monday.calculateDate(monday);
      expect(result!.day, monday.day);
      expect(result.hour, 9);
    });

    test('next_monday when today is Wednesday returns next Monday', () {
      final wednesday = DateTime(
        2025,
        11,
        12,
        13,
        0,
      ); // Wednesday 13:00 -> nearest 15
      final result = NewTaskDue.next_monday.calculateDate(wednesday);
      expect(result!.day, wednesday.day + 5); // Wednesday -> next Monday
      expect(result.weekday, DateTime.monday);
      expect(result.hour, 15);
    });

    test('weekend when today is Monday returns Saturday', () {
      final monday = DateTime(
        2025,
        11,
        10,
        11,
        0,
      ); // Monday 11:00 -> nearest 12
      final result = NewTaskDue.weekend.calculateDate(monday);
      expect(result!.weekday, DateTime.saturday);
      expect(result.day, monday.day + 5);
      expect(result.hour, 12);
    });

    test('weekend when today is Saturday returns today', () {
      final saturday = DateTime(
        2025,
        11,
        15,
        20,
        0,
      ); // Saturday 20:00 -> nearest 21
      final result = NewTaskDue.weekend.calculateDate(saturday);
      expect(result!.day, saturday.day);
      expect(result.hour, 21);
    });

    test('later_this_week early in week adds two days', () {
      final tuesday = DateTime(
        2025,
        11,
        11,
        14,
        59,
      ); // Tuesday 14:59 -> nearest 15
      final result = NewTaskDue.later_this_week.calculateDate(tuesday);
      expect(result!.day, tuesday.day + 2);
      expect(result.hour, 15);
    });

    test('later_this_week on Friday returns same day', () {
      final friday = DateTime(2025, 11, 14, 8, 0); // Friday 08:00 -> nearest 9
      final result = NewTaskDue.later_this_week.calculateDate(friday);
      expect(result!.day, friday.day);
      expect(result.hour, 9);
    });

    test('next_week adds seven days', () {
      final base = DateTime(2025, 11, 10, 17, 30); // Monday 17:30 -> nearest 18
      final result = NewTaskDue.next_week.calculateDate(base);
      expect(result!.day, base.day + 7);
      expect(result.hour, 18);
    });

    test('custom returns exact current time', () {
      final base = DateTime(2025, 11, 10, 10, 34, 12, 123, 456);
      final result = NewTaskDue.custom.calculateDate(base);
      expect(result, base);
    });
  });

  group('NewTaskDue.calculateNearestHours boundaries', () {
    void check(int hour, int minute, int expected) {
      final base = DateTime(2025, 11, 10, hour, minute);
      expect(
        NewTaskDue.today.calculateNearestHours(base),
        expected,
        reason: 'At $hour:$minute expected $expected',
      );
    }

    test('hour rounding cases', () {
      check(9, 0, 9); // <=9
      check(9, 1, 9); // still 9 because logic uses hour <= 9
      check(11, 59, 12);
      check(12, 0, 15);
      check(14, 59, 15);
      check(15, 0, 18);
      check(17, 59, 18);
      check(18, 0, 21);
      check(20, 59, 21);
      check(21, 0, 9); // >=21 -> 9
      check(23, 59, 9);
    });
  });
}
