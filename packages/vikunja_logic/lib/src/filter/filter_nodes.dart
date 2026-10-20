import 'package:meta/meta.dart';
import 'package:vikunja_logic/src/filter/filter_context.dart';
import 'package:vikunja_logic/src/filter/filter_dates.dart';
import 'package:vikunja_logic/src/filter/filterable_task.dart';
import 'package:vikunja_logic/src/filter/sql_text.dart';

enum FilterValueKind { integer, decimal, boolean, text, date, unsupported }

/// The task fields the server accepts in a filter (`project` is an alias
/// of `project_id`).
enum FilterField {
  id('id', FilterValueKind.integer),
  title('title', FilterValueKind.text),
  description('description', FilterValueKind.text),
  done('done', FilterValueKind.boolean),
  doneAt('done_at', FilterValueKind.date),
  dueDate('due_date', FilterValueKind.date),
  startDate('start_date', FilterValueKind.date),
  endDate('end_date', FilterValueKind.date),
  created('created', FilterValueKind.date),
  updated('updated', FilterValueKind.date),
  projectId('project_id', FilterValueKind.integer),
  priority('priority', FilterValueKind.integer),
  repeatAfter('repeat_after', FilterValueKind.integer),
  taskIndex('index', FilterValueKind.integer),
  createdById('created_by_id', FilterValueKind.integer),
  percentDone('percent_done', FilterValueKind.decimal),
  hexColor('hex_color', FilterValueKind.text),
  bucketId('bucket_id', FilterValueKind.integer),
  labels('labels', FilterValueKind.integer),
  reminders('reminders', FilterValueKind.date),
  assignees('assignees', FilterValueKind.text),
  createdBy('created_by', FilterValueKind.text),
  uid('uid', FilterValueKind.unsupported),
  position('position', FilterValueKind.unsupported);

  new(this.wireName, this.kind);

  final String wireName;
  final FilterValueKind kind;

  /// Compared by existence of a matching row (labels, reminders, assignees,
  /// the creator's user row) rather than as a column.
  bool get isRelation => switch (this) {
    labels || reminders || assignees || createdBy => true,
    _ => false,
  };

  static final Map<String, FilterField> byWireName = {
    for (final field in values) field.wireName: field,
  };
}

enum FilterComparator {
  equals('='),
  notEquals('!='),
  greater('>'),
  greaterOrEqual('>='),
  less('<'),
  lessOrEqual('<='),
  like('like'),
  inList('in'),
  notInList('not in');

  new(this.symbol);

  final String symbol;

  bool get isRange => switch (this) {
    greater || greaterOrEqual || less || lessOrEqual => true,
    _ => false,
  };

  bool get isList => this == inList || this == notInList;

  bool get isNegative => this == notEquals || this == notInList;
}

/// One comparison. [values] hold ints, doubles, bools, strings or
/// [FilterDate]s by the field's kind; one unless [comparator] is a list
/// (assignees and created_by always take a list).
@immutable
final class FilterCondition {
  new(this.field, this.comparator, this.values)
    : pattern = comparator == FilterComparator.like
          ? ContainsPattern(values.single as String)
          : null;

  final FilterField field;
  final FilterComparator comparator;
  final List<Object> values;
  final ContainsPattern? pattern;

  @override
  bool operator ==(Object other) =>
      other is FilterCondition &&
      other.field == field &&
      other.comparator == comparator &&
      _sameList(other.values, values);

  @override
  int get hashCode => Object.hash(field, comparator, Object.hashAll(values));

  @override
  String toString() {
    final shown = [
      for (final value in values)
        if (value is FilterDate) value.source else value,
    ];
    return '${field.wireName} ${comparator.symbol} ${shown.join(', ')}';
  }
}

/// A parenthesised list of conditions, folded strictly left to right.
@immutable
final class FilterGroup {
  const new(this.items, {this.includeNulls = false});

  final List<FilterItem> items;

  /// `filter_include_nulls` for this group whatever the context says.
  final bool includeNulls;

  bool get isEmpty => items.isEmpty;

  /// Every match has `done = false`: the fold ends in a conjunct that says
  /// so (`a || b && done = false`), or both sides of its last `||` do.
  bool get impliesOpen {
    bool upTo(int end) {
      if (end < 0) return false;
      final item = items[end];
      final last = item.node.impliesOpen;
      if (end == 0) return last;
      return item.or ? last && upTo(end - 1) : last || upTo(end - 1);
    }

    return upTo(items.length - 1);
  }

  @override
  bool operator ==(Object other) =>
      other is FilterGroup &&
      other.includeNulls == includeNulls &&
      _sameList(other.items, items);

  @override
  int get hashCode => Object.hash(includeNulls, Object.hashAll(items));

  @override
  String toString() {
    final buffer = StringBuffer(includeNulls ? 'nulls(' : '(');
    for (final (index, item) in items.indexed) {
      if (index > 0) buffer.write(item.or ? ' || ' : ' && ');
      buffer.write(item.node);
    }
    return (buffer..write(')')).toString();
  }
}

@immutable
final class FilterItem {
  const new(this.node, {this.or = false});

  final FilterNode node;

  /// Joined to what comes before with `||`; the first item's join is
  /// ignored.
  final bool or;

  @override
  bool operator ==(Object other) =>
      other is FilterItem && other.or == or && other.node == node;

  @override
  int get hashCode => Object.hash(or, node);
}

@immutable
sealed class FilterNode {
  const new();

  bool get impliesOpen;
}

final class FilterGroupNode extends FilterNode {
  const new(this.group);

  final FilterGroup group;

  @override
  bool get impliesOpen => group.impliesOpen;

  @override
  bool operator ==(Object other) =>
      other is FilterGroupNode && other.group == group;

  @override
  int get hashCode => group.hashCode;

  @override
  String toString() => group.toString();
}

final class FilterConditionNode extends FilterNode {
  const new(this.condition);

  final FilterCondition condition;

  @override
  bool get impliesOpen {
    if (condition.field != FilterField.done) return false;
    final values = condition.values.cast<bool>();
    return switch (condition.comparator) {
      FilterComparator.equals || FilterComparator.lessOrEqual => !values.single,
      FilterComparator.notEquals || FilterComparator.less => values.single,
      FilterComparator.inList => !values.contains(true),
      FilterComparator.notInList => values.contains(true),
      _ => false,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FilterConditionNode && other.condition == condition;

  @override
  int get hashCode => condition.hashCode;

  @override
  String toString() => condition.toString();
}

/// Consecutive `&&`-joined range comparisons on labels or reminders, which
/// the server checks against one row together: `reminders > a && reminders
/// < b` needs a single reminder between a and b.
final class FilterRangeNode extends FilterNode {
  const new(this.conditions);

  final List<FilterCondition> conditions;

  FilterField get field => conditions.first.field;

  @override
  bool get impliesOpen => false;

  @override
  bool operator ==(Object other) =>
      other is FilterRangeNode && _sameList(other.conditions, conditions);

  @override
  int get hashCode => Object.hashAll(conditions);

  @override
  String toString() => 'one(${conditions.join(' && ')})';
}

bool _sameList(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

typedef _Predicate = bool Function(FilterableTask task, int? bucketId);

/// A filter compiled for one context: dates resolved once, then plain
/// predicates. A comparison with a missing value fails, `!=` included,
/// unless include-nulls lets the missing value match.
final class FilterEvaluator {
  new(this.root, this.context, {required this.usesBucketId}) {
    _predicate = _group(root, inheritedNulls: context.includeNulls);
  }

  final FilterGroup root;
  final FilterContext context;
  final bool usesBucketId;
  late final _Predicate _predicate;

  bool matches(FilterableTask task) {
    if (!usesBucketId) return _predicate(task, null);
    if (context.viewId case final viewId?) {
      return _predicate(task, task.bucketIds[viewId]);
    }
    // A join on every view's bucket rows: one of them has to satisfy the
    // whole filter, a task without any reads as a missing value.
    final buckets = task.bucketIds.values.toSet();
    if (buckets.isEmpty) return _predicate(task, null);
    return buckets.any((bucketId) => _predicate(task, bucketId));
  }

  _Predicate _group(FilterGroup group, {required bool inheritedNulls}) {
    final includeNulls = inheritedNulls || group.includeNulls;
    final parts = [
      for (final item in group.items)
        (or: item.or, test: _node(item.node, includeNulls)),
    ];
    if (parts.isEmpty) return (_, _) => true;
    return (task, bucketId) {
      var result = parts.first.test(task, bucketId);
      for (var i = 1; i < parts.length; i++) {
        final part = parts[i];
        result = part.or
            ? result || part.test(task, bucketId)
            : result && part.test(task, bucketId);
      }
      return result;
    };
  }

  _Predicate _node(FilterNode node, bool includeNulls) => switch (node) {
    FilterGroupNode(:final group) => _group(
      group,
      inheritedNulls: includeNulls,
    ),
    FilterConditionNode(:final condition) =>
      condition.field.isRelation
          ? _relation(condition, includeNulls)
          : _column(condition, includeNulls),
    FilterRangeNode(:final conditions) => _range(conditions, includeNulls),
  };

  List<Object?> _resolved(List<Object> values) => [
    for (final value in values)
      if (value is FilterDate)
        value.resolve(context.now, context.location)?.microsecondsSinceEpoch
      else
        value,
  ];

  _Predicate _column(FilterCondition condition, bool includeNulls) {
    final comparator = condition.comparator;
    if (condition.pattern case final pattern?) {
      final read = _textOf(condition.field);
      return (task, _) => pattern.matches(read(task));
    }
    final values = _resolved(condition.values);
    final read = _columnOf(condition.field);
    final zeroCountsAsNull =
        condition.field.kind == FilterValueKind.integer && !comparator.isList;
    return (task, bucketId) {
      final value = read(task, bucketId);
      if (value == null) return includeNulls;
      if (_compareAny(value, comparator, values)) return true;
      return includeNulls && zeroCountsAsNull && value == 0;
    };
  }

  _Predicate _relation(FilterCondition condition, bool includeNulls) {
    final comparator = condition.comparator;
    final values = _resolved(condition.values);
    if (condition.field == FilterField.createdBy) {
      return (task, _) {
        final username = task.createdByUsername;
        final exists = username != null && values.contains(username);
        return comparator.isNegative ? !exists : exists;
      };
    }
    final rows = _rowsOf(condition.field);
    if (comparator.isRange) return _range([condition], includeNulls);
    final wanted = values.toSet();
    return (task, _) {
      final taskRows = rows(task);
      final exists = taskRows.any(wanted.contains);
      final result = comparator.isNegative ? !exists : exists;
      return result || (includeNulls && taskRows.isEmpty);
    };
  }

  _Predicate _range(List<FilterCondition> conditions, bool includeNulls) {
    final rows = _rowsOf(conditions.first.field);
    final bounds = [
      for (final condition in conditions)
        (comparator: condition.comparator, values: _resolved(condition.values)),
    ];
    return (task, _) {
      final taskRows = rows(task);
      final exists = taskRows.any(
        (row) => bounds.every(
          (bound) => _compareAny(row, bound.comparator, bound.values),
        ),
      );
      return exists || (includeNulls && taskRows.isEmpty);
    };
  }
}

/// `value <comparator> values` for a present value; an unresolvable bound
/// (null) never compares.
bool _compareAny(
  Object value,
  FilterComparator comparator,
  List<Object?> values,
) {
  switch (comparator) {
    case FilterComparator.inList:
      return values.any(
        (bound) => bound != null && _compare(value, bound) == 0,
      );
    case FilterComparator.notInList:
      if (values.contains(null)) return false;
      return values.every((bound) => _compare(value, bound!) != 0);
    case FilterComparator.like:
      return false;
    case FilterComparator.equals ||
        FilterComparator.notEquals ||
        FilterComparator.greater ||
        FilterComparator.greaterOrEqual ||
        FilterComparator.less ||
        FilterComparator.lessOrEqual:
      final bound = values.single;
      if (bound == null) return false;
      final order = _compare(value, bound);
      if (order == null) return false;
      return switch (comparator) {
        FilterComparator.equals => order == 0,
        FilterComparator.notEquals => order != 0,
        FilterComparator.greater => order > 0,
        FilterComparator.greaterOrEqual => order >= 0,
        FilterComparator.less => order < 0,
        _ => order <= 0,
      };
  }
}

/// SQL's order of two values of one field; null where SQL knows none (NaN).
int? _compare(Object value, Object bound) => switch ((value, bound)) {
  (final int a, final int b) => a.compareTo(b),
  (final double a, final double b) =>
    a.isNaN || b.isNaN ? null : a.compareTo(b),
  (final bool a, final bool b) => (a ? 1 : 0) - (b ? 1 : 0),
  (final String a, final String b) => compareUtf8(a, b),
  _ => null,
};

String Function(FilterableTask) _textOf(FilterField field) => switch (field) {
  FilterField.title => (task) => task.title,
  FilterField.description => (task) => task.description,
  _ => (task) => task.hexColor,
};

/// Dates as microseconds since the epoch, for comparing with resolved
/// bounds.
Object? Function(FilterableTask, int?) _columnOf(FilterField field) =>
    switch (field) {
      FilterField.id => (task, _) => task.id,
      FilterField.title => (task, _) => task.title,
      FilterField.description => (task, _) => task.description,
      FilterField.done => (task, _) => task.done,
      FilterField.doneAt => (task, _) => task.doneAt?.microsecondsSinceEpoch,
      FilterField.dueDate => (task, _) => task.dueDate?.microsecondsSinceEpoch,
      FilterField.startDate => (
        task,
        _,
      ) => task.startDate?.microsecondsSinceEpoch,
      FilterField.endDate => (task, _) => task.endDate?.microsecondsSinceEpoch,
      FilterField.created => (task, _) => task.created?.microsecondsSinceEpoch,
      FilterField.updated => (task, _) => task.updated?.microsecondsSinceEpoch,
      FilterField.projectId => (task, _) => task.projectId,
      FilterField.priority => (task, _) => task.priority,
      FilterField.repeatAfter => (task, _) => task.repeatAfterSeconds,
      FilterField.taskIndex => (task, _) => task.index,
      FilterField.createdById => (task, _) => task.createdById,
      FilterField.percentDone => (task, _) => task.percentDone,
      FilterField.hexColor => (task, _) => task.hexColor,
      FilterField.bucketId => (_, bucketId) => bucketId,
      FilterField.labels ||
      FilterField.reminders ||
      FilterField.assignees ||
      FilterField.createdBy ||
      FilterField.uid ||
      FilterField.position => (_, _) => null,
    };

Iterable<Object> Function(FilterableTask) _rowsOf(FilterField field) =>
    switch (field) {
      FilterField.labels => (task) => task.labelIds,
      FilterField.reminders => (task) => task.reminders.map(
        (reminder) => reminder.microsecondsSinceEpoch,
      ),
      _ => (task) => task.assigneeUsernames,
    };
