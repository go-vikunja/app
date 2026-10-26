import 'package:meta/meta.dart';
import 'package:vikunja_logic/src/time/calendar_date.dart';

/// The days a timeline shows, both included.
@immutable
final class GanttRange {
  /// [from] must not be after [to].
  const new({required this.from, required this.to});

  final CalendarDate from;
  final CalendarDate to;

  /// The number of day columns.
  int get dayCount => to.daysSince(from) + 1;

  bool contains(CalendarDate date) => !date.isBefore(from) && !date.isAfter(to);

  /// The date of a day column; 0 is [from].
  CalendarDate dayAt(int column) => from.addDays(column);

  Map<String, String> toJson() => {'from': '$from', 'to': '$to'};

  /// What [toJson] wrote; null for anything else, including a range that
  /// ends before it starts.
  static GanttRange? fromJson(Object? json) {
    if (json is! Map) return null;
    final from = CalendarDate.tryParse(_string(json['from']));
    final to = CalendarDate.tryParse(_string(json['to']));
    if (from == null || to == null || to.isBefore(from)) return null;
    return GanttRange(from: from, to: to);
  }

  static String? _string(Object? value) => value is String ? value : null;

  @override
  bool operator ==(Object other) =>
      other is GanttRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'GanttRange($from, $to)';
}

/// The web's default (`useGanttFilters.ts`): 15 days before the date of
/// [today] through 55 days after it, 71 day columns. Pass the moment the
/// screen opened or resumed: the web fixes it once when the page loads.
GanttRange defaultGanttRange(DateTime today) {
  final date = CalendarDate.of(today);
  return GanttRange(from: date.addDays(-15), to: date.addDays(55));
}

/// The web's Gantt filter, character for character. The server places the
/// bare dates at midnight of `filter_timezone`, so a task that starts on
/// [GanttRange.to] after midnight only matches through another clause, and
/// the spanning clause ignores `due_date`; both are the web's behaviour.
String ganttFilterText(GanttRange range) {
  final from = '"${range.from}"';
  final to = '"${range.to}"';
  return '((start_date >= $from && start_date <= $to) || '
      '(end_date >= $from && end_date <= $to) || '
      '(due_date >= $from && due_date <= $to) || '
      '(start_date <= $from && end_date >= $to))';
}
