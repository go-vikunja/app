// Go's string-to-value functions as the server applies them to filter
// values; Dart's own parsers accept more (hex, blanks, out-of-range values).

/// `strings.TrimSpace`: Unicode White_Space, which unlike Dart's `trim`
/// leaves U+FEFF alone.
String goTrimSpace(String text) {
  var start = 0;
  var end = text.length;
  while (start < end && _isGoSpace(text.codeUnitAt(start))) {
    start++;
  }
  while (end > start && _isGoSpace(text.codeUnitAt(end - 1))) {
    end--;
  }
  return start == 0 && end == text.length ? text : text.substring(start, end);
}

bool _isGoSpace(int unit) =>
    (unit >= 0x09 && unit <= 0x0D) ||
    unit == 0x20 ||
    unit == 0x85 ||
    unit == 0xA0 ||
    unit == 0x1680 ||
    (unit >= 0x2000 && unit <= 0x200A) ||
    unit == 0x2028 ||
    unit == 0x2029 ||
    unit == 0x202F ||
    unit == 0x205F ||
    unit == 0x3000;

final _decimalInteger = RegExp(r'^[+-]?[0-9]+$');

/// `strconv.ParseInt(text, 10, 64)` and `strconv.Atoi`: an optional sign
/// and decimal digits, within 64 bits.
int? goParseInt(String text) {
  if (!_decimalInteger.hasMatch(text)) return null;
  return int.tryParse(text, radix: 10);
}

final _decimalFloat = RegExp(
  r'^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$',
);
final _specialFloat = RegExp(
  r'^([+-]?)(inf|infinity|nan)$',
  caseSensitive: false,
);

/// `strconv.ParseFloat(text, 64)` for decimal notation and `Inf`/`NaN`;
/// a value out of range is an error, as in Go.
double? goParseFloat(String text) {
  if (_specialFloat.firstMatch(text) case final special?) {
    if (special[2]!.toLowerCase() == 'nan') return double.nan;
    return special[1] == '-' ? double.negativeInfinity : double.infinity;
  }
  if (!_decimalFloat.hasMatch(text)) return null;
  final value = double.parse(text);
  return value.isInfinite ? null : value;
}

/// `strconv.ParseBool`.
bool? goParseBool(String text) => switch (text) {
  '1' || 't' || 'T' || 'TRUE' || 'true' || 'True' => true,
  '0' || 'f' || 'F' || 'FALSE' || 'false' || 'False' => false,
  _ => null,
};
