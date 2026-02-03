import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/repeat_after_parse.dart';

void main() {
  test('Repeat after hours', () {
    Duration testDuration = Duration(hours: 6);

    expect(getRepeatAfterTypeFromDuration(testDuration), 0);
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after days', () {
    Duration testDuration = Duration(days: 6);

    expect(getRepeatAfterTypeFromDuration(testDuration), 1);
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after weeks', () {
    Duration testDuration = Duration(days: 6 * 7);

    expect(getRepeatAfterTypeFromDuration(testDuration), 2);
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after months', () {
    Duration testDuration = Duration(days: 6 * 30);

    expect(getRepeatAfterTypeFromDuration(testDuration), 3);
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat after years', () {
    Duration testDuration = Duration(days: 6 * 365);

    expect(getRepeatAfterTypeFromDuration(testDuration), 4);
    expect(getRepeatAfterValueFromDuration(testDuration), 6);
  });

  test('Repeat null value', () {
    Duration testDuration = Duration();

    expect(getRepeatAfterTypeFromDuration(testDuration), 0);
    expect(getRepeatAfterValueFromDuration(testDuration), 0);
  });

  test('Hours to duration', () {
    Duration? parsedDuration = getDurationFromType(6, 0);
    expect(parsedDuration, Duration(hours: 6));
  });

  test('Days to duration', () {
    Duration? parsedDuration = getDurationFromType(6, 1);
    expect(parsedDuration, Duration(days: 6));
  });

  test('Weeks to duration', () {
    Duration? parsedDuration = getDurationFromType(6, 2);
    expect(parsedDuration, Duration(days: 6 * 7));
  });

  test('Months to duration', () {
    Duration? parsedDuration = getDurationFromType(6, 3);
    expect(parsedDuration, Duration(days: 6 * 30));
  });

  test('Years to duration', () {
    Duration? parsedDuration = getDurationFromType(6, 4);
    expect(parsedDuration, Duration(days: 6 * 365));
  });
}
