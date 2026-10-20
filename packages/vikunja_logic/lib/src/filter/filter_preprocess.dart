import 'dart:convert';

import 'package:vikunja_logic/src/filter/filter_expression.dart';
import 'package:vikunja_logic/src/filter/go_values.dart';

// The server's checks and rewrites before it parses a filter.

const int _maxFilterBytes = 16 * 1024;
const _maxNesting = 100;

/// The size and nesting limits (4033) and an unmatched `)` (4024), checked
/// on the filter as sent and again after the rewrites.
FilterError? complexityError(String filter) {
  if (utf8.encode(filter).length > _maxFilterBytes) {
    return const FilterError(
      code: FilterError.tooComplex,
      message:
          'The filter expression is too complex: it exceeds the '
          '$_maxFilterBytes-byte limit',
    );
  }
  var depth = 0;
  for (var i = 0; i < filter.length; i++) {
    final char = filter.codeUnitAt(i);
    if (_isQuote(char)) {
      final end = _quotedRunEnd(filter, i);
      if (end >= 0) {
        i = end;
        continue;
      }
    }
    if (char == 0x28 && ++depth > _maxNesting) {
      return const FilterError(
        code: FilterError.tooComplex,
        message:
            'The filter expression is too complex: it exceeds the '
            '$_maxNesting-level nesting limit',
      );
    }
    if (char == 0x29 && --depth < 0) {
      return const FilterError(
        code: FilterError.invalidExpression,
        message:
            'The filter expression is invalid: unexpected closing parenthesis',
      );
    }
  }
  return null;
}

bool _isQuote(int char) => char == 0x27 || char == 0x22;

/// The index of the quote closing the one at [start], a backslash skipping
/// the next character; -1 when it is never closed, and then the quote is an
/// ordinary character.
int _quotedRunEnd(String text, int start) {
  final quote = text.codeUnitAt(start);
  for (var i = start + 1; i < text.length; i++) {
    final char = text.codeUnitAt(i);
    if (char == 0x5C) {
      i++;
    } else if (char == quote) {
      return i;
    }
  }
  return -1;
}

const List<(String, String)> _operatorWords = [
  (' not in ', ' ?!= '),
  (' in ', ' ?= '),
  (' like ', ' ~ '),
];

/// ` not in `, ` in ` and ` like ` become `?!=`, `?=` and `~` outside
/// closed quotes, even inside an unquoted value: `title = stuff in
/// progress` compares with `stuff ?= progress`.
String replaceOperatorWords(String filter) {
  final buffer = StringBuffer();
  var i = 0;
  outer:
  while (i < filter.length) {
    if (_isQuote(filter.codeUnitAt(i))) {
      final end = _quotedRunEnd(filter, i);
      if (end >= 0) {
        buffer.write(filter.substring(i, end + 1));
        i = end + 1;
        continue;
      }
    }
    for (final (word, sign) in _operatorWords) {
      if (filter.startsWith(word, i)) {
        buffer.write(sign);
        i += word.length;
        continue outer;
      }
    }
    buffer.writeCharCode(filter.codeUnitAt(i));
    i++;
  }
  return buffer.toString();
}

/// Quotes every condition's value unless it is quoted already, like the
/// server's `(\w+)\s*(>=|<=|!=|~|\?=|\?!=|=|>|<)\s*([^&|()]+)` replacement
/// with Go's ASCII `\w` and `\s`: a value runs to the next `&`, `|`, `(` or
/// `)` and swallows later clauses (`done = false and priority = 1` compares
/// done with `false and priority = 1`).
///
/// Scanned by hand: a backtracking regex takes quadratic time on a long
/// run of word characters, where Go's is linear.
String quoteValues(String filter) {
  final buffer = StringBuffer();
  var copied = 0;
  var i = 0;
  while (i < filter.length) {
    if (!_isWordChar(filter.codeUnitAt(i))) {
      i++;
      continue;
    }
    final fieldStart = i;
    while (i < filter.length && _isWordChar(filter.codeUnitAt(i))) {
      i++;
    }
    final fieldEnd = i;
    var operatorStart = fieldEnd;
    while (operatorStart < filter.length &&
        _isAsciiSpace(filter.codeUnitAt(operatorStart))) {
      operatorStart++;
    }
    final match = _operatorAndValue(filter, operatorStart);
    if (match == null) continue;
    final (:operator, :valueStart, :valueEnd) = match;
    final value = goTrimSpace(filter.substring(valueStart, valueEnd));
    final quoted =
        (value.startsWith("'") && value.endsWith("'")) ||
            (value.startsWith('"') && value.endsWith('"'))
        ? value
        : "'${value.replaceAll("'", r"\'")}'";
    buffer
      ..write(filter.substring(copied, fieldStart))
      ..write('${filter.substring(fieldStart, fieldEnd)} $operator $quoted');
    copied = i = valueEnd;
  }
  return (buffer..write(filter.substring(copied))).toString();
}

const List<String> _operators = [
  '>=',
  '<=',
  '!=',
  '~',
  '?=',
  '?!=',
  '=',
  '>',
  '<',
];

// The first operator, in the regex's order, after which a value follows:
// blanks, then at least one character up to the next & | ( ) or the end;
// with nothing but blanks there, the last blank is the value.
({String operator, int valueStart, int valueEnd})? _operatorAndValue(
  String filter,
  int start,
) {
  for (final operator in _operators) {
    if (!filter.startsWith(operator, start)) continue;
    final afterOperator = start + operator.length;
    var valueStart = afterOperator;
    while (valueStart < filter.length &&
        _isAsciiSpace(filter.codeUnitAt(valueStart))) {
      valueStart++;
    }
    var valueEnd = valueStart;
    while (valueEnd < filter.length &&
        !_endsValue(filter.codeUnitAt(valueEnd))) {
      valueEnd++;
    }
    if (valueEnd > valueStart) {
      return (operator: operator, valueStart: valueStart, valueEnd: valueEnd);
    }
    if (valueStart > afterOperator) {
      return (
        operator: operator,
        valueStart: valueStart - 1,
        valueEnd: valueStart,
      );
    }
  }
  return null;
}

bool _isWordChar(int char) =>
    (char >= 0x30 && char <= 0x39) ||
    (char >= 0x41 && char <= 0x5A) ||
    (char >= 0x61 && char <= 0x7A) ||
    char == 0x5F;

bool _isAsciiSpace(int char) =>
    char == 0x20 ||
    char == 0x09 ||
    char == 0x0A ||
    char == 0x0C ||
    char == 0x0D;

bool _endsValue(int char) =>
    char == 0x26 || char == 0x7C || char == 0x28 || char == 0x29;
