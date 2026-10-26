import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';
import 'package:vikunja_domain/src/project/permission.dart';

@immutable
final class TeamMember {
  const new({required this.user, this.admin = false});

  final User user;
  final bool admin;

  @override
  bool operator ==(Object other) =>
      other is TeamMember && other.user == user && other.admin == admin;

  @override
  int get hashCode => Object.hash(user, admin);

  @override
  String toString() => 'TeamMember(${user.id}, admin: $admin)';
}

/// A team as the server reads it; never stored on the device.
@immutable
final class Team {
  new({
    required this.id,
    required this.name,
    this.description = '',
    this.isPublic = false,
    this.isExternal = false,
    this.createdBy,
    List<TeamMember> members = const [],
    this.created,
    this.updated,
    this.maxPermission,
  }) : members = List.unmodifiable(members);

  /// The server's limit in code points.
  static const maxNameLength = 250;

  final int id;

  /// An external team's name ends in ` (<provider>)`.
  final String name;

  /// HTML. The server cannot store an empty one: an empty write keeps the
  /// old text.
  final String description;

  /// Stored even while the server has public teams turned off.
  final bool isPublic;

  /// Synced from a sign-in provider (OIDC or LDAP): the server refuses to
  /// remove its members, and the provider overwrites name and description.
  final bool isExternal;

  /// Null once the creator has left the team.
  final User? createdBy;

  /// In the server's order (by user id).
  final List<TeamMember> members;
  final DateTime? created;
  final DateTime? updated;

  /// The user's permission from a single read: [Permission.admin] for team
  /// admins, [Permission.read] for members; null from a list.
  final Permission? maxPermission;

  @override
  bool operator ==(Object other) =>
      other is Team &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.isPublic == isPublic &&
      other.isExternal == isExternal &&
      other.createdBy == createdBy &&
      _sameMembers(other.members, members) &&
      other.created == created &&
      other.updated == updated &&
      other.maxPermission == maxPermission;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    isPublic,
    isExternal,
    createdBy,
    Object.hashAll(members),
    created,
    updated,
    maxPermission,
  );

  /// Without the name, which is user text.
  @override
  String toString() => 'Team($id, ${members.length} members)';

  static bool _sameMembers(List<TeamMember> a, List<TeamMember> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// What the app sends to create a team; the creator becomes its admin.
@immutable
final class NewTeam {
  const new({required this.name, this.description, this.isPublic});

  final String name;

  /// HTML.
  final String? description;

  /// Only meaningful while the server has public teams turned on.
  final bool? isPublic;

  @override
  bool operator ==(Object other) =>
      other is NewTeam &&
      other.name == name &&
      other.description == description &&
      other.isPublic == isPublic;

  @override
  int get hashCode => Object.hash(name, description, isPublic);

  /// Without user text.
  @override
  String toString() => 'NewTeam(isPublic: $isPublic)';
}

/// The fields of one team edit; a null field stays as it is on the server.
@immutable
final class TeamChanges {
  const new({this.name, this.description, this.isPublic});

  final String? name;

  /// HTML; empty clears it (sent as an empty paragraph, which the server
  /// stores, unlike an empty text).
  final String? description;
  final bool? isPublic;

  bool get isEmpty => name == null && description == null && isPublic == null;

  @override
  bool operator ==(Object other) =>
      other is TeamChanges &&
      other.name == name &&
      other.description == description &&
      other.isPublic == isPublic;

  @override
  int get hashCode => Object.hash(name, description, isPublic);

  /// Names the fields set, without user text.
  @override
  String toString() {
    final fields = [
      if (name != null) 'name',
      if (description != null) 'description',
      if (isPublic != null) 'isPublic: $isPublic',
    ];
    return 'TeamChanges(${fields.join(', ')})';
  }
}
