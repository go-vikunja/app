import 'package:test/test.dart';
import 'package:vikunja_app/core/utils/repeat_after_parse.dart';

void main() {
  test('Repeat after hours', () {
    Duration testDuration = Duration(hours: 6);

    expect(getRepeatAfterTypeFromDuration(testDuration), 'Hours');
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after days', () {
    Duration testDuration = Duration(days: 6);

    expect(getRepeatAfterTypeFromDuration(testDuration), 'Days');
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after weeks', () {
    Duration testDuration = Duration(days: 6 * 7);

    expect(getRepeatAfterTypeFromDuration(testDuration), 'Weeks');
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after months', () {
    Duration testDuration = Duration(days: 6 * 30);

    expect(getRepeatAfterTypeFromDuration(testDuration), 'Months');
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after years', () {
    Duration testDuration = Duration(days: 6 * 365);

    expect(getRepeatAfterTypeFromDuration(testDuration), 'Years');
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat null value', () {
    Duration testDuration = Duration();

    expect(getRepeatAfterTypeFromDuration(testDuration), null);
    expect(getRepeatAfterValueFromDuration(testDuration), null);
  });

  test('Hours to duration', () {
    Duration? parsedDuration = getDurationFromType('6', 'Hours');
    expect(parsedDuration, Duration(hours: 6));
  });

  test('Days to duration', () {
    Duration? parsedDuration = getDurationFromType('6', 'Days');
    expect(parsedDuration, Duration(days: 6));
  });

  test('Weeks to duration', () {
    Duration? parsedDuration = getDurationFromType('6', 'Weeks');
    expect(parsedDuration, Duration(days: 6 * 7));
  });

  test('Months to duration', () {
    Duration? parsedDuration = getDurationFromType('6', 'Months');
    expect(parsedDuration, Duration(days: 6 * 30));
  });

  test('Years to duration', () {
    Duration? parsedDuration = getDurationFromType('6', 'Years');
    expect(parsedDuration, Duration(days: 6 * 365));
  });

  test('null to duration', () {
    Duration? parsedDuration = getDurationFromType(null, null);
    expect(parsedDuration, Duration());
  });
}
