enum HeaderProblem {
  emptyName,

  /// Not an RFC 7230 token.
  invalidName,

  /// Owned by the HTTP stack, Vikunja or the WebSocket upgrade.
  reservedName,

  /// Another header has the same name, ignoring case.
  duplicateName,
  emptyValue,

  /// Only visible ASCII is allowed; a control character, a no-break space,
  /// a zero-width character or any other non-ASCII text is refused.
  nonAscii,
  valueTooLong,
  tooManyHeaders,
}

enum HeaderPreset {
  cloudflareAccessServiceToken([
    'CF-Access-Client-Id',
    'CF-Access-Client-Secret',
  ]),
  custom([]);

  new(this.names);

  final List<String> names;
}

/// Which custom headers a connection profile may send.
abstract final class HeaderRules {
  static const maxHeaders = 10;
  static const maxValueLength = 4096;

  static const _reservedNames = {
    'host',
    'authorization',
    'cookie',
    'content-length',
    'content-type',
    'content-encoding',
    'transfer-encoding',
    'connection',
    'upgrade',
    'user-agent',
    'accept',
    'accept-encoding',
    'origin',
    'range',
    'if-range',
    'expect',
    'te',
    'trailer',
    'keep-alive',
    'cache-control',
  };

  static const _reservedPrefixes = ['proxy-', 'sec-'];

  static final _token = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

  // Visible ASCII at both ends; spaces and tabs only inside.
  static final _value = RegExp(r'^[\x21-\x7E](?:[\x20-\x7E\t]*[\x21-\x7E])?$');

  /// The form a value is stored and sent in.
  static String normalizeValue(String value) => value.trim();

  static HeaderProblem? validateName(String name) {
    if (name.isEmpty) return HeaderProblem.emptyName;
    if (!_token.hasMatch(name)) return HeaderProblem.invalidName;
    final lower = name.toLowerCase();
    if (_reservedNames.contains(lower) ||
        _reservedPrefixes.any(lower.startsWith)) {
      return HeaderProblem.reservedName;
    }
    return null;
  }

  /// Checks [value] as [normalizeValue] leaves it.
  static HeaderProblem? validateValue(String value) {
    final normalized = normalizeValue(value);
    if (normalized.isEmpty) return HeaderProblem.emptyValue;
    if (normalized.length > maxValueLength) return HeaderProblem.valueTooLong;
    if (!_value.hasMatch(normalized)) return HeaderProblem.nonAscii;
    return null;
  }

  static HeaderProblem? validate(String name, String value) =>
      validateName(name) ?? validateValue(value);

  /// The first problem of a whole set, in entry order; duplicates and the
  /// count are checked across entries.
  static HeaderProblem? validateAll(Iterable<(String, String)> headers) {
    final seen = <String>{};
    var count = 0;
    for (final (name, value) in headers) {
      if (++count > maxHeaders) return HeaderProblem.tooManyHeaders;
      if (validate(name, value) case final problem?) return problem;
      if (!seen.add(name.toLowerCase())) return HeaderProblem.duplicateName;
    }
    return null;
  }
}
