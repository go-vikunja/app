import 'dart:convert';

/// The fields of the error bodies Vikunja sends: v1 `{code, message,
/// invalid_fields?}`, v2 problem+json `{status, title, detail, code?,
/// errors?}` and Echo's plain `{message}`.
final class ErrorBody {
  new _(this._json);

  /// Null when [data] is not a JSON object.
  static ErrorBody? tryParse(Object? data) {
    final json = switch (data) {
      final Map<String, Object?> map => map,
      final String text => _decode(text),
      final List<int> bytes => _decode(
        utf8.decode(bytes, allowMalformed: true),
      ),
      _ => null,
    };
    return json == null ? null : ErrorBody._(json);
  }

  final Map<String, Object?> _json;

  /// Since 2.4.0 a 403 without a domain error carries `"code": 0`.
  int? get code => switch (_json['code']) {
    final int code when code != 0 => code,
    _ => null,
  };

  String get message {
    for (final key in const ['detail', 'message', 'title']) {
      if (_json[key] case final String text when text.trim().isNotEmpty) {
        return text.trim();
      }
    }
    return '';
  }

  /// Since 2.8.0 a 404 for something in the trash (codes 4040 and 3018)
  /// describes it here, in v1 and v2 alike. Null when absent or not an
  /// object.
  Map<String, Object?>? get details => switch (_json['details']) {
    final Map<String, Object?> details => details,
    _ => null,
  };

  /// Field name to messages from v1 `invalid_fields` (`"title: reason"` or a
  /// bare field name) and v2 `errors[]` (`location` `body.title`). Null when
  /// the body has neither.
  Map<String, List<String>>? get fieldErrors {
    final invalidFields = _json['invalid_fields'];
    final errors = _json['errors'];
    if (invalidFields is! List<Object?> && errors is! List<Object?>) {
      return null;
    }
    final fields = <String, List<String>>{};
    if (invalidFields is List<Object?>) {
      for (final entry in invalidFields.whereType<String>()) {
        final separator = entry.indexOf(': ');
        final field = separator < 0 ? entry : entry.substring(0, separator);
        final messages = fields.putIfAbsent(field.trim(), () => []);
        if (separator >= 0) messages.add(entry.substring(separator + 2));
      }
    }
    if (errors is List<Object?>) {
      for (final entry in errors.whereType<Map<String, Object?>>()) {
        final location = switch (entry['location']) {
          final String location => location,
          _ => '',
        };
        final field = location.startsWith('body.')
            ? location.substring('body.'.length)
            : location;
        final messages = fields.putIfAbsent(field, () => []);
        if (entry['message'] case final String message) messages.add(message);
      }
    }
    return {
      for (final MapEntry(:key, :value) in fields.entries)
        key: List.unmodifiable(value),
    };
  }

  static Map<String, Object?>? _decode(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
