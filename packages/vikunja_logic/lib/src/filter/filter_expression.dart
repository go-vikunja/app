import 'package:meta/meta.dart';
import 'package:vikunja_logic/src/filter/filter_context.dart';
import 'package:vikunja_logic/src/filter/filter_dates.dart';
import 'package:vikunja_logic/src/filter/filter_nodes.dart';
import 'package:vikunja_logic/src/filter/filterable_task.dart';

/// What `parseTaskFilter` makes of a filter: a [FilterExpression] or the
/// [FilterError] the server would answer.
sealed class FilterParseResult {
  const new();
}

/// The server's refusal of a filter, with its error code.
@immutable
final class FilterError extends FilterParseResult {
  const new({
    required this.code,
    required this.message,
    this.field,
    this.value,
  });

  static const int invalidField = 4016;
  static const int invalidComparator = 4017;
  static const int invalidValue = 4019;
  static const int invalidExpression = 4024;
  static const int tooComplex = 4033;

  final int code;

  /// English, in the server's words; for logs, not for the user.
  final String message;

  /// The field of a 4016, 4017 or 4019, as the server names it
  /// (`project` is `project_id`).
  final String? field;

  /// The value of a 4019.
  final String? value;

  @override
  bool operator ==(Object other) =>
      other is FilterError &&
      other.code == code &&
      other.message == message &&
      other.field == field &&
      other.value == value;

  @override
  int get hashCode => Object.hash(code, message, field, value);

  @override
  String toString() => 'FilterError($code, $message)';
}

/// A filter the server accepts, ready to be evaluated on the device.
@immutable
final class FilterExpression extends FilterParseResult {
  const new(this.root, {this.fields = const {}});

  /// The empty filter: every task matches.
  static const FilterExpression matchAll = FilterExpression(FilterGroup([]));

  final FilterGroup root;

  /// The fields the filter names, as the server spells them (`project` is
  /// `project_id`).
  final Set<String> fields;

  bool get isEmpty => root.isEmpty;

  /// Needs the task's buckets, which only boards know.
  bool get usesBucketId => fields.contains('bucket_id');

  /// No done task can match (a `done = false` the whole filter depends
  /// on), so done tasks need not be loaded.
  bool get matchesOnlyOpenTasks => root.impliesOpen;

  /// Compares with a date counted from now (`now/d`, `now+7d`), so what
  /// the filter matches changes with time alone.
  bool get usesRelativeDates => _usesRelativeDates(root);

  /// Both filters, as the server combines a request's filter with a view's.
  FilterExpression and(FilterExpression other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;
    return FilterExpression(
      FilterGroup([
        FilterItem(FilterGroupNode(root)),
        FilterItem(FilterGroupNode(other.root)),
      ]),
      fields: {...fields, ...other.fields},
    );
  }

  /// This filter with `filter_include_nulls` for all of its conditions,
  /// whatever the context says; the server does this to a request's filter
  /// when it adds a saved filter that has the flag off.
  FilterExpression includingNulls() => isEmpty
      ? this
      : FilterExpression(
          FilterGroup([FilterItem(FilterGroupNode(root))], includeNulls: true),
          fields: fields,
        );

  /// This filter for one context, which resolves its dates once.
  BoundFilter bind(FilterContext context) =>
      BoundFilter._(FilterEvaluator(root, context, usesBucketId: usesBucketId));

  @override
  bool operator ==(Object other) =>
      other is FilterExpression && other.root == root;

  @override
  int get hashCode => root.hashCode;

  @override
  String toString() => 'FilterExpression$root';
}

/// What the server evaluates when a request with its own filter reads a
/// saved filter's tasks (`mergeRequestFilter`): a request filter with
/// include-nulls keeps the flag to itself; otherwise the saved filter's
/// flag covers both, so a request cannot switch it off. Pass the returned
/// flag as the context's include-nulls.
({FilterExpression expression, bool includeNulls}) mergeSavedFilter({
  required FilterExpression saved,
  required bool savedIncludesNulls,
  FilterExpression request = FilterExpression.matchAll,
  bool requestIncludesNulls = false,
}) {
  if (request.isEmpty) {
    return (expression: saved, includeNulls: savedIncludesNulls);
  }
  if (saved.isEmpty) {
    return (
      expression: request,
      includeNulls: savedIncludesNulls || requestIncludesNulls,
    );
  }
  if (requestIncludesNulls && !savedIncludesNulls) {
    return (
      expression: request.includingNulls().and(saved),
      includeNulls: false,
    );
  }
  return (expression: request.and(saved), includeNulls: savedIncludesNulls);
}

/// A [FilterExpression] bound to a [FilterContext].
final class BoundFilter {
  new _(this._evaluator);

  final FilterEvaluator _evaluator;

  FilterContext get context => _evaluator.context;

  bool matches(FilterableTask task) => _evaluator.matches(task);
}

bool _usesRelativeDates(FilterGroup group) => group.items.any(
  (item) => switch (item.node) {
    FilterGroupNode(:final group) => _usesRelativeDates(group),
    FilterConditionNode(:final condition) => _comparesRelative(condition),
    FilterRangeNode(:final conditions) => conditions.any(_comparesRelative),
  },
);

bool _comparesRelative(FilterCondition condition) =>
    condition.values.any((value) => value is FilterDate && value.isRelative);

final Expando<BoundFilter> _lastBound = Expando('lastBound');

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
