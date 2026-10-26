import 'package:meta/meta.dart';

enum AccountKind {
  /// Signed in through the browser with a user's OAuth session.
  user,

  /// A guest through a link share: one project, no user behind it.
  linkShare,
}

/// One signed-in identity: a user on a server, or a guest through one link
/// share. The same user, or the same share, on the same server is always the
/// same account; secrets live outside this object.
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
  }) : kind = AccountKind.user,
       linkShareId = null,
       projectId = null,
       shareName = null;

  /// The server shows a guest as the pseudo user `-shareId` named
  /// `link-share-<shareId>` in `created_by` and `author`.
  const new linkShare({
    required this.id,
    required this.serverRoot,
    required int shareId,
    required int this.projectId,
    required this.displayName,
    required this.addedAt,
    this.shareName,
    this.needsReauth = false,
  }) : kind = AccountKind.linkShare,
       linkShareId = shareId,
       userId = -shareId,
       username = 'link-share-$shareId';

  final String id;
  final AccountKind kind;
  final Uri serverRoot;

  /// The server's user id; for a guest the negative share id.
  final int userId;
  final String username;
  final String displayName;
  final DateTime addedAt;

  /// The server ended the session; the account stays with its local data
  /// until the user signs in again or removes it.
  final bool needsReauth;

  /// Null unless [isLinkShare].
  final int? linkShareId;

  /// The shared project; null unless [isLinkShare].
  final int? projectId;

  /// The name the share's creator gave it; null when it has none.
  final String? shareName;

  bool get isLinkShare => kind == AccountKind.linkShare;

  Account copyWith({String? displayName, bool? needsReauth}) => switch (kind) {
    AccountKind.user => Account(
      id: id,
      serverRoot: serverRoot,
      userId: userId,
      username: username,
      displayName: displayName ?? this.displayName,
      addedAt: addedAt,
      needsReauth: needsReauth ?? this.needsReauth,
    ),
    AccountKind.linkShare => Account.linkShare(
      id: id,
      serverRoot: serverRoot,
      shareId: linkShareId!,
      projectId: projectId!,
      displayName: displayName ?? this.displayName,
      addedAt: addedAt,
      shareName: shareName,
      needsReauth: needsReauth ?? this.needsReauth,
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.kind == kind &&
      other.serverRoot == serverRoot &&
      other.userId == userId &&
      other.username == username &&
      other.displayName == displayName &&
      other.addedAt == addedAt &&
      other.needsReauth == needsReauth &&
      other.linkShareId == linkShareId &&
      other.projectId == projectId &&
      other.shareName == shareName;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    serverRoot,
    userId,
    username,
    displayName,
    addedAt,
    needsReauth,
    linkShareId,
    projectId,
    shareName,
  );

  @override
  String toString() => 'Account($id, $username@${serverRoot.host})';
}
