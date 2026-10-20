import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a field's values are, which picks its operators and suggestions.
enum FilterFieldKind { done, number, date, text, labels, project, users }

/// The fields the builder offers, in the order it suggests them, spelled
/// as the web's filter input shows them: camelCase where the web converts
/// a field for the server, its snake_case name elsewhere.
const Map<String, FilterFieldKind> suggestedFilterFields = {
  'done': FilterFieldKind.done,
  'priority': FilterFieldKind.number,
  'dueDate': FilterFieldKind.date,
  'labels': FilterFieldKind.labels,
  'assignees': FilterFieldKind.users,
  'project': FilterFieldKind.project,
  'title': FilterFieldKind.text,
  'description': FilterFieldKind.text,
  'startDate': FilterFieldKind.date,
  'endDate': FilterFieldKind.date,
  'doneAt': FilterFieldKind.date,
  'reminders': FilterFieldKind.date,
  'percentDone': FilterFieldKind.number,
  'created': FilterFieldKind.date,
  'updated': FilterFieldKind.date,
  'createdBy': FilterFieldKind.users,
  'index': FilterFieldKind.number,
  'hex_color': FilterFieldKind.text,
  'repeat_after': FilterFieldKind.number,
  'id': FilterFieldKind.number,
};

/// Every field the server knows, by its snake_case name. The builder does
/// not suggest `uid` and `position`, which never match, nor `bucket_id`,
/// which needs a board.
const Map<String, FilterFieldKind> _serverFields = {
  'done': FilterFieldKind.done,
  'priority': FilterFieldKind.number,
  'due_date': FilterFieldKind.date,
  'labels': FilterFieldKind.labels,
  'assignees': FilterFieldKind.users,
  'project': FilterFieldKind.project,
  'project_id': FilterFieldKind.project,
  'title': FilterFieldKind.text,
  'description': FilterFieldKind.text,
  'start_date': FilterFieldKind.date,
  'end_date': FilterFieldKind.date,
  'done_at': FilterFieldKind.date,
  'reminders': FilterFieldKind.date,
  'percent_done': FilterFieldKind.number,
  'created': FilterFieldKind.date,
  'updated': FilterFieldKind.date,
  'created_by': FilterFieldKind.users,
  'created_by_id': FilterFieldKind.number,
  'index': FilterFieldKind.number,
  'hex_color': FilterFieldKind.text,
  'repeat_after': FilterFieldKind.number,
  'id': FilterFieldKind.number,
  'bucket_id': FilterFieldKind.number,
  'position': FilterFieldKind.number,
  'uid': FilterFieldKind.text,
};

/// The fields the web's input converts for the server, in any case, by
/// their lower-cased spelling.
const Map<String, String> _webFields = {
  'done': 'done',
  'priority': 'priority',
  'percentdone': 'percent_done',
  'duedate': 'due_date',
  'startdate': 'start_date',
  'enddate': 'end_date',
  'doneat': 'done_at',
  'reminders': 'reminders',
  'created': 'created',
  'updated': 'updated',
  'assignees': 'assignees',
  'createdby': 'created_by',
  'labels': 'labels',
  'project': 'project',
};

/// The server's name of the field [name] stands for once the web's
/// conversion ran, null when there is none.
String? filterFieldNamed(String name) {
  if (_serverFields.containsKey(name)) return name;
  return _webFields[name.toLowerCase()];
}

/// The server's field [name] as the builder suggests it (`due_date` is
/// `dueDate`, `project_id` is `project`), for messages about it.
String suggestedFilterFieldName(String name) =>
    _suggestedSpellings[name] ?? name;

const Map<String, String> _suggestedSpellings = {
  'percent_done': 'percentDone',
  'due_date': 'dueDate',
  'start_date': 'startDate',
  'end_date': 'endDate',
  'done_at': 'doneAt',
  'created_by': 'createdBy',
  'project_id': 'project',
};

FilterFieldKind? filterFieldKindOf(String name) =>
    switch (filterFieldNamed(name)) {
      final field? => _serverFields[field],
      null => null,
    };

/// The operators the builder suggests for a kind of field.
List<String> filterOperatorsFor(FilterFieldKind kind) => switch (kind) {
  FilterFieldKind.done => const ['=', '!='],
  FilterFieldKind.number => const [
    '=',
    '!=',
    '>',
    '>=',
    '<',
    '<=',
    'in',
    'not in',
  ],
  FilterFieldKind.date => const ['=', '!=', '>', '>=', '<', '<='],
  FilterFieldKind.text => const ['=', '!=', 'like'],
  FilterFieldKind.labels ||
  FilterFieldKind.project ||
  FilterFieldKind.users => const ['=', '!=', 'in', 'not in'],
};

/// Relative dates in the server's date math, nearest first.
const List<String> filterDateShortcuts = [
  'now',
  'now/d',
  'now/d+1d',
  'now+7d',
  'now/w',
  'now/w+1w',
  'now/M',
  'now-7d',
];

bool isListOperator(String operator) => switch (operator) {
  'in' || 'not in' || '?=' || '?!=' => true,
  _ => false,
};

enum FilterSpanKind {
  field,

  /// A word in a field's place that names no field.
  unknownField,
  operator,
  value,

  /// `&&`, `||` and the brackets.
  join,
}

@immutable
final class FilterSpan {
  const new(this.start, this.end, this.kind);

  final int start;
  final int end;
  final FilterSpanKind kind;

  @override
  bool operator ==(Object other) =>
      other is FilterSpan &&
      other.start == start &&
      other.end == end &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(start, end, kind);

  @override
  String toString() => 'FilterSpan($start, $end, ${kind.name})';
}

// The server's quoting rule, on ASCII classes as Go's RE2 has them: a
// field, an operator and a value running to the next `&`, `|`, `(` or `)`.
// The word operators need a space on each side, as the server's rewrite
// does.
final _condition = RegExp(
  r'([0-9A-Za-z_]+)([\t\n\f\r ]*)(>=|<=|!=|\?!=|\?=|~|=|>|<| not in | in | like )([^&|()]*)',
);

/// Where [text]'s fields, operators, values and joins are, in order: a
/// value runs to the next `&`, `|`, `(` or `)` as on the server, so the
/// highlight shows how far it reaches.
List<FilterSpan> filterSpans(String text) {
  final spans = <FilterSpan>[];
  var from = 0;
  void joinsUpTo(int end) {
    for (var index = from; index < end; index++) {
      final char = text[index];
      if (char == '(' || char == ')') {
        spans.add(FilterSpan(index, index + 1, FilterSpanKind.join));
      } else if ((char == '&' || char == '|') &&
          index + 1 < end &&
          text[index + 1] == char) {
        spans.add(FilterSpan(index, index + 2, FilterSpanKind.join));
        index++;
      }
    }
  }

  for (final match in _condition.allMatches(text)) {
    joinsUpTo(match.start);
    final field = match[1]!;
    final fieldEnd = match.start + field.length;
    spans.add(
      FilterSpan(
        match.start,
        fieldEnd,
        filterFieldNamed(field) == null
            ? FilterSpanKind.unknownField
            : FilterSpanKind.field,
      ),
    );
    final operator = match[3]!;
    final operatorStart = fieldEnd + match[2]!.length;
    final trimmedOperator = operator.trim();
    final operatorOffset = operator.indexOf(trimmedOperator);
    spans.add(
      FilterSpan(
        operatorStart + operatorOffset,
        operatorStart + operatorOffset + trimmedOperator.length,
        FilterSpanKind.operator,
      ),
    );
    final value = match[4]!;
    final valueStart = operatorStart + operator.length;
    final leading = value.length - value.trimLeft().length;
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      spans.add(
        FilterSpan(
          valueStart + leading,
          valueStart + leading + trimmed.length,
          FilterSpanKind.value,
        ),
      );
    }
    from = match.end;
  }
  joinsUpTo(text.length);
  return spans;
}

/// What the caret is in, which the suggestions complete.
@immutable
sealed class FilterCompletionContext {
  const new({required this.start, required this.end});

  /// The range a chosen suggestion replaces.
  final int start;
  final int end;
}

/// A field's place: [partial] is the word typed so far.
final class FieldContext extends FilterCompletionContext {
  const new({required super.start, required super.end, required this.partial});

  final String partial;
}

/// After a field and a space: [partial] is the start of an operator.
final class OperatorContext extends FilterCompletionContext {
  const new({
    required super.start,
    required super.end,
    required this.field,
    required this.kind,
    required this.partial,
  });

  final String field;
  final FilterFieldKind kind;
  final String partial;
}

/// A value's place: [partial] is the value typed so far, for a list
/// operator its last item, without an opening quote. [joinable] when a
/// value is complete enough for `&&` or `||` to follow.
final class ValueContext extends FilterCompletionContext {
  const new({
    required super.start,
    required super.end,
    required this.field,
    required this.kind,
    required this.operator,
    required this.partial,
    required this.joinable,
  });

  final String field;
  final FilterFieldKind kind;
  final String operator;
  final String partial;
  final bool joinable;
}

/// After a closing bracket, where only a join can follow.
final class JoinContext extends FilterCompletionContext {
  const new({required super.start, required super.end});
}

final _fieldPlace = RegExp(r'^\s*([0-9A-Za-z_]*)$');
final _operatorPlace = RegExp(r'^(\s*)([0-9A-Za-z_]+)(\s+)([a-z]*|[<>!?])$');
final _symbolOperatorPlace = RegExp(r'^(\s*)([0-9A-Za-z_]+)(\s*)([<>!?])$');
final _valuePlace = RegExp(
  r'^\s*([0-9A-Za-z_]+)\s*(>=|<=|!=|\?!=|\?=|~|=|>|<)(.*)$',
  dotAll: true,
);
final _wordValuePlace = RegExp(
  r'^\s*([0-9A-Za-z_]+)\s+(not in|in|like)(\s.*)$',
  dotAll: true,
);
final _boundary = RegExp('[&|()]');

/// The context at the caret of [value], null with a selection or where
/// nothing can be suggested (an unknown field, inside a join).
FilterCompletionContext? filterCompletionContext(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) return null;
  final text = value.text;
  final caret = selection.baseOffset;
  if (caret > text.length) return null;
  final before = text.substring(0, caret);
  var boundary = -1;
  for (final match in _boundary.allMatches(before)) {
    boundary = match.start;
  }
  final segmentStart = boundary + 1;
  final segment = before.substring(segmentStart);
  if (boundary >= 0 && before[boundary] == ')') {
    return segment.trim().isEmpty
        ? JoinContext(start: caret, end: caret)
        : null;
  }
  if (boundary >= 0 &&
      (before[boundary] == '&' || before[boundary] == '|') &&
      (boundary == 0 || before[boundary - 1] != before[boundary])) {
    // A single `&` or `|`, half a join.
    return null;
  }
  if (_fieldPlace.firstMatch(segment) case final match?) {
    final partial = match[1]!;
    return FieldContext(
      start: caret - partial.length,
      end: _wordEnd(text, caret),
      partial: partial,
    );
  }
  if (_valuePlace.firstMatch(segment) ?? _wordValuePlace.firstMatch(segment)
      case final match?) {
    final kind = filterFieldKindOf(match[1]!);
    if (kind == null) return null;
    final operator = match[2]!;
    final rest = match[3]!;
    final list = isListOperator(operator);
    final itemStart = list ? rest.lastIndexOf(',') + 1 : 0;
    final item = rest.substring(itemStart);
    final leading = item.length - item.trimLeft().length;
    var partial = item.substring(leading);
    var start = caret - rest.length + itemStart + leading;
    if (partial.startsWith('"') || partial.startsWith("'")) {
      partial = partial.substring(1);
    }
    final valueEnd = _valueEnd(text, caret, list: list);
    if (partial.isEmpty) start = caret;
    return ValueContext(
      start: start,
      end: partial.isEmpty ? caret : valueEnd,
      field: match[1]!,
      kind: kind,
      operator: operator,
      partial: partial,
      joinable: rest.trim().isNotEmpty && rest.endsWith(' '),
    );
  }
  if (_operatorPlace.firstMatch(segment) ??
          _symbolOperatorPlace.firstMatch(segment)
      case final match?) {
    final kind = filterFieldKindOf(match[2]!);
    if (kind == null) return null;
    final partial = match[4]!;
    return OperatorContext(
      start: caret - partial.length,
      end: caret,
      field: match[2]!,
      kind: kind,
      partial: partial,
    );
  }
  return null;
}

final _wordChar = RegExp('[0-9A-Za-z_]');

int _wordEnd(String text, int from) {
  var end = from;
  while (end < text.length && _wordChar.hasMatch(text[end])) {
    end++;
  }
  return end;
}

/// Where the value the caret is in ends: before the next `&`, `|`, `(` or
/// `)` (or `,` in a list), without the spaces before it.
int _valueEnd(String text, int from, {required bool list}) {
  var end = from;
  while (end < text.length) {
    final char = text[end];
    if (char == '&' || char == '|' || char == '(' || char == ')') break;
    if (list && char == ',') break;
    end++;
  }
  while (end > from && text[end - 1] == ' ') {
    end--;
  }
  return end;
}

/// The operators of [context] that start with what is typed.
List<String> operatorSuggestions(OperatorContext context) => [
  for (final operator in filterOperatorsFor(context.kind))
    if (operator.startsWith(context.partial)) operator,
];

/// The suggested fields that contain what is typed, ignoring case and
/// underscores, so `dued` finds `due_date`; those that start with it first.
List<String> fieldSuggestions(FieldContext context) {
  String plain(String name) => name.replaceAll('_', '').toLowerCase();
  final needle = plain(context.partial);
  if (needle.isEmpty) return suggestedFilterFields.keys.toList();
  return [
    for (final field in suggestedFilterFields.keys)
      if (plain(field).startsWith(needle)) field,
    for (final field in suggestedFilterFields.keys)
      if (!plain(field).startsWith(needle) && plain(field).contains(needle))
        field,
  ];
}

/// [value] as a filter value: in quotes when it holds a comma that would
/// otherwise split it, or spaces at its ends that would be trimmed.
String filterValueText(String value, {required bool list}) {
  final needsQuotes =
      (!list && value.contains(',')) || value.trim().length != value.length;
  if (!needsQuotes) return value;
  return value.contains('"') ? "'$value'" : '"$value"';
}

/// Whether [value] can stand in a filter at all: a value always ends at
/// `&`, `|`, `(` or `)`, quoted or not, and an item of a list at a comma.
bool canBeFilterValue(String value, {required bool list}) =>
    value.trim().isNotEmpty &&
    !value.contains(_boundary) &&
    !(list && value.contains(','));

/// [value] with [context]'s range replaced by [insert]; the caret goes
/// after it and the space that follows, which is added unless one is
/// there.
TextEditingValue completeFilter(
  TextEditingValue value,
  FilterCompletionContext context,
  String insert,
) {
  final text = value.text;
  final before = text.substring(0, context.start);
  final after = text.substring(context.end);
  final leading = switch (context) {
    OperatorContext() ||
    JoinContext() when before.isNotEmpty => before.endsWith(' ') ? '' : ' ',
    FieldContext() when before.endsWith('&') || before.endsWith('|') => ' ',
    ValueContext() when before.isNotEmpty && !before.endsWith(' ') =>
      _needsSpaceBefore(before) ? ' ' : '',
    _ => '',
  };
  final trailing = after.startsWith(' ') ? '' : ' ';
  final replaced = '$before$leading$insert$trailing$after';
  return TextEditingValue(
    text: replaced,
    selection: TextSelection.collapsed(
      offset: before.length + leading.length + insert.length + 1,
    ),
  );
}

bool _needsSpaceBefore(String before) {
  final last = before[before.length - 1];
  return last != ',' && last != '"' && last != "'";
}
