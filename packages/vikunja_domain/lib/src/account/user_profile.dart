import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';

/// The signed-in user as `GET /user` describes them, apart from the
/// settings. The server never sends the current email address.
@immutable
final class UserProfile {
  const new({
    required this.id,
    required this.username,
    this.name = '',
    this.isLocalUser = true,
    this.authProvider = '',
    this.pendingEmail,
    this.updated,
    this.deletionScheduledAt,
  });

  final int id;
  final String username;
  final String name;

  /// False for OIDC and LDAP accounts: they have no password on the server,
  /// and every sign-in overwrites their name and email.
  final bool isLocalUser;

  /// `local`, `ldap`, the OIDC provider's configured name, or empty.
  final String authProvider;

  /// An email change waiting for its confirmation link (servers with a
  /// mailer); the old address stays active until then.
  final String? pendingEmail;

  /// Bumped by every write to the user; the only sign that the avatar
  /// changed, since avatar answers carry no cache validators.
  final DateTime? updated;

  /// When the server will delete the account, set once the user confirmed
  /// the deletion mail. A past date does not mean the account is gone: the
  /// hourly deletion can fail and retry.
  final DateTime? deletionScheduledAt;

  String get displayName => name.trim().isEmpty ? username : name.trim();

  User get user => User(id: id, username: username, name: name);

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.username == username &&
      other.name == name &&
      other.isLocalUser == isLocalUser &&
      other.authProvider == authProvider &&
      other.pendingEmail == pendingEmail &&
      other.updated == updated &&
      other.deletionScheduledAt == deletionScheduledAt;

  @override
  int get hashCode => Object.hash(
    id,
    username,
    name,
    isLocalUser,
    authProvider,
    pendingEmail,
    updated,
    deletionScheduledAt,
  );

  @override
  String toString() => 'UserProfile($id, $username)';
}
