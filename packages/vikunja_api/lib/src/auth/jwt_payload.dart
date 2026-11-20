import 'dart:convert';

/// The decoded payload of a three-part JWT; null when it is no JSON object.
/// The signature is not checked: only the server can.
Map<String, Object?>? jwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  final Object? payload;
  try {
    payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
  } on FormatException {
    return null;
  }
  return payload is Map<String, Object?> ? payload : null;
}

int? jwtInteger(Object? value) => switch (value) {
  final int integer => integer,
  final double number when number == number.truncateToDouble() =>
    number.toInt(),
  _ => null,
};

// The range DateTime can represent.
const _maxSeconds = 8640000000000;

DateTime? jwtTime(Object? value) => switch (value) {
  final num seconds when seconds.isFinite && seconds.abs() <= _maxSeconds =>
    DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round(), isUtc: true),
  _ => null,
};
