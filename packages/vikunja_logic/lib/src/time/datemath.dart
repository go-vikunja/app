import 'package:timezone/timezone.dart';
import 'package:vikunja_logic/src/time/datemath_expression.dart';
import 'package:vikunja_logic/src/time/wall_clock.dart';

/// Evaluates a datemath expression the way the server's go-datemath does:
/// `now` or an absolute value (`2026`, `2026-10`, `2026-10-20`, a time
/// `22`, `22:00`, `22:00:05.123` on 1970-01-01, `2026-10-20T22:00` with an
/// optional `Z` or `+02:00`, or five or more digits as epoch
/// milliseconds), the latter optionally followed by `||`, then any
/// sequence of `+N<unit>`, `-N<unit>` (a missing N is 1) and `/<unit>`
/// (rounding down), with the units `y Q M w d b h H m s fy fQ` (`b`
/// business days, `fy`/`fQ` equal to `y`/`Q`).
///
/// Values without a zone, rounding and calendar units use [location]'s
/// wall clock, else [now]'s zone (the process's local zone or UTC). A week
/// starts on Monday whatever the user's week start, as on the server.
/// Days, weeks, months and years keep the wall clock across a DST change;
/// hours, minutes and seconds add real time.
///
/// Throws a [FormatException] for anything else and for results beyond
/// DateTime's range.
DateTime evaluateDatemath(
  String expression,
  DateTime now, {
  Location? location,
}) {
  // The server trims a filter value before it parses the datemath.
  final parsed = Datemath.tryParse(expression.trim());
  if (parsed == null) {
    throw FormatException('Not a datemath expression', expression);
  }
  final result = parsed.evaluate(now, WallClock.of(now, location: location));
  if (result == null) {
    throw FormatException('Datemath result out of range', expression);
  }
  return result;
}
