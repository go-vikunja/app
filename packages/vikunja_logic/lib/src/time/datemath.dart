/// Evaluates a datemath expression the way the server's go-datemath does:
/// `now`, then any sequence of `+N<unit>`, `-N<unit>` and `/<unit>`
/// (rounding down), with the units `y M w d h H m s`. Rounding happens in
/// [now]'s zone, and a week starts on Monday whatever the user's week
/// start, as on the server. Days, weeks, months and years keep the wall
/// clock across a DST change; hours, minutes and seconds add real time.
///
/// Throws a [FormatException] for anything else, including absolute
/// anchors (`2026-10-13||+1d`), which no preset uses.
DateTime evaluateDatemath(String expression, DateTime now) {
  // The server trims a filter value before it parses the datemath.
  final source = expression.trim();
  if (!_expression.hasMatch(source)) {
    throw FormatException('Not a datemath expression', expression);
  }
  var result = now;
  for (final operation in _operation.allMatches(source, 'now'.length)) {
    if (operation[4] case final unit?) {
      result = _roundDown(result, unit);
      continue;
    }
    final unit = operation[3]!;
    final amount = int.parse('${operation[1]}${operation[2]}');
    if (!_staysInRange(result, unit, amount)) {
      throw FormatException('Datemath result out of range', expression);
    }
    result = _add(result, unit, amount);
  }
  return result;
}

final _expression = RegExp(r'^now(?:[+-]\d{1,9}[yMwdhHms]|/[yMwdhHms])*$');
final _operation = RegExp(r'([+-])(\d+)([yMwdhHms])|/([yMwdhHms])');

// DateTime covers ±100 000 000 days around 1970 and silently wraps far
// beyond them, so an addition that could leave them is refused up front,
// overestimating months and years.
bool _staysInRange(DateTime time, String unit, int amount) {
  final days = switch (unit) {
    'y' => 366 * amount,
    'M' => 31 * amount,
    'w' => 7 * amount,
    'd' => amount,
    'h' || 'H' => amount ~/ Duration.hoursPerDay,
    'm' => amount ~/ Duration.minutesPerDay,
    _ => amount ~/ Duration.secondsPerDay,
  };
  final day = time.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  return (day + days).abs() <= 99000000;
}

DateTime _add(DateTime time, String unit, int amount) => switch (unit) {
  'y' => _withDate(time, time.year + amount, time.month, time.day),
  'M' => _withDate(time, time.year, time.month + amount, time.day),
  'w' => _withDate(time, time.year, time.month, time.day + 7 * amount),
  'd' => _withDate(time, time.year, time.month, time.day + amount),
  'h' || 'H' => time.add(Duration(hours: amount)),
  'm' => time.add(Duration(minutes: amount)),
  _ => time.add(Duration(seconds: amount)),
};

DateTime _roundDown(DateTime time, String unit) => switch (unit) {
  'y' => _midnight(time, time.year, 1, 1),
  'M' => _midnight(time, time.year, time.month, 1),
  'w' => _midnight(
    time,
    time.year,
    time.month,
    time.day - (time.weekday - DateTime.monday),
  ),
  'd' => _midnight(time, time.year, time.month, time.day),
  // Subtracting the wall clock's remainder keeps the right instant in the
  // hour a DST change repeats.
  'h' || 'H' => time.subtract(
    Duration(
      minutes: time.minute,
      seconds: time.second,
      milliseconds: time.millisecond,
      microseconds: time.microsecond,
    ),
  ),
  'm' => time.subtract(
    Duration(
      seconds: time.second,
      milliseconds: time.millisecond,
      microseconds: time.microsecond,
    ),
  ),
  _ => time.subtract(
    Duration(milliseconds: time.millisecond, microseconds: time.microsecond),
  ),
};

/// The same wall clock on another date, normalised like Go's `AddDate`
/// (January 31 plus a month is March 3).
DateTime _withDate(DateTime time, int year, int month, int day) => time.isUtc
    ? DateTime.utc(
        year,
        month,
        day,
        time.hour,
        time.minute,
        time.second,
        time.millisecond,
        time.microsecond,
      )
    : DateTime(
        year,
        month,
        day,
        time.hour,
        time.minute,
        time.second,
        time.millisecond,
        time.microsecond,
      );

DateTime _midnight(DateTime time, int year, int month, int day) =>
    time.isUtc ? DateTime.utc(year, month, day) : DateTime(year, month, day);
