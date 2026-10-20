// Follows go-datemath, Copyright (c) 2019, Timber Technologies, Inc., ISC
// License; see THIRD_PARTY_NOTICES.md in this package.

import 'package:vikunja_logic/src/time/wall_clock.dart';

/// A parsed go-datemath expression.
final class Datemath {
  const new _(this._anchor, this._operations);

  /// Null when [source] is not go-datemath; blanks included.
  static Datemath? tryParse(String source) => _DatemathReader(source).read();

  final _Anchor _anchor;
  final List<_Operation> _operations;

  bool get isRelative => _anchor is _Now;

  /// The instant, presented in [clock]'s zone; null when it leaves
  /// DateTime's range.
  DateTime? evaluate(DateTime now, WallClock clock) {
    var time = _anchor.resolve(now, clock);
    for (final operation in _operations) {
      if (time == null) return null;
      time = operation.apply(time, clock);
    }
    return time;
  }
}

enum _Unit {
  year,
  fiscalYear,
  quarter,
  fiscalQuarter,
  month,
  week,
  day,
  businessDay,
  hour,
  minute,
  second,
}

sealed class _Anchor {
  const new();

  DateTime? resolve(DateTime now, WallClock clock);
}

final class _Now extends _Anchor {
  const new();

  @override
  DateTime resolve(DateTime now, WallClock clock) => clock.present(now);
}

final class _EpochMilliseconds extends _Anchor {
  const new(this.milliseconds);

  final int milliseconds;

  @override
  DateTime? resolve(DateTime now, WallClock clock) {
    if (!within(milliseconds, 8640000000000000)) return null;
    return clock.present(
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
    );
  }
}

final class _WallTime extends _Anchor {
  const new({
    required this.year,
    this.month = 1,
    this.day = 1,
    this.hour = 0,
    this.minute = 0,
    this.second = 0,
    this.millisecond = 0,
    this.offset,
  });

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;
  final int millisecond;

  /// East of UTC; null for the clock's zone.
  final Duration? offset;

  @override
  DateTime? resolve(DateTime now, WallClock clock) {
    final offset = this.offset;
    if (offset == null) {
      return clock.fromFields(
        year,
        month,
        day,
        hour,
        minute,
        second,
        millisecond,
      );
    }
    final wall = utcFromFields(
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
    );
    if (wall == null) return null;
    return clock.present(wall.subtract(offset));
  }
}

sealed class _Operation {
  const new();

  DateTime? apply(DateTime time, WallClock clock);
}

final class _Add extends _Operation {
  const new(this.unit, this.amount);

  final _Unit unit;
  final int amount;

  @override
  DateTime? apply(DateTime time, WallClock clock) => switch (unit) {
    _Unit.year || _Unit.fiscalYear => _addDate(time, clock, years: amount),
    _Unit.quarter || _Unit.fiscalQuarter => _addMonths(time, clock, 3 * amount),
    _Unit.month => _addMonths(time, clock, amount),
    _Unit.week => _addDays(time, clock, 7 * amount),
    _Unit.day => _addDays(time, clock, amount),
    _Unit.businessDay => _addBusinessDays(time, clock, amount),
    _Unit.hour => _addMicroseconds(
      time,
      clock,
      amount,
      Duration.microsecondsPerHour,
    ),
    _Unit.minute => _addMicroseconds(
      time,
      clock,
      amount,
      Duration.microsecondsPerMinute,
    ),
    _Unit.second => _addMicroseconds(
      time,
      clock,
      amount,
      Duration.microsecondsPerSecond,
    ),
  };

  static DateTime? _addMonths(DateTime time, WallClock clock, int months) =>
      within(months, 100000000) ? _addDate(time, clock, months: months) : null;

  static DateTime? _addDays(DateTime time, WallClock clock, int days) =>
      within(days, 1000000000) ? _addDate(time, clock, days: days) : null;

  // Go's AddDate: the same wall clock, the date overflowing into the next
  // unit (January 31 plus a month is March 3).
  static DateTime? _addDate(
    DateTime time,
    WallClock clock, {
    int years = 0,
    int months = 0,
    int days = 0,
  }) {
    if (!within(years, 10000000)) return null;
    return clock.fromFields(
      time.year + years,
      time.month + months,
      time.day + days,
      time.hour,
      time.minute,
      time.second,
      time.millisecond,
      time.microsecond,
    );
  }

  // A day at a time, as go-datemath steps, counting Monday to Friday only.
  // Five of them from a weekday are a week, which lets absurd amounts jump;
  // the jump could only differ from stepping in a wall time a DST gap skips.
  static DateTime? _addBusinessDays(
    DateTime time,
    WallClock clock,
    int amount,
  ) {
    if (!within(amount, 1000000000)) return null;
    final step = amount.sign;
    var remaining = amount.abs();
    DateTime? current = time;
    while (remaining > 0 && current != null) {
      if (remaining > 100000 && !_isWeekend(current)) {
        current = _addDays(current, clock, step * 7 * (remaining ~/ 5));
        remaining %= 5;
        continue;
      }
      current = _addDays(current, clock, step);
      if (current != null && !_isWeekend(current)) remaining--;
    }
    return current;
  }

  static bool _isWeekend(DateTime time) =>
      time.weekday == DateTime.saturday || time.weekday == DateTime.sunday;

  static DateTime? _addMicroseconds(
    DateTime time,
    WallClock clock,
    int amount,
    int unitMicroseconds,
  ) {
    if (!within(amount, 8640000000000000000 ~/ unitMicroseconds)) return null;
    return clock.fromMicroseconds(
      time.microsecondsSinceEpoch + amount * unitMicroseconds,
    );
  }
}

final class _RoundDown extends _Operation {
  const new(this.unit);

  final _Unit unit;

  @override
  DateTime? apply(DateTime time, WallClock clock) => switch (unit) {
    _Unit.year => clock.fromFields(time.year),
    _Unit.fiscalYear => _fiscalYearStart(time, clock),
    _Unit.quarter => clock.fromFields(
      time.year,
      time.month - (time.month - 1) % 3,
    ),
    _Unit.fiscalQuarter => _fiscalQuarterStart(time, clock),
    _Unit.month => clock.fromFields(time.year, time.month),
    _Unit.week => _weekStart(time, clock),
    _Unit.day => clock.fromFields(time.year, time.month, time.day),
    // The reader refuses `/b`: go-datemath panics on it.
    _Unit.businessDay => null,
    _Unit.hour => _truncate(time, clock, Duration.microsecondsPerHour),
    _Unit.minute => _truncate(time, clock, Duration.microsecondsPerMinute),
    _Unit.second => _truncate(time, clock, Duration.microsecondsPerSecond),
  };

  // Go's Truncate cuts the instant, not the wall clock: in a zone with a
  // half-hour offset the hour starts at :30.
  static DateTime? _truncate(DateTime time, WallClock clock, int unit) {
    final microseconds = time.microsecondsSinceEpoch;
    return clock.fromMicroseconds(microseconds - microseconds % unit);
  }

  // Midnight first, then whole days back, each step keeping that wall
  // clock, as go-datemath does it (they differ where midnight is skipped).
  static DateTime? _weekStart(DateTime time, WallClock clock) {
    final daysSinceMonday = time.weekday % 7 - DateTime.monday;
    var start = clock.fromFields(time.year, time.month, time.day);
    if (start != null && daysSinceMonday < 0) {
      start = _Add._addDays(start, clock, -7);
    }
    return start == null ? null : _Add._addDays(start, clock, -daysSinceMonday);
  }

  // Vikunja sets no fiscal year start, so it is January 1.
  static DateTime? _fiscalYearStart(DateTime time, WallClock clock) {
    final start = clock.fromFields(time.year);
    if (start == null || !start.isAfter(time)) return start;
    return clock.fromFields(time.year - 1);
  }

  static DateTime? _fiscalQuarterStart(DateTime time, WallClock clock) {
    final start = _fiscalYearStart(time, clock);
    if (start == null) return null;
    final months = time.month >= start.month
        ? time.month - start.month
        : time.month + 12 - start.month;
    return _Add._addMonths(start, clock, months ~/ 3 * 3);
  }
}

final class _DatemathReader {
  new(this._source);

  final String _source;
  var _position = 0;

  bool get _atEnd => _position == _source.length;

  Datemath? read() {
    final _Anchor anchor;
    if (_source.startsWith('now')) {
      _position = 3;
      anchor = const _Now();
    } else {
      final absolute = _absolute();
      if (absolute == null) return null;
      anchor = absolute;
      if (_atEnd) return Datemath._(anchor, const []);
      if (!_source.startsWith('||', _position)) return null;
      _position += 2;
    }
    final operations = <_Operation>[];
    while (!_atEnd) {
      final operation = _operation();
      if (operation == null) return null;
      operations.add(operation);
    }
    return Datemath._(anchor, operations);
  }

  _Operation? _operation() {
    final char = _source[_position++];
    if (char == '/') {
      final unit = _unit();
      return unit == null || unit == _Unit.businessDay
          ? null
          : _RoundDown(unit);
    }
    if (char != '+' && char != '-') return null;
    final digits = _digits();
    final amount = digits.isEmpty ? 1 : _wrappingNumber(digits);
    final unit = _unit();
    if (unit == null) return null;
    return _Add(unit, char == '-' ? -amount : amount);
  }

  _Unit? _unit() {
    if (_atEnd) return null;
    if (_source.startsWith('fy', _position)) {
      _position += 2;
      return _Unit.fiscalYear;
    }
    if (_source.startsWith('fQ', _position)) {
      _position += 2;
      return _Unit.fiscalQuarter;
    }
    final unit = switch (_source[_position]) {
      'y' => _Unit.year,
      'Q' => _Unit.quarter,
      'M' => _Unit.month,
      'w' => _Unit.week,
      'd' => _Unit.day,
      'b' => _Unit.businessDay,
      'h' || 'H' => _Unit.hour,
      'm' => _Unit.minute,
      's' => _Unit.second,
      _ => null,
    };
    if (unit != null) _position++;
    return unit;
  }

  _Anchor? _absolute() {
    final start = _position;
    final digits = _digits();
    if (digits.length >= 5) return _EpochMilliseconds(_wrappingNumber(digits));
    if (digits.length == 2) {
      _position = start;
      final time = _time();
      if (time == null) return null;
      return _WallTime(
        year: 1970,
        hour: time.hour,
        minute: time.minute,
        second: time.second,
        millisecond: time.millisecond,
      );
    }
    if (digits.length != 4) return null;
    final year = int.parse(digits);
    var month = 1;
    var day = 1;
    // Like go-datemath: month and day 00 pass and roll back.
    if (_consume('-')) {
      final value = _fixed(2);
      if (value == null || value > 12) return null;
      month = value;
      if (_consume('-')) {
        final value = _fixed(2);
        if (value == null || value > DateTime.utc(year, month + 1, 0).day) {
          return null;
        }
        day = value;
      }
    }
    if (!_consume('T')) return _WallTime(year: year, month: month, day: day);
    final time = _time();
    if (time == null) return null;
    final Duration? offset;
    if (_consume('Z')) {
      offset = Duration.zero;
    } else if (_source.startsWith('+', _position) ||
        _source.startsWith('-', _position)) {
      final sign = _source[_position++] == '-' ? -1 : 1;
      final hours = _fixed(2);
      if (hours == null || !_consume(':')) return null;
      final minutes = _fixed(2);
      if (minutes == null) return null;
      offset = Duration(hours: sign * hours, minutes: sign * minutes);
    } else {
      offset = null;
    }
    return _WallTime(
      year: year,
      month: month,
      day: day,
      hour: time.hour,
      minute: time.minute,
      second: time.second,
      millisecond: time.millisecond,
      offset: offset,
    );
  }

  ({int hour, int minute, int second, int millisecond})? _time() {
    final hour = _fixed(2);
    if (hour == null || hour > 23) return null;
    var minute = 0;
    var second = 0;
    var millisecond = 0;
    if (_consume(':')) {
      final value = _fixed(2);
      if (value == null || value > 59) return null;
      minute = value;
      if (_consume(':')) {
        final value = _fixed(2);
        if (value == null || value > 59) return null;
        second = value;
        if (_consume('.')) {
          final fraction = _digits();
          if (fraction.isEmpty || fraction.length > 3) return null;
          millisecond = int.parse(fraction.padRight(3, '0'));
        }
      }
    }
    return (
      hour: hour,
      minute: minute,
      second: second,
      millisecond: millisecond,
    );
  }

  bool _consume(String char) {
    if (!_source.startsWith(char, _position)) return false;
    _position += char.length;
    return true;
  }

  int? _fixed(int length) {
    final start = _position;
    final digits = _digits();
    if (digits.length != length) {
      _position = start;
      return null;
    }
    return int.parse(digits);
  }

  String _digits() {
    final start = _position;
    while (!_atEnd && _isDigit(_source.codeUnitAt(_position))) {
      _position++;
    }
    return _source.substring(start, _position);
  }
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

// go-datemath builds numbers digit by digit in 64 bits and never checks
// for overflow; Dart's ints wrap the same way.
int _wrappingNumber(String digits) {
  var value = 0;
  for (final unit in digits.codeUnits) {
    value = value * 10 + (unit - 0x30);
  }
  return value;
}
