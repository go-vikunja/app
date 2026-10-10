/// A body whose shape this client does not understand. Never carries the
/// input itself, which could hold a token.
final class MalformedJson implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'MalformedJson: $message';
}

Map<String, Object?> objectOf(Object? value, String what) => switch (value) {
  final Map<String, Object?> map => map,
  _ => throw MalformedJson('$what is not a JSON object'),
};

/// Null and non-list values are empty; non-object entries are skipped.
List<Map<String, Object?>> objectListOf(Object? value) => switch (value) {
  final List<Object?> list => list.whereType<Map<String, Object?>>().toList(),
  _ => const [],
};

List<String> stringListOf(Object? value) => switch (value) {
  final List<Object?> list => List.unmodifiable(list.whereType<String>()),
  _ => const [],
};

int requireInt(Map<String, Object?> json, String key, String what) =>
    switch (json[key]) {
      final int value => value,
      _ => throw MalformedJson('$what without $key'),
    };

String requireString(Map<String, Object?> json, String key, String what) =>
    switch (json[key]) {
      final String value => value,
      _ => throw MalformedJson('$what without $key'),
    };

int intOr(Map<String, Object?> json, String key, int fallback) =>
    switch (json[key]) {
      final int value => value,
      _ => fallback,
    };

double doubleOr(Map<String, Object?> json, String key, double fallback) =>
    switch (json[key]) {
      final num value => value.toDouble(),
      _ => fallback,
    };

bool boolOr(Map<String, Object?> json, String key, {required bool fallback}) =>
    switch (json[key]) {
      final bool value => value,
      _ => fallback,
    };

String stringOr(Map<String, Object?> json, String key, String fallback) =>
    switch (json[key]) {
      final String value => value,
      _ => fallback,
    };

/// Go's zero time: the server sends it for "no date" and clears a date
/// when it receives it.
const zeroDate = '0001-01-01T00:00:00Z';

/// RFC 3339 in the server's zone, converted to UTC. [zeroDate] means
/// "no date".
DateTime? dateOf(Object? value) {
  if (value is! String) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.year <= 1) return null;
  return parsed.toUtc();
}

String encodeDate(DateTime value) => value.toUtc().toIso8601String();

final _sixHexDigits = RegExp(r'^[0-9a-f]{6}$');
final _threeHexDigits = RegExp(r'^[0-9a-f]{3}$');

/// Six lowercase hex digits without `#`, or empty for anything else.
String hexColorOf(Object? value) {
  if (value is! String) return '';
  var hex = value.trim().toLowerCase();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (_threeHexDigits.hasMatch(hex)) {
    hex = hex.split('').map((digit) => '$digit$digit').join();
  }
  return _sixHexDigits.hasMatch(hex) ? hex : '';
}
