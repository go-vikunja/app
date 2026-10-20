// Text comparisons as SQLite does them: `=` and `<` on bytes, `LIKE` with
// `%`/`_` wildcards (never escaped by the server) and ASCII-only case folding.

/// Only A–Z become lowercase, as SQLite's `LIKE` folds case.
String asciiLowerCase(String text) {
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit >= 0x41 && unit <= 0x5A) {
      final units = text.codeUnits.toList();
      for (var j = i; j < units.length; j++) {
        if (units[j] >= 0x41 && units[j] <= 0x5A) units[j] += 0x20;
      }
      return String.fromCharCodes(units);
    }
  }
  return text;
}

/// UTF-8 byte order, which is code point order (Dart's `compareTo` orders
/// UTF-16 code units, which differs above U+FFFF).
int compareUtf8(String a, String b) {
  final left = a.runes.iterator;
  final right = b.runes.iterator;
  while (true) {
    final hasLeft = left.moveNext();
    final hasRight = right.moveNext();
    if (!hasLeft || !hasRight) {
      return hasLeft
          ? 1
          : hasRight
          ? -1
          : 0;
    }
    if (left.current != right.current) return left.current - right.current;
  }
}

/// `column LIKE '%value%'`.
final class ContainsPattern {
  new(String value) : this._lowered(asciiLowerCase(value));

  new _lowered(String lowered)
    : _literal = lowered.contains('%') || lowered.contains('_')
          ? null
          : lowered,
      _pattern = [_percent, ...lowered.runes, _percent];

  final String? _literal;

  /// With the implicit leading and trailing `%`.
  final List<int> _pattern;

  bool matches(String text) {
    final subject = asciiLowerCase(text);
    if (_literal case final literal?) return subject.contains(literal);
    return _matchesWildcards(subject.runes.toList(growable: false));
  }

  // Greedy matching that backtracks to the last `%` only, which suffices
  // because `%` matches any run.
  bool _matchesWildcards(List<int> subject) {
    final pattern = _pattern;
    var s = 0;
    var p = 0;
    var starP = -1;
    var starS = 0;
    while (s < subject.length) {
      if (p < pattern.length &&
          pattern[p] != _percent &&
          (pattern[p] == _underscore || pattern[p] == subject[s])) {
        s++;
        p++;
      } else if (p < pattern.length && pattern[p] == _percent) {
        starP = p++;
        starS = s;
      } else if (starP >= 0) {
        p = starP + 1;
        s = ++starS;
      } else {
        return false;
      }
    }
    while (p < pattern.length && pattern[p] == _percent) {
      p++;
    }
    return p == pattern.length;
  }

  static const _percent = 0x25;
  static const _underscore = 0x5F;
}
