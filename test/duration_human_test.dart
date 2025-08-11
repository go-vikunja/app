import 'package:test/test.dart';
import 'package:vikunja_app/core/utils/misc.dart';

void main() {
  group('Duration to human readable tests', () {
    group('Positive durations (future)', () {
      test('Less than a minute should return "in less than a minute"', () {
        expect(durationToHumanReadable(Duration(seconds: 30)),
            "in less than a minute");
        expect(durationToHumanReadable(Duration(seconds: 59)),
            "in less than a minute");
        expect(durationToHumanReadable(Duration(seconds: 0)),
            "in less than a minute");
      });

      test('Exactly 1 minute should return "in 1 minute"', () {
        expect(durationToHumanReadable(Duration(minutes: 1)), "in 1 minute");
      });

      test('Multiple minutes should return "in X minutes"', () {
        expect(durationToHumanReadable(Duration(minutes: 2)), "in 2 minutes");
        expect(durationToHumanReadable(Duration(minutes: 30)), "in 30 minutes");
        expect(durationToHumanReadable(Duration(minutes: 59)), "in 59 minutes");
      });

      test('Exactly 1 hour should return "in 1 hour"', () {
        expect(durationToHumanReadable(Duration(hours: 1)), "in 1 hour");
      });

      test('Multiple hours should return "in X hours"', () {
        expect(durationToHumanReadable(Duration(hours: 2)), "in 2 hours");
        expect(durationToHumanReadable(Duration(hours: 12)), "in 12 hours");
        expect(durationToHumanReadable(Duration(hours: 23)), "in 23 hours");
      });

      test('Exactly 1 day should return "in 1 day"', () {
        expect(durationToHumanReadable(Duration(days: 1)), "in 1 day");
      });

      test('Multiple days should return "in X days"', () {
        expect(durationToHumanReadable(Duration(days: 2)), "in 2 days");
        expect(durationToHumanReadable(Duration(days: 7)), "in 7 days");
        expect(durationToHumanReadable(Duration(days: 365)), "in 365 days");
      });
    });

    group('Negative durations (past)', () {
      test('Less than a minute ago should return "less than a minute ago"', () {
        expect(durationToHumanReadable(Duration(seconds: -30)),
            "less than a minute ago");
        expect(durationToHumanReadable(Duration(seconds: -59)),
            "less than a minute ago");
      });

      test('Exactly 1 minute ago should return "1 minute ago"', () {
        expect(durationToHumanReadable(Duration(minutes: -1)), "1 minute ago");
      });

      test('Multiple minutes ago should return "X minutes ago"', () {
        expect(durationToHumanReadable(Duration(minutes: -2)), "2 minutes ago");
        expect(
            durationToHumanReadable(Duration(minutes: -30)), "30 minutes ago");
        expect(
            durationToHumanReadable(Duration(minutes: -59)), "59 minutes ago");
      });

      test('Exactly 1 hour ago should return "1 hour ago"', () {
        expect(durationToHumanReadable(Duration(hours: -1)), "1 hour ago");
      });

      test('Multiple hours ago should return "X hours ago"', () {
        expect(durationToHumanReadable(Duration(hours: -2)), "2 hours ago");
        expect(durationToHumanReadable(Duration(hours: -12)), "12 hours ago");
        expect(durationToHumanReadable(Duration(hours: -23)), "23 hours ago");
      });

      test('Exactly 1 day ago should return "1 day ago"', () {
        expect(durationToHumanReadable(Duration(days: -1)), "1 day ago");
      });

      test('Multiple days ago should return "X days ago"', () {
        expect(durationToHumanReadable(Duration(days: -2)), "2 days ago");
        expect(durationToHumanReadable(Duration(days: -7)), "7 days ago");
        expect(durationToHumanReadable(Duration(days: -365)), "365 days ago");
      });
    });

    group('Edge cases and precedence', () {
      test('Duration with hours and minutes should prioritize larger unit', () {
        expect(durationToHumanReadable(Duration(hours: 2, minutes: 30)),
            "in 2 hours");
        expect(durationToHumanReadable(Duration(hours: -5, minutes: -15)),
            "5 hours ago");
      });

      test('Duration with days and hours should prioritize days', () {
        expect(
            durationToHumanReadable(Duration(days: 3, hours: 12)), "in 3 days");
        expect(durationToHumanReadable(Duration(days: -1, hours: -6)),
            "1 day ago");
      });

      test('Duration with mixed components should use largest unit', () {
        expect(
            durationToHumanReadable(
                Duration(days: 1, hours: 23, minutes: 59, seconds: 59)),
            "in 1 day");
        expect(
            durationToHumanReadable(
                Duration(days: -2, hours: -1, minutes: -30)),
            "2 days ago");
      });

      test('Very large durations should work correctly', () {
        expect(durationToHumanReadable(Duration(days: 1000)), "in 1000 days");
        expect(durationToHumanReadable(Duration(days: -9999)), "9999 days ago");
      });
    });
  });
}
