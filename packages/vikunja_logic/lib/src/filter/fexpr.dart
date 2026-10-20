// The expression syntax the server parses filters with (ganigeorgiev/fexpr
// v0.6.0): `left sign right` items joined by `&&`/`||` into a flat list,
// with parenthesised groups. No precedence: the server folds the list from
// the left.
//
// Translated from fexpr, Copyright (c) 2022-present, Gani Georgiev,
// BSD 3-Clause License; see THIRD_PARTY_NOTICES.md in this package.

enum FexprTokenType { identifier, function, number, text, sign, join, group }

final class FexprToken {
  const new(this.type, this.literal);

  final FexprTokenType type;

  /// Text without its quotes and escapes; a function's name.
  final String literal;
}

sealed class FexprItem;

final class FexprCondition extends FexprItem {
  new(this.left, this.sign, this.right);

  final FexprToken left;
  final String sign;
  final FexprToken right;
}

final class FexprGroupItem extends FexprItem {
  new(this.groups);

  final List<FexprGroup> groups;
}

final class FexprGroup {
  new({required this.or, required this.item});

  final bool or;
  final FexprItem item;
}

final class FexprSyntaxError implements Exception {
  const new(this.message);

  /// Never quotes the input, which may hold titles.
  final String message;

  @override
  String toString() => message;
}

/// Throws a [FexprSyntaxError] where the server's parser fails.
List<FexprGroup> parseFexpr(String text) {
  final scanner = _Scanner(text);
  final result = <FexprGroup>[];
  var step = _Step.beforeSign;
  var or = false;
  FexprToken? left;
  String? sign;

  while (true) {
    final token = scanner.scan();
    if (token == null) break;

    if (token.type == FexprTokenType.group) {
      // A group is taken in any state and drops a half-built condition.
      result.add(
        FexprGroup(or: or, item: FexprGroupItem(parseFexpr(token.literal))),
      );
      step = _Step.join;
      continue;
    }

    switch (step) {
      case _Step.beforeSign:
        if (!_isOperand(token)) {
          throw FexprSyntaxError(
            'expected left operand (identifier, function, text or number), '
            'got ${token.type.name}',
          );
        }
        left = token;
        sign = null;
        step = _Step.sign;
      case _Step.sign:
        if (token.type != FexprTokenType.sign) {
          throw FexprSyntaxError(
            'expected a sign operator, got ${token.type.name}',
          );
        }
        sign = token.literal;
        step = _Step.afterSign;
      case _Step.afterSign:
        if (!_isOperand(token)) {
          throw FexprSyntaxError(
            'expected right operand (identifier, function, text or number), '
            'got ${token.type.name}',
          );
        }
        result.add(
          FexprGroup(or: or, item: FexprCondition(left!, sign!, token)),
        );
        step = _Step.join;
      case _Step.join:
        if (token.type != FexprTokenType.join) {
          throw FexprSyntaxError('expected && or ||, got ${token.type.name}');
        }
        or = token.literal == '||';
        step = _Step.beforeSign;
    }
  }

  if (step != _Step.join) {
    if (result.isEmpty && left == null) {
      throw const FexprSyntaxError('empty filter expression');
    }
    throw const FexprSyntaxError('invalid or incomplete filter expression');
  }
  return result;
}

enum _Step { beforeSign, sign, afterSign, join }

bool _isOperand(FexprToken token) => switch (token.type) {
  FexprTokenType.identifier ||
  FexprTokenType.text ||
  FexprTokenType.number ||
  FexprTokenType.function => true,
  _ => false,
};

const _signs = {
  '=',
  '!=',
  '~',
  '!~',
  '<',
  '<=',
  '>',
  '>=',
  '?=',
  '?!=',
  '?~',
  '?!~',
  '?<',
  '?<=',
  '?>',
  '?>=',
};

// The scanner only lets `@`, `#` and `_` start a name and letters, digits,
// `_`, `.` and `:` follow.
bool _isValidIdentifier(String literal) =>
    !literal.endsWith('.') &&
    !literal.endsWith(':') &&
    literal != '@' &&
    literal != '_' &&
    literal != '#';
final _number = RegExp(r'^-?[0-9]+(\.[0-9]+)?$');

const _maxFunctionDepth = 3;

final class _Scanner {
  new(this._data);

  final String _data;
  var _position = 0;

  // The server reads a NUL as the end of the input.
  int get _peek {
    if (_position >= _data.length) return 0;
    return _data.codeUnitAt(_position);
  }

  int _read() {
    final char = _peek;
    if (char != 0) _position++;
    return char;
  }

  /// The next token, skipping blanks and comments; null at the end.
  FexprToken? scan() {
    while (true) {
      final char = _peek;
      if (char == 0) return null;
      if (_isWhitespace(char)) {
        _position++;
        continue;
      }
      if (char == 0x28) return _group();
      if (_isIdentifierStart(char)) {
        return _identifierOrFunction(_maxFunctionDepth);
      }
      if (_isNumberStart(char)) return _numberToken();
      if (_isQuote(char)) return _text(preserveQuotes: false);
      if (_isSignStart(char)) return _run(FexprTokenType.sign, _isSignStart);
      if (_isJoinStart(char)) return _run(FexprTokenType.join, _isJoinStart);
      if (char == 0x2F) {
        _comment();
        continue;
      }
      throw FexprSyntaxError('unexpected character at offset $_position');
    }
  }

  FexprToken _run(FexprTokenType type, bool Function(int) belongs) {
    final start = _position;
    while (belongs(_peek)) {
      _position++;
    }
    final literal = _data.substring(start, _position);
    final valid = type == FexprTokenType.sign
        ? _signs.contains(literal)
        : literal == '&&' || literal == '||';
    if (!valid) {
      throw FexprSyntaxError(
        type == FexprTokenType.sign
            ? 'invalid sign operator'
            : 'invalid join operator',
      );
    }
    return FexprToken(type, literal);
  }

  void _comment() {
    _position++;
    if (_read() != 0x2F) throw const FexprSyntaxError('invalid comment');
    while (true) {
      final char = _read();
      if (char == 0 || char == 0x0A) return;
    }
  }

  FexprToken _identifierOrFunction(int depth) {
    final start = _position;
    _position++;
    while (true) {
      final char = _peek;
      if (char == 0x28) {
        final name = _data.substring(start, _position);
        if (depth <= 0) {
          throw const FexprSyntaxError('max nested function arguments reached');
        }
        if (!_isValidIdentifier(name)) {
          throw const FexprSyntaxError('invalid function name');
        }
        _functionArguments(depth);
        return FexprToken(FexprTokenType.function, name);
      }
      if (!_isIdentifierPart(char)) break;
      _position++;
    }
    final literal = _data.substring(start, _position);
    if (!_isValidIdentifier(literal)) {
      throw const FexprSyntaxError('invalid identifier');
    }
    return FexprToken(FexprTokenType.identifier, literal);
  }

  void _functionArguments(int depth) {
    _position++;
    var expectComma = false;
    var afterComma = false;
    while (true) {
      final char = _peek;
      if (char == 0) {
        throw const FexprSyntaxError('invalid or incomplete function call');
      }
      if (char == 0x29) {
        _position++;
        if (afterComma) {
          throw const FexprSyntaxError('unexpected trailing comma');
        }
        return;
      }
      if (_isWhitespace(char)) {
        _position++;
        continue;
      }
      if (char == 0x2F) {
        _comment();
        continue;
      }
      if (char == 0x2C) {
        if (!expectComma) throw const FexprSyntaxError('unexpected comma');
        _position++;
        expectComma = false;
        afterComma = true;
        continue;
      }
      if (expectComma) {
        throw const FexprSyntaxError('expected comma after the last argument');
      }
      if (_isIdentifierStart(char)) {
        _identifierOrFunction(depth - 1);
      } else if (_isNumberStart(char)) {
        _numberToken();
      } else if (_isQuote(char)) {
        _text(preserveQuotes: false);
      } else {
        throw const FexprSyntaxError('unsupported argument character');
      }
      expectComma = true;
      afterComma = false;
    }
  }

  FexprToken _numberToken() {
    final start = _position;
    _position++;
    var hadDot = false;
    while (true) {
      final char = _peek;
      if (char == 0x2E && !hadDot) {
        hadDot = true;
      } else if (!_isDigit(char)) {
        break;
      }
      _position++;
    }
    final literal = _data.substring(start, _position);
    if (!_number.hasMatch(literal)) {
      throw const FexprSyntaxError('invalid number');
    }
    return FexprToken(FexprTokenType.number, literal);
  }

  FexprToken _text({required bool preserveQuotes}) {
    final start = _position;
    final quote = _read();
    while (true) {
      final char = _read();
      if (char == 0) {
        throw const FexprSyntaxError('invalid quoted text');
      }
      if (char == 0x5C) {
        if (_read() == 0) {
          throw const FexprSyntaxError('invalid quoted text');
        }
        continue;
      }
      if (char == quote) break;
    }
    final raw = _data.substring(start, _position);
    return FexprToken(
      FexprTokenType.text,
      preserveQuotes ? raw : _unescape(raw.substring(1, raw.length - 1)),
    );
  }

  FexprToken _group() {
    _position++;
    final buffer = StringBuffer();
    var open = 1;
    while (true) {
      final char = _peek;
      if (char == 0) {
        throw FexprSyntaxError(
          'invalid formatted group - missing $open closing bracket(s)',
        );
      }
      if (_isQuote(char)) {
        buffer.write(_text(preserveQuotes: true).literal);
        continue;
      }
      _position++;
      if (char == 0x28) {
        open++;
      } else if (char == 0x29) {
        open--;
        if (open == 0) break;
      }
      buffer.writeCharCode(char);
    }
    return FexprToken(FexprTokenType.group, buffer.toString());
  }
}

String _unescape(String text) {
  if (!text.contains(r'\')) return text;
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char != r'\' || i + 1 == text.length) {
      buffer.write(char);
      continue;
    }
    final next = text[++i];
    buffer.write(switch (next) {
      'n' => '\n',
      't' => '\t',
      'r' => '\r',
      r'\' || "'" || '"' => next,
      _ => '\\$next',
    });
  }
  return buffer.toString();
}

bool _isWhitespace(int char) => char == 0x20 || char == 0x09 || char == 0x0A;

bool _isDigit(int char) => char >= 0x30 && char <= 0x39;

bool _isLetter(int char) =>
    (char >= 0x61 && char <= 0x7A) || (char >= 0x41 && char <= 0x5A);

bool _isIdentifierStart(int char) =>
    _isLetter(char) || char == 0x5F || char == 0x40 || char == 0x23;

bool _isIdentifierPart(int char) =>
    _isLetter(char) ||
    _isDigit(char) ||
    char == 0x5F ||
    char == 0x2E ||
    char == 0x3A;

bool _isNumberStart(int char) => char == 0x2D || _isDigit(char);

bool _isQuote(int char) => char == 0x27 || char == 0x22;

bool _isSignStart(int char) =>
    char == 0x3D ||
    char == 0x3F ||
    char == 0x21 ||
    char == 0x3E ||
    char == 0x3C ||
    char == 0x7E;

bool _isJoinStart(int char) => char == 0x26 || char == 0x7C;
