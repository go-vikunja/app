import 'dart:async';
import 'dart:math';
import 'dart:ui' show Rect;

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/files/link_share_actions.dart';
import 'package:vikunja_mobile/core/repositories/project_sharing_repository.dart';
import 'package:vikunja_mobile/core/repositories/team_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

/// The signed-in user of the team and sharing fakes.
const fakeMe = User(id: 1, username: 'me', name: 'Me Myself');

/// Made up like a real one (40 letters and digits), so a test can look for
/// it where it must not be.
String fakeLinkShareHash(int id) => 'Hx${'$id'.padLeft(38, '0')}';

int _nextId(Iterable<int> ids) => ids.fold(0, max) + 1;

/// What the fakes record of every call, and how a test fails or holds one:
/// each call is added to [calls] first (`list`, `read 5`, `addMember 5
/// ben`, …); [beforeCall] can hold it, and the entry of [failures] for the
/// method name, else [failure], is thrown instead while set, with nothing
/// changed.
mixin _Calls {
  final List<String> calls = [];
  Exception? failure;
  final Map<String, Exception> failures = {};
  Future<void> Function(String call)? beforeCall;

  Future<void> _call(String method, [String detail = '']) async {
    calls.add(detail.isEmpty ? method : '$method $detail');
    await beforeCall?.call(calls.last);
    if (failures[method] ?? failure case final failure?) throw failure;
  }
}

/// The account's teams as the server holds them, in [teams], with [me] as
/// the signed-in user; [publicTeams] are other public teams that a list
/// with `includePublic` adds. [people] are the users a member can be added
/// by, by username. The server's answers and the real repository's checks
/// apply: a blank or too long name and the user's own row for a removal or
/// an admin toggle are `ArgumentError`s; [leave] follows `TeamGuards`;
/// adding an unknown user is a `NotFound` code 1005, a member a
/// `DomainError` code 6005; removing from an external team code 6010, the
/// last member code 6006; toggling one who is not in the team a
/// `TeamMemberMissing`; a team the user is not in is `Forbidden`. A leave
/// or delete asks [sync] for a quiet run, as the real one does.
final class FakeTeamRepository with _Calls implements TeamRepository {
  new({
    List<Team> teams = const [],
    this.publicTeams = const [],
    List<User> people = const [],
    this.me = fakeMe,
    this.sync,
    DateTime Function()? now,
  }) : teams = [...teams],
       people = [fakeMe, ...people],
       _now = now ?? DateTime.now;

  List<Team> teams;
  List<Team> publicTeams;
  List<User> people;
  User me;
  SyncEngine? sync;
  final DateTime Function() _now;

  /// The id the next created team gets; above every team's by default.
  int? nextTeamId;

  @override
  Future<List<Team>> list({String? query, bool includePublic = false}) async {
    await _call(
      'list',
      [
        if (query != null) 'query $query',
        if (includePublic) 'public',
      ].join(' '),
    );
    final needle = query?.trim().toLowerCase() ?? '';
    return [
      for (final team in [
        ...teams,
        if (includePublic)
          for (final public in publicTeams)
            if (!teams.any((team) => team.id == public.id)) public,
      ])
        if (team.name.toLowerCase().contains(needle)) _listed(team),
    ];
  }

  @override
  Future<Team> read(int id) async {
    await _call('read', '$id');
    return _read(id);
  }

  @override
  Future<Team> create(NewTeam team) async {
    await _call('create');
    if (teamNameProblem(team.name) != null) {
      throw ArgumentError.value(team, 'team');
    }
    final id = nextTeamId ?? _nextId(teams.map((team) => team.id));
    nextTeamId = null;
    final now = _now().toUtc();
    final created = Team(
      id: id,
      name: team.name.trim(),
      description: team.description ?? '',
      isPublic: team.isPublic ?? false,
      createdBy: me,
      members: [TeamMember(user: me, admin: true)],
      created: now,
      updated: now,
    );
    teams = [...teams, created];
    return _read(id);
  }

  @override
  Future<Team> update(int id, TeamChanges changes) async {
    await _call('update', '$id $changes');
    if (changes.name case final name? when teamNameProblem(name) != null) {
      throw ArgumentError.value(changes, 'changes');
    }
    final team = _adminOf(id);
    _replace(
      _copy(
        team,
        name: changes.name?.trim(),
        description: switch (changes.description) {
          '' => '<p></p>',
          final description => description,
        },
        isPublic: changes.isPublic,
      ),
    );
    return _read(id);
  }

  @override
  Future<void> delete(int id) async {
    await _call('delete', '$id');
    _adminOf(id);
    teams = [
      for (final team in teams)
        if (team.id != id) team,
    ];
    _settle();
  }

  @override
  Future<void> addMember(
    int teamId,
    String username, {
    bool admin = false,
  }) async {
    await _call('addMember', '$teamId $username${admin ? ' admin' : ''}');
    final team = _adminOf(teamId);
    final user = people
        .where((person) => person.username == username)
        .firstOrNull;
    if (user == null) throw const NotFound(code: 1005);
    if (team.members.any((member) => member.user.id == user.id)) {
      throw const DomainError(409, code: 6005);
    }
    _replace(
      _copy(
        team,
        members: [...team.members, TeamMember(user: user, admin: admin)]
          ..sort((a, b) => a.user.id.compareTo(b.user.id)),
      ),
    );
  }

  @override
  Future<void> removeMember(int teamId, String username) async {
    await _call('removeMember', '$teamId $username');
    if (username == me.username) throw ArgumentError.value(username);
    final team = _adminOf(teamId);
    _remove(team, username);
  }

  @override
  Future<bool> toggleAdmin(int teamId, String username) async {
    await _call('toggleAdmin', '$teamId $username');
    if (username == me.username) throw ArgumentError.value(username);
    final team = _adminOf(teamId);
    final member = team.members
        .where((member) => member.user.username == username)
        .firstOrNull;
    if (member == null) throw const TeamMemberMissing();
    _replace(
      _copy(
        team,
        members: [
          for (final each in team.members)
            if (each == member)
              TeamMember(user: each.user, admin: !each.admin)
            else
              each,
        ],
      ),
    );
    return !member.admin;
  }

  @override
  Future<void> leave(int teamId) async {
    await _call('leave', '$teamId');
    final team = _memberOf(teamId);
    final rule = TeamGuards.of(team, currentUserId: me.id).leave;
    if (rule != TeamLeaveRule.allowed) throw ArgumentError.value(rule);
    _remove(team, me.username);
    teams = [
      for (final each in teams)
        if (each.id != teamId) each,
    ];
    _settle();
  }

  void _remove(Team team, String username) {
    if (!team.members.any((member) => member.user.username == username)) {
      return;
    }
    if (team.isExternal) throw const DomainError(412, code: 6010);
    if (team.members.length == 1) throw const DomainError(400, code: 6006);
    _replace(
      _copy(
        team,
        members: [
          for (final member in team.members)
            if (member.user.username != username) member,
        ],
      ),
    );
  }

  /// The user's permission is in single reads only.
  Team _read(int id) {
    final team = _memberOf(id);
    final admin = team.members.any(
      (member) => member.user.id == me.id && member.admin,
    );
    return _copy(
      team,
      maxPermission: admin ? Permission.admin : Permission.read,
    );
  }

  Team _listed(Team team) => _copy(team, maxPermission: null);

  Team _memberOf(int id) {
    final team = teams.where((team) => team.id == id).firstOrNull;
    if (team == null ||
        !team.members.any((member) => member.user.id == me.id)) {
      throw const Forbidden();
    }
    return team;
  }

  Team _adminOf(int id) {
    final team = _memberOf(id);
    if (!team.members.any(
      (member) => member.user.id == me.id && member.admin,
    )) {
      throw const Forbidden();
    }
    return team;
  }

  void _replace(Team changed) => teams = [
    for (final team in teams)
      if (team.id == changed.id) changed else team,
  ];

  void _settle() {
    final sync = this.sync;
    if (sync != null) unawaited(sync.refreshAfterWrite().catchError((_) {}));
  }
}

const _unset = Object();

Team _copy(
  Team team, {
  String? name,
  String? description,
  bool? isPublic,
  List<TeamMember>? members,
  Object? maxPermission = _unset,
}) => Team(
  id: team.id,
  name: name ?? team.name,
  description: description ?? team.description,
  isPublic: isPublic ?? team.isPublic,
  isExternal: team.isExternal,
  createdBy: team.createdBy,
  members: members ?? team.members,
  created: team.created,
  updated: team.updated,
  maxPermission: identical(maxPermission, _unset)
      ? team.maxPermission
      : maxPermission as Permission?,
);

/// One project's shares as the server holds them.
final class FakeProjectShares {
  new({
    List<ProjectUserShare> users = const [],
    List<ProjectTeamShare> teams = const [],
    List<LinkShare> links = const [],
  }) : users = [...users],
       teams = [...teams],
       links = [...links];

  List<ProjectUserShare> users;
  List<ProjectTeamShare> teams;
  List<LinkShare> links;
}

/// The shares of [projects] as the server holds them (a project without an
/// entry has none), with [me] as the signed-in user. [people] are the users
/// a project can be shared with, by username, [teamNames] the teams the
/// user can share with and their member counts. Answers as the server does:
/// an unknown user is a `NotFound` code 1005, one already shared or
/// [ownerUsername] a `DomainError` code 7002, removing one without a share
/// a `Forbidden` code 7003; an unknown team a `NotFound` code 6002, one
/// already shared a `DomainError` code 6004, removing one without a share
/// a `Forbidden` code 6007; with [linkSharingEnabled] off every link share
/// call is a codeless `NotFound`. A new link gets the next id, a made-up
/// hash ([fakeLinkShareHash]), [me] as its author and `now`. A change to
/// the user's own share or to any team share asks [sync] for a quiet run,
/// as the real one does.
final class FakeProjectSharingRepository
    with _Calls
    implements ProjectSharingRepository {
  new({
    Map<int, FakeProjectShares>? projects,
    List<User> people = const [],
    Map<int, ({String name, int memberCount})> teamNames = const {},
    this.me = fakeMe,
    this.ownerUsername,
    this.linkSharingEnabled = true,
    this.sync,
    DateTime Function()? now,
  }) : projects = projects ?? {},
       people = [...people],
       teamNames = {...teamNames},
       _now = now ?? DateTime.now;

  final Map<int, FakeProjectShares> projects;
  List<User> people;
  Map<int, ({String name, int memberCount})> teamNames;
  User me;
  String? ownerUsername;
  bool linkSharingEnabled;
  SyncEngine? sync;
  final DateTime Function() _now;

  /// The requests of [createLinkShare], passwords included, in order.
  final List<NewLinkShare> createdLinks = [];

  FakeProjectShares sharesOf(int projectId) =>
      projects.putIfAbsent(projectId, FakeProjectShares.new);

  @override
  Future<List<ProjectUserShare>> userShares(int projectId) async {
    await _call('userShares', '$projectId');
    return List.unmodifiable(sharesOf(projectId).users);
  }

  @override
  Future<void> shareWithUser(
    int projectId,
    String username,
    Permission permission,
  ) async {
    await _call('shareWithUser', '$projectId $username ${permission.name}');
    final shares = sharesOf(projectId);
    final user = [
      me,
      ...people,
    ].where((person) => person.username == username).firstOrNull;
    if (user == null) throw const NotFound(code: 1005);
    if (username == ownerUsername ||
        shares.users.any((share) => share.user.username == username)) {
      throw const DomainError(409, code: 7002);
    }
    shares.users = [
      ...shares.users,
      ProjectUserShare(user: user, permission: permission),
    ];
  }

  @override
  Future<void> setUserPermission(
    int projectId,
    String username,
    Permission permission,
  ) async {
    await _call('setUserPermission', '$projectId $username ${permission.name}');
    final shares = sharesOf(projectId);
    shares.users = [
      for (final share in shares.users)
        if (share.user.username == username)
          ProjectUserShare(user: share.user, permission: permission)
        else
          share,
    ];
    if (username == me.username) _settle();
  }

  @override
  Future<void> removeUserShare(int projectId, String username) async {
    await _call('removeUserShare', '$projectId $username');
    final shares = sharesOf(projectId);
    if (!shares.users.any((share) => share.user.username == username)) {
      throw const Forbidden(code: 7003);
    }
    shares.users = [
      for (final share in shares.users)
        if (share.user.username != username) share,
    ];
    if (username == me.username) _settle();
  }

  @override
  Future<List<ProjectTeamShare>> teamShares(int projectId) async {
    await _call('teamShares', '$projectId');
    return List.unmodifiable(sharesOf(projectId).teams);
  }

  @override
  Future<void> shareWithTeam(
    int projectId,
    int teamId,
    Permission permission,
  ) async {
    await _call('shareWithTeam', '$projectId $teamId ${permission.name}');
    final shares = sharesOf(projectId);
    final team = teamNames[teamId];
    if (team == null) throw const NotFound(code: 6002);
    if (shares.teams.any((share) => share.teamId == teamId)) {
      throw const DomainError(409, code: 6004);
    }
    shares.teams = [
      ...shares.teams,
      ProjectTeamShare(
        teamId: teamId,
        teamName: team.name,
        memberCount: team.memberCount,
        permission: permission,
      ),
    ];
  }

  @override
  Future<void> setTeamPermission(
    int projectId,
    int teamId,
    Permission permission,
  ) async {
    await _call('setTeamPermission', '$projectId $teamId ${permission.name}');
    final shares = sharesOf(projectId);
    shares.teams = [
      for (final share in shares.teams)
        if (share.teamId == teamId)
          ProjectTeamShare(
            teamId: teamId,
            teamName: share.teamName,
            memberCount: share.memberCount,
            permission: permission,
          )
        else
          share,
    ];
    _settle();
  }

  @override
  Future<void> removeTeamShare(int projectId, int teamId) async {
    await _call('removeTeamShare', '$projectId $teamId');
    final shares = sharesOf(projectId);
    if (!shares.teams.any((share) => share.teamId == teamId)) {
      throw const Forbidden(code: 6007);
    }
    shares.teams = [
      for (final share in shares.teams)
        if (share.teamId != teamId) share,
    ];
    _settle();
  }

  @override
  Future<List<LinkShare>> linkShares(int projectId) async {
    await _call('linkShares', '$projectId');
    _checkLinkSharing();
    return List.unmodifiable(sharesOf(projectId).links);
  }

  @override
  Future<LinkShare> createLinkShare(int projectId, NewLinkShare share) async {
    createdLinks.add(share);
    await _call('createLinkShare', '$projectId ${share.permission.name}');
    _checkLinkSharing();
    final shares = sharesOf(projectId);
    final id = _nextId([
      for (final project in projects.values)
        for (final link in project.links) link.id,
    ]);
    final created = LinkShare(
      id: id,
      hash: fakeLinkShareHash(id),
      permission: share.permission,
      name: share.name ?? '',
      passwordProtected: share.password?.isNotEmpty ?? false,
      sharedBy: me,
      created: _now().toUtc(),
    );
    shares.links = [...shares.links, created];
    return created;
  }

  @override
  Future<void> deleteLinkShare(int projectId, int shareId) async {
    await _call('deleteLinkShare', '$projectId $shareId');
    _checkLinkSharing();
    final shares = sharesOf(projectId);
    shares.links = [
      for (final link in shares.links)
        if (link.id != shareId) link,
    ];
  }

  void _checkLinkSharing() {
    if (!linkSharingEnabled) throw const NotFound();
  }

  void _settle() {
    final sync = this.sync;
    if (sync != null) unawaited(sync.refreshAfterWrite().catchError((_) {}));
  }
}

/// Keeps every shared link in [shared]; [failure] is thrown instead while
/// set, and [available] false answers like a system without a share sheet.
final class FakeLinkShareActions implements LinkShareActions {
  final List<({Uri url, String? subject, Rect? origin})> shared = [];
  final List<({String text, String? subject, Rect? origin})> sharedTexts = [];
  Exception? failure;
  bool available = true;

  @override
  Future<bool> shareLink(Uri url, {String? subject, Rect? origin}) async {
    if (failure case final failure?) throw failure;
    shared.add((url: url, subject: subject, origin: origin));
    return available;
  }

  @override
  Future<bool> shareText(String text, {String? subject, Rect? origin}) async {
    if (failure case final failure?) throw failure;
    sharedTexts.add((text: text, subject: subject, origin: origin));
    return available;
  }
}
