import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user.dart';
import 'package:vikunja_domain/src/project/permission.dart';

/// A project shared directly with a user. The owner and team members are
/// not listed.
@immutable
final class ProjectUserShare {
  const new({required this.user, required this.permission});

  final User user;
  final Permission permission;

  @override
  bool operator ==(Object other) =>
      other is ProjectUserShare &&
      other.user == user &&
      other.permission == permission;

  @override
  int get hashCode => Object.hash(user, permission);

  @override
  String toString() => 'ProjectUserShare(${user.id}, ${permission.name})';
}

/// A project shared with a team.
@immutable
final class ProjectTeamShare {
  const new({
    required this.teamId,
    required this.permission,
    this.teamName,
    this.memberCount,
  });

  final int teamId;

  /// Null when the server hides the team from the reader: one they are not
  /// in that is not public.
  final String? teamName;

  /// Null when the server sent no members (a hidden team).
  final int? memberCount;
  final Permission permission;

  bool get isHidden => teamName == null;

  @override
  bool operator ==(Object other) =>
      other is ProjectTeamShare &&
      other.teamId == teamId &&
      other.teamName == teamName &&
      other.memberCount == memberCount &&
      other.permission == permission;

  @override
  int get hashCode => Object.hash(teamId, teamName, memberCount, permission);

  @override
  String toString() => 'ProjectTeamShare($teamId, ${permission.name})';
}
