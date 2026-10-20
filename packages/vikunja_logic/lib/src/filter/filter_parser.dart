import 'package:vikunja_logic/src/filter/fexpr.dart';
import 'package:vikunja_logic/src/filter/filter_dates.dart';
import 'package:vikunja_logic/src/filter/filter_expression.dart';
import 'package:vikunja_logic/src/filter/filter_nodes.dart';
import 'package:vikunja_logic/src/filter/filter_preprocess.dart';
import 'package:vikunja_logic/src/filter/go_values.dart';

/// Parses a filter in the server's language (snake_case fields, label and
/// project ids, usernames) exactly as Vikunja does, with its error codes.
/// Only the empty string is no filter; blanks are a syntax error.
///
/// Beyond the server, `position` and range comparisons on `assignees` or
/// `created_by` are refused with 4019 here: the server accepts them and then
/// fails every request with a 500.
FilterParseResult parseTaskFilter(String text) {
  if (text.isEmpty) return FilterExpression.matchAll;
  if (complexityError(text) case final error?) return error;
  final preprocessed = quoteValues(replaceOperatorWords(text));
  if (complexityError(preprocessed) case final error?) return error;
  final List<FexprGroup> groups;
  try {
    groups = parseFexpr(preprocessed);
  } on FexprSyntaxError catch (error) {
    return FilterError(
      code: FilterError.invalidExpression,
      message: 'The filter expression is invalid: ${error.message}',
    );
  }
  final conversion = _Conversion();
  final converted = _convert(groups, conversion);
  if (converted is FilterError) return converted;
  if (conversion.queryError case final error?) return error;
  return FilterExpression(converted as FilterGroup, fields: conversion.fields);
}

/// The server converts the whole filter before it builds its query, so an
/// error it only finds then (`like` on a field that is not text) gives way
/// to any conversion error further on.
final class _Conversion {
  final fields = <String>{};
  FilterError? queryError;
}

const Map<String, FilterComparator> _comparators = {
  '=': FilterComparator.equals,
  '!=': FilterComparator.notEquals,
  '>': FilterComparator.greater,
  '>=': FilterComparator.greaterOrEqual,
  '<': FilterComparator.less,
  '<=': FilterComparator.lessOrEqual,
  '~': FilterComparator.like,
  '?=': FilterComparator.inList,
  '?!=': FilterComparator.notInList,
};

/// What a condition becomes before the fold: dropped when the server
/// ignores it (`assignees like …`).
typedef _Converted = ({bool or, Object? node});

Object _convert(List<FexprGroup> groups, _Conversion conversion) {
  final converted = <_Converted>[];
  for (final group in groups) {
    final Object? node;
    switch (group.item) {
      case FexprGroupItem(groups: final inner):
        final result = _convert(inner, conversion);
        if (result is FilterError) return result;
        node = result;
      case final FexprCondition condition:
        final result = _condition(condition, conversion);
        if (result is FilterError) return result;
        node = result;
    }
    converted.add((or: group.or, node: node));
  }
  return _fold(converted);
}

// Drops what the server ignores, skips empty groups (their joins vanish
// with them) and merges consecutive `&&`-joined range comparisons on labels
// or on reminders into one row check, as the server builds its SQL.
FilterGroup _fold(List<_Converted> converted) {
  final items = <FilterItem>[];
  for (var i = 0; i < converted.length; i++) {
    final (:or, :node) = converted[i];
    switch (node) {
      case FilterGroup(isEmpty: false):
        items.add(FilterItem(FilterGroupNode(node), or: or));
      case final FilterCondition condition when _mergesRanges(condition):
        final merged = [condition];
        while (i + 1 < converted.length) {
          final next = converted[i + 1];
          if (next.or ||
              next.node is! FilterCondition ||
              !_mergesRanges(next.node! as FilterCondition) ||
              (next.node! as FilterCondition).field != condition.field) {
            break;
          }
          merged.add(next.node! as FilterCondition);
          i++;
        }
        items.add(FilterItem(FilterRangeNode(merged), or: or));
      case final FilterCondition condition:
        items.add(FilterItem(FilterConditionNode(condition), or: or));
    }
  }
  return FilterGroup(items);
}

bool _mergesRanges(FilterCondition condition) =>
    condition.comparator.isRange &&
    (condition.field == FilterField.labels ||
        condition.field == FilterField.reminders);

/// A [FilterCondition], null for a dropped one, or a [FilterError].
Object? _condition(FexprCondition condition, _Conversion conversion) {
  final name = condition.left.literal == 'project'
      ? 'project_id'
      : condition.left.literal;
  final comparator = _comparators[condition.sign];
  if (comparator == null) {
    return FilterError(
      code: FilterError.invalidComparator,
      message: 'The task filter comparator is invalid.',
      field: name,
    );
  }
  final field = FilterField.byWireName[name];
  if (field == null) {
    return FilterError(
      code: FilterError.invalidField,
      message: 'The task field is invalid.',
      field: name,
    );
  }
  conversion.fields.add(name);
  final raw = condition.right.literal;
  FilterError invalid() => FilterError(
    code: FilterError.invalidValue,
    message: "The task filter value for field '$name' is invalid.",
    field: name,
    value: raw,
  );

  if (field == FilterField.assignees || field == FilterField.createdBy) {
    if (comparator == FilterComparator.like) return null;
    if (comparator.isRange) return invalid();
    return FilterCondition(field, comparator, [
      for (final part in raw.split(','))
        if (goTrimSpace(part) case final username when username.isNotEmpty)
          username,
    ]);
  }
  if (field.kind == FilterValueKind.unsupported) return invalid();

  final parts = comparator.isList ? raw.split(',') : [raw];
  final values = <Object>[];
  for (final part in parts) {
    final value = _value(field.kind, goTrimSpace(part));
    if (value == null) return invalid();
    values.add(value);
  }
  if (comparator == FilterComparator.like &&
      field.kind != FilterValueKind.text) {
    conversion.queryError ??= invalid();
    return null;
  }
  return FilterCondition(field, comparator, values);
}

Object? _value(FilterValueKind kind, String text) => switch (kind) {
  FilterValueKind.integer => goParseInt(text),
  FilterValueKind.decimal => goParseFloat(text),
  FilterValueKind.boolean => goParseBool(text),
  FilterValueKind.text => text,
  FilterValueKind.date => FilterDate.tryParse(text),
  FilterValueKind.unsupported => null,
};
