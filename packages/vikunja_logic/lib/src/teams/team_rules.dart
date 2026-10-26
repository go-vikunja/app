import 'package:vikunja_domain/vikunja_domain.dart';

/// The sign-in provider that manages an external team, from the ` (<name>)`
/// the server appends to the names of the teams it syncs, e.g. `Keycloak`
/// for `Developers (Keycloak)`; null without one.
String? externalTeamProvider(String name) =>
    _providerSuffix.firstMatch(name.trimRight())?[1]?.trim().nonEmpty;

final _providerSuffix = RegExp(r'\S\s+\(([^()]*[^()\s][^()]*)\)$');

enum TeamLeaveRule {
  allowed,

  /// The user is the team's only admin and others remain, who would be
  /// left with a team nobody can change; the server does not prevent it.
  makeSomeoneAdminFirst,

  /// The user is the last member, whom the server never removes; an admin
  /// deletes the team instead.
  deleteInstead,

  /// An external team (the server refuses), a team the user is not in, or
  /// the last member who cannot delete it.
  unavailable,
}

/// What the user may do with a team, from its members. The server lacks
/// these guards: it lets the only admin leave or demote themselves, which
/// freezes the team.
final class TeamGuards {
  const new({
    required this.members,
    required this.currentUserId,
    required this.isExternal,
  });

  factory of(Team team, {required int currentUserId}) => TeamGuards(
    members: team.members,
    currentUserId: currentUserId,
    isExternal: team.isExternal,
  );

  final List<TeamMember> members;
  final int currentUserId;
  final bool isExternal;

  TeamMember? get _me =>
      members.where((member) => member.user.id == currentUserId).firstOrNull;

  bool get isMember => _me != null;

  bool get isAdmin => _me?.admin ?? false;

  /// Name, description and the public switch; a provider owns an external
  /// team's.
  bool get canEdit => isAdmin && !isExternal;

  bool get canAddMembers => isAdmin && !isExternal;

  /// Never on the user's own row.
  bool canToggleAdmin(TeamMember member) =>
      isAdmin && member.user.id != currentUserId;

  /// Never on the user's own row; the server refuses it for external teams.
  bool canRemoveMember(TeamMember member) =>
      canToggleAdmin(member) && !isExternal;

  bool get canDelete => isAdmin;

  TeamLeaveRule get leave {
    final me = _me;
    if (me == null || isExternal) return TeamLeaveRule.unavailable;
    if (members.length == 1) {
      return me.admin ? TeamLeaveRule.deleteInstead : TeamLeaveRule.unavailable;
    }
    final admins = members.where((member) => member.admin).length;
    if (me.admin && admins == 1) return TeamLeaveRule.makeSomeoneAdminFirst;
    return TeamLeaveRule.allowed;
  }
}

extension on String {
  String? get nonEmpty => isEmpty ? null : this;
}
