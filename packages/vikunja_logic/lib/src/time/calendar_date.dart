import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart';

/// A day of the proleptic Gregorian calendar, without a time or a zone.
/// Arithmetic counts calendar days, so a DST change never shifts it.
@immutable
final class CalendarDate implements Comparable<CalendarDate> {
  /// [day] must exist in [month]; [addDays] and [CalendarDate.of] always
  /// give one that does.
  const new(this.year, this.month, this.day)
    : assert(month >= 1 && month <= 12, 'month'),
      assert(day >= 1 && day <= 31, 'day');

  /// The date [dateTime]'s own fields show: local for a local DateTime,
  /// the zone's for a `TZDateTime`.
  factory of(DateTime dateTime) =>
      CalendarDate(dateTime.year, dateTime.month, dateTime.day);

  /// The date of [instant] on [zone]'s wall clock.
  factory inZone(DateTime instant, Location zone) =>
      CalendarDate.of(TZDateTime.from(instant, zone));

  static final _ymd = RegExp(r'^(\d{1,4})-(\d{1,2})-(\d{1,2})$');

  /// `YYYY-MM-DD`, also unpadded (`2024-1-5`). As the web reads a date
  /// from its URL, a day past the month's end rolls over (`2024-02-30` is
  /// March 1); a month outside 1–12 or a day outside 1–31 is null.
  static CalendarDate? tryParse(String? text) {
    final match = _ymd.firstMatch(text?.trim() ?? '');
    if (match == null) return null;
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return CalendarDate.of(DateTime.utc(int.parse(match[1]!), month, day));
  }

  final int year;
  final int month;
  final int day;

  CalendarDate addDays(int days) =>
      CalendarDate.of(DateTime.utc(year, month, day + days));

  /// Calendar days from [other] to this date, negative when [other] is
  /// later.
  int daysSince(CalendarDate other) => _utc.difference(other._utc).inDays;

  /// [DateTime.monday] … [DateTime.sunday].
  int get weekday => _utc.weekday;

  /// Local midnight, as date pickers take and give dates.
  DateTime toDateTime() => DateTime(year, month, day);

  /// The first instant of this date in [zone].
  TZDateTime startIn(Location zone) => TZDateTime(zone, year, month, day);

  bool isBefore(CalendarDate other) => compareTo(other) < 0;

  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  DateTime get _utc => DateTime.utc(year, month, day);

  @override
  int compareTo(CalendarDate other) => year != other.year
      ? year.compareTo(other.year)
      : month != other.month
      ? month.compareTo(other.month)
      : day.compareTo(other.day);

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// `YYYY-MM-DD`, the form filters and the web's URLs use.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
