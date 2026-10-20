import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'filter_test_support.dart';

final DateTime _now = utc('2026-10-20T08:05:00Z');

DateTime? _date(String value, [String zoneName = 'UTC']) =>
    parseFilterDate(value, now: _now, location: zone(zoneName));

void main() {
  setUpAll(loadTimeZones);

  group('the server tries datemath, then its own layouts', () {
    final cases = <String, String>{
      // go-datemath
      'now': '2026-10-20T08:05:00Z',
      'now/d+1d': '2026-10-21T00:00:00Z',
      '2026': '2026-01-01T00:00:00Z',
      '2026-10-20T22:00': '2026-10-20T22:00:00Z',
      '2026-10-20T22:00:00.000Z': '2026-10-20T22:00:00Z',
      '1544500000': '1970-01-18T21:01:40Z',
      // RFC 3339 beyond datemath: a one-digit hour, long or comma fractions.
      '2026-10-20T9:00:00Z': '2026-10-20T09:00:00Z',
      '2026-10-20T09:00:00.123456Z': '2026-10-20T09:00:00.123456Z',
      '2026-10-20T09:00:00,5+01:00': '2026-10-20T08:00:00.500Z',
      // 2006-01-02 15:04, the hour again one or two digits.
      '2026-10-20 22:00': '2026-10-20T22:00:00Z',
      '2026-10-20 9:05': '2026-10-20T09:05:00Z',
      // Go matches the layout's space with any run of spaces.
      '2026-10-20  22:00': '2026-10-20T22:00:00Z',
      '2026-10-20   9:05': '2026-10-20T09:05:00Z',
      // The lenient Y-M-D rolls over and ignores what follows a third dash.
      '2026-10-1': '2026-10-01T00:00:00Z',
      '2026-13-01': '2027-01-01T00:00:00Z',
      '2023-02-30': '2023-03-02T00:00:00Z',
      '2023-2-5-later': '2023-02-05T00:00:00Z',
      '2023-+2-5': '2023-02-05T00:00:00Z',
      '2023-0-0': '2022-11-30T00:00:00Z',
      // Trimmed like Go's TrimSpace.
      ' 2026-10-20 ': '2026-10-20T00:00:00Z',
    };
    for (final MapEntry(key: value, value: expected) in cases.entries) {
      test("'$value'", () {
        expect(_date(value), utc(expected));
      });
    }
  });

  group('refused values', () {
    for (final value in [
      '',
      '0',
      '123',
      'tomorrow',
      'NOW',
      'now+1D',
      'now+',
      'now/x',
      'now + 1d',
      '2026/10/20',
      '20.10.2026',
      '2026-10-20 21:30:00',
      '2026-10-20\t22:00',
      '2026-10-20 \t22:00',
      '2026-10-2022:00',
      '2026-10-20T21:30:00+0200',
      '2026-10-20T25:00:00Z',
      '2023--5-1',
      '2023-2',
      '﻿2026-10-20',
    ]) {
      test("'$value'", () {
        expect(FilterDate.tryParse(value), isNull);
        expect(_date(value), isNull);
      });
    }
  });

  group('zones', () {
    test('wall times and dates sit in the location', () {
      expect(_date('2026-10-20', 'Europe/Berlin'), utc('2026-10-19T22:00:00Z'));
      expect(
        _date('2026-10-20 22:00', 'Europe/Berlin'),
        utc('2026-10-20T20:00:00Z'),
      );
      expect(
        _date('2026-13-01', 'America/New_York'),
        utc('2027-01-01T05:00:00Z'),
      );
      expect(
        _date('2026-10-20T22:00:00+02:00', 'America/New_York'),
        utc('2026-10-20T20:00:00Z'),
      );
    });

    test('answers UTC', () {
      expect(_date('now/d', 'Europe/Berlin')!.isUtc, isTrue);
    });
  });

  group('years before 1 are lifted to year 1', () {
    test('January 1 becomes January 2', () {
      expect(_date('0000-01-01'), DateTime.utc(1, 1, 2));
      expect(_date('0000-01-01 00:00'), DateTime.utc(1, 1, 2));
    });

    test('other days keep their date', () {
      expect(_date('0000-06-15'), DateTime.utc(1, 6, 15));
      expect(_date('now-3000y'), DateTime.utc(1, 10, 20, 8, 5));
    });

    test('so "> 0000-01-01" means having a date', () {
      final early = FilterableTask(
        id: 1,
        projectId: 1,
        dueDate: DateTime.utc(1900),
      );
      const undated = FilterableTask(id: 2, projectId: 1);
      final context = FilterContext(now: _now, location: zone('Europe/Berlin'));
      final expression = parsed('due_date > 0000-01-01');

      expect(matchesFilter(expression, early, context), isTrue);
      expect(matchesFilter(expression, undated, context), isFalse);
    });
  });

  test('a result beyond DateTime parses but resolves to nothing', () {
    final date = FilterDate.tryParse('now+999999999y');

    expect(date, isNotNull);
    expect(date!.resolve(_now, zone('UTC')), isNull);
    expect(
      FilterDate.tryParse('99999-01-01')!.resolve(_now, zone('UTC')),
      isNotNull,
    );
  });

  test('dates are equal by their text', () {
    expect(FilterDate.tryParse('now/d'), FilterDate.tryParse(' now/d '));
    expect(FilterDate.tryParse('now/d'), isNot(FilterDate.tryParse('now/w')));
  });
}
