import 'package:meta/meta.dart';
import 'package:vikunja_api/src/auth/jwt_payload.dart';

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
    final payload = jwtPayload(token);
    if (payload == null) return null;

    final userId = jwtInteger(payload['id']);
    final username = payload['username'];
    final sessionId = payload['sid'];
    final expiresAt = jwtTime(payload['exp']);
    if (jwtInteger(payload['type']) != _userTokenType ||
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
      issuedAt: jwtTime(payload['iat']),
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
