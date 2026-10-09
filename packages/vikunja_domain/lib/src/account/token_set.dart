import 'package:meta/meta.dart';

/// Tokens of one server session. Vikunja rotates [refreshToken] on every
/// refresh without a grace period, so the newest one must be persisted
/// before anything else happens.
@immutable
final class TokenSet {
  const new({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiry,
    required this.issuedAt,
    required this.sessionId,
    required this.userId,
    required this.username,
  });

  final String accessToken;
  final String refreshToken;

  /// `exp` of the access token, in server time.
  final DateTime accessTokenExpiry;

  /// `iat` of the access token, in server time.
  final DateTime issuedAt;

  /// `sid` claim: the server-side session this token belongs to.
  final String sessionId;
  final int userId;
  final String username;

  @override
  bool operator ==(Object other) =>
      other is TokenSet &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken &&
      other.accessTokenExpiry == accessTokenExpiry &&
      other.issuedAt == issuedAt &&
      other.sessionId == sessionId &&
      other.userId == userId &&
      other.username == username;

  @override
  int get hashCode => Object.hash(
    accessToken,
    refreshToken,
    accessTokenExpiry,
    issuedAt,
    sessionId,
    userId,
    username,
  );

  @override
  String toString() =>
      'TokenSet(user: $userId, sid: $sessionId, exp: $accessTokenExpiry)';
}
