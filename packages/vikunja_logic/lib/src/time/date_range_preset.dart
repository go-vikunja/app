import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart';
import 'package:vikunja_logic/src/time/datemath.dart';

/// The web's date-range presets (`dateRanges.ts`), in its order.
enum DateRangePreset {
  today('now/d', 'now/d+1d'),
  tomorrow('now/d+1d', 'now/d+2d'),
  lastWeek('now/w-1w', 'now/w'),
  thisWeek('now/w', 'now/w+1w'),
  restOfThisWeek('now', 'now/w+1w'),
  nextWeek('now/w+1w', 'now/w+2w'),
  next7Days('now', 'now+7d'),
  lastMonth('now/M-1M', 'now/M'),
  thisMonth('now/M', 'now/M+1M'),
  restOfThisMonth('now', 'now/M+1M'),
  nextMonth('now/M+1M', 'now/M+2M'),
  next30Days('now', 'now+30d'),
  thisYear('now/y', 'now/y+1y'),
  restOfThisYear('now', 'now/y+1y');

  new(this.from, this.to);

  final String from;
  final String to;

  DateRange resolve(DateTime now, {Location? location}) => DateRange(
    from: evaluateDatemath(from, now, location: location),
    to: evaluateDatemath(to, now, location: location),
  );

  static DateRangePreset? fromName(String? name) =>
      values.where((preset) => preset.name == name).firstOrNull;
}

/// Both ends exclusive, as the web's Upcoming filter compares them, except
/// that a range with [includesFrom] holds [from] itself: a custom range of
/// whole days starts at its first day's midnight.
@immutable
final class DateRange {
  const new({required this.from, required this.to, this.includesFrom = false});

  final DateTime from;
  final DateTime to;
  final bool includesFrom;

  bool contains(DateTime moment) =>
      (includesFrom ? !moment.isBefore(from) : moment.isAfter(from)) &&
      moment.isBefore(to);

  @override
  bool operator ==(Object other) =>
      other is DateRange &&
      other.from == from &&
      other.to == to &&
      other.includesFrom == includesFrom;

  @override
  int get hashCode => Object.hash(from, to, includesFrom);

  @override
  String toString() =>
      'DateRange($from, $to${includesFrom ? ', includesFrom' : ''})';
}
