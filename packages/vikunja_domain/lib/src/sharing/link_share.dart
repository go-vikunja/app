import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';
import 'package:vikunja_domain/src/project/permission.dart';

/// A link that opens a project without an account. The server cannot
/// change one: it is created and deleted only.
@immutable
final class LinkShare {
  const new({
    required this.id,
    required this.hash,
    required this.permission,
    this.name = '',
    this.passwordProtected = false,
    this.sharedBy,
    this.created,
  });

  final int id;

  /// The link's long-lived secret: only ever shown inside its URL, never
  /// logged or stored.
  final String hash;

  /// Shown as the author of what is changed through the link; may be empty.
  final String name;
  final Permission permission;
  final bool passwordProtected;
  final User? sharedBy;
  final DateTime? created;

  @override
  bool operator ==(Object other) =>
      other is LinkShare &&
      other.id == id &&
      other.hash == hash &&
      other.name == name &&
      other.permission == permission &&
      other.passwordProtected == passwordProtected &&
      other.sharedBy == sharedBy &&
      other.created == created;

  @override
  int get hashCode => Object.hash(
    id,
    hash,
    name,
    permission,
    passwordProtected,
    sharedBy,
    created,
  );

  /// Never with the hash.
  @override
  String toString() =>
      'LinkShare($id, ${permission.name}, '
      'passwordProtected: $passwordProtected)';
}

/// What the app sends to create a link share.
@immutable
final class NewLinkShare {
  const new({required this.permission, this.name, this.password});

  final Permission permission;
  final String? name;

  /// Never stored or logged.
  final String? password;

  @override
  bool operator ==(Object other) =>
      other is NewLinkShare &&
      other.permission == permission &&
      other.name == name &&
      other.password == password;

  @override
  int get hashCode => Object.hash(permission, name, password);

  /// Never with the password or the name.
  @override
  String toString() =>
      'NewLinkShare(${permission.name}, '
      'password: ${password?.isNotEmpty ?? false})';
}
