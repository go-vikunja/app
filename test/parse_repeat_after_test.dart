import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/repeat_after_parse.dart';
import 'package:vikunja_app/core/utils/repeat_after_unit.dart';

void main() {
  test('Repeat after hours', () {
    Duration testDuration = Duration(hours: 6);

    expect(getRepeatAfterTypeFromDuration(testDuration), RepeatAfterUnit.HOURS);
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after days', () {
    Duration testDuration = Duration(days: 6);

    expect(getRepeatAfterTypeFromDuration(testDuration), RepeatAfterUnit.DAYS);
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after weeks', () {
    Duration testDuration = Duration(days: 6 * 7);

    expect(getRepeatAfterTypeFromDuration(testDuration), RepeatAfterUnit.WEEKS);
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after months', () {
    Duration testDuration = Duration(days: 6 * 30);

    expect(
      getRepeatAfterTypeFromDuration(testDuration),
      RepeatAfterUnit.MONTHS,
    );
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after years', () {
    Duration testDuration = Duration(days: 6 * 365);

    expect(getRepeatAfterTypeFromDuration(testDuration), RepeatAfterUnit.YEARS);
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat null value', () {
    Duration testDuration = Duration();

    expect(getRepeatAfterTypeFromDuration(testDuration), RepeatAfterUnit.HOURS);
    expect(getRepeatAfterValueFromDuration(testDuration), 0);
  });

  test('Hours to duration', () {
    Duration? parsedDuration = RepeatAfterUnit.HOURS.getDuration(6);
    expect(parsedDuration, Duration(hours: 6));
  });

  test('Days to duration', () {
    Duration? parsedDuration = RepeatAfterUnit.DAYS.getDuration(6);
    expect(parsedDuration, Duration(days: 6));
  });

  test('Weeks to duration', () {
    Duration? parsedDuration = RepeatAfterUnit.WEEKS.getDuration(6);
    expect(parsedDuration, Duration(days: 6 * 7));
  });

  test('Months to duration', () {
    Duration? parsedDuration = RepeatAfterUnit.MONTHS.getDuration(6);
    expect(parsedDuration, Duration(days: 6 * 30));
  });

  test('Years to duration', () {
    Duration? parsedDuration = RepeatAfterUnit.YEARS.getDuration(6);
    expect(parsedDuration, Duration(days: 6 * 365));
  });
}
