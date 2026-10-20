import 'package:timezone/timezone.dart';

/// Wall-clock arithmetic in one zone. Out-of-range results are null:
/// DateTime ends at ±100 000 000 days and silently wraps far beyond.
sealed class WallClock {
  const new();

  /// A [Location] places a wall time like Go's `time.Date` (a time in a
  /// DST gap moves by the gap); without one the zone is [now]'s: its
  /// location, the process's local zone or UTC.
  factory of(DateTime now, {Location? location}) => switch ((location, now)) {
    (final Location location, _) => _LocationClock(location),
    (null, final TZDateTime zoned) => _LocationClock(zoned.location),
    (null, _) when now.isUtc => const _UtcClock(),
    (null, _) => const _LocalClock(),
  };

  /// The instant whose wall clock shows these fields, which overflow into
  /// the next unit like Go's `time.Date` (January 32 is February 1).
  DateTime? fromFields(
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ]);

  /// [instant] with this zone's wall clock.
  DateTime present(DateTime instant);

  DateTime? fromMicroseconds(int microsecondsSinceEpoch);
}

final class _UtcClock extends WallClock {
  const new();

  @override
  DateTime? fromFields(
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ]) => utcFromFields(
    year,
    month,
    day,
    hour,
    minute,
    second,
    millisecond,
    microsecond,
  );

  @override
  DateTime present(DateTime instant) => instant.toUtc();

  @override
  DateTime? fromMicroseconds(int microsecondsSinceEpoch) =>
      _inRange(microsecondsSinceEpoch)
      ? DateTime.fromMicrosecondsSinceEpoch(microsecondsSinceEpoch, isUtc: true)
      : null;
}

final class _LocalClock extends WallClock {
  const new();

  @override
  DateTime? fromFields(
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ]) {
    if (!_fieldsInRange(year, month, day, hour, minute, second)) return null;
    return DateTime(
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
      microsecond,
    );
  }

  @override
  DateTime present(DateTime instant) => instant.toLocal();

  @override
  DateTime? fromMicroseconds(int microsecondsSinceEpoch) =>
      _inRange(microsecondsSinceEpoch)
      ? DateTime.fromMicrosecondsSinceEpoch(microsecondsSinceEpoch)
      : null;
}

final class _LocationClock extends WallClock {
  const new(this.location);

  final Location location;

  @override
  DateTime? fromFields(
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  ]) {
    final wall = utcFromFields(
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
      microsecond,
    );
    if (wall == null) return null;
    // translateToUtc is Go's resolution of a wall time to an instant.
    final utcMilliseconds = location.translateToUtc(
      wall.millisecondsSinceEpoch,
    );
    return fromMicroseconds(
      utcMilliseconds * Duration.microsecondsPerMillisecond + wall.microsecond,
    );
  }

  @override
  DateTime present(DateTime instant) => TZDateTime.from(instant, location);

  @override
  DateTime? fromMicroseconds(int microsecondsSinceEpoch) =>
      _inRange(microsecondsSinceEpoch)
      ? TZDateTime.fromMicrosecondsSinceEpoch(location, microsecondsSinceEpoch)
      : null;
}

/// `DateTime.utc` that answers null instead of wrapping or throwing.
DateTime? utcFromFields(
  int year, [
  int month = 1,
  int day = 1,
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
  int microsecond = 0,
]) {
  if (!_fieldsInRange(year, month, day, hour, minute, second)) return null;
  return DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    millisecond,
    microsecond,
  );
}

const _maxMicroseconds = 8640000000000000000;

bool _inRange(int microsecondsSinceEpoch) =>
    within(microsecondsSinceEpoch, _maxMicroseconds);

// DateTime sums the fields' microseconds in 64-bit integers, which is exact
// whenever the true sum fits, and throws beyond its range; an estimate in
// doubles, off by days at most, keeps well inside both.
bool _fieldsInRange(
  int year,
  int month,
  int day,
  int hour,
  int minute,
  int second,
) {
  if (!within(year, 10000000)) return false;
  final days = (year - 1970) * 365.2425 + (month - 1) * 30.436875 + (day - 1);
  final microseconds =
      days * Duration.microsecondsPerDay +
      hour * Duration.microsecondsPerHour.toDouble() +
      minute * Duration.microsecondsPerMinute.toDouble() +
      second * Duration.microsecondsPerSecond.toDouble();
  return microseconds.abs() < 8.63e18;
}

/// Days in [month] (1–12) of the proleptic Gregorian [year].
int daysInMonth(int year, int month) => switch (month) {
  2 => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) ? 29 : 28,
  4 || 6 || 9 || 11 => 30,
  _ => 31,
};

/// `-limit <= value <= limit`; unlike `abs()` right for the smallest int,
/// which wrapped datemath numbers can reach.
bool within(int value, int limit) => value >= -limit && value <= limit;
