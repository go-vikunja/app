import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';

import '../../helpers/pump_app.dart';

void main() {
  late MaterialLocalizations materialEn;
  late MaterialLocalizations materialDe;

  setUpAll(() async {
    materialEn = await GlobalMaterialLocalizations.delegate.load(
      const Locale('en'),
    );
    materialDe = await GlobalMaterialLocalizations.delegate.load(
      const Locale('de'),
    );
  });

  MomentFormatter formatter({
    bool german = false,
    DateDisplay? display,
    TimeFormat? time,
    bool device24Hour = false,
  }) => MomentFormatter(
    l10n: german ? de : en,
    material: german ? materialDe : materialEn,
    settings: DisplaySettings(dateDisplay: display, timeFormat: time),
    alwaysUse24HourFormat: device24Hour,
  );

  // The web's vectors (`formatDisplayDate`), in local wall-clock time.
  final moments = [
    DateTime(2026, 10, 19, 14, 5),
    DateTime(2026, 1, 5, 9, 7),
    DateTime(2026, 12, 31, 0, 30),
    DateTime(2026, 7, 4, 12),
  ];

  group('numeric displays, the same in English and German', () {
    const twentyFourHour = {
      DateDisplay.monthDayYearDashed: [
        '10-19-2026 14:05',
        '01-05-2026 09:07',
        '12-31-2026 00:30',
        '07-04-2026 12:00',
      ],
      DateDisplay.dayMonthYearDashed: [
        '19-10-2026 14:05',
        '05-01-2026 09:07',
        '31-12-2026 00:30',
        '04-07-2026 12:00',
      ],
      DateDisplay.yearMonthDayDashed: [
        '2026-10-19 14:05',
        '2026-01-05 09:07',
        '2026-12-31 00:30',
        '2026-07-04 12:00',
      ],
      DateDisplay.monthDayYearSlashed: [
        '10/19/2026 14:05',
        '01/05/2026 09:07',
        '12/31/2026 00:30',
        '07/04/2026 12:00',
      ],
      DateDisplay.dayMonthYearSlashed: [
        '19/10/2026 14:05',
        '05/01/2026 09:07',
        '31/12/2026 00:30',
        '04/07/2026 12:00',
      ],
      DateDisplay.yearMonthDaySlashed: [
        '2026/10/19 14:05',
        '2026/01/05 09:07',
        '2026/12/31 00:30',
        '2026/07/04 12:00',
      ],
    };
    const twelveHourTimes = ['02:05 PM', '09:07 AM', '12:30 AM', '12:00 PM'];

    for (final MapEntry(key: display, value: expected)
        in twentyFourHour.entries) {
      for (final german in [false, true]) {
        test('${display.wireName}, ${german ? 'de' : 'en'}', () {
          final at24 = formatter(
            german: german,
            display: display,
            time: TimeFormat.twentyFourHour,
          );
          final at12 = formatter(
            german: german,
            display: display,
            time: TimeFormat.twelveHour,
          );
          for (var i = 0; i < moments.length; i++) {
            expect(at24.absolute(moments[i]), expected[i]);
            final date = expected[i].split(' ').first;
            expect(at12.absolute(moments[i]), '$date ${twelveHourTimes[i]}');
          }
        });
      }
    }

    test('the rows and the sheet show the same', () {
      final dashed = formatter(
        display: DateDisplay.yearMonthDayDashed,
        time: TimeFormat.twentyFourHour,
      );
      expect(
        dashed.relative(moments.first, now: DateTime(2026, 10, 18)),
        '2026-10-19 14:05',
      );
    });
  });

  group('written displays', () {
    String join(String date, String time, {required bool german}) =>
        (german ? de : en).momentDateAtTime(date, time);

    final vectors = <(DateTime, bool, String, String, String, String)>[
      (
        moments[0],
        false,
        'October 19, 2026',
        'Monday, October 19, 2026',
        '14:05',
        '2:05 PM',
      ),
      (
        moments[0],
        true,
        '19. Oktober 2026',
        'Montag, 19. Oktober 2026',
        '14:05',
        '2:05 PM',
      ),
      (
        moments[1],
        false,
        'January 5, 2026',
        'Monday, January 5, 2026',
        '09:07',
        '9:07 AM',
      ),
      (
        moments[1],
        true,
        '5. Januar 2026',
        'Montag, 5. Januar 2026',
        '09:07',
        '9:07 AM',
      ),
      (
        moments[2],
        false,
        'December 31, 2026',
        'Thursday, December 31, 2026',
        '00:30',
        '12:30 AM',
      ),
      (
        moments[2],
        true,
        '31. Dezember 2026',
        'Donnerstag, 31. Dezember 2026',
        '00:30',
        '12:30 AM',
      ),
      (
        moments[3],
        false,
        'July 4, 2026',
        'Saturday, July 4, 2026',
        '12:00',
        '12:00 PM',
      ),
      (
        moments[3],
        true,
        '4. Juli 2026',
        'Samstag, 4. Juli 2026',
        '12:00',
        '12:00 PM',
      ),
    ];

    for (final (moment, german, date, weekdayDate, time24, time12) in vectors) {
      test('$date, ${german ? 'de' : 'en'}', () {
        for (final (time, clock) in [
          (TimeFormat.twentyFourHour, time24),
          (TimeFormat.twelveHour, time12),
        ]) {
          expect(
            formatter(
              german: german,
              display: DateDisplay.dayMonthYear,
              time: time,
            ).absolute(moment),
            join(date, clock, german: german),
          );
          expect(
            formatter(
              german: german,
              display: DateDisplay.weekdayDayMonthYear,
              time: time,
            ).absolute(moment),
            join(weekdayDate, clock, german: german),
          );
        }
      });
    }

    test("the joining words are the web's", () {
      expect(
        formatter(
          display: DateDisplay.weekdayDayMonthYear,
          time: TimeFormat.twentyFourHour,
        ).absolute(moments[0]),
        'Monday, October 19, 2026 at 14:05',
      );
      expect(
        formatter(
          german: true,
          display: DateDisplay.dayMonthYear,
          time: TimeFormat.twelveHour,
        ).absolute(moments[0]),
        '19. Oktober 2026 um 2:05 PM',
      );
    });
  });

  group('relative', () {
    final now = DateTime(2026, 10, 19, 12);

    test('"just now" within a minute either way, in both languages', () {
      final relative = formatter(display: DateDisplay.relative);
      final german = formatter(german: true, display: DateDisplay.relative);
      for (final offset in [
        Duration.zero,
        const Duration(seconds: 59),
        const Duration(seconds: -59),
        const Duration(seconds: 50),
      ]) {
        expect(relative.relative(now.add(offset), now: now), 'just now');
        expect(german.relative(now.add(offset), now: now), 'gerade eben');
      }
    });

    test("from a minute on the app's relative wording", () {
      final relative = formatter(display: DateDisplay.relative);
      final german = formatter(german: true, display: DateDisplay.relative);
      final cases = [
        (const Duration(seconds: -60), '1 minute ago', 'vor 1 Minute'),
        (const Duration(minutes: -5), '5 minutes ago', 'vor 5 Minuten'),
        (const Duration(minutes: 5), 'in 5 minutes', 'in 5 Minuten'),
        (const Duration(minutes: -44), '44 minutes ago', 'vor 44 Minuten'),
        (const Duration(hours: 2), 'in 2 hours', 'in 2 Stunden'),
        (const Duration(days: 3), 'in 3 days', 'in 3 Tagen'),
      ];
      for (final (offset, english, inGerman) in cases) {
        expect(relative.relative(now.add(offset), now: now), english);
        expect(german.relative(now.add(offset), now: now), inGerman);
      }
    });

    test('the sites that show the moment itself keep the device format', () {
      expect(
        formatter(display: DateDisplay.relative).absolute(moments[0]),
        'Oct 19, 2026 2:05 PM',
      );
    });
  });

  group('never set', () {
    final now = DateTime(2026, 10, 19, 12);

    test("relative sites keep today's wording, with 45 s for now", () {
      final unset = formatter();
      expect(
        unset.relative(now.add(const Duration(seconds: 30)), now: now),
        'now',
      );
      expect(
        unset.relative(now.subtract(const Duration(seconds: 50)), now: now),
        '1 minute ago',
      );
      expect(formatter(german: true).relative(now, now: now), de.relativeNow);
    });

    test("absolute sites keep the device's short date and clock", () {
      expect(formatter().absolute(moments[0]), 'Oct 19, 2026 2:05 PM');
      expect(
        formatter(device24Hour: true).absolute(moments[0]),
        'Oct 19, 2026 14:05',
      );
      expect(
        formatter(german: true).absolute(moments[0]),
        '19. Okt. 2026 14:05',
      );
    });

    test('screen readers keep what each place read out', () {
      expect(formatter().semanticsLabel(moments[0]), isNull);
      expect(
        formatter(time: TimeFormat.twelveHour).semanticsLabel(moments[0]),
        isNull,
      );
    });

    test("a picked display without a clock follows the device's", () {
      expect(
        formatter(display: DateDisplay.monthDayYearSlashed)
            .absolute(moments[0]),
        '10/19/2026 02:05 PM',
      );
      expect(
        formatter(
          display: DateDisplay.monthDayYearSlashed,
          device24Hour: true,
        ).absolute(moments[0]),
        '10/19/2026 14:05',
      );
      expect(
        formatter(
          german: true,
          display: DateDisplay.dayMonthYear,
        ).absolute(moments[0]),
        '19. Oktober 2026 um 14:05',
      );
    });
  });

  group('time format alone', () {
    test("changes the clock of the app's own formats", () {
      expect(
        formatter(time: TimeFormat.twentyFourHour).absolute(moments[0]),
        'Oct 19, 2026 14:05',
      );
      expect(
        formatter(
          german: true,
          time: TimeFormat.twelveHour,
        ).absolute(moments[0]),
        '19. Okt. 2026 2:05 PM',
      );
      expect(
        formatter(
          german: true,
          time: TimeFormat.twelveHour,
        ).timeOfDay(moments[1]),
        '9:07 AM',
      );
    });

    test('decides the clock of the web formats', () {
      expect(formatter().uses24HourFormat, isFalse);
      expect(formatter(device24Hour: true).uses24HourFormat, isTrue);
      expect(formatter(german: true).uses24HourFormat, isTrue);
      expect(
        formatter(german: true, time: TimeFormat.twelveHour).uses24HourFormat,
        isFalse,
      );
      expect(
        formatter(time: TimeFormat.twentyFourHour).uses24HourFormat,
        isTrue,
      );
    });
  });

  test('screen readers get the long date with the weekday once a display is '
      'picked, with the clock of the time format', () {
    for (final display in DateDisplay.values) {
      expect(
        formatter(
          display: display,
          time: TimeFormat.twentyFourHour,
        ).semanticsLabel(moments[0]),
        'Monday, October 19, 2026 at 14:05',
      );
    }
    expect(
      formatter(
        german: true,
        display: DateDisplay.yearMonthDayDashed,
        time: TimeFormat.twelveHour,
      ).semanticsLabel(moments[2]),
      'Donnerstag, 31. Dezember 2026 um 12:30 AM',
    );
  });

  test("week start: only 1–6 replace the locale's first day", () {
    expect(const DisplaySettings().firstDayOfWeekIndex, isNull);
    expect(const DisplaySettings(weekStart: 1).firstDayOfWeekIndex, 1);
    expect(const DisplaySettings(weekStart: 6).firstDayOfWeekIndex, 6);
    expect(const DisplaySettings(weekStart: 7).firstDayOfWeekIndex, isNull);
  });
}
