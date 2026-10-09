import 'package:meta/meta.dart';

/// One signed-in identity: a user on a server. The same user on the same
/// server is always the same account; secrets live outside this object.
@immutable
final class Account {
  const new({
    required this.id,
    required this.serverRoot,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.addedAt,
    this.needsReauth = false,
  });

  final String id;
  final Uri serverRoot;
  final int userId;
  final String username;
  final String displayName;
  final DateTime addedAt;

  /// The server ended the session; the account stays with its local data
  /// until the user signs in again or removes it.
  final bool needsReauth;

  Account copyWith({String? displayName, bool? needsReauth}) => Account(
    id: id,
    serverRoot: serverRoot,
    userId: userId,
    username: username,
    displayName: displayName ?? this.displayName,
    addedAt: addedAt,
    needsReauth: needsReauth ?? this.needsReauth,
  );

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.serverRoot == serverRoot &&
      other.userId == userId &&
      other.username == username &&
      other.displayName == displayName &&
      other.addedAt == addedAt &&
      other.needsReauth == needsReauth;

  @override
  int get hashCode => Object.hash(
    id,
    serverRoot,
    userId,
    username,
    displayName,
    addedAt,
    needsReauth,
  );

  @override
  String toString() => 'Account($id, $username@${serverRoot.host})';
}
