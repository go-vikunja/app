import 'dart:convert';

import 'package:meta/meta.dart';

/// The payload of a Vikunja user JWT. The signature cannot be checked on the
/// client (HS256 with the server secret); the server checks it.
@immutable
final class JwtClaims {
  const new({
    required this.userId,
    required this.username,
    required this.sessionId,
    required this.issuedAt,
    required this.expiresAt,
  });

  /// Null unless [token] is a well-formed user JWT (`type` 1 with `id`,
  /// `username`, `sid` and `exp`; `iat` is optional).
  static JwtClaims? tryParse(String token) {
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
    if (payload is! Map<String, Object?>) return null;

    final userId = _integer(payload['id']);
    final username = payload['username'];
    final sessionId = payload['sid'];
    final expiresAt = _time(payload['exp']);
    if (_integer(payload['type']) != _userTokenType ||
        userId == null ||
        username is! String ||
        sessionId is! String ||
        sessionId.isEmpty ||
        expiresAt == null) {
      return null;
    }
    return JwtClaims(
      userId: userId,
      username: username,
      sessionId: sessionId,
      issuedAt: _time(payload['iat']),
      expiresAt: expiresAt,
    );
  }

  static const _userTokenType = 1;

  final int userId;
  final String username;
  final String sessionId;

  /// Server time. 2.3.0 and 2.4.0 send no `iat`.
  final DateTime? issuedAt;

  /// Server time.
  final DateTime expiresAt;

  @override
  String toString() => 'JwtClaims(user: $userId, sid: $sessionId)';
}

int? _integer(Object? value) => switch (value) {
  final int integer => integer,
  final double number when number == number.truncateToDouble() =>
    number.toInt(),
  _ => null,
};

// The range DateTime can represent.
const _maxSeconds = 8640000000000;

DateTime? _time(Object? value) => switch (value) {
  final num seconds when seconds.isFinite && seconds.abs() <= _maxSeconds =>
    DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round(), isUtc: true),
  _ => null,
};
