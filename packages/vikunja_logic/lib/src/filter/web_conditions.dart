/// One match of the web's condition pattern for a field,
/// `\b(field)\s*OP\s*(?:(["'])((?:\\.|(?!\3)[^\\])*?)\3|([^&|()<]+?))`
/// `(?=\s*(?:&&|\||\)|$))`, with OP one of `!= >= <= = > < like not in in
/// ?=`.
final class WebCondition {
  const new({
    required this.start,
    required this.end,
    required this.operator,
    required this.value,
    required this.quoted,
  });

  final int start;
  final int end;
  final String operator;

  /// Without its quotes when [quoted].
  final String value;
  final bool quoted;
}

/// The non-overlapping matches from the left, as a global regex finds
/// them. Scanned by hand: the backtracking regex takes cubic time on long
/// runs of blanks.
Iterable<WebCondition> webConditions(String text, String field) sync* {
  var from = 0;
  while (true) {
    final start = text.indexOf(field, from);
    if (start < 0) return;
    final match = start > 0 && _isWord(text.codeUnitAt(start - 1))
        ? null
        : _conditionAt(text, start, start + field.length);
    if (match == null) {
      from = start + 1;
    } else {
      yield match;
      from = match.end;
    }
  }
}

/// Replaces every match of [field]'s condition with what [replace] makes
/// of it.
String replaceWebConditions(
  String text,
  String field,
  String Function(WebCondition condition) replace,
) {
  final buffer = StringBuffer();
  var copied = 0;
  for (final condition in webConditions(text, field)) {
    buffer
      ..write(text.substring(copied, condition.start))
      ..write(replace(condition));
    copied = condition.end;
  }
  return (buffer..write(text.substring(copied))).toString();
}

const List<String> _operators = [
  '!=',
  '>=',
  '<=',
  '=',
  '>',
  '<',
  'like',
  'not in',
  'in',
  '?=',
];

WebCondition? _conditionAt(String text, int start, int fieldEnd) {
  final operatorStart = _skipBlanks(text, fieldEnd);
  for (final operator in _operators) {
    if (!text.startsWith(operator, operatorStart)) continue;
    final operatorEnd = operatorStart + operator.length;
    if (_isWord(operator.codeUnitAt(0)) &&
        (_isWordAt(text, operatorStart - 1) || _isWordAt(text, operatorEnd))) {
      continue;
    }
    final value = _valueAt(text, operatorEnd);
    if (value != null) {
      return WebCondition(
        start: start,
        end: value.end,
        operator: operator,
        value: value.value,
        quoted: value.quoted,
      );
    }
  }
  return null;
}

typedef _Value = ({int end, String value, bool quoted});

// After the operator: blanks, then a quoted value whose closing quote is
// followed by the end of the condition, else the shortest unquoted run
// without `& | ( ) <` that is. With only blanks before the end, the regex
// backtracks and takes the last blank as the value.
_Value? _valueAt(String text, int afterOperator) {
  final start = _skipBlanks(text, afterOperator);
  if (start < text.length) {
    final quote = text.codeUnitAt(start);
    if (quote == 0x22 || quote == 0x27) {
      final close = _closingQuote(text, start + 1, quote);
      if (close >= 0 && _endsCondition(text, close + 1)) {
        return (
          end: close + 1,
          value: text.substring(start + 1, close),
          quoted: true,
        );
      }
    }
  }
  var stop = start;
  while (stop < text.length && !_stopsUnquoted(text.codeUnitAt(stop))) {
    stop++;
  }
  if (stop > start && _endsCondition(text, stop)) {
    var end = stop;
    while (end - 1 > start && _isBlank(text.codeUnitAt(end - 1))) {
      end--;
    }
    return (end: end, value: text.substring(start, end), quoted: false);
  }
  if (start > afterOperator && _endsCondition(text, start)) {
    return (end: start, value: text.substring(start - 1, start), quoted: false);
  }
  return null;
}

// The first unescaped [quote]: a backslash takes the next character unless
// that ends a line (the regex's `.`), and a lone one ends the value.
int _closingQuote(String text, int from, int quote) {
  var i = from;
  while (i < text.length) {
    final char = text.codeUnitAt(i);
    if (char == quote) return i;
    if (char == 0x5C) {
      if (i + 1 >= text.length || _isLineTerminator(text.codeUnitAt(i + 1))) {
        return -1;
      }
      i += 2;
    } else {
      i++;
    }
  }
  return -1;
}

/// `(?=\s*(?:&&|\||\)|$))`.
bool _endsCondition(String text, int position) {
  final at = _skipBlanks(text, position);
  return at == text.length ||
      text.startsWith('&&', at) ||
      text.startsWith('|', at) ||
      text.startsWith(')', at);
}

int _skipBlanks(String text, int from) {
  var i = from;
  while (i < text.length && _isBlank(text.codeUnitAt(i))) {
    i++;
  }
  return i;
}

bool _stopsUnquoted(int char) =>
    char == 0x26 ||
    char == 0x7C ||
    char == 0x28 ||
    char == 0x29 ||
    char == 0x3C;

bool _isWordAt(String text, int index) =>
    index >= 0 && index < text.length && _isWord(text.codeUnitAt(index));

bool _isWord(int char) =>
    (char >= 0x30 && char <= 0x39) ||
    (char >= 0x41 && char <= 0x5A) ||
    (char >= 0x61 && char <= 0x7A) ||
    char == 0x5F;

bool _isLineTerminator(int char) =>
    char == 0x0A || char == 0x0D || char == 0x2028 || char == 0x2029;

/// JavaScript's `\s`.
bool _isBlank(int char) =>
    (char >= 0x09 && char <= 0x0D) ||
    char == 0x20 ||
    char == 0xA0 ||
    char == 0x1680 ||
    (char >= 0x2000 && char <= 0x200A) ||
    char == 0x2028 ||
    char == 0x2029 ||
    char == 0x202F ||
    char == 0x205F ||
    char == 0x3000 ||
    char == 0xFEFF;
