import 'package:timezone/timezone.dart';
import 'package:vikunja_logic/src/filter/filter_dates.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

/// Whether [task] matches [expression] the way the server decides it.
/// Repeated calls with the same [context] reuse its resolved dates.
bool matchesFilter(
  FilterExpression expression,
  FilterableTask task,
  FilterContext context,
) {
  var bound = _lastBound[expression.root];
  if (bound == null || bound.context != context) {
    bound = expression.bind(context);
    _lastBound[expression.root] = bound;
  }
  return bound.matches(task);
}

final Expando<BoundFilter> _lastBound = Expando('lastBound');

/// A date value of a filter as the instant the server compares with, in
/// UTC, or null when the server refuses it (4019).
DateTime? parseFilterDate(
  String value, {
  required DateTime now,
  required Location location,
}) => FilterDate.tryParse(value)?.resolve(now, location);

bool matchesTaskSearch(String search, FilterableTask task) =>
    TaskSearchMatcher(search).matches(task);
