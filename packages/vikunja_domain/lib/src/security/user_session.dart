import 'package:meta/meta.dart';

/// A signed-in session of the user: a web login or an app's OAuth sign-in.
@immutable
final class UserSession {
  const new({
    required this.id,
    this.deviceInfo = '',
    this.ipAddress = '',
    this.created,
    this.lastActive,
  });

  /// A UUID, also the `sid` claim of the session's access tokens.
  final String id;

  /// The raw User-Agent of the request that created the session.
  final String deviceInfo;
  final String ipAddress;
  final DateTime? created;

  /// Moves only when the session's refresh token is used.
  final DateTime? lastActive;

  @override
  bool operator ==(Object other) =>
      other is UserSession &&
      other.id == id &&
      other.deviceInfo == deviceInfo &&
      other.ipAddress == ipAddress &&
      other.created == created &&
      other.lastActive == lastActive;

  @override
  int get hashCode =>
      Object.hash(id, deviceInfo, ipAddress, created, lastActive);

  @override
  String toString() => 'UserSession($id)';
}
