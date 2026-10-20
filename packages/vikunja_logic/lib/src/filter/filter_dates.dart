import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart';
import 'package:vikunja_logic/src/filter/go_values.dart';
import 'package:vikunja_logic/src/time/datemath_expression.dart';
import 'package:vikunja_logic/src/time/wall_clock.dart';

/// A date value of a filter (`due_date < now/d+1d`, `2026-10-20`,
/// `2026-10-20 22:00`, …) as the instant the server compares with, in UTC,
/// or null when the server refuses it (4019).
DateTime? parseFilterDate(
  String value, {
  required DateTime now,
  required Location location,
}) => FilterDate.tryParse(value)?.resolve(now, location);

/// A filter's date value, parsed without its context: go-datemath first,
/// then RFC 3339, `2006-01-02 15:04`, `2006-01-02` and a lenient `Y-M-D`
/// that rolls over (`2023-02-30` is March 2), as the server tries them.
@immutable
sealed class FilterDate {
  const new(this.source);

  /// Null for what the server refuses with 4019; [value] is trimmed first.
  static FilterDate? tryParse(String value) {
    final source = goTrimSpace(value);
    if (Datemath.tryParse(source) case final datemath?) {
      return _DatemathDate(source, datemath);
    }
    return _rfc3339(source) ??
        _wallTime(source) ??
        _date(source) ??
        _lenientDate(source);
  }

  /// As the server wrote it, trimmed.
  final String source;

  /// Counted from the moment of evaluation (`now`, `now/d+1d`), so the
  /// instant moves with time.
  bool get isRelative => false;

  /// The instant in UTC, null when it leaves DateTime's range.
  DateTime? resolve(DateTime now, Location location);

  @override
  bool operator ==(Object other) =>
      other is FilterDate && other.source == source;

  @override
  int get hashCode => source.hashCode;
}

final class _DatemathDate extends FilterDate {
  const new(super.source, this._datemath);

  final Datemath _datemath;

  @override
  bool get isRelative => _datemath.isRelative;

  @override
  DateTime? resolve(DateTime now, Location location) =>
      _clamped(_datemath.evaluate(now, WallClock.of(now, location: location)));
}

final class _InstantDate extends FilterDate {
  const new(super.source, this._instant);

  final DateTime _instant;

  @override
  DateTime? resolve(DateTime now, Location location) => _clamped(_instant);
}

final class _WallDate extends FilterDate {
  const new(
    super.source,
    this._year,
    this._month,
    this._day, [
    this._hour = 0,
    this._minute = 0,
  ]);

  final int _year;
  final int _month;
  final int _day;
  final int _hour;
  final int _minute;

  @override
  DateTime? resolve(DateTime now, Location location) => _clamped(
    WallClock.of(
      now,
      location: location,
    ).fromFields(_year, _month, _day, _hour, _minute),
  );
}

// The server lifts years before 1 to year 1, a day later when that is
// January 1, so `> 0000-01-01` means "has a date".
DateTime? _clamped(DateTime? time) {
  if (time == null) return null;
  final utc = time.toUtc();
  if (utc.year >= 1) return utc;
  final lifted = DateTime.utc(
    1,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
    utc.microsecond,
  );
  return lifted.month == 1 && lifted.day == 1
      ? lifted.add(const Duration(days: 1))
      : lifted;
}

// Go's time.Parse with the layouts the server tries: a four-digit year,
// two-digit month, day, minute and second, a one- or two-digit hour, and
// the day checked against the month.
final _rfc3339Pattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{1,2}):(\d{2}):(\d{2})(?:[.,](\d+))?'
  r'(?:(Z)|([+-])(\d{2}):(\d{2}))$',
);
// Go matches the layout's space with a run of spaces, never with a tab.
final _wallTimePattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2}) +(\d{1,2}):(\d{2})$',
);
final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

bool _validDate(int year, int month, int day) =>
    month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth(year, month);

bool _validTime(int hour, int minute, [int second = 0]) =>
    hour < 24 && minute < 60 && second < 60;

FilterDate? _rfc3339(String source) {
  final match = _rfc3339Pattern.firstMatch(source);
  if (match == null) return null;
  final [year, month, day, hour, minute, second] = [
    for (var group = 1; group <= 6; group++) int.parse(match[group]!),
  ];
  if (!_validDate(year, month, day) || !_validTime(hour, minute, second)) {
    return null;
  }
  final fraction = match[7] ?? '';
  final microseconds = fraction.isEmpty
      ? 0
      : int.parse(fraction.padRight(6, '0').substring(0, 6));
  var offset = Duration.zero;
  if (match[8] == null) {
    final offsetHours = int.parse(match[10]!);
    final offsetMinutes = int.parse(match[11]!);
    if (offsetHours > 24 || offsetMinutes > 59) return null;
    offset = Duration(hours: offsetHours, minutes: offsetMinutes);
    if (match[9] == '-') offset = -offset;
  }
  final wall = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    0,
    microseconds,
  );
  return _InstantDate(source, wall.subtract(offset));
}

FilterDate? _wallTime(String source) {
  final match = _wallTimePattern.firstMatch(source);
  if (match == null) return null;
  final [year, month, day, hour, minute] = [
    for (var group = 1; group <= 5; group++) int.parse(match[group]!),
  ];
  if (!_validDate(year, month, day) || !_validTime(hour, minute)) return null;
  return _WallDate(source, year, month, day, hour, minute);
}

FilterDate? _date(String source) {
  final match = _datePattern.firstMatch(source);
  if (match == null) return null;
  final [year, month, day] = [
    for (var group = 1; group <= 3; group++) int.parse(match[group]!),
  ];
  if (!_validDate(year, month, day)) return null;
  return _WallDate(source, year, month, day);
}

FilterDate? _lenientDate(String source) {
  final parts = source.split('-');
  if (parts.length < 3) return null;
  final year = goParseInt(parts[0]);
  final month = goParseInt(parts[1]);
  final day = goParseInt(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (utcFromFields(year, month, day) == null) return null;
  return _WallDate(source, year, month, day);
}
